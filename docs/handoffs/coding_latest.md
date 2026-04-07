---
feature: 크루 고도화 (정보 수정 + 리더 검증 + 멤버 퇴출 + UX 문구)
status: done
analyze: pass
date: 2026-04-07
---

## 변경된 파일

### 수정
- `lib/features/crew/data/datasources/crew_firestore_datasource.dart`
  - leaveCrew(): 리더 탈퇴 방지 Firestore 검증 추가
  - updateCrew(): 크루 정보 수정 메서드 추가
  - kickMember(): 멤버 강제 퇴출 메서드 추가
- `lib/features/crew/presentation/providers/crew_provider.dart`
  - updateCrew(), kickMember() 액션 추가
- `lib/features/crew/presentation/pages/crew_detail_page.dart`
  - AppBar에 수정 버튼 (리더 전용)
  - 수정 BottomSheet (이름/지역 휠피커/소개/인원)
  - 멤버 목록에 ✕ 퇴출 아이콘 (리더 전용, 리더 본인 제외)
  - 퇴출 확인 다이얼로그
- `lib/features/crew/presentation/pages/crew_challenge_page.dart`
  - 빈 챌린지 상태 문구: 리더/비리더 구분

## 주요 구현 결정사항
- leaveCrew()에서 Firestore 트랜잭션 내 leaderId 검증 (UI+서버 이중 검증)
- 멤버 퇴출 시 확인 다이얼로그 필수 (실수 방지)
- 크루 수정 BottomSheet에서 지역 선택은 korea_regions.dart 휠 피커 재사용
- 비리더 챌린지 안내: "크루 리더가 곧 챌린지를 시작할 거예요 🔥"

## 정적 분석 결과
```
flutter analyze --no-pub
→ No issues found!
```
