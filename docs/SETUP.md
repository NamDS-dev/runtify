# Runtify 셋업 가이드 (1회성)

> 신규 클론 / 새 환경에서만 참고. 일상 개발은 [DEV_GUIDE.md](DEV_GUIDE.md) 참조.

## Firebase Dev 환경 (최초 1회)

1. [Firebase Console](https://console.firebase.google.com) → 새 프로젝트 → **runtify-dev**
2. Android 앱 등록 (패키지명: `com.yourcompany.runtify.dev`)
3. iOS 앱 등록 (번들 ID: `com.yourcompany.runtify.dev`)
4. dev 설정 파일 자동 생성:
   ```bash
   flutterfire configure --project=runtify-dev --out=lib/firebase_options_dev.dart
   ```
5. Firestore, Authentication 활성화 (prod와 동일하게 설정)

## VS Code 실행 설정 (.vscode/launch.json)

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

## Git 커밋 컨벤션

```
feat: 새 기능
fix: 버그 수정
design: Figma/UI 변경
refactor: 리팩토링
docs: 문서
chore: 설정/패키지

예시:
feat: 소셜 로그인 화면 (Google/Apple)
fix: 스트릭 계산 엣지케이스
```

브랜치 전략: `main` 단일 브랜치 (혼자 개발). 큰 변경 전 commit으로 체크포인트.
