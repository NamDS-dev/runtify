---
feature: 크루 이벤트 (그룹 러닝 모집)
status: done
date: 2026-04-12
---

## Figma 프레임
| 화면 | ID | x | y |
|------|-----|---|---|
| 5-SUB. Crew Event List | 288:68 | 5760 | 924 |
| 5-SUB. Crew Event Create | 288:69 | 5760 | 1848 |

## 이벤트 목록 (288:68)
- 앱바: "← 크루 이벤트"
- 다가오는 이벤트 섹션: #FFFFFF 16px Bold
  - 이벤트 카드: #252525, cornerRadius 16, 358×160
    - 날짜/시간: #FF4D00 12px SemiBold
    - 제목: "🏃 토요 한강 러닝" #FFFFFF 18px Bold
    - 장소: "📍 반포한강공원 · 5km 코스" #9E9E9E 13px
    - 참가자: "👥 8 / 15명 참가" #808080 12px
    - 참가하기 버튼: #FF4D00, cornerRadius 8, 326×40
- 지난 이벤트 섹션: #9E9E9E 16px Bold
  - 카드: #1A1A1A, cornerRadius 16, 회색 텍스트
- 이벤트 만들기 FAB: #FF4D00, 56×56, 📅, 리더에게만

## 이벤트 생성 BottomSheet (288:69)
- 딤: #000000 50%
- BottomSheet: #1A1A1A, cornerRadius 24
- 핸들바: 48×4, grey.600
- 제목: "📅 이벤트 만들기" #FFFFFF 18px Bold
- 필드 3개 (모두 #252525, cornerRadius 12):
  - 이벤트 제목: TextField (최대 30자)
  - 날짜: showDatePicker (캘린더), 시간: CupertinoPicker (휠 피커)
  - 장소: TextField
- 이벤트 만들기 버튼: #FF4D00, cornerRadius 14, 350×52

## Firestore 구조
```
crews/{crewId}/events/{eventId}
  title: string
  date: timestamp
  locationName: string
  participantIds: [userId, ...]
  createdBy: userId
  createdAt: timestamp
  status: "upcoming" | "completed"
```

## 코딩 에이전트 참고사항
- 크루 상세 정보 탭에 "이벤트" 섹션 추가 또는 별도 라우트 /crew/events
- 진입: 정보 탭의 위클리 챌린지 카드 아래 또는 AppBar 아이콘
- 참가하기: participantIds에 userId toggle (arrayUnion/arrayRemove)
- 날짜 선택: showDatePicker + showTimePicker (Flutter 기본)
- 지난 이벤트: date < now → status=completed, 회색 처리
- 이벤트 생성 시 content_validator.dart로 제목/장소 검증
