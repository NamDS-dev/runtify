---
date: 2026-04-12
target: 크루 이벤트 (그룹 러닝 모집)
result: pass
---

## 분석 결과
- flutter analyze: ✅ pass (0 issues)
- flutter test: ✅ pass (1 passed)

## 사전 조치
- crew_detail_page 정보 탭에 이벤트 진입 카드 추가 (QA 중 발견 → 즉시 수정)
- Firestore Rules: events 서브컬렉션 규칙 배포

## 테스트 케이스

| # | 케이스 | 조건 | 기대 결과 | 실제 결과 | 상태 |
|---|--------|------|-----------|-----------|------|
| 1 | 이벤트 진입 카드 | 크루 상세 정보 탭 | "📅 크루 이벤트" 카드 | 정상 (위클리 챌린지 아래) | ✅ |
| 2 | 빈 상태 | 이벤트 없음 | "아직 이벤트가 없어요" + FAB | 정상 | ✅ |
| 3 | 생성 BottomSheet | FAB 탭 | 제목/날짜/시간/장소 폼 | 정상 (30자 제한, 캘린더, 휠 피커) | ✅ |
| 4 | 이벤트 생성 | 폼 입력 후 생성 | 목록에 카드 표시 + SnackBar | 정상 (1명 참가 + 참가 취소 버튼) | ✅ |

## 발견 + 해결된 이슈

| 우선순위 | 이슈 | 조치 |
|----------|------|------|
| 🔴 | 이벤트 진입점 없음 | ✅ crew_detail_page에 이벤트 카드 추가 |

## 스크린샷
- `qa_crew_event_entry_20260412.png` — 정보 탭 이벤트 진입 카드
- `qa_crew_event_empty_20260412.png` — 빈 상태
- `qa_crew_event_create_20260412.png` — 생성 BottomSheet
- `qa_crew_event_created_20260412.png` — 이벤트 생성 완료 + 목록
