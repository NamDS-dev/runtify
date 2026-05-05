# 실기기 검증 대기 큐

> **목적**: 실기기(iPhone/Android)에서 직접 테스트가 필요한 항목 모음
> **작성 주체**: PM/coding/qa 에이전트가 작업 완료 시 자동 추가 (규칙은 `.claude/commands/pm.md`, `qa.md` 참조)
> **활용**: 사용자가 실기기 확보 시 이 파일 하나만 보고 순차 테스트

---

## 📝 작성 규칙

새 항목 추가 시 아래 형식:

```markdown
- [ ] **[분류] 제목 (YYYY-MM-DD)**
  - 변경: (어떤 코드가 바뀌었나, 한 줄)
  - 재현/검증 절차:
    1. 단계 1
    2. 단계 2
  - 관련 커밋: `짧은 해시`
  - 관련 핸드오프: `docs/handoffs/파일명.md`
```

테스트 완료되면 `[ ]` → `[x]` 변경 + "✅ 완료 아카이브" 섹션으로 이동.

---

## 🔴 대기 중

### iOS

- [ ] **[UX] iOS 엣지 스와이프 뒤로가기 (2026-04-20)**
  - 변경: `lib/core/router/app_router.dart`에 `CupertinoPage` 플랫폼 분기 추가
  - 재현/검증 절차:
    1. 임의 화면(크루 상세, 러닝 기록 상세 등) 진입
    2. 좌측 엣지에서 우측으로 스와이프
    3. 이전 화면으로 돌아가는지 + **Cupertino 슬라이드 애니메이션**(좌우) 확인
    4. `/running/result` 등 extra 파라미터 라우트도 정상 표시되는지
  - 관련 커밋: `5a5c313`
  - 관련 핸드오프: `docs/handoffs/auto_2026-04-20-2240.md`

- [ ] **[버그] iOS 러닝 중 백그라운드 복귀 시 크래시 (2026-04-19)**
  - 변경: `lib/features/running/presentation/pages/running_page.dart`에 `WidgetsBindingObserver` 추가, `AppleSettings`의 `allowBackgroundLocationUpdates: true` 설정, `Info.plist`에 BLE 권한 문구 + `UIBackgroundModes: location` 추가
  - 재현/검증 절차:
    1. 러닝 시작
    2. 홈 버튼(또는 Cmd+Shift+H) → 앱 백그라운드 진입
    3. 홈 화면에서 Runtify 아이콘 다시 탭 → 앱 복귀
    4. **크래시 없이 러닝 상태 유지**되는지 확인
    5. 거리/시간 카운트 지속되는지 확인
  - Xcode Capability: `Background Modes → Location updates` 체크 필요 (미설정 시 실기기 빌드에서만 실패)

- [ ] **[선택] iOS 러닝 시간 측정 실기기 최종 확인 (2026-04-19)**
  - 시뮬에서 이미 검증됨 — 실기기 재확인은 안전망 차원
  - 재현/검증: 러닝 시작 → 10초간 시간 카운트 증가 확인

- [ ] **[선택] iPhone 17 Pro Max 화면 비율 실기기 확인 (2026-04-19)**
  - 시뮬에서 레터박스 해결 검증 완료 — 실기기도 동일한지 확인
  - 원인: `lib/main.dart`의 `MaterialApp.builder` 고정 390px 제약 → 플랫폼 분기로 수정
  - 재현/검증: 홈 화면에서 좌우 여백 대칭 + 네이티브 너비 확인

### Android

- [ ] **🔴 [버그] Android 러닝 중 GPS 거리 0km — 알림 권한 + onError 재구독 픽스 (2026-05-03 수정, 가장 핵심)**
  - 변경 (2026-05-03): `running_page.dart`
    - 알림 권한을 GPS stream 시작 전 await (3초 timeout) — 이전엔 fire-and-forget이라 권한 거부 상태에서 `ForegroundNotificationConfig`가 foreground service 시작 실패 → stream 즉시 onError로 죽음
    - 권한 거부 시 `ForegroundNotificationConfig` null 처리 (foreground service 시도 안 함)
    - onError 발생 시 1s/2s/4s backoff로 자동 재구독 (max 3회), 정상 이벤트 수신 시 카운터 리셋
    - 부수 픽스: `android/app/build.gradle.kts` Properties/FileInputStream 명시적 import (빌드 차단 해결)
  - 재현/검증 절차:
    1. **앱 첫 실행 시나리오 (가장 중요)**: 앱 새로 설치 → 러닝 시작 → 권한 다이얼로그(GPS, 알림) 모두 허용 → 야외 100m+ 실제 이동 → 거리 정상 카운트 확인
    2. **알림 거부 시나리오**: 앱 재설치 → 러닝 시작 → GPS는 허용, **알림은 거부** → 야외 100m+ 이동 → 거리 정상 카운트 (foreground 알림은 안 떠도 GPS는 살아 있어야 함)
    3. **이미 권한 부여된 시나리오**: 위 1번 후 앱 재시작 → 러닝 시작 → 권한 다이얼로그 없이 즉시 GPS 시작 + 거리 카운트
    4. 지도에 경로 polyline 그려지는지 확인
    5. 화면 꺼진 상태로 1분 이동 → 복귀 시 거리 지속 누적 여부 확인
    6. **재구독 동작 확인 (옵션)**: 비행기 모드 ON → 러닝 시작 → "GPS 신호 재연결 중... (n/3)" 메시지 표시 → 비행기 모드 OFF → 자동 복구
  - 관련 커밋: `13eaac7`
  - 이전 시도: `running_page.dart` accuracy 필터 완화, `foregroundNotificationConfig` 적용, `AndroidManifest.xml` 권한 추가

### 공통

- [ ] **[기능] BLE 심박수 측정 실기기 검증**
  - Galaxy Watch/Apple Watch 페어링 상태에서 실제 심박수 수신 테스트
  - 시뮬레이터 미지원 기능 — 실기기 필수
  - 재현/검증 절차:
    1. 워치 심박수 센서 활성
    2. Runtify 러닝 시작
    3. BLE 자동 스캔/연결 → 실시간 심박수 표시 확인

- [ ] **[UX] 리워드 메뉴 숨김 검증 (2026-05-05)**
  - 변경: `FeatureFlags.rewardEnabled = false` — 1차 출시에서는 사업자/통신판매업 미등록 상태라 숨김
  - 재현/검증 절차:
    1. 앱 실행 → 홈 화면 진입
    2. **하단 탭이 4개**(홈/러닝/크루/랭킹)인지 확인 — 5번째 "리워드" 탭 없어야 함
    3. **홈 화면 본문에 "리워드 포인트 1,230P" 배너 안 보여야 함** (크루/지역 미니카드 + 워치 동기화 + 통계만)
    4. 라우트는 코드상 유지됨 — 외부 노출 차단만, dev에서 `/reward` 직접 입력 시 페이지는 동작 (확인 옵션)
  - 관련 커밋: 다음 commit 예정
  - 활성화 시점: 사업자 등록 + 통신판매업 신고 후 `app_env.dart`에서 `rewardEnabled = true`

- [ ] **[회귀] 정리 작업 후 기본 플로우 smoke test (2026-05-05)**
  - 배경: md 정리 + GPS 픽스 + 리워드 숨김 commit 후 기본 동작 회귀 점검
  - 재현/검증 절차:
    1. **로그인 플로우**: 이메일 로그인 → 홈 도달 (또는 신규 계정 → 홈 지역 온보딩 → 건너뛰기 → 홈)
    2. **홈 화면**: 상단 인사 + 레벨 바 + "러닝 시작하기" CTA + 크루/지역 미니카드 + 워치 동기화 + 통계 카드 표시
    3. **러닝 시작 → 종료**: 시작 → 거리 누적 → 종료 → 결과 페이지 → 홈 복귀
    4. **크루/랭킹 탭 진입**: 데이터 정상 표시
    5. **프로필 페이지**: 프로필 아바타 탭 → 레벨/배지/지역/테마/로그아웃 표시
    6. **로그아웃**: 정상 동작 → 로그인 화면 복귀

---

## ✅ 완료 아카이브

(테스트 후 이 섹션으로 이동)

