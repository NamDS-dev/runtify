---
feature: 워치 동기화 홈 카드 + BLE 심박수 온보딩
status: done
date: 2026-04-10
---

## Figma 프레임
| 화면 | ID | x | y |
|------|-----|---|---|
| 2-SUB. Home (Watch Sync) | 281:149 | 1060 | 924 |
| OB-4. BLE 심박수 연결 | 281:159 | 9690 | 924 |

## 1. 워치 동기화 홈 카드 (281:149)
- 위치: 홈 대시보드에 삽입 (리워드 포인트 배너 아래 또는 위)
- 카드: #252525, cornerRadius 16, 358×168
- 헤더: "⌚ 워치 동기화" #FFFFFF 15px Bold + "N건 새 기록" #FF4D00 12px SemiBold
- 기록 행: "🏃 4.2km · 24:30 · 148bpm" #9E9E9E 13px + 날짜 #666666 11px
- 버튼: "전체 기록 가져오기 →" #FF4D00/10% bg, cornerRadius 10
- 표시 조건: Health Connect 권한 허용 + 동기화된 워치 기록이 있을 때만
- "전체 기록 가져오기" 탭 → HealthConnectDataSource.getRecentSessions() 호출 → Firestore에 저장

## 2. BLE 심박수 연결 (281:159)
- 진입: Health Connect 온보딩 완료 후 또는 프로필 설정에서
- 제목: "❤️ 실시간 심박수 연결" #FFFFFF 22px Bold
- 설명: "갤럭시 워치의 심박수를 러닝 중 실시간으로 표시합니다"
- 스캔 상태: "주변 기기 검색 중..." #FF4D00 13px SemiBold
- 기기 카드: #252525 cornerRadius 14, 350×64
  - 기기명: "⌚ Galaxy Watch6" #FFFFFF 15px Bold
  - 신호: "신호 강함 · Heart Rate Service" #808080 11px
  - 연결 버튼: "연결" #FF4D00 14px Bold
- 약한 신호 기기: #1A1A1A bg, 회색 텍스트
- 힌트: "💡 워치의 삼성 헬스 앱이 실행 중이어야..." #666666 12px
- 나중에 하기: #666666 13px Center

## 코딩 에이전트 참고사항
- 워치 카드: home_page.dart에 조건부 표시 (Health Connect 권한 + 데이터 존재)
- BLE 온보딩: heart_rate_ble_datasource.dart의 scanForDevices() 재사용
- 라우트: /onboarding/ble 추가
- 연결 성공 시 SharedPreferences에 저장, 러닝 시 자동 재연결
