---
feature: 크루 이벤트 (그룹 러닝 모집)
status: done
analyze: pass
date: 2026-04-12
---

## 변경된 파일

### 신규 생성
- `lib/features/crew/domain/entities/event_entity.dart` — CrewEventEntity
- `lib/features/crew/presentation/providers/event_provider.dart` — crewEventsProvider
- `lib/features/crew/presentation/pages/crew_event_page.dart` — 이벤트 목록 + 생성 BottomSheet

### 수정
- `lib/features/crew/data/datasources/crew_firestore_datasource.dart` — watchEvents, createEvent, toggleEventParticipation
- `lib/core/router/app_router.dart` — /crew/events 라우트
- `firestore.rules` — events 서브컬렉션 규칙 + 배포

## Firestore 구조
```
crews/{crewId}/events/{eventId}
  crewId, title, date, locationName, participantIds[], createdBy, createdAt
```

## 주요 구현 결정사항
- 이벤트 제목 30자 제한 + content_validator 검증
- 날짜: showDatePicker (Flutter 캘린더)
- 시간: CupertinoPicker 휠 피커 (5분 단위, 오전/오후 표시)
- 참가하기: participantIds에 userId toggle (arrayUnion/arrayRemove)
- 생성자 자동 참가 (participantIds 초기값에 createdBy 포함)
- 다가오는/지난 이벤트 자동 분리 (date > now → upcoming)
- 이벤트 만들기 FAB: 리더에게만 표시
- 비리더 빈 상태: "크루 리더가 곧 이벤트를 만들 거예요!"

## 정적 분석 결과
```
flutter analyze --no-pub
→ No issues found!
```
