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

- [ ] **[버그] Android 러닝 중 GPS 거리 0km (2026-04-19)**
  - 변경: `running_page.dart` GPS accuracy 필터 완화 (20m → 초기 10초 면제 + 이후 50m), `AndroidSettings` + `foregroundNotificationConfig` 적용, `AndroidManifest.xml`에 `ACCESS_BACKGROUND_LOCATION` + `FOREGROUND_SERVICE_LOCATION` 추가
  - 재현/검증 절차:
    1. 야외에서 앱 실행 → 러닝 시작
    2. 최소 100m 이상 실제 이동
    3. **거리 카운트가 0km가 아닌 값으로 증가**하는지 확인
    4. 지도에 경로 polyline 그려지는지 확인
    5. 화면 꺼진 상태로 1분 이동 → 복귀 시 거리 지속 누적 여부 확인

### 공통

- [ ] **[기능] BLE 심박수 측정 실기기 검증**
  - Galaxy Watch/Apple Watch 페어링 상태에서 실제 심박수 수신 테스트
  - 시뮬레이터 미지원 기능 — 실기기 필수
  - 재현/검증 절차:
    1. 워치 심박수 센서 활성
    2. Runtify 러닝 시작
    3. BLE 자동 스캔/연결 → 실시간 심박수 표시 확인

---

## ✅ 완료 아카이브

(테스트 후 이 섹션으로 이동)

