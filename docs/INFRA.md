# Runtify 인프라 / 배포

> Firebase 백엔드·Cloud Functions·Hosting·배포 절차 단일 소스.
> 일상 개발은 [DEV_GUIDE.md](DEV_GUIDE.md), 1회성 셋업은 [SETUP.md](SETUP.md).
> 최종 갱신: 2026-05-09 (Blaze 전환 + Functions/Hosting/인덱스 dev 배포 완료)

---

## Firebase 프로젝트

| 환경 | 프로젝트 ID | 용도 |
|------|------------|------|
| **Dev** (기본) | `runtify-dev` | 개발/검증 — 모든 인프라 작업은 여기 먼저 |
| **Prod** | `runtifydb` | 실사용자 — 출시 직전 동기화 |
| 요금제 | **Blaze (종량제)** | 2026-05-09 전환. 예산 알림 $5 권장 |

배포는 항상 `--project=runtify-dev` 명시. prod는 출시 직전 동일 절차 반복.

---

## Cloud Functions (`functions/`)

Node.js 20 · firebase-functions v6 · 서울 리전(`asia-northeast3`) · maxInstances 10

| 함수 | 트리거 | 상태 |
|------|--------|------|
| `weeklyRankingChangePush` | scheduled 월 09:00 KST | ⚠️ placeholder — 랭킹 비교 로직 TODO |
| `scheduledHardDelete` | scheduled 매일 04:00 KST | ⚠️ placeholder — subcollection 정리 TODO |
| `sendDeletionCodeEmail` | callable | ⚠️ placeholder — SendGrid 연동 TODO |

배포:
```bash
firebase deploy --only functions --project=runtify-dev
firebase functions:list --project=runtify-dev   # 확인
firebase functions:log --project=runtify-dev    # 로그
```

> ⚠️ Cloud Functions v2 첫 배포 시 권한 에러 → IAM에서 Compute 기본 SA(`{projectNumber}-compute@developer.gserviceaccount.com`)에 Editor 또는 (Cloud Build Service Account + Artifact Registry Writer + Cloud Run Developer + Service Account User + Logs Writer) 부여.

---

## Hosting (`hosting/`)

`runtify-dev.web.app` — Deep Link 도메인 인증용.

| 파일 | 용도 |
|------|------|
| `.well-known/assetlinks.json` | Android App Links (debug SHA-256 등록됨, **release SHA-256 추가 필요**) |
| `.well-known/apple-app-site-association` | iOS Universal Links (**`TEAMID` placeholder — Apple Developer 후 교체**) |
| `index.html` | 간단 랜딩 |

배포:
```bash
firebase deploy --only hosting --project=runtify-dev
curl https://runtify-dev.web.app/.well-known/assetlinks.json   # 검증
```

---

## Firestore

```bash
firebase deploy --only firestore:rules --project=runtify-dev
firebase deploy --only firestore:indexes --project=runtify-dev
```

- `firestore.rules` — 보안 규칙
- `firestore.indexes.json` — 복합 인덱스(regionStats, joinRequests) + `users.nameNormalized` 단일 필드(닉네임 중복 검사)

---

## 사용자 직접 작업 체크리스트

### 출시 전 (지금 가능)
- [ ] 예산 알림 $5 설정 (Cloud Console → 결제 → 예산)
- [ ] Firebase Auth Action URL → `https://runtify-dev.web.app/__/auth/action` (Console → Authentication → Templates: 비번 재설정 + 이메일 인증 둘 다)
- [ ] Cloud Functions TODO 로직 채우기 (랭킹 비교 / hard delete subcollection / SendGrid) — `/pm-night` 가능

### Apple Developer 등록 후
- [ ] iOS Crashlytics Run Script (Xcode → Runner → Build Phases → `${PODS_ROOT}/FirebaseCrashlytics/run`)
- [ ] APNS 키 발급 → Firebase Console 등록
- [ ] `apple-app-site-association`의 `TEAMID` → 실제 Team ID 교체 후 재배포

### 출시 직전
- [ ] release keystore SHA-256 → `assetlinks.json` 추가 후 재배포
- [ ] 전체 인프라 `runtifydb`(prod)에 동일 배포 (functions/hosting/firestore)
- [ ] prod Blaze + 예산 알림

---

## 배포 순서 (출시 직전 prod)

```bash
P=runtifydb
firebase deploy --only firestore:rules,firestore:indexes --project=$P
firebase deploy --only functions --project=$P
firebase deploy --only hosting --project=$P
firebase functions:list --project=$P   # 검증
```
