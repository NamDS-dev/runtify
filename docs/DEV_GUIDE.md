# Runtify 개발 가이드

> 작성일: 2026-03-09
> 규칙: **Design-First** — Figma 디자인 확정 → Flutter 코드 구현 순서 필수

---

## 1. 환경 구성 (Dev / Prod)

### 개념

| 환경 | Firebase 프로젝트 | 용도 |
|------|-------------------|------|
| **Dev** | `runtify-dev` | 개발/테스트용. 실데이터 오염 걱정 없이 자유롭게 테스트 |
| **Prod** | `runtify` | 실사용자 데이터. 신중하게 접근 |

### 실행 명령어

```bash
# 개발 환경 (기본값 — 평소 개발 시 사용)
flutter run --dart-define=FLAVOR=dev

# 프로덕션 환경 (실사용자 DB 확인 시만 사용)
flutter run --dart-define=FLAVOR=prod

# 프로덕션 APK 빌드 (앱 배포 시)
flutter build apk --dart-define=FLAVOR=prod

# 프로덕션 iOS 빌드
flutter build ios --dart-define=FLAVOR=prod
```

### VS Code 실행 설정 (.vscode/launch.json)

`.vscode/launch.json` 파일을 만들면 VS Code에서 버튼 하나로 환경 전환:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Runtify (Dev)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define=FLAVOR=dev"]
    },
    {
      "name": "Runtify (Prod)",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define=FLAVOR=prod"]
    }
  ]
}
```

### 개발용 Firebase 셋업 (최초 1회)

1. [Firebase Console](https://console.firebase.google.com) → 새 프로젝트 → **runtify-dev**
2. Android 앱 등록 (패키지명: `com.yourcompany.runtify.dev`)
3. iOS 앱 등록 (번들 ID: `com.yourcompany.runtify.dev`)
4. 아래 명령어로 dev 설정 파일 자동 생성:
   ```bash
   flutterfire configure --project=runtify-dev --out=lib/firebase_options_dev.dart
   ```
5. Firestore, Authentication 활성화 (prod와 동일하게 설정)

---

## 2. 개발 워크플로우

### 기능 개발 순서 (매번 동일)

```
1. FEATURE_PLAN.md 에서 해당 Phase 기획 확인
2. /project:design → Figma에서 화면 디자인
3. 디자인 확정
4. /project:coding → Flutter + Firebase 코드 구현
5. flutter analyze 통과 확인
6. Dev 환경에서 직접 테스트
7. 다음 Phase
```

### 코드 품질 체크 (PR 전 필수)

```bash
# 정적 분석 (오류/경고 확인)
flutter analyze

# 코드 포맷 자동 정리
dart format lib/

# 테스트 실행
flutter test
```

---

## 3. 테스트 전략

### 테스트 범위 (현실적인 기준)

| 레이어 | 테스트 여부 | 이유 |
|--------|------------|------|
| **Domain UseCase** | ✅ 필수 | 포인트/스트릭 계산 버그가 치명적 |
| **Data Repository** | ⚡ 핵심만 | Firebase 모킹 필요 |
| **Presentation Widget** | ❌ 선택 | 시간 대비 효율 낮음 |

### 테스트 파일 위치

```
test/
├── features/
│   └── running/
│       └── domain/
│           └── usecases/
│               └── point_calculation_test.dart  ← 포인트 계산 테스트
```

### 핵심 테스트 케이스 (구현 예정)

```dart
// 포인트 계산 테스트
test('5km 달리면 50P', ...);
test('페이스 5분 이하면 속도 보너스 +25P', ...);
test('7일 스트릭이면 1.5배', ...);
test('스트릭 하루 끊기면 리셋', ...);
```

---

## 4. Firebase 보안 규칙

### Firestore Rules (현재 상태 확인 필요)

```
// 기본 규칙 — 로그인한 유저만 자신의 데이터 접근
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 유저 문서: 본인만 읽기/쓰기
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    // 러닝 세션: 본인 세션만 접근
    match /running_sessions/{sessionId} {
      allow read, write: if request.auth.uid == resource.data.userId;
      allow create: if request.auth.uid == request.resource.data.userId;
    }
    // 크루: 로그인 유저 읽기 가능, 쓰기는 크루장만
    match /crews/{crewId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == resource.data.leaderId;
    }
  }
}
```

---

## 5. 브랜치 전략 (단순화)

혼자 개발하므로 브랜치 전략을 단순하게 유지:

```
main  ← 항상 동작하는 코드 유지
```

- 기능 개발은 `main`에서 직접 (브랜치 없음)
- 큰 변경 전 commit으로 체크포인트 저장

### Git 커밋 컨벤션

```
feat: 새 기능 추가
fix: 버그 수정
design: Figma/UI 변경
refactor: 코드 리팩토링
docs: 문서 수정
chore: 설정/패키지 변경

예시:
feat: 소셜 로그인 화면 (Google/Apple)
fix: 스트릭 계산 엣지케이스 수정
design: Home Hub 화면 레이아웃 변경
```

---

## 6. 주요 파일 위치

| 파일 | 역할 |
|------|------|
| `lib/core/config/app_env.dart` | 환경 설정 (dev/prod 구분) |
| `lib/firebase_options.dart` | Prod Firebase 설정 |
| `lib/firebase_options_dev.dart` | Dev Firebase 설정 (셋업 필요) |
| `lib/core/router/app_router.dart` | 라우팅 전체 |
| `lib/core/theme/app_theme.dart` | 색상/테마 |
| `docs/FEATURE_PLAN.md` | 기능 기획서 |
| `docs/DEV_GUIDE.md` | 이 파일 |

---

## 7. 배포 체크리스트 (앱스토어 출시 전)

- [ ] Apple Developer 계정 등록 ($99/년)
- [ ] Apple 로그인 설정 완료
- [ ] 회원 탈퇴 기능 구현 (Apple 정책 필수)
- [ ] Firebase 보안 규칙 점검
- [ ] Prod 환경 빌드 테스트
- [ ] 앱 아이콘 / 스플래시 스크린 적용
- [ ] 개인정보 처리방침 URL 준비
- [ ] Flutter analyze 0 errors
