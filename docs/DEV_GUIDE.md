# Runtify 개발 가이드

> 일상 개발 참고. 1회성 셋업(Firebase, VS Code launch.json, 커밋 컨벤션)은 [SETUP.md](SETUP.md).
> 규칙: **Design-First** — Figma 디자인 확정 → Flutter 코드 구현 순서 필수

---

## 환경

| 환경 | Firebase 프로젝트 | 용도 |
|------|-------------------|------|
| **Dev** (기본) | `runtify-dev` | 개발/테스트 |
| **Prod** | `runtify` | 실사용자 데이터 |

```bash
# 개발 (기본값)
flutter run --dart-define=FLAVOR=dev

# 프로덕션 (실DB 확인 시만)
flutter run --dart-define=FLAVOR=prod

# 프로덕션 빌드
flutter build apk --dart-define=FLAVOR=prod
flutter build ios --dart-define=FLAVOR=prod
```

---

## 개발 워크플로우

```
1. FEATURE_PLAN.md 에서 해당 작업 확인
2. /design → Figma 디자인 확정
3. /coding → Flutter + Firebase 구현
4. flutter analyze --no-pub
5. flutter test
6. Dev 환경 직접 테스트
```

PR/커밋 전 필수: `flutter analyze` 0 issues + `flutter test` 통과.

---

## 테스트 전략

| 레이어 | 테스트 |
|--------|---------|
| Domain UseCase | ✅ 필수 (포인트/스트릭 계산 버그 치명적) |
| Data Repository | ⚡ 핵심만 (Firebase 모킹 필요) |
| Presentation Widget | ❌ 선택 (시간 대비 효율 낮음) |

현재 99건 단위/위젯 테스트. 신규 비즈니스 로직 추가 시 테스트도 함께.

---

## Firebase 보안 규칙

실제 규칙: `firestore.rules` 파일 참조. 변경 시 `firebase deploy --only firestore:rules`.

---

## 주요 파일 위치

| 파일 | 역할 |
|------|------|
| `lib/core/config/app_env.dart` | 환경 설정 (dev/prod) |
| `lib/firebase_options.dart` | Prod Firebase 설정 |
| `lib/firebase_options_dev.dart` | Dev Firebase 설정 |
| `lib/core/router/app_router.dart` | 라우팅 |
| `lib/core/theme/app_theme.dart` | 색상/테마 |
| `firestore.rules` | Firestore 보안 규칙 |
| `docs/FEATURE_PLAN.md` | 기능 기획서 |
| `docs/POLICY.md` | 운영 정책 결정서 |
| `docs/STATUS.md` | 현재 진행 상황 |

---

## 출시 체크리스트

- [ ] Apple Developer 계정 등록 ($99/년)
- [ ] Apple 로그인 설정 완료
- [ ] 회원 탈퇴 기능 구현 (Apple 정책 필수)
- [ ] Firebase 보안 규칙 점검
- [ ] Prod 환경 빌드 테스트
- [ ] 앱 아이콘 / 스플래시 스크린 적용
- [ ] 개인정보 처리방침 URL 준비
- [ ] Flutter analyze 0 errors
