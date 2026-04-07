---
date: 2026-04-07
target: 크루 고도화 (정보 수정 + 리더 검증 + 멤버 퇴출 + UX 문구)
result: pass
---

## 분석 결과
- flutter analyze: ✅ pass (0 issues)
- flutter test: ✅ pass (1 passed)

## 사전 조치
- Firestore Security Rules 배포 (`firestore.rules` 생성 + `firebase deploy`)
- crews, courses, regionStats 등 전체 컬렉션 규칙 추가

## 테스트 케이스

| # | 케이스 | 조건 | 기대 결과 | 실제 결과 | 상태 |
|---|--------|------|-----------|-----------|------|
| 1 | 수정 버튼 표시 | 리더 시점 크루 상세 | AppBar에 ✏️ 버튼 | ref=e46 버튼 표시됨 | ✅ |
| 2 | 수정 BottomSheet | ✏️ 탭 | 이름/지역/소개/인원 폼 | 정상 (기존값 입력됨 + 휠 피커) | ✅ |
| 3 | 멤버 퇴출 ✕ | 리더 시점 멤버 목록 | 리더 본인 ✕ 없음 | 1인 크루에서 ✕ 미표시 (정상) | ✅ |
| 4 | 챌린지 빈 상태 문구 | 리더 시점 | "아래 버튼으로 새 챌린지를..." | 정상 표시 | ✅ |

## 발견된 이슈

없음 (이전 블로커였던 Firestore 권한 문제 해결됨)

## 스크린샷
- `qa_crew_detail_leader_20260407.png` — 크루 상세 (수정 버튼 + 리더 탈퇴 비활성화)
- `qa_crew_edit_sheet_20260407.png` — 수정 BottomSheet
- `qa_crew_challenge_leader_20260407.png` — 챌린지 빈 상태 (리더 문구)

## 다음 액션
- 없음 (전체 통과)
