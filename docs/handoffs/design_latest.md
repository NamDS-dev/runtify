---
feature: 크루 고도화 — 정보 수정 + 멤버 퇴출
status: done
date: 2026-04-07
---

## Figma 프레임
| 화면 | ID | x | y |
|------|-----|---|---|
| 5-SUB. Crew Edit (수정 BottomSheet) | 267:23 | 4300 | 2772 |
| 5-SUB. Crew Detail (Member Kick) | 268:44 | 4730 | 2772 |

## 1. 크루 정보 수정 BottomSheet (리더 전용)
- 트리거: 크루 상세 페이지에서 "✏️ 수정" 버튼 (리더에게만 표시)
- BottomSheet: #1A1A1A, cornerRadius 24, 핸들바 48×4 grey.600
- 제목: "✏️ 크루 정보 수정" #FFFFFF 18px Bold
- 필드 4개:
  - 크루 이름: TextField, fillColor #252525, borderRadius 12
  - 활동 지역: 탭 → 휠 피커 (korea_regions.dart 재사용)
  - 크루 소개: TextField multiline, fillColor #252525, borderRadius 12
  - 최대 인원: [−] N명 [+] 카운터 (기존 crew_create_page 패턴 재사용)
- 저장 버튼: #FF4D00, cornerRadius 14, 350×52, "저장하기"

## 2. 멤버 강제 퇴출 (리더 전용)
- 위치: crew_detail_page.dart 멤버 목록의 각 멤버 행
- 리더에게만 표시: 멤버 행 우측에 빨간 ✕ 아이콘 (#FF3333, 18px)
- 리더 본인 행에는 ✕ 미표시 (자기 자신 퇴출 불가)
- 탭 시 확인 다이얼로그: "홍길동님을 크루에서 퇴출하시겠습니까?"
- 확인 → Firestore에서 멤버 제거 + users/{id}.crewId 삭제

## 코딩 에이전트 참고사항
- 크루 수정: crew_firestore_datasource.dart에 updateCrew() 메서드 추가
- 크루장 탈퇴 방지: leaveCrew()에 leaderId 검증 추가 (Firestore 레벨)
- 멤버 퇴출: crew_firestore_datasource.dart에 kickMember() 메서드 추가
- UX 문구: crew_challenge_page에서 비리더에게 "리더가 챌린지를 만들 수 있어요" 표시
