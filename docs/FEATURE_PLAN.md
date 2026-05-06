# Runtify 기능 기획서

> 작성일: 2026-03-04 / 최종 수정: 2026-05-06
> 규칙: **Figma 디자인 승인 → 코드 구현** 순서 필수
> 관련 문서: [POLICY.md](POLICY.md) (운영 정책), [STATUS.md](STATUS.md) (현재 상황)
> **완료 항목의 구현 detail은 git log + 코드 참조** — 이 문서는 미완료 / 의사결정 / 정책 중심

---

## 🤖 야간 PM 발견 갭

> `/pm-night` 실행 시 자동 갱신되는 섹션
> 🟢 = 야간 자동 구현 대상 / 🟡 = 사용자 검토 필요 / 🔴 = 정책·보안 결정 필요

### 🟢 자동 구현 대상 (다음 야간 작업 우선순위)

#### 미완료 (야간 큐)

- [ ] **[러닝v2] 워치 미연결 안내 (2026-04-28 정책 확정)** — 30분
  - 정책: BLE HRM 페어링 기록 있는데 현재 미연결 → 시작 화면 배너. "이 세션만 그냥 시작" 시 해당 세션 dismiss(다음 세션엔 다시 표시). 자동 재연결은 사용자 클릭 시에만
  - 구현: `running_page.dart` 시작 화면 상단 `WatchStatusBanner` 위젯, `flutter_blue_plus` 재연결, 세션 dismiss 플래그(Riverpod, 영속 X)
  - 파일: `lib/features/running/presentation/pages/running_page.dart`, `lib/features/running/presentation/widgets/watch_status_banner.dart` (신규)


- [ ] **[러닝v1] 일시정지/재시작 기능 (Phase 2 — 2026-04-28 추가)** — 70분
  - 정책: Strava/Nike 표준 — 일시정지 중 GPS·시간·거리 모두 멈춤. 재시작 시 누적 데이터 보존
  - 구현: `RunningProvider.isPaused/pause()/resume()`, Timer 일시정지, `running_page.dart` 3-button 레이아웃, "⏸ 일시정지 중" 배너
  - ⚠️ GPS stream pause/resume은 라이프사이클 위험으로 야간 보류 — 일시정지 중에도 stream은 살아있되 누적 로직만 차단

- [ ] **[러닝v1] 자동 일시정지 (정지 감지) (Phase 2 — 2026-04-28 추가)** — 60분
  - 정책: 속도 < 0.5 m/s가 5초+ 지속 시 자동 일시정지. > 1.0 m/s 회복 시 자동 재시작. Profile 토글 (기본 ON)
  - 구현: `RunningProvider`에 임계값 + debounce timer, 위 일시정지 기능과 통합


- [ ] **[가입 UX] 이메일 인증 Deep Link → 앱 자동 진입 (2026-04-27 추가)** — 60분 (Flutter 측만)
  - 현재: 인증 메일 링크 클릭 → Firebase 웹 페이지에서 "verified". 앱 다시 열어 "인증 완료 확인" 버튼 눌러야 반영
  - 개선: App Links(Android) / Universal Links(iOS) 설정 → 링크 클릭 시 앱 자동 열림 + 자동 reload + 토스트
  - 구현: `app_links` 패키지로 콜드/웜 진입 처리, `oobCode` 추출 → `applyActionCode` → 자동 reload
  - ⚠️ 호스팅 단계(`assetlinks.json`, `apple-app-site-association`) + Firebase Auth Action URL 설정은 사용자 직접 작업
  - 파일: `pubspec.yaml`, `lib/core/services/deep_link_handler.dart` (신규), `lib/main.dart`

- [ ] **[인증] 이메일 인증 — 잔여 가드 적용 (POLICY § 1)**
  - [ ] 러닝 트래킹 페이지 메인 saveSession 가드 (실기기 검증 필요, 야간 보류) — `requireEmailVerified` + 로컬 큐 enqueue
  - [ ] 크루 게시글 작성 가드 — 호출부 페이지 신설 시 적용 (헬퍼 준비 완료)
  - [ ] 리워드 교환 가드 — 리워드 스토어 구현 시 적용
  - [ ] 로컬 큐잉된 러닝 데이터 자동 flush — 러닝 가드와 함께 차기 세션
  - [ ] "러닝 시작 1회 유예" 상태 머신 — 차기 세션 (실기기 필요)

- [ ] **[인증] 세션 만료 — running_page hookup (POLICY § 3)**
  - [ ] `running_page.dart` initState에서 `runningInProgressProvider.notifier.state = true`, dispose/`_stopRun`에서 false (GPS 라이프사이클 영역 — 데스크톱 세션)
  - [ ] saveSession 실패 시 `RunningSyncQueue.enqueue` 호출
  - [ ] 앱 재시작 / 온라인 복귀 시 자동 flush — `connectivity_plus` 새 의존성 결정 필요 (🟡)
  - [ ] 홈 상단 "동기화 대기 N건" 배너 위젯
  - [ ] 이메일 인증 가드와 큐 공유

- [ ] **[네트워크] Firebase 호출 timeout 30초 적용 (2026-05-06 결정)** — 60분
  - 결정: **모든 Firebase call 30초 timeout** (보수적 — 데이터 유실 방지)
  - 구현: `lib/core/utils/firebase_timeout.dart` 신설 — `withFirebaseTimeout<T>(Future<T>)` 헬퍼 (TimeoutException 발생 시 명확한 에러 메시지로 변환)
  - 호출부 적용: `auth_firebase_datasource.dart`, `running_firestore_datasource.dart`, `crew_firestore_datasource.dart`, `goal_firestore_datasource.dart`, `course_firestore_datasource.dart`, `regionStats` 관련 등
  - 단위 테스트: timeout 시 친절 에러 메시지, 정상 흐름 통과
  - 파일: `lib/core/utils/firebase_timeout.dart` (신규), 호출부 6개+

- [ ] **[기능] 닉네임 사후 변경 — 30일 1회 제한 (2026-05-06 결정)** — 90분
  - 결정: **30일 1회 변경 가능** (Strava 정책 참고, 악용/공격 방지 + UX 균형)
  - 구현 체크리스트:
    - [ ] `UserEntity`/`UserModel` 에 `nameChangedAt: DateTime?` 필드 추가, Firestore 양방향 직렬화
    - [ ] `core/services/nickname_change_policy.dart` 신설 — `canChangeNickname(nameChangedAt) → bool`, `daysUntilChangeable(nameChangedAt) → int` (30일 윈도우 계산)
    - [ ] `auth_firebase_datasource.changeNickname(uid, newName)` 추가 — 기존 `NicknameAvailability` 검증 재사용 + `nameChangedAt = now` 갱신
    - [ ] `AuthRepository`/`AuthRemoteDataSource`/`AuthNotifier` 체인 노출
    - [ ] `profile_page.dart`에 닉네임 옆 편집 아이콘 → `ChangeNicknameDialog` (검증 + 30일 미만 시 "X일 후 변경 가능" disabled 안내)
    - [ ] 단위 테스트 (정책 함수 + UseCase)
    - [ ] `flutter analyze --no-pub` + `flutter test` 통과
  - 파일: `lib/core/services/nickname_change_policy.dart` (신규), `lib/features/auth/presentation/widgets/change_nickname_dialog.dart` (신규), 외 5개

- [ ] **[데이터] wakelock_plus 도입 (2026-05-06 결정)** — 50분
  - 결정: **wakelock_plus 패키지 도입** (알림 권한 거부 시에도 화면 켜짐 보장 + GPS 정확도 보장)
  - 구현 체크리스트:
    - [ ] `pubspec.yaml`에 `wakelock_plus: ^1.x.x` 추가
    - [ ] `running_page.dart` `_startRun()` 에서 `WakelockPlus.enable()`, `_stopRun()` + dispose에서 `WakelockPlus.disable()`
    - [ ] try/catch로 미지원 플랫폼(웹)에서 폴백
    - [ ] Profile에 "러닝 중 화면 켜짐 유지" 토글 추가 (기본 ON, SharedPreferences)
    - [ ] `flutter analyze --no-pub` + `flutter test` 통과
  - ⚠️ **실기기 라이프사이클 검증 필수** — 백그라운드 진입/복귀 시 wakelock 상태 확인
  - 파일: `pubspec.yaml`, `lib/features/running/presentation/pages/running_page.dart`, `lib/features/auth/presentation/pages/profile_page.dart`

- [ ] **[계정] 회원 탈퇴 플로우 — Flutter 측 (2026-05-03 추가, POLICY § 4 기반)** — 180분
  - 분리 원칙: **Flutter 측은 야간 자동, Cloud Functions / 이메일 발송 / 약관 변호사 검토는 사용자 직접** (출시 직전 묶음)
  - 구현 체크리스트 (Flutter 측 야간):
    - [ ] `UserEntity`/`UserModel` 에 `deletedAt: DateTime?`, `scheduledHardDeleteAt: DateTime?` 필드 추가
    - [ ] `auth_firebase_datasource.getCurrentUser` 등에서 `deletedAt != null` 시 복구 화면으로 분기
    - [ ] `lib/core/services/account_deletion_service.dart` 신설 — `requestDeletion`/`confirmDeletion`/`recoverAccount`. 6자리 코드는 SHA256 해시로 subdoc(TTL 10분) 저장
    - [ ] 이메일 코드 발송은 Flutter 측 placeholder — 실제 발송은 Cloud Functions(추후)
    - [ ] `AuthRepository`/`AuthRemoteDataSource`/`AuthNotifier` 체인 노출
    - [ ] 크루 리더 탈퇴 검증: 본인 리더 + 멤버 1명+ 시 거부 + 양도 안내
    - [ ] 프로필 하단 "계정 삭제" 버튼 → `AccountDeletionDialog` (1차: 비번/소셜 재로그인 → 2차: 이메일 코드)
    - [ ] 30일 내 재로그인 시 `RecoverAccountPage` 자동 표시 (router에 추가)
    - [ ] 모든 user/running/crew 조회 쿼리에 `where('deletedAt', '==', null)` 클라이언트 필터
    - [ ] 단위 테스트 + `flutter analyze` + `flutter test`
  - **사용자 직접 작업 (출시 2주 전 묶음)**: Cloud Functions (`scheduledHardDelete` cron + `sendDeletionCodeEmail` + `FirebaseAuth.delete()` 30일 후) / Blaze 요금제 / 약관 탈퇴 조항 + 변호사 검토 / App Store 심사 메모

#### 완료 (한 줄 요약, 상세는 git log)

- [x] **🌙 [입력 검증] 목표 입력 극단값 차단** (2026-05-06) — 야간 PM 발견 갭. `GoalTypeExtension.maxAllowedValue` + `validateInputValue`, `_AddGoalBottomSheet` errorText 즉시 피드백 (주간 200km/월간 800km/주간 21회/streak 365일). 153 tests pass
- [x] **🌙 [러닝v1] 1km 음성 안내 (TTS)** (2026-05-06) — `flutter_tts` 추가, `RunningVoiceAnnouncer` (한국어, formatAnnouncement 단위 테스트), Profile 토글(기본 ON, SharedPreferences). 147 tests pass
- [x] **🌙 [러닝v1] 결과 페이지 차트 강화** (2026-05-06) — `RunningSample` 10초 샘플링, `SessionChartCard` (페이스/고도/심박 탭, 페이스 Y축 반전, 0값 무시). result/detail 페이지 통합. 139 tests pass
- [x] **🌙 [러닝v2] 주간·월간 통계 페이지** (2026-05-06) — `fl_chart` 추가, 4번째 탭 "통계", `StatsSummary.aggregate` 순수 함수(주간 일별/월간 주차별), 거리 가중 평균 페이스. 136 tests pass
- [x] **🌙 [러닝v2] GPS 신호 강도 표시** (2026-05-06) — `gpsSignalProvider` autoDispose StreamProvider, `classifyAccuracy` (≤10m good/≤25m ok/>weak), 시작 전 우측 상단 배지, 약함 시 경고 다이얼로그. 129 tests pass
- [x] **🌙 [러닝v2] 랩(Lap) 기능 — 1km 자동 분할** (2026-05-06) — `LapData` 엔티티(km/splitSeconds/pace/avgHeartRate), `LapTable` 위젯(가장 빠른 랩 강조), 백업 스냅샷 + 모델 직렬화. 122 tests pass
- [x] **🌙 [러닝v2] 잠금 화면 (실수 터치 방지)** (2026-05-06) — `LockSwipeTracker`(거리·시간 동시 100px+/2초+, 아래로 이동 시 리셋), `LockOverlay` Positioned.fill + opaque 흡수. 116 tests pass
- [x] **🌙 [러닝v2] 자동 저장 (crash 복구)** (2026-05-06) — `RunningBackup` 30초 주기 SharedPreferences, `RunningRecoveryHandler` 홈에서 첫 build 후 다이얼로그(저장/버리기), 0.1km/60초 미만 노이즈 필터. 107 tests pass
- [x] **[러닝/GPS] 알림 권한 거부 시 GPS stream 죽는 이슈 + 자동 재구독** (2026-05-03) — `_subscribePositionStream` 헬퍼, onError 1s/2s/4s backoff (max 3회). 부수 픽스: `android/app/build.gradle.kts` Properties import. 99 tests pass. ⚠️ 실기기 검증 필수
- [x] **[온보딩/UX] AsyncValue 에러 메시지 정리 + 공통 ErrorView 위젯** (2026-04-28) — `friendly_error.dart` + `error_view.dart`, 16개 페이지 적용. 93 tests pass
- [x] **[러닝v2] 개인 최고 기록(PB) 자동 추적** (2026-04-28) — 5종 거리(1k/5k/10k/하프/풀), `personal_record_service.dart`, Firestore subcollection, result/profile 배너. 99 tests pass
- [x] **[러닝v2] 러닝 데이터 편집 — 제목/메모** (2026-04-28) — `EditSessionDialog`, `RunningDataSource.updateSession`, 30자/200자 제한, 제어 문자 차단. 99 tests pass
- [x] **[관측성] FirebaseCrashlytics + Analytics — Flutter 측** (2026-04-28) — `runZonedGuarded`, `AuthNotifier` listener로 setUserIdentifier/setUserId, 호출부 6곳. ⚠️ 네이티브 편집 사용자 직접 작업 (Android Gradle 플러그인, iOS Run Script Phase)
- [x] **[입력 검증] 닉네임 — 욕설/사칭/이모지/grapheme + Firestore 중복 검사** (2026-04-28) — `NameValidator` + `NicknameAvailability` (`nameNormalized` 인덱스 필요). ⚠️ 사용자 작업: `firestore.indexes.json` 배포
- [x] **[가입 UX] 마케팅 수신 동의 분리 (선택)** (2026-04-28) — `marketingConsent`/`marketingConsentAt` 필드, Profile 토글
- [x] **[가입 UX] autofill hints (비번 매니저 호환)** (2026-04-28) — `AutofillGroup` + email/password/newPassword/name hints
- [x] **[가입 UX] 같은 이메일 다른 provider 친절 안내** (2026-04-28) — `provider_conflict_message.dart` (Google/Apple/password 우선순위), `account-exists-with-different-credential` 처리
- [x] **[가입 UX] Apple "Hide My Email" 가짜 이메일 처리** (2026-04-28) — `apple_email.dart`, `appleHiddenEmail: bool` 필드
- [x] **[가입 UX] 가입 직후 홈 지역 설정 강제 온보딩** (2026-04-24) — `/onboarding/home-region` 전체화면, `auth_router_state.dart`, redirect 로직
- [x] **[가입 UX] 이메일 회원가입 약관·개인정보 동의 체크박스** (2026-04-24) — 회원가입 전용, `TermsOfServicePage` + `PrivacyPolicyPage`
- [x] **[인증] 이메일 인증 플로우 — 스캐폴딩** (2026-04-23) — `emailVerified` 필드, `sendEmailVerification` 자동, OAuth 자동 true, `EmailVerificationCooldown`(슬라이딩 윈도우 5분/3회), `VerifyEmailDialog`. 정책 확정: POLICY § 1
  - 적용된 가드: 크루 가입 신청, 러닝 결과 랭킹 기여 지역 확정 (2026-04-26 완료, `requireEmailVerified` 헬퍼)
- [x] **[인증] 세션 만료 + 러닝 중 로그아웃 차단 — 부분** (2026-04-28) — `runningInProgressProvider`, `AuthNotifier idTokenChanges` 리스너, `RunningSyncQueue` (SharedPreferences). 차기: running_page hookup
- [x] **[인증] 로그인 실패 레이트 리밋 — Phase 1 로컬** (2026-04-23) — `login_rate_limiter.dart`, 3회/60초, SharedPreferences 키 hashCode 난독화. 한계: 앱 재설치 시 초기화 (Phase 2 서버는 출시 직전)
- [x] **[인증] 비밀번호 표시/숨김 토글 + autocorrect 차단** (2026-04-22)
- [x] **[인증] 회원가입 비밀번호 확인 입력 필드** (2026-04-22)
- [x] **[인증] 닉네임 입력 검증·정규화** (2026-04-22) — `name_validator.dart` (2~20자, 제어 문자 차단)
- [x] **[인증] 소셜 로그인 화면 — 카카오·네이버 + 순서 재배치** (2026-04-22)
- [x] **[인증] Firebase 에러 코드 → 사용자 친화 메시지 맵핑** (2026-04-20)
- [x] **[인증] 이메일 형식 검증 및 정규화** (2026-04-20) — `email_validator.dart`
- [x] **[인증] 로그아웃 후 민감 데이터 클리어 보강** (2026-04-20) — BLE/Health Connect 키 삭제
- [x] **[인증] 비밀번호 복잡도 규칙** (2026-04-20) — `password_validator.dart` (8자+, 대·소·숫자, 흔한 비번 차단), `PasswordStrengthBar`
- [x] **[인증] 비밀번호 재설정** (2026-04-22) — `ForgotPasswordUseCase`, `_ForgotPasswordSheet`, 통일 응답(계정 존재 노출 X). Firebase Console 템플릿 완료(2026-04-23)
- [x] **[가입 UX] OAuth 가입자 닉네임 처리** (2026-04-24) — Google displayName 그대로, 추가 작업 없음

### 🟡 기획 확정 대기 (사용자 검토 후 구현)

- [ ] **[접근성] Semantics 라벨 + textScaler — 운영 단계로 연기 (2026-04-28 결정)**
  - 출시 후 사용자 1만 명 도달 시점에 시작 — MVP에서는 도입 안 함

#### 📦 런닝페이즈 — 출시 후 운영 단계 작업 (2026-04-28 사용자 결정)

- [ ] **[R2] 목표 페이스 알림** — 시작 전 목표 페이스 입력 → 실제 페이스 ±N초 차이 시 음성/진동
- [ ] **[R7] 운동 종류 선택** — 러닝/조깅/걷기/하이킹/사이클 (현재 러닝만)
- [ ] **[R9] 공유 기능** — 결과 화면 이미지로 인스타/카카오 공유
- [ ] **[R10] 수동 거리 보정** — GPS 부정확 시 사용자 직접 km 입력
- [ ] **[R12] iOS Live Activity / Dynamic Island** — iOS 16+ 가시성
- [ ] **[R13] 음악 컨트롤 통합** — Spotify/Apple Music 위젯
- [ ] **[R14] 러닝 비교** — 같은 코스 두 번 달릴 때 비교 (Phase 8 코스 저장과 연동)
- [ ] **[R15] Year in Review** — 연말 리포트, 마케팅 자산
- [ ] **[R16] 응급 연락처 / 운동 강도 경고** — 안전 기능
- [ ] **[R17] Apple HealthKit / Strava / Garmin 동기화** — 출시 로드맵에 등록됨

### 🔴 사용자 결정 필요 (보안·정책 critical)

(현재 활성 항목 없음 — 모두 정책 확정 또는 출시 로드맵으로 이관)

---

## 출시 로드맵

### 🚀 1차 출시 — Android + Galaxy Watch
> Galaxy Watch → 삼성 헬스 앱 → Health Connect → Runtify (`health` 패키지)
> 실시간 심박수: BLE HRM → `flutter_blue_plus` (구현 완료)

| 항목 | 상태 | 비고 |
|------|------|------|
| Android 앱 / Health Connect / BLE 심박수 | ✅ | 코드 완료 |
| Health Connect 온보딩 UI | ⬜ 개발 필요 | 유저에게 Health Connect + 삼성 헬스 동기화 안내 |
| 워치 러닝 기록 홈 연동 | ⬜ 개발 필요 | Health Connect 과거 데이터 → 홈 대시보드 |
| BLE 연결 온보딩 UI | ⬜ 개발 필요 | 갤럭시 워치 심박수 페어링 안내 |
| 🔐 레이트 리밋 Phase 2 (서버) | ⬜ **출시 2주 전** | Cloud Functions, **Blaze 요금제 전환 필요** ($0~5/월). [POLICY § 2](POLICY.md) |
| 🔴 계정 탈퇴 플로우 (Cloud Functions 측) | ⬜ **출시 직전 필수** | App Store 심사 요건. [POLICY § 4](POLICY.md) — 소프트 삭제 30일 + 이중 재인증. Flutter 측은 야간 큐 등록됨 |
| ⚖️ 약관 변호사 검토 1회 | ⬜ **출시 직전 필수 (2026-04-27)** | 현재 MVP 8조 → 보완 |
| 🏢 사업자 정보 채우기 | ⬜ **출시 직전 필수 (2026-04-27)** | 약관·앱 내 사업자 정보 표시 |
| Play Store 출시 | ⬜ 준비 필요 | 스토어 등록, 스크린샷, 설명 |

#### Android 실기기 테스트 이슈 (2026-04-19 발견)
- [ ] 🔴 **러닝 중 GPS 위치 업데이트 안 됨** — 거리 0km 고정. 코드 수정 완료(2026-05-03), **실기기 검증 필수**
  - 수정: `running_page.dart` 알림 권한 await + `ForegroundNotificationConfig` 조건부 + onError backoff 재구독
  - 재현: 앱 실행 → 러닝 시작 → 걷거나 뜀 → 화면상 거리 0.00km 유지 시 검증 실패

### 📱 2차 업데이트 — iOS 출시
> iOS 코드 이미 완성, 계정 등록만

| 항목 | 상태 | 비고 |
|------|------|------|
| iOS 앱 코드 | ✅ | Flutter 크로스 플랫폼 |
| Apple Developer 등록 | ⬜ **Android 출시 1개월 전 (2026-04-26 결정)** | $99/년. 등록 후 Apple 로그인 + 심사 준비 시작 |
| Apple 로그인 활성화 | ⬜ Apple Developer 등록 후 | 소셜 로그인 제공 시 필수 |
| App Store 심사 | ⬜ 필요 | 회원 탈퇴 (30일 소프트 삭제로 정책 확정) |

#### iOS 실기기 테스트 이슈 (2026-04-19 발견)
- [x] iPhone 17 Pro Max 화면 비율 대응 (2026-04-19) — `MaterialApp.builder` 플랫폼 분기, iOS deployment target 13→15
- [x] iOS 엣지 스와이프 뒤로가기 (2026-04-20) — `_platformPage()` 헬퍼, iOS=`CupertinoPage`
- [x] 러닝 시작 후 경과 시간 미증가 (2026-04-19) — Timer를 알림 권한 요청보다 먼저 등록
- [ ] 🔴 **러닝 중 백그라운드 복귀 시 크래시** — 러닝 시작 → 홈(백그라운드) → 앱 복귀 시 즉시 종료
  - 원인 추정: `WidgetsBindingObserver` 복귀 처리 누락, GPS/BLE 스트림 재구독 실패, UIBackgroundModes(`location`)에 대응하는 Xcode Capability(**Background Modes → Location updates**) 미설정 가능성
  - 확인 파일: `lib/features/running/presentation/pages/running_page.dart`, Xcode `Signing & Capabilities`

### ⌚ 3차 업데이트 — Apple HealthKit
| Apple HealthKit 연동 / Apple Watch 심박·거리 동기화 | ⬜ | iOS 유저 확보 후 진행 |

### ⌚ 4차 업데이트 — Garmin Connect API
| Garmin Connect API 연동 | ⬜ | OAuth 인증 → 자동 동기화. 워치 앱 개발 ❌ 불필요 (Strava와 동일) |

### 크루 소셜 기능 (Strava 대비 보완)
| 우선순위 | 기능 | 상태 |
|----------|------|------|
| 🔴 1 | 크루 게시글/피드 (글/사진/댓글/좋아요) | ⬜ |
| 🔴 2 | 크루 이벤트 (날짜/장소/루트, 참가하기) | ✅ |
| 🔴 3 | 크루 멤버 관리 (역할/가입일/기여도/퇴출) | ⬜ |
| 🟡 4 | 공개/비공개 크루 (가입 승인제) | ⬜ |

### 추후 검토
- [ ] 리워드 쿠폰 코드 — 자동 생성 난수? 외부 API 연동?
- [ ] Coros/Suunto 등 기타 워치 연동

---

## 완료된 Phase (압축)

> 상세 구현 detail은 git log + 코드 참조. 각 Phase의 정책/배경만 유지.

- [x] **Phase 0 — 네비게이션 구조 개편** — 5탭(홈/러닝/크루/랭킹/리워드) + 러닝 내부 3탭(기록/캘린더/목표)
- [x] **Phase 1 — 포인트 시스템 고도화** — 거리×10 + 속도보너스(페이스 5'00"/km 이하 +5P/km) × 스트릭배율(3일×1.2, 7일×1.5). users 컬렉션에 points/experience/level/streak/lastRunDate
  - 미완료: EXP 레벨 공식 고도화 (Lv.N→N+1: 이전 × 2, 현재 단순 100exp = 1레벨)
- [x] **Phase 2 — 크루 기능 Firebase 연동** — 생성/가입/탈퇴/멤버 조회, 1인 1크루, crewPoints/monthlyPoints 트랜잭션 자동 누적
- [x] **Phase 3 — 지역 계층형 랭킹** — 동/구/시 3단계, geocoding 패키지 매핑(subLocality/locality/administrativeArea), `regionStats/{level}_{name}_{YYYY-MM}` 구조, geocoding 실패 시 수동 BottomSheet
- [x] **Phase 3.5 — 러닝 캘린더** — `table_calendar` 월간, 러닝한 날 점/아이콘 표시, 날짜별 기록 목록, 이번 달 통계 요약
- [x] **Phase 4 — 프로필 홈 지역 설정 (GPS)** — GPS + 역지오코딩, `users.homeRegionSi/Gu/Dong`, 랭킹 "내 지역" 배너 homeRegion 기준
- [x] **Phase 5 — 런닝 위치 컨펌 + 랭킹 기여 지역 분리** — `geoRegion` (실제 GPS) + `rankingRegion` (홈 지역 우선) 분리. 시작=종료 구 다를 시 결과 페이지 컨펌 카드. 홈 지역 설정자는 컨펌 없이 자동
- [x] **Phase 6 — 배지 & 칭호 시스템** — 6종 배지 (불꽃 러너 7일 / 새벽 러너 / 스피드 마스터 4'30"/km 5km / 지역 지킴이 구 1위 / 원정대 5개 구 / 100km 클럽). `users/{id}/badges` 서브컬렉션
- [x] **Phase 7 — 크루 위클리 챌린지** — 합산 거리/참여 인원/연속 달리기 3유형, 리더만 생성, 진행 중 챌린지 progress 자동 업데이트, 달성 시 크루 전체 보너스 포인트
- [x] **Phase 8 — 런닝 코스 저장 & 공유** — 결과 페이지 "코스 저장", 코스 이름/난이도(1~5), 지역별 인기 코스 리스트, "이 코스로 달리기"
- [x] **Phase 9 — 목표(Goals) 기능** — 4타입(weekly_distance/monthly_distance/weekly_count/streak), 진행률 카드, BottomSheet 추가/수정/삭제, 자동 progress 업데이트

---

## UI/UX 개선 과제

### 🎨 지도 스타일 컬러화
- **현재:** 러닝 지도 흑백(다크 모노크롬)
- **목표:** 도로/건물/공원 색상 구분되는 컬러 지도 — 다크 테마 조화, Primary `#FF4D00`와 충돌 X
- **영향 화면:** `running_page.dart`, `running_result_page.dart`, 러닝 기록 상세, 코스 상세
- **작업 순서:** `/design` Figma 비교 → Google Maps Style JSON (https://mapstyle.withgoogle.com) → `/coding` 적용

---

## 🍎 Apple 로그인 (앱스토어 출시 전 필수)

> Apple Developer Program 가입 필요 ($99/년)
> App Store 정책: 소셜 로그인 제공 시 Apple 로그인 반드시 포함 (미준수 = 심사 거절)

### 구현 체크리스트
- [ ] Apple Developer Console → App ID에 "Sign In with Apple" 활성화
- [ ] Firebase Console → Authentication → Apple 로그인 사용 설정
- [ ] Xcode → Signing & Capabilities → "Sign In with Apple" 추가
- [ ] 실기기 테스트 (시뮬레이터 불가)

### 코드 현황
- Flutter 코드 완성 (`auth_firebase_datasource.dart`, `social_login_page.dart`)
- Apple Developer 계정 등록 후 위 체크리스트만 완료하면 즉시 동작

### 주의사항
- Apple은 최초 로그인 시에만 이름/이메일 제공 → 재로그인 시 null
- 회원 탈퇴 기능 앱 내 제공 필수 (미구현 = 심사 거절)
