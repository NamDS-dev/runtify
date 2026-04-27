# Runtify 기능 기획서

> 작성일: 2026-03-04
> 최종 수정: 2026-04-21
> 규칙: **Figma 디자인 승인 → 코드 구현** 순서 필수
> 관련 문서: [POLICY.md](POLICY.md) — 운영 정책 결정(이메일 인증·레이트 리밋·세션·탈퇴)

---

## 🤖 야간 PM 발견 갭

> `/pm-night` 실행 시 자동 갱신되는 섹션
> PM이 기획 오딧(코드/UX ↔ 모범사례 비교)으로 누락된 항목 기록
> 🟢 = 야간 자동 구현 대상 / 🟡 = 사용자 검토 필요 / 🔴 = 정책·보안 결정 필요

### 🟢 자동 구현 대상 (다음 야간 작업 우선순위)

- [ ] **[입력 검증] 닉네임 규칙 강화 — 욕설·중복·사칭·이모지·grapheme (2026-04-27 추가)**
  - 현재: `NameValidator`는 길이 2~20자 + 제어 문자 차단만. 추가 보호 규칙 필요
  - 정책 (한 번에 모두 적용):
    1. **욕설/비속어 필터** — `assets/badwords_ko.json` 자체 사전(핵심 50~100단어) 기반. 대소문자 무관, 공백/특수문자 제거 후 매칭
    2. **닉네임 중복 검사** — Firestore `users` 컬렉션에 `nameNormalized: string` 필드 추가, `where('nameNormalized', '==', normalize(input))` 쿼리. 트랜잭션으로 동시성 보장
    3. **운영진 이름 사칭 차단** — `assets/reserved_names.json`에 하드코딩 리스트 (관리자, 운영자, admin, 운영팀, runtify, runtify팀, anthropic, claude, 공지사항, 고객센터, system, 시스템 등). 정규화 후 부분 매치 차단
    4. **숫자만 닉네임 차단** — `^\d+$` 정규식 매치 시 거부 ("닉네임에 글자를 포함해주세요")
    5. **이모지만 닉네임 차단** — 모든 grapheme이 이모지면 거부 ("닉네임에 텍스트를 포함해주세요"). `characters` 패키지의 `Characters` 사용
    6. **이모지 grapheme 카운트 정확화** — `value.length` 대신 `value.characters.length`로 측정 (🔥를 1자로 셈)
  - 구현 체크리스트:
    - [ ] `assets/badwords_ko.json` 신규 (50~100단어 리스트, 추후 운영 중 보강)
    - [ ] `assets/reserved_names.json` 신규 (운영진 사칭 단어 리스트)
    - [ ] `pubspec.yaml`에 두 에셋 등록
    - [ ] `NameValidator.validate`에 5개 추가 규칙 통합 + grapheme 길이 측정으로 변경
    - [ ] `NameValidator.containsBadword(input)` / `isReserved(input)` 정적 메서드 분리 (테스트 편의)
    - [ ] Firestore 중복 쿼리는 별도 클래스로 분리 (`NicknameAvailability` 서비스, 비동기) — `NameValidator`는 sync 검증, 중복은 별도 단계
    - [ ] `signUpWithEmail` 흐름: 폼 sync 검증 → 비동기 중복 검사 → Firebase 가입. 가입 직후 `nameNormalized` 필드도 같이 저장
    - [ ] 기존 사용자 마이그레이션: `users` 컬렉션에 `nameNormalized` 누락 문서가 있을 수 있으므로 `getCurrentUser` 시 backfill (현재 name → nameNormalized) 한번 동기화
    - [ ] 단위 테스트:
      - [ ] 욕설 포함 차단 (3건+)
      - [ ] 운영진 이름 차단 (관리자/admin/runtify팀 등 4건+)
      - [ ] 숫자만 차단 ("12345")
      - [ ] 이모지만 차단 ("🔥🔥")
      - [ ] grapheme 길이 — "🔥" 1자로 카운트 (기존 `length`는 2)
      - [ ] grapheme 길이 — "abc🔥def" 7자로 카운트
      - [ ] 정상 케이스 (한글+이모지 조합 "러너🔥") 통과
  - 파일: `lib/core/validators/name_validator.dart`, `lib/core/services/nickname_availability.dart` (신규), `assets/badwords_ko.json` (신규), `assets/reserved_names.json` (신규), `pubspec.yaml`, `lib/features/auth/data/datasources/auth_firebase_datasource.dart`, `lib/features/auth/data/models/user_model.dart`, `test/core/validators/name_validator_test.dart` (확장), `test/core/services/nickname_availability_test.dart` (신규)
  - 예상: 100분
  - **⚠️ 주의**: Firestore 중복 쿼리에 인덱스 자동 생성 필요할 수 있음. 야간 PM은 `firestore.indexes.json` 변경 금지 → 인덱스 필요 시 사용자 직접 작업으로 분리 (Firebase Console에서 자동 생성 링크 클릭). 이미 `email` 필터에 인덱스가 있어서 단일 필드 쿼리는 가능할 가능성 높음

- [ ] **[가입 UX] 이메일 인증 Deep Link → 앱 자동 진입 (2026-04-27 추가, 모범사례 갭)**
  - 현재: 인증 메일 링크 클릭 → Firebase 웹 페이지에서 "verified" 표시. 사용자가 앱 다시 열어 "인증 완료 확인" 버튼 눌러야 반영
  - 개선: App Links(Android) / Universal Links(iOS) 설정 → 링크 클릭 시 앱 자동 열림 + 자동 reload + 인증 완료 토스트
  - 구현 체크리스트:
    - [ ] Firebase Auth Action URL을 커스텀 도메인 또는 App Hosting URL로 설정 (콘솔 작업)
    - [ ] Android `assetlinks.json` 작성 + 호스팅
    - [ ] iOS `apple-app-site-association` 작성 + 호스팅 (Universal Links)
    - [ ] Flutter에서 `uni_links` 또는 `app_links` 패키지로 콜드/웜 진입 처리
    - [ ] 앱 진입 시 `oobCode` 추출 → `applyActionCode` 호출 → 토스트 + 자동 reload
    - [ ] `flutter analyze --no-pub` + `flutter test` 통과
  - ⚠️ Android `assetlinks.json` 호스팅과 iOS `.well-known` 설정은 사용자 직접 작업 영역 (도메인/호스팅 결정 필요). **야간엔 코드만, 호스팅 단계는 사용자 직접 처리 항목으로 분리**
  - 파일: `pubspec.yaml`, `lib/core/services/deep_link_handler.dart` (신규), `lib/main.dart`, `android/app/src/main/AndroidManifest.xml`(보류 — 네이티브 편집 금지), `ios/Runner/Info.plist`(보류)
  - 예상: 60분 (Flutter 측만, 네이티브/호스팅 별도)

- [ ] **[가입 UX] 마케팅 수신 동의 체크박스 분리 (선택 동의) (2026-04-27 추가, 한국 표준)**
  - 현재: 회원가입 시 필수 동의 2개(서비스 약관 / 개인정보)만. 마케팅 동의 미수집 → 추후 마케팅 푸시·이메일 발송 시 법적 근거 없음
  - 개선: 회원가입 모드 체크박스에 "[선택] 마케팅 정보 수신 동의" 1개 추가 — 선택이므로 미체크라도 가입 가능
  - 구현 체크리스트:
    - [ ] `login_page.dart` `_buildConsentRow`에 선택 항목 1개 추가 (`isRequired: false` 옵션 신설)
    - [ ] `users/{uid}` 문서에 `marketingConsent: bool` + `marketingConsentAt: timestamp` 필드 추가
    - [ ] `signUpWithEmail` 시 동의 상태 저장 (이메일 가입자만 — 소셜은 추후 별도 동의 화면)
    - [ ] Profile 화면에 "마케팅 수신 동의" 토글 추가 (언제든 변경 가능, 변경 시 timestamp 갱신)
    - [ ] `flutter analyze --no-pub` + `flutter test` 통과
  - 파일: `lib/features/auth/presentation/pages/login_page.dart`, `lib/features/auth/data/models/user_model.dart`, `lib/features/auth/data/datasources/auth_firebase_datasource.dart`, `lib/features/profile/presentation/pages/profile_page.dart`
  - 예상: 50분

- [x] ✅ **[가입 UX] autofill hints — 비밀번호 매니저 호환 (2026-04-28 구현 완료)**
  - 구현: 로그인/회원가입 폼 전체를 `AutofillGroup`으로 감싸고 각 필드에 hints 부여 — 이메일=`username,email`, 비번 로그인=`password`, 비번 회원가입/확인=`newPassword`, 닉네임=`name,nickname`
  - `_buildTextField`/`_buildPasswordField` 헬퍼에 `autofillHints` 옵션 파라미터 추가
  - 검증: `flutter analyze` 0 issues + `flutter test` 45건 pass
  - 파일: `lib/features/auth/presentation/pages/login_page.dart`

- [ ] **[가입 UX] 같은 이메일 다른 provider 친절 안내 (2026-04-27 추가, 모범사례 갭)**
  - 현재: `account-exists-with-different-credential` 에러 발생 시 generic 메시지 "다른 로그인 방식으로 가입된 이메일입니다"만 노출 → 어느 방식으로 가입했는지 모름
  - 개선: 에러 시 `fetchSignInMethodsForEmail(email)`로 기존 가입 방식 조회 후 안내 ("이 이메일은 Google로 가입돼 있어요. Google로 로그인해주세요")
  - 구현 체크리스트:
    - [ ] `signInWith*` 메서드들의 `account-exists-with-different-credential` 핸들러에서 `_auth.fetchSignInMethodsForEmail(email)` 호출
    - [ ] 반환된 provider list 기준 메시지 분기: `password` / `google.com` / `apple.com` 등
    - [ ] 사용자 친화 문구로 반환: "이 이메일은 {provider}로 가입돼 있어요. {provider} 로그인을 사용해주세요"
    - [ ] 단위 테스트: 각 provider별 메시지 정확히 분기되는지 (mock으로 테스트)
    - [ ] `flutter analyze --no-pub` + `flutter test` 통과
  - 파일: `lib/features/auth/data/datasources/auth_firebase_datasource.dart`, `test/features/auth/auth_firebase_datasource_provider_conflict_test.dart` (신규)
  - 예상: 40분

- [x] ✅ **[가입 UX] Apple "Hide My Email" 가짜 이메일 처리 점검 (2026-04-28 구현 완료)**
  - 구현: `core/auth/apple_email.dart` 신설 — `AppleEmail.isHidden(email)` 도메인 감지(대소문자/공백 무관, endsWith 매칭으로 사칭 도메인 차단)
  - `UserEntity`/`UserModel`에 `appleHiddenEmail: bool` 필드 추가, Firestore 직렬화 포함
  - `signInWithApple` 흐름에서 `appleCredential.email` 또는 Firebase user.email 을 정규화 후 `AppleEmail.isHidden`로 분기 → `_createUserIfNotExists(appleHiddenEmail: ...)`
  - 단위 테스트 5건 (null/빈/일반/Hide/대소문자/사칭 도메인)
  - 향후 활용: 마케팅 발송 시 도달성 안내 분기 가능. 사용자가 Apple ID 설정에서 해제 시 재로그인 받으면 자동 갱신
  - 검증: `flutter analyze` 0 issues + `flutter test` 50건 pass
  - 파일: `lib/core/auth/apple_email.dart` (신규), `lib/features/auth/data/datasources/auth_firebase_datasource.dart`, `lib/features/auth/data/models/user_model.dart`, `lib/features/auth/domain/entities/user_entity.dart`, `test/core/auth/apple_email_test.dart` (신규)

- [x] ✅ **[가입 UX] 가입 직후 홈 지역 설정 강제 온보딩 (2026-04-24 구현 완료)**
  - 구현: `/onboarding/home-region` 전체화면 페이지 신설 — GPS 감지 버튼 + 강한 안내 + "건너뛰기"(확인 다이얼로그 후 세션 스킵 플래그)
  - 기존 `detectCurrentRegionProvider` + `saveHomeRegionProvider` 재활용 (BottomSheet 분리 없이 Page에서 직접 호출)
  - `auth_router_state.dart` 신설 — `ValueNotifier<UserEntity?>` 싱글톤. `AuthNotifier.addListener` 로 상태 동기화
  - `appRouter`에 `refreshListenable` + `redirect` 추가 — 로그인된 사용자가 homeRegionSi 미설정이고 스킵 안 했을 때 `/onboarding/home-region` 으로 강제. 로그인/법적/온보딩 경로는 예외
  - OAuth 가입자도 동일 플로우 (homeRegion 미설정 동일 조건)
  - 세션 스킵 플래그는 앱 재시작 시 초기화 → 다음 실행에서 다시 온보딩 유도(의도된 동작)
  - 검증: `flutter analyze` 0 issues + `flutter test` 43건 pass
  - 파일: `lib/core/router/app_router.dart`, `lib/core/router/auth_router_state.dart` (신규), `lib/features/auth/presentation/pages/onboarding_home_region_page.dart` (신규), `lib/features/auth/presentation/providers/auth_provider.dart`

- [x] ✅ **[가입 UX] 이메일 회원가입 약관·개인정보 동의 체크박스 (2026-04-24 구현 완료)**
  - 구현: `login_page.dart` 회원가입 모드에만 체크박스 2개 노출 — `_buildConsentRow` 헬퍼(체크박스 + 라벨 + "자세히 보기"). 둘 다 체크 안 되면 회원가입 버튼 `onPressed: null` 비활성
  - 법적 전문 페이지: `TermsOfServicePage`(MVP 간이 약관 8조), `PrivacyPolicyPage`(docs/PRIVACY_POLICY.md 전문 그대로 임베드). go_router에 `/legal/terms`·`/legal/privacy` 라우트 추가
  - "자세히 보기" 탭 시 `context.push` 로 전환 → 뒤로가기로 가입 폼 복귀(체크 상태 유지)
  - 소셜 로그인은 탭 행위를 동의로 간주(현재 유지, UI 변경 없음)
  - 검증: `flutter analyze` 0 issues + `flutter test` 43건 pass
  - 파일: `lib/features/auth/presentation/pages/login_page.dart`, `lib/features/legal/presentation/pages/terms_of_service_page.dart` (신규), `lib/features/legal/presentation/pages/privacy_policy_page.dart` (신규), `lib/core/router/app_router.dart`

- [x] ✅ **[가입 UX] OAuth 가입자 닉네임 처리 (2026-04-24 결정, 추가 작업 없음)**
  - 결정: Google displayName 그대로 사용, 가입 직후 닉네임 입력 화면 없음
  - 현재 구현: `auth_firebase_datasource.dart` `_createUserIfNotExists(name: googleUser.displayName ?? '러너')` 이미 동작
  - 사용자는 Profile에서 언제든 닉네임 수정 가능

- [ ] **[인증] 이메일 인증 플로우 — 스캐폴딩 완료 / 기능 가드 통합 남음 (2026-04-23 부분 구현)**
  - 정책: [POLICY.md § 1](POLICY.md#-1-이메일-인증verification-정책) — 러닝 1회 유예 + 기능 작동 시 인증 유도
  - ✅ 야간 완료 (2026-04-23):
    - [x] `UserEntity`/`UserModel`에 `emailVerified: bool` 필드 추가 (Firestore 직렬화 + fromFirestore 기본 false)
    - [x] `AuthFirebaseDataSource.signUpWithEmail` 계정 생성 직후 `sendEmailVerification()` 자동 호출
    - [x] OAuth 가입자(Google/Apple)는 `_createUserIfNotExists(emailVerified: true)` 자동 저장
    - [x] `getCurrentUser` 호출 시 Firebase Auth.emailVerified 와 Firestore 동기화(뒤처진 경우 자동 update)
    - [x] `sendCurrentUserEmailVerification` + `reloadAndSyncEmailVerification` datasource 메서드
    - [x] `EmailVerificationCooldown` 신설 (기본 60초, SharedPreferences 기반) + Riverpod provider
    - [x] `AuthNotifier.resendEmailVerification` + `reloadEmailVerification` 메서드
    - [x] `VerifyEmailDialog` 공통 위젯 — 재발송/인증 완료 체크/나중에 3 액션 + 상태 메시지 UI
    - [x] 단위 테스트: EmailVerificationCooldown 5건
    - [x] `flutter analyze` 0 issues + 총 42건 테스트 pass
  - ⚠️ 남은 작업 (2026-04-26 정책 확정 → 야간 큐 진입 가능):
    - [x] ✅ **재발송 쿨다운 로직 교체 — 슬라이딩 윈도우 5분/3회 (2026-04-24 구현 완료)**
      - `email_verification_cooldown.dart` → `email_verification_rate_limiter.dart` 리네이밍, 클래스/provider/AuthNotifier 시그니처 일괄 갱신
      - SharedPreferences에 타임스탬프 ms 3개를 ',' 구분 단일 문자열로 저장 (uid별 키), 읽기 시점에 윈도우 밖 항목 자연 청소
      - 3개 슬롯이 모두 윈도우 내면 잠금, 남은 시간은 "가장 오래된 발송 + 5분 - now"
      - 에러 메시지는 남은 시간 1분↑이면 분 단위, 미만이면 초 단위 안내
      - 단위 테스트 6건 재작성 (최초/1~2회/3회 잠금/오래된 슬롯 만료 후 즉시 재잠금/독립 uid/전체 윈도우 경과)
      - 검증: `flutter analyze` 0 issues + 총 43건 pass
    - [x] ✅ **공통 가드 헬퍼 `requireEmailVerified(BuildContext, ref)` 신설 (2026-04-26 구현 완료)**
      - `lib/core/auth/require_email_verified.dart` — 인증됨/비로그인 분기 즉시 반환, 미인증은 `VerifyEmailDialog.show` 후 결과 반환
      - 단위 테스트 2건 (위젯 테스트 — 인증된 사용자/비로그인 분기). `flutter test` 45건 pass
    - [x] ✅ **크루 가입 신청 가드 적용 (2026-04-26 구현 완료)**
      - `crew_detail_page.dart` `_requestJoinCrew` 진입 시 `requireEmailVerified(contextMessage: '크루에 가입하려면')` 체크 — 차단 시 다이얼로그 노출 후 신청 중단
    - [x] ✅ **러닝 결과 — 랭킹 기여 지역 확정 가드 (2026-04-26 구현 완료)**
      - `running_result_page.dart` `_onRegionSelected` 진입 시 `requireEmailVerified(contextMessage: '랭킹 기여 지역을 확정하려면')`
    - [ ] ⚠️ **러닝 트래킹 페이지 메인 saveSession 가드** — 야간 제약상 보류 (실기기 검증 필요)
      - `lib/features/running/presentation/pages/running_page.dart` `_stopRun` 의 `dataSource.saveSession(savedSession)` 호출이 GPS/위치 라이프사이클이 활발한 영역에 위치 → 야간 자동 수정 금지
      - 다음 세션(데스크톱+실기기)에서 `requireEmailVerified` + 로컬 큐 enqueue 적용 필요
      - 동일하게 `home_page.dart` Health Connect 임포트 saveSession 도 보류
    - [ ] **크루 게시글 작성 가드** — 호출부 페이지 미존재 (출시 후 기능). 페이지 신설 시 즉시 적용 가능 — 헬퍼는 준비 완료
    - [ ] **리워드 교환 가드** — 리워드 스토어 미구현. 스토어 구현 시 적용
    - [ ] **로컬 큐잉된 러닝 데이터 자동 flush** — 러닝 가드와 함께 차기 세션
    - [ ] **"러닝 시작 1회 유예" 상태 머신** — 차기 세션 (실기기 필요)
  - 파일(완료): `lib/features/auth/domain/entities/user_entity.dart`, `data/models/user_model.dart`, `data/datasources/auth_firebase_datasource.dart`, `lib/core/services/email_verification_cooldown.dart` (신규), `presentation/providers/auth_provider.dart`, `presentation/widgets/verify_email_dialog.dart` (신규), `test/core/services/email_verification_cooldown_test.dart` (신규)

- [ ] **[인증] 세션 만료 및 러닝 중 로그아웃 차단 (2026-04-23 정책 확정)**
  - 정책: [POLICY.md § 3](POLICY.md#-3-세션-만료-및-토큰-갱신-정책) — 러닝 중 로그아웃 X, 종료 시점 저장 + 로컬 큐잉
  - 구현 체크리스트:
    - [ ] `RunningProvider`에 `isRunningInProgress: bool` getter/state 노출
    - [ ] `AuthNotifier`의 `idTokenChanges()` 리스너에서 `isRunningInProgress == true` 시 로그아웃 트리거 무시 (로그만 찍기)
    - [ ] `running_firestore_datasource.dart`의 `saveSession`이 현재 종료 버튼 1회 저장인지 점검 + 아니면 수정 (중간 저장 제거)
    - [ ] 저장 실패 시 로컬 큐 보관 — **`SharedPreferences` + JSON 직렬화 확정** (2026-04-26 결정). 큐 키 `running_sync_queue_v1`, 배열 형태 (각 항목: 세션 JSON + 시도 횟수 + 마지막 시도 시각)
    - [ ] 앱 재시작 또는 온라인 복귀 시 큐 자동 flush (`ConnectivityPlus` 스트림 구독)
    - [ ] 홈 상단에 "동기화 대기 N건" 배너 — 큐가 비어있지 않을 때만 표시
    - [ ] **이메일 인증 가드와 동일 큐 공유** — 미인증으로 인한 차단도 같은 큐에 enqueue. flush 시점에 인증 상태 재확인 후 미인증이면 보류 유지
    - [ ] `flutter analyze --no-pub` + `flutter test` 통과 (큐 enqueue/flush/재시도 단위 테스트 포함)
  - 파일: `lib/features/running/presentation/providers/running_provider.dart`, `lib/features/auth/presentation/providers/auth_provider.dart`, `lib/features/running/data/datasources/running_firestore_datasource.dart`, `lib/core/services/running_sync_queue.dart` (신규)
  - 예상: 60분

- [x] ✅ **[인증] 로그인 실패 레이트 리밋 — Phase 1 로컬 (2026-04-23 구현 완료)**
  - 구현: `core/services/login_rate_limiter.dart` 신설 — maxAttempts(3) + lockDuration(60s), SharedPreferences 키는 정규화된 이메일의 hashCode(36진수)로 난독화. `AuthNotifier.signIn`에서 호출 전 사전 잠금 체크(즉시 차단), 실패 시 `recordFailure`, 성공 시 `resetOnSuccess`. 잠금 만료 후 자동 카운터 정리. 만료 시간 오차를 고려해 첫 잠금 안내 문구를 정확한 잔여 초수로 노출.
  - 카운트다운 UI는 다음 세션에서 login_page.dart에 추가 예정(현재는 에러 SnackBar 문구에 남은 초 표시)
  - 검증: `flutter analyze` 0 issues + 단위 테스트 7건 포함 총 37건 pass (최초/미만 실패/3회 잠금/만료 후 해제/리셋/독립 카운터/정규화)
  - 파일: `lib/core/services/login_rate_limiter.dart` (신규), `lib/features/auth/presentation/providers/auth_provider.dart`, `test/core/services/login_rate_limiter_test.dart` (신규)
  - 한계: 앱 재설치 시 초기화 (Phase 2 서버 측 강화는 출시 직전)

- [x] ✅ **[인증] 비밀번호 표시/숨김 토글 (2026-04-22 구현 완료)**
  - 구현: `_buildPasswordField` 헬퍼 신설 — suffix 눈 아이콘 + `_obscurePassword`/`_obscureConfirmPassword` state 토글. `autocorrect: false`/`enableSuggestions: false`로 자동완성·개인사전 학습 차단
  - 검증: `flutter analyze` 0 issues + `flutter test` 22건 pass
  - 파일: `lib/features/auth/presentation/pages/login_page.dart`

- [x] ✅ **[인증] 회원가입 시 비밀번호 확인 입력 필드 (2026-04-22 구현 완료)**
  - 구현: 회원가입 모드에서만 "비밀번호 확인" 필드 표시 — validator로 원본과 불일치 시 "비밀번호가 일치하지 않습니다" 에러. 눈 아이콘은 비밀번호 필드와 별도 토글
  - 검증: `flutter analyze` 0 issues + `flutter test` 22건 pass
  - 파일: `lib/features/auth/presentation/pages/login_page.dart`

- [x] ✅ **[인증] 닉네임 입력 검증·정규화 (2026-04-22 구현 완료)**
  - 구현: `lib/core/validators/name_validator.dart` 신설 — 길이 2~20자 + 제어 문자(U+0000~U+001F, U+007F~U+009F) 차단 + `normalize`는 trim + 내부 다중 공백 단일화. `login_page.dart` validator 교체 + 회원가입 저장 직전 `NameValidator.normalize` 거침
  - 검증: `flutter analyze` 0 issues + 유닛 테스트 8건 포함 총 30건 pass
  - 파일: `lib/core/validators/name_validator.dart`, `lib/features/auth/presentation/pages/login_page.dart`, `test/core/validators/name_validator_test.dart` (신규)

- [x] ✅ **[인증] 소셜 로그인 화면 — 카카오·네이버 버튼 + 순서 재배치 (2026-04-22 구현 완료)**
  - 구현: 버튼 순서 카카오→네이버→Google→Apple 재배치, `_buildNaverButton` 신규(배경 `#03C75A` + 흰 'N' 로고), 카카오·네이버 SnackBar "곧 만나보실 수 있어요!" 통일, 카카오 아이콘 💛→💬
  - 검증: `flutter analyze` 0 issues + `flutter test` 18건 pass
  - 파일: `lib/features/auth/presentation/pages/social_login_page.dart`

- [x] ✅ **[인증] Firebase 에러 코드 → 사용자 친화적 메시지 맵핑 확장 (2026-04-20 구현 완료)**
  - 구현: `_convertAuthException` 확장 — `user-not-found`/`wrong-password`/`invalid-credential`을 통일 메시지로 처리(계정 존재 힌트 차단), `network-request-failed`/`user-disabled`/`requires-recent-login`/`operation-not-allowed`/`account-exists-with-different-credential`/`credential-already-in-use`/`expired-action-code`/`invalid-action-code`/`user-token-expired` 추가, default 메시지에서 원본 `e.message` 노출 제거
  - 검증: `flutter analyze` 0 issues + `flutter test` pass
  - 파일: `lib/features/auth/data/datasources/auth_firebase_datasource.dart`

- [x] ✅ **[인증] 이메일 형식 검증 및 정규화 (2026-04-20 구현 완료)**
  - 구현: `lib/core/validators/email_validator.dart` 신설 (RFC 5322 기반 정규식 + 길이 제한 + `.toLowerCase().trim()` 정규화). 로그인/회원가입 폼 validator 교체, 데이터소스에서도 방어적 정규화 + Firebase Auth/Firestore 저장 값까지 일관 정규화
  - 검증: `flutter analyze` 0 issues + 단위 테스트 6건 pass
  - 파일: `lib/core/validators/email_validator.dart`, `lib/features/auth/presentation/pages/login_page.dart`, `lib/features/auth/data/datasources/auth_firebase_datasource.dart`, `test/core/validators/email_validator_test.dart`

- [x] ✅ **[인증] 로그아웃 후 민감 데이터 클리어 보강 (2026-04-20 구현 완료)**
  - 구현: `signOut`에서 BLE 페어링 키(`ble_device_id`, `ble_device_name`, `ble_onboarding_done`)와 Health Connect 온보딩 키 삭제. 테마 선호도(`runtify_theme_mode`)는 기기 설정이라 유지. Google/Firebase/SharedPreferences 3단계를 try-catch로 격리해 부분 실패 시에도 다음 cleanup 진행
  - 검증: `flutter analyze` 0 issues + 기존 테스트 pass
  - 파일: `lib/features/auth/data/datasources/auth_firebase_datasource.dart`

- [x] ✅ **[인증] 비밀번호 복잡도 규칙 적용 (2026-04-20 구현 완료)**
  - 구현: `lib/core/validators/password_validator.dart` 신설 — `validateForSignUp`(8자+ / 대·소·숫자 / 흔한 비번 16종 차단) + `validateForSignIn`(기존 사용자 호환, 6자+). `PasswordStrengthBar` 위젯으로 가입 모드에서 4단 실시간 강도 표시
  - 검증: `flutter analyze` 0 issues + 단위 테스트 11건 pass
  - 파일: `lib/core/validators/password_validator.dart`, `lib/features/auth/presentation/widgets/password_strength_bar.dart`, `lib/features/auth/presentation/pages/login_page.dart`, `test/core/validators/password_validator_test.dart`

- [x] ✅ **[인증] 비밀번호 재설정 기능 — Flutter 구현 완료 (2026-04-22 구현 완료)**
  - 구현: 클린 아키텍처 따라 `AuthRemoteDataSource.sendPasswordResetEmail` → `AuthRepository.sendPasswordReset` → `ForgotPasswordUseCase` → `AuthNotifier.sendPasswordReset` → `login_page.dart` 하단 "비밀번호를 잊으셨나요?" 버튼 → `_ForgotPasswordSheet` BottomSheet (이메일 입력 + 로딩 + 성공/에러 SnackBar)
  - 보안: UseCase 레벨에서 네트워크/형식 에러만 Left, 계정 존재 여부와 무관하게 "해당 이메일이 등록되어 있다면 재설정 메일이 발송됩니다" 통일 응답. `_convertAuthException`은 기존 매핑 재사용
  - 검증: `flutter analyze` 0 issues + `flutter test` 22건 pass (신규 4건: 정상/형식 오류/빈 입력/Repository 실패)
  - 파일: `lib/features/auth/data/datasources/auth_remote_datasource.dart`, `auth_firebase_datasource.dart`, `auth_mock_datasource.dart`, `data/repositories/auth_repository_impl.dart`, `domain/repositories/auth_repository.dart`, `domain/usecases/forgot_password_usecase.dart` (신규), `presentation/providers/auth_provider.dart`, `presentation/pages/login_page.dart`, `test/features/auth/forgot_password_usecase_test.dart` (신규)
  - ✅ Firebase Console 템플릿 설정 완료 (2026-04-23)

### 🟡 기획 확정 대기 (사용자 검토 후 구현)

- [ ] **[인증] 이메일 인증 (Verification) 플로우 (2026-04-20 발견)**
  - 현재: `signUpWithEmail`에서 계정 생성 후 인증 이메일 자동 발송 없음. 미검증 계정도 전체 기능 접근 가능
  - 개선: `sendEmailVerification()` 호출 + `emailVerified` 필드를 UserEntity에 추가 + 미인증 상태 UI 배너 + 인증 전 특정 기능(크루 가입, 리워드) 제한
  - 검토 필요: 어느 기능까지 인증 없이 허용할지(온보딩 UX vs 정책 강도)
  - 정책 결정: [POLICY.md § 1](POLICY.md#-1-이메일-인증verification-정책)
  - 파일: `auth_firebase_datasource.dart`, `user_entity.dart`, `user_model.dart`, `login_page.dart`
  - 예상: 120분

- [ ] **[인증] 연속 로그인 실패 레이트 리밋 (2026-04-20 발견)**
  - 현재: 실패 에러만 반환. 3회 이상 실패 시 계정 잠금/대기 없음 (Firebase 측 기본 rate limit만)
  - 개선: 로컬 `SharedPreferences`로 실패 횟수 추적 → 3회 실패 시 60초 대기 강제 + UI 카운트다운
  - 검토 필요: 서버 측(Firebase 규칙/함수) 강화도 추가할지 — Blaze 요금제 전환 검토
  - 정책 결정: [POLICY.md § 2](POLICY.md#-2-로그인-실패-레이트-리밋-정책)
  - 파일: `lib/features/auth/presentation/pages/login_page.dart`, `lib/features/auth/presentation/providers/auth_provider.dart`
  - 예상: 85분

- [ ] **[인증] 세션 만료 및 토큰 갱신 처리 (2026-04-20 발견)**
  - 현재: Firebase ID token 만료(1시간)에 대한 명시적 처리 없음. 갱신 자동화/UI 피드백 미구현
  - 개선: `FirebaseAuth.instance.idTokenChanges()` 스트림 모니터링 → 갱신 실패 시 로그인 리다이렉트. 선택: 30분 유휴 시 강제 재인증
  - 검토 필요: 유휴 시간 정책 정하기 + 기존 러닝 중에 토큰 만료 시 UX 시나리오
  - 정책 결정: [POLICY.md § 3](POLICY.md#-3-세션-만료-및-토큰-갱신-정책)
  - 파일: `auth_provider.dart`, `lib/core/services/session_manager.dart` (신규)
  - 예상: 95분

### 🔴 사용자 결정 필요 (보안·정책 critical)

- [ ] **[인증] 계정 탈퇴(Account Deletion) 플로우 (2026-04-20 발견)**
  - 현재: 프로필 페이지에 로그아웃만 있음. 계정 삭제 기능 전무
  - 개선: "계정 삭제" 버튼 → 확인 다이얼로그 → **비밀번호 재인증** → Firestore 사용자 데이터 삭제 + `FirebaseAuth.currentUser.delete()` + 관련 컬렉션(크루 멤버십, 러닝 세션 등) 처리
  - 사용자 결정 사항:
    - 연관 데이터 처리 방식: **완전 삭제 vs 익명화 vs 소프트 삭제**
    - 크루 리더가 탈퇴 시: 리더 위임 vs 크루 해체 vs 탈퇴 제한
    - 유예기간: 즉시 삭제 vs 30일 복구 가능
    - GDPR/CCPA 컴플라이언스 문구 포함 여부
  - **중요**: App Store 14+ 정책상 필수. 미구현 시 심사 거절 가능성
  - 정책 결정: [POLICY.md § 4](POLICY.md#-4-계정-탈퇴-정책)
  - 파일: `profile_page.dart`, `auth_firebase_datasource.dart`, `delete_account_usecase.dart` (신규)
  - 예상: 110분 + 사용자 정책 결정 시간

---

## 현재 상태 (구현 완료)

| 기능 | 상태 | 비고 |
|------|------|------|
| 로그인/회원가입 | ✅ 완료 | Firebase Auth (이메일) |
| Google 로그인 | ✅ 완료 | Firebase Auth + google_sign_in |
| Apple 로그인 | ⏸ 보류 | Apple Developer 계정($99/년) 필요 — 앱스토어 출시 전 필수 |
| 홈 대시보드 | ✅ 완료 | 러닝 기록 목록, 통계 |
| 러닝 트래킹 | ✅ 완료 | GPS + BLE 심박수 + 지도 경로 |
| 러닝 완료 페이지 | ✅ 완료 | 경로 지도 + 구간 페이스 + 스트릭 배너 |
| 러닝 기록 상세 | ✅ 완료 | 지도 재현 + 삭제 |
| 프로필/레벨 | ✅ 완료 | EXP 바, 테마 설정 |
| 포인트 시스템 | ✅ 완료 | 속도보너스 + 스트릭 배율 + 크루 연동 |
| 크루 | ✅ 완료 | Firebase 연동 (생성/가입/탈퇴/멤버 조회) |
| 랭킹 | ✅ 완료 | regionStats 3단계(동/구/시) Firebase 연동 |
| 네비게이션 구조 | ✅ 완료 | 5탭 + 러닝 내부 3탭(기록/캘린더/목표) |
| 러닝 캘린더 | ✅ 완료 | PageView 월간 캘린더 + Firebase 연동 |
| 크루 위클리 챌린지 | ✅ 완료 | 생성/진행/달성/보너스 포인트 Firebase 연동 |
| 목표(Goals) | ✅ 완료 | 4가지 목표 타입 + 자동 진행률 + Firebase 연동 |
| 리워드 스토어 | ⏸ 보류 | 실제 보상 연동 방식 미결정 |

---

## 개인 러닝 기능 강화 → ✅ 완료

→ 상세: [RUNNING_FEATURE_PLAN.md](RUNNING_FEATURE_PLAN.md)

---

## 소셜/게임 기능 기획 (우선순위 순)

---

### ✅ Phase 1 — 포인트 시스템 고도화 (완료)

#### 포인트 계산 공식 (구현됨)
```
포인트 = (거리(km) × 10 + 속도보너스) × 스트릭배율
- 속도보너스: 페이스 5'00"/km 이하 → +5P/km
- 스트릭배율: 3일 연속 ×1.2, 7일 연속 ×1.5
```

#### Firestore 구조 (구현됨)
```
users/{userId}
  points, experience, level, totalDistance
  streak: number          // 연속 러닝 일수
  lastRunDate: timestamp  // 스트릭 계산용
```

#### 남은 작업
- [x] 홈: 스트릭 표시 (불꽃 아이콘 + 일수) ← 구현 완료
- [ ] EXP 레벨 공식 고도화 (Lv.N→N+1: 이전 × 2, 현재는 단순 100exp = 1레벨)

---

### ✅ Phase 2 — 크루 기능 Firebase 연동 (완료)

**목적:** 소셜 요소로 앱 리텐션 강화

#### 기능 범위
1. **크루 생성** — 이름/지역/설명/최대인원 입력
2. **크루 가입/탈퇴** — 1인 1크루 제한
3. **크루 포인트** — 멤버 포인트 합산, 이번 달 기준 (트랜잭션 연동 완료)
4. **내 크루 표시** — 홈 화면에 내 크루 카드 추가

#### 필요한 화면 변경 (Figma 작업 필요)
- [x] 크루 목록: 가입 상태 표시, "내 크루" 뱃지
- [x] 크루 상세 화면 (NEW): 멤버 목록, 크루 통계, 탈퇴 버튼
- [x] 크루 생성 다이얼로그 (NEW): 폼 입력
- [x] 홈: 내 크루 포인트 미니 카드 추가

#### Firestore 구조
```
crews/{crewId}
  name, region, description, leaderId
  memberIds: string[]
  maxMembers: number
  crewPoints: number        // 누적 포인트 (러닝 시 자동 증가 ✅)
  monthlyPoints: number     // 이번 달 포인트 (러닝 시 자동 증가 ✅)
  createdAt: timestamp

users/{userId}
  crewId: string | null
```

---

### ✅ Phase 3 — 지역 계층형 랭킹 시스템 (완료)

**목적:** 동네→구→시 단위 경쟁으로 로컬 커뮤니티 활성화

#### 지역 계층 구조 (3단계)
```
동(洞) → 구(區) → 시/도(市/道)
예: 역삼동 → 강남구 → 서울특별시
```

#### geocoding 패키지 필드 매핑 (한국 주소 기준)
```
Placemark 필드        → Runtify 레벨
subLocality           → dong  (동, 예: "역삼동")
locality              → gu    (구/군, 예: "강남구")
administrativeArea    → si    (시/도, 예: "서울특별시", "경기도")
```
> ⚠️ geocoding 한국 주소 결과는 기기/위치에 따라 불안정할 수 있음
> 없는 레벨(예: 군 단위 지역의 동)은 null로 처리

#### running_session 데이터 구조 변경 필요
```dart
// running_session_entity.dart 에 regionData 필드 추가 예정
running_sessions/{sessionId}
  region: "서울특별시 강남구"   // 기존 (표시용 문자열)
  regionData: {                // NEW: 계층별 분리 저장
    dong: "역삼동",             // subLocality
    gu: "강남구",               // locality
    si: "서울특별시",           // administrativeArea
  }
```

#### regionStats Firestore 구조
```
regionStats/{id}
  // id 형식: "{level}_{regionName}_{YYYY-MM}"
  // 예: "gu_강남구_2026-03", "si_서울특별시_2026-03"
  level: "dong" | "gu" | "si"
  region: string          // 예: "강남구"
  parentRegion: string    // 상위 지역 (예: "강남구" → "서울특별시")
  month: string           // "2026-03"
  totalPoints: number
  runnerCount: number
  updatedAt: timestamp
```

#### 랭킹 화면 변경 (Figma 작업 필요)
- [ ] 랭킹 탭 3개: "동네" / "구" / "시·도"
- [ ] 내 지역 행 하이라이트 (primary 색 테두리)
- [ ] 크루별 랭킹 탭 (Phase 2 완료 후 추가)

#### 코드 변경 범위
1. `running_session_entity.dart` — `regionData` 필드 추가
2. `running_page.dart` — `_reverseGeocode()` 개선 (3단계 분리 추출)
3. `running_firestore_datasource.dart` — 세션 저장 시 `regionStats` 3단계 동시 업데이트
4. `ranking_page.dart` — Firebase 실데이터 연동 + 탭 추가

---

### ✅ Phase 3.5 — 러닝 캘린더 (신규 기획)

**목적:** 러닝 이력을 캘린더로 시각화 → 스트릭 동기부여 강화

#### 기능 범위
1. **월간 캘린더 뷰** — 러닝한 날에 점(dot) 또는 아이콘 표시
2. **날짜 탭** — 해당 날짜 러닝 기록 목록 표시
3. **스트릭 시각화** — 연속 달린 날짜 연결선 또는 색상 강조
4. **통계 요약** — 이번 달 총 횟수 / 총 거리 / 활동일수

#### 화면 위치
- **홈 화면에 탭 추가**: "기록" / "캘린더"
- 또는 독립 화면으로 추가

#### UI 구성 (안)
```
┌─────────────────────────────┐
│  < 2026년 3월 >              │
│  월  화  수  목  금  토  일   │
│   3   4   5  🔥  7   8   9  │
│  10  11  🔥 🔥 🔥  15  16   │
│  17  18  🔥 🔥 🔥 🔥  23   │
│  24  25  26  27  28  29  30 │
├─────────────────────────────┤
│  이번 달 요약                │
│  활동일: 7일  총 거리: 42km  │
│  최장 스트릭: 4일 🔥🔥🔥🔥  │
├─────────────────────────────┤
│  3월 17일 기록               │
│  ┌───────────────────────┐  │
│  │ 5.3km  28:32  +53P    │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

#### 기술 결정
- **패키지:** `table_calendar: ^3.1.0` (Flutter 캘린더 표준 패키지)
  - 또는 직접 구현 (GridView 기반, 의존성 최소화)
- **데이터:** 기존 `recentRunsProvider` 데이터 재활용 (별도 쿼리 불필요)
  - `startTime` 기준으로 날짜별 그루핑

#### Firestore 추가 구조 없음
> 기존 `running_sessions` 쿼리로 충분
> 단, 월별 조회 범위 확장 필요 (현재 최근 20개 → 해당 월 전체)

#### 필요한 화면 변경 (Figma 작업 필요)
- [ ] 캘린더 화면 (NEW): 월간 캘린더 + 날짜별 기록 목록
- [ ] 홈: 탭 추가 또는 캘린더 진입 버튼

#### 코드 변경 범위
1. `pubspec.yaml` — `table_calendar` 패키지 추가 (또는 직접 구현)
2. `running_provider.dart` — 월별 전체 조회 Provider 추가
3. `running_firestore_datasource.dart` — `getSessionsByMonth()` 메서드 추가
4. `calendar_page.dart` — 신규 화면 생성
5. `app_router.dart` — `/calendar` 라우트 추가

---

---

## ✅ Phase 0 — 네비게이션 구조 개편 (완료)

> 5탭(홈/러닝/크루/랭킹/리워드) + 러닝 내부 3탭(기록/캘린더/목표) 구현 완료

### 변경 방향

| 현재 | 변경 후 |
|------|---------|
| 홈 = 러닝 기록 + 통계 | 홈 = Runtify 전체 허브 (대시보드) |
| 러닝 = 트래킹만 | 러닝 = 러닝 전용 섹션 (캘린더/기록/목표/트래킹) |

### 새 하단 탭 구조
```
홈(Hub) | 러닝 | 크루 | 랭킹 | 리워드
```

### 홈(Hub) 화면 — Runtify 전체 진입점
```
┌─────────────────────────────┐
│  안녕하세요, Dave 🔥 3일     │  ← 유저 이름 + 스트릭
│  Lv.5  ████░░  420/500 EXP  │  ← 레벨 진행바
├─────────────────────────────┤
│  [ 러닝 시작하기 → ]         │  ← 메인 CTA
├────────────┬────────────────┤
│ 내 크루     │ 내 지역 랭킹   │  ← 미니 카드
│ 강남 러너스  │ 강남구 12위   │
├────────────┴────────────────┤
│  리워드 1,230P              │
│  교환 가능한 리워드 2개      │
└─────────────────────────────┘
```

### 러닝 섹션 — 러닝 전용 허브 (내부 탭)
```
러닝 섹션 탭:  [기록]  [캘린더]  [목표*]   (* 추후 구현)

기록 탭: 최근 러닝 목록 + 카드 탭 → 상세
캘린더 탭: 월간 캘린더 (Phase 3.5)
목표 탭: 월간 목표 거리/횟수 (추후)
```

### 코드 영향 범위
- `home_page.dart` — 완전 재설계 (허브로)
- `running_section_page.dart` (NEW) — 러닝 섹션 랜딩 (내부 탭)
- `app_router.dart` — 라우트 구조 변경
- BottomNavigationBar — 공통 위젯으로 분리 (현재 각 화면에 중복 선언됨)

### ⚠️ Figma 작업 필수
- [ ] 홈(Hub) 화면 전체 레이아웃
- [ ] 러닝 섹션 랜딩 (기록/캘린더/목표 탭 구조)
- [ ] 하단 네비게이션 확정

---

### 🟡 Phase 4 — 프로필 홈 지역 설정 (GPS 기반) — 데이터 구조 완료, UI 미구현

**목표:** 유저가 자신의 홈 지역을 설정해 랭킹 기여 지역의 기준으로 사용

**배경/이유:**
- 랭킹 "내 지역" 배너가 현재 마지막 런닝 GPS 기반이라 여행 중 달리면 틀려짐
- homeRegion을 명시적으로 설정해야 랭킹 기여 지역이 정확해짐

**구현 체크리스트:**
- [ ] 프로필 페이지에 "내 지역 설정" 버튼 추가
- [ ] GPS 현재 위치 → 역지오코딩 → 시·도/구·군/동네 3단계 표시 후 확인
- [ ] users/{id} 에 homeRegionSi / homeRegionGu / homeRegionDong 필드 저장
- [ ] 랭킹 화면 "내 지역" 배너를 homeRegion 기준으로 변경
- [ ] 홈 지역 미설정 시 "지역을 설정해보세요" 안내 문구 표시

**Firestore 변경:**
```
users/{id}
  homeRegionSi: "서울특별시"   // 시·도
  homeRegionGu: "서초구"       // 구·군
  homeRegionDong: "반포동"     // 동네
```

---

### ✅ Phase 5 — 런닝 위치 컨펌 + 랭킹 기여 지역 분리 (완료)

**목표:** 원정 런닝(크루 이벤트 등)에서도 랭킹 기여 지역을 올바르게 처리

**핵심 설계 원칙:**
- **뛴 위치(geo)** = 실제 GPS 위치 → 개인 기록/지도에 표시
- **랭킹 기여 지역(ranking)** = 홈 지역 우선 → regionStats 포인트 누적에 사용
- 홈 지역 미설정 유저 → 뛴 위치를 기본값으로 사용
- 예: 서초구 거주자가 강릉에서 달려도 포인트는 서초구 랭킹에 기여

**구현 체크리스트:**
- [ ] RunningSessionEntity에 geoRegionSi/Gu/Dong, rankingRegionSi/Gu/Dong 필드 추가
- [ ] _stopRun()에서 rankingRegion 결정 로직 추가 (홈 지역 우선, 없으면 geoRegion)
- [ ] 시작점과 종료점의 구가 다를 경우 running_result_page.dart에 컨펌 카드 표시
  - "시작: 강남구 / 종료: 서초구 — 어느 지역으로 기록할까요?" UI
  - 기본값: 시작점 기준 선택
  - 홈 지역 설정된 경우 컨펌 없이 홈 지역 자동 반영
- [ ] regionStats 누적을 rankingRegion 기준으로 변경 (현재 geoRegion 기준)
- [ ] running_firestore_datasource.dart saveSession 트랜잭션에서 rankingRegion 사용

**Firestore 변경:**
```
running_sessions/{id}
  // 기존
  region: "서울특별시 강남구"   // 하위호환 유지
  regionSi: "서울특별시"
  regionGu: "강남구"
  regionDong: "역삼동"

  // 신규 추가
  geoRegionSi: "강원도"         // 실제 뛴 위치
  geoRegionGu: "강릉시"
  geoRegionDong: "교동"
  rankingRegionSi: "서울특별시" // 랭킹 반영 지역 (홈 지역 우선)
  rankingRegionGu: "서초구"
  rankingRegionDong: "반포동"
```

**엣지케이스 처리:**
| 상황 | rankingRegion 결정 |
|------|-------------------|
| 홈 지역 설정 O | 항상 홈 지역 |
| 홈 지역 설정 X + 시작=종료 구 | 뛴 위치 자동 반영 |
| 홈 지역 설정 X + 시작≠종료 구 | 컨펌 UI → 사용자 선택 |

---

## UI/UX 개선 과제

> 버그와 구분되는 개선 기획. 디자인 작업 + 소규모 코드 변경으로 처리.

### 🎨 지도 스타일 컬러화
- **현재:** 러닝 지도 화면이 흑백(다크 모노크롬) 스타일로 표시
- **목표:** 도로/건물/공원 등 색상 구분되는 **컬러 지도**로 변경
- **디자인 결정 필요:**
  - 다크 모드 앱 테마와 조화로운 컬러 지도 스타일 (너무 밝지 않게)
  - Runtify 브랜드 컬러(Primary `#FF4D00`)와 충돌 없는 지도 배경
  - 러닝 경로 폴리라인은 기존 Primary 컬러 유지 → 지도 위에서 잘 보여야 함
- **영향 화면:**
  - 러닝 중 지도 (`running_page.dart`)
  - 러닝 완료 결과 지도 (`running_result_page.dart`)
  - 러닝 기록 상세 지도
  - 런닝 코스 상세 지도 (Phase 8)
- **작업 순서:**
  1. `/project:design` — Figma에서 컬러 지도 스타일 샘플 비교
  2. Google Maps Style JSON 생성 (https://mapstyle.withgoogle.com)
  3. `/project:coding` — 각 지도 위젯에 `mapStyle` 적용

---

## 확정된 설계 결정사항

| 항목 | 결정 |
|------|------|
| 스트릭 기준 | 자정 기준 ✅ |
| 크루 포인트 집계 | 실시간 트랜잭션 ✅ |
| 캘린더 위치 | **러닝 섹션 내 탭** ✅ |
| 지역 계층 단계 | **동/구/시 3단계 모두** ✅ |
| geocoding 실패 시 | **수동 지역 선택 BottomSheet** ✅ |

---

## 수동 지역 선택 UI (geocoding 실패 시 대응)

### 흐름
```
러닝 종료 → geocoding 시도
  ├─ 성공 → 자동 저장
  └─ 실패 → 지역 선택 BottomSheet 표시
               시/도 선택 → 구/군 선택 → 확인 → 저장
```

### UI (BottomSheet)
```
┌─────────────────────────────┐
│  📍 러닝 지역을 선택해주세요   │
│  (GPS 자동 감지 실패)         │
├─────────────────────────────┤
│  시/도: [서울특별시    ▼]    │
│  구/군: [강남구        ▼]    │
├─────────────────────────────┤
│      [ 이 지역으로 저장 ]     │
└─────────────────────────────┘
```

### 데이터
- 시/도 목록: 하드코딩 (17개 광역자치단체)
- 구/군 목록: 시/도별 하드코딩 (또는 공공 API)
- 동 선택: 생략 (입력 부담 최소화)

---

## 작업 순서 (각 Phase 공통)

```
1. 이 문서에서 해당 Phase 기획 확인
2. /project:design → Figma에서 변경된 화면 디자인
3. 디자인 승인 요청
4. 승인 후 /project:coding → Flutter + Firebase 코드 구현
5. 테스트 후 다음 Phase
```

**권장 작업 순서 (남은 작업):**
```
Phase 4 (홈 지역 설정 UI) → Phase 5 (랭킹 기여 지역 분리) → Phase 6 (배지) → Phase 8 (런닝 코스)
```

---

---

## 출시 로드맵

### 🚀 1차 출시 — Android + Galaxy Watch
> 목표: Play Store 출시 + 갤럭시 워치 연동
> 
> **기술 경로:** Samsung Health SDK 직접 사용 불필요.
> Galaxy Watch → 삼성 헬스 앱(폰) → Health Connect → Runtify (`health` 패키지)
> 실시간 심박수: BLE HRM → `flutter_blue_plus` (이미 구현)

| 항목 | 상태 | 비고 |
|------|------|------|
| Android 앱 | ✅ 완료 | Flutter 빌드 |
| Health Connect 연동 코드 | ✅ 완료 | `health_connect_datasource.dart` |
| BLE 심박수 연동 코드 | ✅ 완료 | `heart_rate_ble_datasource.dart` |
| Health Connect 온보딩 UI | ⬜ 개발 필요 | 유저에게 Health Connect + 삼성 헬스 동기화 안내 |
| 워치 러닝 기록 홈 연동 | ⬜ 개발 필요 | Health Connect 과거 데이터 → 홈 대시보드 표시 |
| BLE 연결 온보딩 UI | ⬜ 개발 필요 | 갤럭시 워치 심박수 페어링 안내 |
| 🔐 레이트 리밋 Phase 2 (서버) | ⬜ **출시 2주 전 (2026-04-26 결정)** | Cloud Functions로 이메일별 실패 카운터 → 분산 공격 방어. **Blaze 요금제 전환 필요** ($0~5/월 예상). [POLICY § 2](POLICY.md#-2-로그인-실패-레이트-리밋-정책) 참조 |
| 🔴 계정 탈퇴 플로우 | ⬜ **출시 직전 필수** | App Store 심사 요건. 정책 확정됨(2026-04-27). [POLICY § 4](POLICY.md#-4-계정-탈퇴-정책) — 소프트 삭제 30일 + 이중 재인증(비번+이메일 코드) |
| ⚖️ 약관 변호사 검토 1회 | ⬜ **출시 직전 필수 (2026-04-27 결정)** | 현재 MVP 8조 → 변호사 검토 후 보완. 비용/일정 확보 필요 |
| 🏢 사업자 정보 채우기 | ⬜ **출시 직전 필수 (2026-04-27 결정)** | 약관·앱 내 사업자 정보(상호/대표자/사업자번호 등) 표시. 사업자 등록 완료 전제 |
| Play Store 출시 | ⬜ 준비 필요 | 스토어 등록, 스크린샷, 설명 |

#### Android 실기기 테스트 이슈 (2026-04-19 발견)
- [ ] 🔴 **러닝 중 GPS 위치 업데이트 안 됨** — 시간은 정상 카운트, 거리가 0km 고정, 지도 내 위치 이동 없음
  - 원인 추정: `geolocator` stream 초기화 실패, 백그라운드 위치 권한(`ACCESS_BACKGROUND_LOCATION`) 미허용, 또는 위치 서비스 빈도 설정(`LocationAccuracy`, `distanceFilter`) 이슈
  - 확인 파일: `lib/features/running/presentation/pages/running_page.dart` 의 GPS stream 구독부, `android/app/src/main/AndroidManifest.xml` 권한 선언
  - 재현: 앱 실행 → 러닝 시작 → 걷거나 뜀 → 화면상 거리 0.00km 유지

### 📱 2차 업데이트 — iOS 출시
> 목표: App Store 출시 (코드 이미 완성, 계정 등록만)

| 항목 | 상태 | 비고 |
|------|------|------|
| iOS 앱 코드 | ✅ 완료 | Flutter 크로스 플랫폼 |
| Apple Developer 등록 | ⬜ **Android 출시 1개월 전** (2026-04-26 결정) | $99/년, developer.apple.com. 등록 후 Apple 로그인 + 심사 준비 시작 |
| Apple 로그인 활성화 | ⬜ Apple Developer 등록 후 | 소셜 로그인 제공 시 필수 (App Store 정책) |
| App Store 심사 | ⬜ 필요 | 회원 탈퇴 기능 등 심사 요구사항 확인 (계정 탈퇴는 30일 소프트 삭제로 정책 확정) |

#### iOS 실기기 테스트 이슈 (2026-04-19 발견)
- [x] ✅ **iPhone 17 Pro Max 화면 비율 대응** (2026-04-19 수정 완료, 시뮬레이터 검증)
  - 진짜 원인: `lib/main.dart`의 `MaterialApp.builder`에 **`ConstrainedBox(maxWidth: 390)` + `ColoredBox(black)`** 하드코딩 → iOS/Android 실기에서도 390px로 제한 + 검은 레터박스
  - 수정: 플랫폼 분기 (`kIsWeb`, `Platform.isMacOS/Windows/Linux` 일 때만 중앙 정렬 적용) — 모바일은 네이티브 너비 사용
  - 부가 개선: iOS deployment target 13→15, `UILaunchScreen` 추가, LaunchScreen.storyboard Xcode 16 표준으로 재작성
- [x] ✅ **iOS 엣지 스와이프 뒤로가기 미동작** (2026-04-20 수정 완료, analyze+test 통과)
  - 원인: go_router에서 모든 라우트가 `MaterialPage` 사용 → iOS에서 스와이프 제스처 비활성
  - 수정: `lib/core/router/app_router.dart`에 `_platformPage()` 헬퍼 추가 — iOS는 `CupertinoPage`, 그 외는 `MaterialPage`로 분기. 모든 `GoRoute`의 `builder`를 `pageBuilder`로 전환
  - 검증 필요: 실기기에서 좌측 엣지 스와이프 동작 확인 (시뮬레이터에서도 동작)
- [x] ✅ **러닝 시작 후 경과 시간 미증가** (2026-04-19 수정 완료, 시뮬레이터 검증)
  - 원인: `Timer.periodic` 등록이 `await _notificationService.requestPermission()` 뒤에 있어 iOS에서 권한 요청 hang 시 타이머 자체가 등록 안 됨
  - 수정: 타이머를 알림 권한 요청보다 먼저 등록 + `fire-and-forget` 패턴 + Timer 콜백에 `mounted` 체크/try-catch 추가
- [ ] 🔴 **러닝 중 백그라운드 복귀 시 크래시** — 러닝 시작 → 홈(백그라운드) → 앱 복귀 시 즉시 종료
  - 원인 추정: `WidgetsBindingObserver` 복귀 처리 누락, GPS/BLE 스트림 재구독 실패, UIBackgroundModes(`location`)에 대응하는 Xcode Capability: **Background Modes → Location updates** 미설정 가능성
  - 확인 파일: `lib/features/running/presentation/pages/running_page.dart`, Xcode `Signing & Capabilities`

### ⌚ 3차 업데이트 — Apple HealthKit
> 목표: Apple Watch 유저 러닝 데이터 연동

| 항목 | 상태 | 비고 |
|------|------|------|
| Apple HealthKit 연동 | ⬜ 개발 필요 | iOS 유저 확보 후 진행 |
| Apple Watch 심박/거리 동기화 | ⬜ 개발 필요 | HealthKit 읽기 권한 |

### ⌚ 4차 업데이트 — Garmin Connect API
> 목표: 하드코어 러너(Garmin 유저) 확보

| 항목 | 상태 | 비고 |
|------|------|------|
| Garmin Connect API 연동 | ⬜ 개발 필요 | OAuth 인증 → 자동 동기화 |
| Garmin 워치 앱 개발 | ❌ 불필요 | Strava와 동일 패턴 (API만) |

### 크루 소셜 기능 (Strava 대비 보완)
> 현재 Runtify 크루 = 경쟁 그룹 (포인트/챌린지/랭킹)
> 부족한 부분 = 소셜 (게시글/이벤트/채팅)

| 우선순위 | 기능 | 설명 | 상태 |
|----------|------|------|------|
| 🔴 1 | **크루 게시글/피드** | 글쓰기, 사진, 댓글, 좋아요 | ⬜ |
| 🔴 2 | **크루 이벤트** | 날짜/장소/루트 지정 그룹 러닝 모집 + 참가하기 | ✅ |
| 🔴 3 | **크루 멤버 관리** | 멤버 목록 전용 화면, 역할 표시, 가입 일자, 기여도(거리/포인트), 퇴출 확인 | ⬜ |
| 🟡 4 | **공개/비공개 크루** | 가입 승인제 (현재 모두 공개) | ⬜ |

### 러닝 데이터 정책
```
크루 미가입: 개인 러닝 데이터만 저장
크루 가입:   개인 러닝 + 크루 러닝 데이터 동시 저장 (자동, 모드 선택 없음)
```
- 크루 소속 시 러닝하면 개인 포인트 + 크루 포인트 자동 적립 (현재 구현 완료)

### 추후 검토
- [ ] 리워드 쿠폰 코드: 자동 생성 난수? 외부 API 연동?
- [ ] Coros/Suunto 등 기타 워치 연동

---

### ✅ Phase 6 — 배지 & 칭호 시스템 🏅 (완료)

**목표:** 달성 조건 충족 시 배지/칭호 획득. 프로필에 표시해 게이미피케이션 강화.

**배지 목록 (MVP):**
| 배지 | 조건 |
|------|------|
| 🔥 불꽃 러너 | 7일 연속 런닝 |
| 🌙 새벽 러너 | 오전 6시 이전 런닝 10회 |
| ⚡ 스피드 마스터 | 페이스 4'30"/km 이하로 5km 완주 |
| 🏙️ 지역 지킴이 | 해당 구 월간 랭킹 1위 달성 |
| 🗺️ 원정대 | 홈 지역 외 5개 구에서 런닝 완료 |
| 💯 100km 클럽 | 누적 100km 달성 |

**구현 체크리스트:**
- [ ] BadgeEntity / BadgeModel 생성
- [ ] 런닝 저장 시 배지 달성 조건 체크 (running_firestore_datasource.dart)
- [ ] users/{id}/badges 서브컬렉션에 획득 배지 저장
- [ ] 프로필 페이지에 배지 그리드 표시
- [ ] 신규 배지 획득 시 result 페이지에 팝업 표시

**Firestore:**
```
users/{id}/badges/{badgeId}
  badgeId: string
  earnedAt: timestamp

badges/ (마스터 컬렉션)
  {badgeId}
    name: string
    description: string
    icon: string
    condition: string
```

---

### ✅ Phase 7 — 크루 위클리 챌린지 🎯 (완료)

**목표:** 크루 단위로 매주 목표를 설정하고 달성 시 보너스 포인트 지급. 크루원 간 상호 독려 유도.

**챌린지 유형:**
- 합산 거리: "이번 주 크루 합산 200km"
- 참여 인원: "크루원 80% 이상 이번 주 런닝"
- 연속 달리기: "크루 전원 3일 이상 연속 달리기"

**구현 체크리스트:**
- [ ] crews/{id}/challenges 서브컬렉션 구조 설계
- [ ] 챌린지 생성 UI (크루 리더만 생성 가능)
- [ ] 런닝 저장 시 진행 중인 챌린지 progress 업데이트
- [ ] 챌린지 현황 위젯 (크루 상세 페이지 내)
- [ ] 챌린지 달성 시 크루 전체에 보너스 포인트 일괄 지급
- [ ] 달성/미달성 히스토리 기록

**Firestore:**
```
crews/{crewId}/challenges/{challengeId}
  type: "distance" | "participation" | "streak"
  targetValue: number
  currentValue: number
  startDate: timestamp
  endDate: timestamp
  bonusPoints: number
  status: "active" | "completed" | "failed"
  participantCount: number
```

---

### ✅ Phase 8 — 런닝 코스 저장 & 공유 🗺️ (완료)

**목표:** 유저가 달린 경로를 코스로 저장하고 같은 지역 러너들과 공유. UGC 기반 커뮤니티 형성.

**주요 기능:**
- 런닝 결과 페이지에서 "코스로 저장" 버튼
- 코스 이름, 난이도(1~5) 입력
- 지역별 인기 코스 리스트 (러닝 섹션 or 홈)
- "이 코스로 달리기" → 해당 경로 지도에 표시 후 러닝 시작

**구현 체크리스트:**
- [ ] CourseEntity / CourseModel 생성
- [ ] running_result_page.dart에 "코스 저장" 버튼 추가
- [ ] courses/ 컬렉션에 경로 저장 (routePoints 배열)
- [ ] 지역별 인기 코스 조회 Provider (regionGu 기준 정렬)
- [ ] 코스 상세 페이지 (지도 + 통계)
- [ ] "이 코스로 달리기" 기능 (running_page에서 가이드 경로 표시)

**Firestore:**
```
courses/{courseId}
  creatorId: string
  name: string
  regionGu: string
  regionSi: string
  distanceKm: number
  difficulty: number        // 1~5
  routePoints: array        // [{lat, lng}]
  runCount: number          // 이 코스를 달린 횟수
  createdAt: timestamp
```

---

### ✅ Phase 9 — 목표(Goals) 기능 🎯 (완료)

**목표:** running_section_page.dart의 "목표" 탭(현재 플레이스홀더)을 실제 구현.
개인 주간/월간 목표를 설정하고 진행률을 시각화해 지속적인 동기부여 제공.

**현재 상태:** `_GoalsTab` 클래스가 "목표 기능 준비 중" 플레이스홀더로 존재
**구현 위치:** `lib/features/running/presentation/pages/running_section_page.dart`

**목표 유형:**
| 유형 | 예시 |
|------|------|
| 주간 거리 | 이번 주 30km |
| 월간 거리 | 이번 달 100km |
| 주간 횟수 | 이번 주 4회 런닝 |
| 연속 달리기 | 30일 연속 유지 |

**화면 구성:**
```
[목표 탭]
├── 이번 달 목표 카드
│   └── 진행률 바 (67km / 100km = 67%)
├── 이번 주 목표 카드
│   └── 진행률 바 (3회 / 4회 = 75%)
├── 연속 달리기 카드
│   └── 현재 스트릭: 🔥 12일
└── [+ 목표 추가] 버튼
```

**구현 체크리스트:**
- [ ] GoalEntity / GoalModel 생성 (type, targetValue, period)
- [ ] users/{id}/goals 서브컬렉션 구조 설계
- [ ] 목표 추가/수정/삭제 UI (BottomSheet)
- [ ] _GoalsTab 실제 구현 (진행률 카드 위젯)
- [ ] 런닝 저장 시 현재 활성 목표 progress 자동 업데이트
- [ ] 목표 달성 시 result 페이지에 축하 메시지 표시
- [ ] Phase 6 배지와 연동 (목표 달성 → 배지 획득 조건)

**Firestore:**
```
users/{id}/goals/{goalId}
  type: "weekly_distance" | "monthly_distance" | "weekly_count" | "streak"
  targetValue: number
  currentValue: number
  period: "2026-W12" | "2026-03"   // 주간/월간 식별자
  isCompleted: boolean
  createdAt: timestamp
```

---

## 🍎 Apple 로그인 (앱스토어 출시 전 필수)

> **조건:** Apple Developer Program 가입 필요 ($99/년, developer.apple.com)
> **필수 이유:** App Store 정책 — 소셜 로그인 제공 시 Apple 로그인 반드시 포함 (미준수 시 심사 거절)

### 구현 체크리스트
- [ ] Apple Developer Console → App ID에 "Sign In with Apple" 활성화
- [ ] Firebase Console → Authentication → Apple 로그인 사용 설정
- [ ] Xcode → Signing & Capabilities → "Sign In with Apple" Capability 추가
- [ ] 앱스토어 제출 전 실기기 테스트 (시뮬레이터 불가)

### 코드 현황
- Flutter 코드는 이미 완성 (`auth_firebase_datasource.dart`, `social_login_page.dart`)
- Apple Developer 계정 등록 후 위 체크리스트만 완료하면 즉시 동작

### 주의사항
- Apple은 최초 로그인 시에만 이름/이메일 제공 → 이후 재로그인 시 null
- 회원 탈퇴 기능도 앱 내에서 제공 필수 (미구현 시 App Store 심사 거절)
