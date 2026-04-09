---
date: 2026-04-10
target: 워치 동기화 홈 카드 + BLE 심박수 온보딩
result: pass
---

## 분석 결과
- flutter analyze: ✅ pass (0 issues)
- flutter test: ✅ pass (1 passed)

## 테스트 케이스

| # | 케이스 | 조건 | 기대 결과 | 실제 결과 | 상태 |
|---|--------|------|-----------|-----------|------|
| 1 | 홈 워치 카드 (웹) | kIsWeb | 카드 숨김 | 홈에 워치 카드 미표시 (정상) | ✅ |
| 2 | BLE 온보딩 라우팅 | /onboarding/ble | 페이지 표시 | 정상 렌더링 | ✅ |
| 3 | BLE 온보딩 (웹) | kIsWeb | "모바일에서만" 안내 | ⌚ + 안내 문구 + 홈으로 버튼 | ✅ |
| 4 | 홈으로 이동 | 홈으로 버튼 탭 | /home 이동 | 정상 이동 | ✅ |
| 5 | 워치 카드 데이터 표시 | Android + Health Connect | 워치 기록 미리보기 | 실기기 필요 | ⏭ |
| 6 | BLE 스캔 + 기기 연결 | Android + BLE | 기기 목록 + 연결 | 실기기 필요 | ⏭ |

## 발견된 이슈

없음

## 스크린샷
- `qa_ble_onboarding_web_20260410.png` — BLE 온보딩 웹 안내 화면

## 다음 액션
- [ ] Android 실기기에서 워치 카드 데이터 표시 + 전체 동기화 테스트
- [ ] Android 실기기에서 BLE 스캔 + Galaxy Watch 연결 테스트
