// Runtify Cloud Functions
// Region: asia-northeast3 (서울)
// Runtime: Node.js 20

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// 전역 옵션: 서울 리전 + 메모리 한도 + 인스턴스 한도 (비용 폭주 방지)
setGlobalOptions({
  region: "asia-northeast3",
  memory: "256MiB",
  maxInstances: 10,
});

// ============================================================================
// 1. 주간 랭킹 변동 푸시 알림 (가설 1 검증 트리거)
// 매주 월요일 09:00 KST — 지난 주 vs 이번 주 랭킹 비교 후 변동 사용자에게 발송
// ============================================================================
exports.weeklyRankingChangePush = onSchedule(
  {
    schedule: "every monday 09:00",
    timeZone: "Asia/Seoul",
  },
  async (event) => {
    console.log("[weeklyRankingChangePush] 시작");

    try {
      // homeRegionGu 설정된 사용자만 대상 + fcmToken 있는 사용자만
      const usersSnapshot = await db
        .collection("users")
        .where("homeRegionGu", "!=", null)
        .where("deletedAt", "==", null)
        .get();

      let sent = 0;
      const batch = [];

      for (const userDoc of usersSnapshot.docs) {
        const user = userDoc.data();
        if (!user.fcmToken || !user.homeRegionGu) continue;

        // TODO: 지난 주 vs 이번 주 랭킹 변동 계산
        // - regionStats/{gu}_{prev_month}_xxx 조회 → 본인 위치 N
        // - regionStats/{gu}_{curr_month}_xxx 조회 → 본인 위치 M
        // - N != M 이면 메시지 발송 ("강남구 랭킹 변동! N → M위")
        // 임시: 항상 발송 (placeholder)
        const message = {
          token: user.fcmToken,
          notification: {
            title: "🏃 이번 주 랭킹 결과",
            body: `${user.homeRegionGu} 랭킹을 확인하세요!`,
          },
          data: {
            type: "weekly_ranking",
            region: user.homeRegionGu,
          },
          android: {
            priority: "high",
            notification: { channelId: "ranking_channel" },
          },
          apns: {
            payload: { aps: { sound: "default" } },
          },
        };

        batch.push(messaging.send(message).catch((e) => {
          console.warn(`FCM 발송 실패 uid=${userDoc.id}: ${e.message}`);
          // 무효 토큰이면 제거 (NotRegistered, InvalidRegistration)
          if (e.code === "messaging/registration-token-not-registered") {
            return userDoc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
          }
        }));
      }

      await Promise.allSettled(batch);
      sent = batch.length;
      console.log(`[weeklyRankingChangePush] 완료: ${sent}건 발송 시도`);
    } catch (error) {
      console.error("[weeklyRankingChangePush] 에러:", error);
      throw error;
    }
  }
);

// ============================================================================
// 2. 회원 탈퇴 30일 후 hard delete (POLICY § 4)
// 매일 04:00 KST — deletedAt + 30일 경과한 사용자 영구 삭제
// ============================================================================
exports.scheduledHardDelete = onSchedule(
  {
    schedule: "every day 04:00",
    timeZone: "Asia/Seoul",
  },
  async (event) => {
    console.log("[scheduledHardDelete] 시작");

    try {
      const cutoff = admin.firestore.Timestamp.fromMillis(
        Date.now() - 30 * 24 * 60 * 60 * 1000
      );

      const candidates = await db
        .collection("users")
        .where("scheduledHardDeleteAt", "<=", cutoff)
        .limit(100) // 1회 실행 최대 100명 (안전)
        .get();

      let deleted = 0;
      for (const userDoc of candidates.docs) {
        const uid = userDoc.id;
        try {
          // 1. Firestore subcollection 삭제 (badges, goals, personal_records, etc.)
          // TODO: 모든 subcollection 순회하여 batch delete
          // const subcollections = await userDoc.ref.listCollections();
          // for (const sub of subcollections) {
          //   const docs = await sub.listDocuments();
          //   await Promise.all(docs.map((d) => d.delete()));
          // }

          // 2. 본인 작성 running_sessions 삭제
          // TODO: where('userId', '==', uid) 모두 삭제

          // 3. 크루 멤버십 정리 (리더 위임은 Flutter에서 이미 강제됐을 것)
          // TODO

          // 4. user 문서 삭제
          await userDoc.ref.delete();

          // 5. Firebase Auth 계정 삭제
          await admin.auth().deleteUser(uid).catch((e) => {
            console.warn(`Auth 삭제 실패 uid=${uid}: ${e.message}`);
          });

          deleted++;
        } catch (e) {
          console.error(`Hard delete 실패 uid=${uid}:`, e);
        }
      }

      console.log(`[scheduledHardDelete] 완료: ${deleted}명 영구 삭제`);
    } catch (error) {
      console.error("[scheduledHardDelete] 에러:", error);
      throw error;
    }
  }
);

// ============================================================================
// 3. 회원 탈퇴 6자리 인증 코드 이메일 발송 (POLICY § 4)
// 클라이언트에서 onCall 호출 → 코드 생성 + 해시 저장 + 이메일 발송
// ============================================================================
exports.sendDeletionCodeEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }

  const uid = request.auth.uid;
  const userRecord = await admin.auth().getUser(uid).catch(() => null);
  if (!userRecord || !userRecord.email) {
    throw new HttpsError("not-found", "이메일 정보가 없습니다.");
  }

  // 6자리 랜덤 코드 생성 + 해시 저장
  const code = String(Math.floor(100000 + Math.random() * 900000));
  const hashedCode = crypto.createHash("sha256").update(code).digest("hex");
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + 10 * 60 * 1000 // 10분 TTL
  );

  await db.collection("users").doc(uid).collection("_deletion_codes").doc("active").set({
    hashedCode,
    expiresAt,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // TODO: 실제 이메일 발송 (SendGrid / Mailgun / SES 등)
  // 현재는 로그만 (개발용)
  console.log(
    `[sendDeletionCodeEmail] uid=${uid} email=${userRecord.email} code=${code} (실제 발송 미구현)`
  );

  // 프로덕션 전환 시 아래 활성화 (예시 — SendGrid):
  // const sgMail = require("@sendgrid/mail");
  // sgMail.setApiKey(process.env.SENDGRID_API_KEY);
  // await sgMail.send({
  //   to: userRecord.email,
  //   from: "noreply@runtify.app",
  //   subject: "[Runtify] 회원 탈퇴 인증 코드",
  //   text: `회원 탈퇴를 진행하려면 다음 6자리 코드를 입력하세요: ${code}\n10분 내 만료됩니다.`,
  // });

  return {
    success: true,
    expiresInSeconds: 600,
  };
});
