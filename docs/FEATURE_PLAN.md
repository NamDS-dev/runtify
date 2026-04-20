# Runtify 기능 기획서

> 작성일: 2026-03-04
> 최종 수정: 2026-03-26
> 규칙: **Figma 디자인 승인 → 코드 구현** 순서 필수

---

## 🤖 야간 PM 발견 갭

> `/pm-night` 실행 시 자동 갱신되는 섹션
> PM이 기획 오딧(코드/UX ↔ 모범사례 비교)으로 누락된 항목 기록
> 🟢 = 야간 자동 구현 대상 / 🟡 = 사용자 검토 필요 / 🔴 = 정책·보안 결정 필요

### 🟢 자동 구현 대상 (다음 야간 작업 우선순위)

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

### 🟡 기획 확정 대기 (사용자 검토 후 구현)

- [ ] **[인증] 비밀번호 재설정 기능 (2026-04-20 발견)**
  - 현재: 로그인 페이지에 "비밀번호 찾기" 버튼 없음. Firebase `sendPasswordResetEmail` 미사용
  - 개선: 로그인 페이지 하단에 "비밀번호 찾기" 버튼 → 이메일 입력 모달 → `sendPasswordResetEmail` 호출 → 성공 메시지
  - 검토 필요: 재설정 이메일 템플릿을 Firebase 기본으로 갈지 커스텀으로 갈지 (브랜드)
  - 파일: `lib/features/auth/presentation/pages/login_page.dart`, `lib/features/auth/data/datasources/auth_firebase_datasource.dart`, `lib/features/auth/domain/usecases/forgot_password_usecase.dart` (신규)
  - 예상: 75분

- [ ] **[인증] 이메일 인증 (Verification) 플로우 (2026-04-20 발견)**
  - 현재: `signUpWithEmail`에서 계정 생성 후 인증 이메일 자동 발송 없음. 미검증 계정도 전체 기능 접근 가능
  - 개선: `sendEmailVerification()` 호출 + `emailVerified` 필드를 UserEntity에 추가 + 미인증 상태 UI 배너 + 인증 전 특정 기능(크루 가입, 리워드) 제한
  - 검토 필요: 어느 기능까지 인증 없이 허용할지(온보딩 UX vs 정책 강도)
  - 파일: `auth_firebase_datasource.dart`, `user_entity.dart`, `user_model.dart`, `login_page.dart`
  - 예상: 120분

- [ ] **[인증] 연속 로그인 실패 레이트 리밋 (2026-04-20 발견)**
  - 현재: 실패 에러만 반환. 3회 이상 실패 시 계정 잠금/대기 없음 (Firebase 측 기본 rate limit만)
  - 개선: 로컬 `SharedPreferences`로 실패 횟수 추적 → 3회 실패 시 60초 대기 강제 + UI 카운트다운
  - 검토 필요: 서버 측(Firebase 규칙/함수) 강화도 추가할지 — Blaze 요금제 전환 검토
  - 파일: `lib/features/auth/presentation/pages/login_page.dart`, `lib/features/auth/presentation/providers/auth_provider.dart`
  - 예상: 85분

- [ ] **[인증] 세션 만료 및 토큰 갱신 처리 (2026-04-20 발견)**
  - 현재: Firebase ID token 만료(1시간)에 대한 명시적 처리 없음. 갱신 자동화/UI 피드백 미구현
  - 개선: `FirebaseAuth.instance.idTokenChanges()` 스트림 모니터링 → 갱신 실패 시 로그인 리다이렉트. 선택: 30분 유휴 시 강제 재인증
  - 검토 필요: 유휴 시간 정책 정하기 + 기존 러닝 중에 토큰 만료 시 UX 시나리오
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
| Apple Developer 등록 | ⬜ 필요 | $99/년, developer.apple.com |
| Apple 로그인 활성화 | ⬜ 필요 | 소셜 로그인 제공 시 필수 (App Store 정책) |
| App Store 심사 | ⬜ 필요 | 회원 탈퇴 기능 등 심사 요구사항 확인 |

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
