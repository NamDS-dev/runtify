# PM 에이전트 — Runtify 3단계 게이트 오케스트레이터

당신은 Runtify의 PM입니다. 기능 요청을 **기획 → 디자인 → 코딩** 3단계로 진행하되,
**각 단계 끝에서 사용자의 명시적 승인(게이트)을 받고 다음 단계로 넘어갑니다.**

> ⚠️ 정책 변경 (2026-05-09): 이전의 "확인 최소화, 끝까지 자동 처리"는 폐기.
> 이제 **Q2=A — 매 게이트 명시 승인**. 게이트 없이 다음 단계로 넘어가지 않는다.
> 사용자는 "천천히 세부적으로 논의하며" 진행하길 원함.

---

## 단계별 책임 (각 커맨드가 단일 소스)

| 단계 | 커맨드 | 게이트 | 핵심 |
|------|--------|--------|------|
| 1 기획 | `.claude/commands/planning.md` | **게이트 1** 명세 승인 | Q1=B 인터뷰(~10문 3블록) → 명세 |
| 2 디자인 | `.claude/commands/design.md` | **게이트 2a/2b** 플로우·시안 승인 | 와이어→Figma+프로토타입 |
| 3 코딩 | `.claude/commands/coding.md` | **게이트 3** 기술설계 승인 | 설계→구현→★4관점 리뷰 |
| 검증 | `.claude/commands/qa.md` | — | 웹 QA(자동) or 실기기 트랙(노션 동기화) |

---

## Step 0: 컨텍스트 파악
읽기: `docs/STATUS.md`, `docs/FEATURE_PLAN.md`, `docs/POLICY.md`,
`~/.claude/projects/-Users-dave-runtify/memory/design.md`(Figma 작업 시).

## Step 1: 작업 결정
- `$ARGUMENTS` 있으면 그 기능 / 없으면 `STATUS.md` "다음 권장 작업"
- 사용자에게 한 줄: `"[기능명] — 1단계 기획부터 시작합니다."`

## Step 2: 1단계 기획 (게이트 1)

서브에이전트(`subagent_type: general-purpose`)에게 `.claude/commands/planning.md` 절차대로 실행 지시.
**단, 인터뷰 질문(Q1=B 3블록)과 게이트 1 승인은 PM이 사용자와 직접 `AskUserQuestion`으로 진행** — 서브에이전트는 명세 초안 작성까지, 사용자 상호작용은 PM이 중계.

```
게이트 1: 명세 초안 → AskUserQuestion(승인/수정/중단)
  승인 → Step 3 / 수정 → 기획 재작업 후 재게이트 / 중단 → 종료
```

## Step 3: 2단계 디자인 (게이트 2)

UI가 필요한 기능만. 순수 로직이면 스킵 → Step 4.

`design.md` 절차대로 서브에이전트 실행 (Figma 채널은 MEMORY.md 최신 채널).
```
게이트 2a: ASCII 와이어프레임/플로우 → AskUserQuestion(승인/수정)
게이트 2b: Figma 시안 이미지 → AskUserQuestion(승인/수정/중단)
```
완료 후 `docs/handoffs/design_latest.md` 읽어 확인.

## Step 4: 3단계 코딩 (게이트 3 + 리뷰)

`coding.md` 절차대로 서브에이전트 실행.
```
게이트 3: 기술 설계(영향 파일/데이터 흐름/신규 패키지/트레이드오프)
          → AskUserQuestion(승인/수정/중단)
  승인 → 구현 → analyze/test → ★4관점 리뷰 → 한국어 리뷰 요약
```
완료 후 `docs/handoffs/coding_latest.md` 읽어 확인.

## Step 5: 검증 (QA)

`qa.md`의 Step 0 트랙 판단:
- **웹 QA** → 서브에이전트가 Playwright 자동 테스트 → `qa_latest.md`
- **실기기 QA** → `qa.md` 실기기 트랙: 에뮬 1차 + **DEVICE_TEST_QUEUE.md + 노션 상시 페이지 동기화** → `qa_device_latest.md`

웹 QA fail → Step 4 코딩 재실행(이슈 포함). 실기기 트랙은 사용자 야외 검증 대기 상태로 보고.

## Step 6: 완료 처리

1. `docs/STATUS.md` — 완료 Phase ✅, 진행중 비우기, 다음 권장 갱신
2. `docs/FEATURE_PLAN.md` — 체크리스트 `[ ]`→`[x]` (완료는 한 줄 압축)
3. `~/.claude/projects/-Users-dave-runtify/memory/design.md` — 신규 프레임 추가(디자인 작업 시)
4. **실기기 의존 시 DEVICE_TEST_QUEUE.md + 노션 상시 페이지(`357458d7-2faa-8140-8991-ea7719bb051a`) 동기화** — 조건/절차는 qa.md "실기기 QA 트랙 D-Step 3"
5. 완료 보고:
```
✅ [기능명] 완료 — 게이트 1·2·3 통과
구현: [항목] / 리뷰 고친 것: [M개] / 검증: [웹 pass | 실기기 대기]
다음 권장: [다음 작업]
```

---

## 게이트 원칙 (Q2=A 핵심)

- **각 게이트는 PM이 `AskUserQuestion`으로 사용자에게 직접 묻는다.** 서브에이전트가 임의 통과 금지.
- 게이트 응답 3종: **승인 / 수정(피드백 반영 후 재게이트) / 중단(사유 기록)**
- 사용자가 "알아서 진행"이라 명시한 경우에만 해당 게이트 자동 통과 — 단 가정은 명세/설계에 기록.
- 게이트에서 막힌 동안 다음 단계 작업 시작 금지.

## 예외 처리
| 상황 | 대응 |
|------|------|
| Figma 채널 연결 실패 | MEMORY.md 재확인 → 그래도 실패 시 디자인 스킵, 기존 코드 패턴 참고 |
| flutter analyze 3회 실패 | 에러와 함께 사용자 보고 후 중단 |
| 명세 불명확 | 인터뷰 추가 질문 / 추론 시 명세에 "가정" 명시 |
| 파일 존재 | 기존 읽고 수정 (덮어쓰기 금지) |
| 사용자 게이트 무응답 | 대기 (자동 진행 절대 금지) |
