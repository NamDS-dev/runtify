# 핸드오프 디렉토리

에이전트 간 작업 인계 노트를 저장합니다.
PM 에이전트가 이 파일들을 읽어 다음 단계를 결정합니다.

## 파일 목록

| 파일 | 작성자 | 용도 |
|------|--------|------|
| `design_latest.md` | Design Agent | 가장 최근 Figma 작업 완료 노트 |
| `coding_latest.md` | Coding Agent | 가장 최근 코딩 작업 완료 노트 |

## 파일 형식

### design_latest.md
```
---
feature: [기능명]
status: done
date: YYYY-MM-DD
---

## Figma 프레임
| 화면 | ID | x | y |
...

## 코딩 에이전트 참고사항
- ...
```

### coding_latest.md
```
---
feature: [기능명]
status: done
analyze: pass
date: YYYY-MM-DD
---

## 변경된 파일
- ...

## 주요 구현 결정사항
- ...
```
