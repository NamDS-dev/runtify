---
feature: 워치 동기화 홈 카드 + BLE 심박수 온보딩
status: done
analyze: pass
date: 2026-04-10
---

## 변경된 파일

### 신규 생성
- `lib/features/onboarding/presentation/pages/ble_onboarding_page.dart` — BLE 기기 스캔 → 목록 → 연결

### 수정
- `lib/features/running/presentation/pages/home_page.dart` — _WatchSyncCard 위젯 추가
- `lib/core/router/app_router.dart` — /onboarding/ble 라우트 추가

## 주요 구현 결정사항

### 워치 동기화 카드
- 홈에 조건부 표시: `!kIsWeb && Health Connect 권한 있을 때`만
- HealthConnectDataSource.getRecentSessions()로 워치 기록 조회
- 최근 2건 미리보기 (거리/시간/심박수 + 날짜)
- "전체 기록 가져오기" → Firestore에 저장 (중복 세션은 saveSession에서 스킵)

### BLE 온보딩
- FlutterBluePlus.startScan()으로 Heart Rate Service(0x180D) 기기 스캔
- 기기 목록 표시 (신호 강도별 UI 차별화 — 강함: #252525, 약함: #1A1A1A)
- 연결 탭 → connect() → SharedPreferences에 기기 ID/이름 저장
- 온보딩에서는 연결 확인만 하고 disconnect (실제 연결은 러닝 시)
- 기기 못 찾을 시 "삼성 헬스 앱이 실행 중인지 확인" 안내

## 정적 분석 결과
```
flutter analyze --no-pub
→ No issues found!
```
