# Runtify - 프로젝트 컨텍스트

## 프로젝트 개요
러닝 데이터를 게이미피케이션한 모바일 앱. 웨어러블 기기로 러닝을 트래킹하고, 포인트/크루/랭킹 시스템으로 동기 부여. 실제 리워드(쿠폰, 상품권)까지 연결.

## 기술 스택
- **모바일:** Flutter (Dart)
- **백엔드/DB:** Firebase (Firestore + Realtime DB)
- **디자인:** Figma
- **웨어러블 1차:** Samsung Health SDK (Galaxy Watch)
- **웨어러블 2차:** Apple HealthKit
- **개발 환경:** macOS (Mac Mini M4)

## 개발자 배경
- 웹 개발(React) 경험 있음
- 앱/워치 개발은 처음
- 하루 1시간 내외 사이드 프로젝트
- AI 자동화 최대 활용 원칙

## 에이전트 사용법
| 명령어 | 역할 | 예시 |
|--------|------|------|
| `/project:planning` | 기획/문서화/DB 설계 | `/project:planning 크루 시스템 기능 명세 작성해줘` |
| `/project:coding` | Flutter/Firebase 코드 작성 | `/project:coding 로그인 화면 코드 만들어줘` |
| `/project:design` | UI/UX 디자인 가이드 | `/project:design 홈 대시보드 레이아웃 잡아줘` |

## MVP 우선순위 (개발 순서)
1. Flutter 프로젝트 초기 설정
2. Firebase 연동 + 로그인
3. Samsung Health API 연동 (러닝 데이터 수신)
4. 기본 대시보드 (러닝 기록 표시)
5. 포인트 시스템
6. 크루 기능
7. 랭킹 시스템
8. 리워드 스토어

## 개발 워크플로우 (Design-First)
**반드시 이 순서로 작업:**
1. `/project:design` → Figma에서 UI 먼저 디자인
2. 디자인 확정 후 `/project:coding` → Flutter 코드 구현
3. 코드 먼저 짜는 것 금지 — 항상 Figma 디자인 기준

## 기능 기획 문서
→ [docs/FEATURE_PLAN.md](docs/FEATURE_PLAN.md) 에서 남은 기능 기획 확인

## 코딩 완료 후 필수 체크 (자동 QA)
코드 작성이 끝나면 **항상 이 순서로 실행**:
1. `flutter analyze --no-pub` — 정적 분석 (타입 에러, 미사용 임포트 등)
2. `flutter test` — 유닛/위젯 테스트 실행
3. 실패 항목 있으면 수정 후 재실행, 통과 후 사용자에게 결과 보고

테스트 파일이 없으면 `flutter analyze`만 실행하고,
핵심 비즈니스 로직(포인트 계산, 가입 조건 등)은 테스트 코드도 함께 작성할 것.

## 주요 규칙
- 코드에 한국어 주석 포함
- 복잡한 기능보다 동작하는 기능 우선
- 파일 경로 항상 명시
