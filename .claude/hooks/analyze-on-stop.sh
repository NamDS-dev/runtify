#!/bin/bash
# Stop hook: 세션 종료 시 Dart 파일 변경이 있으면 백그라운드로 flutter analyze 실행
# 에러 발견 시에만 macOS 알림 (성공은 조용히)
#
# settings.json의 Stop hooks 배열에 등록됨
# 입력: Claude Code가 stdin으로 JSON 전달 (사용 안 함)
# 출력: 항상 exit 0 (블로킹 방지)

set -u

PROJECT_DIR="/Users/dave/runtify"
LOG_FILE="/tmp/runtify-analyze.log"

cd "$PROJECT_DIR" || exit 0

# Dart 파일 변경이 없으면 스킵 (불필요한 analyze 회피)
if ! git status --porcelain 2>/dev/null | grep -qE '\.dart$'; then
  exit 0
fi

# 백그라운드에서 analyze 실행, 에러 시에만 알림
(
  if ! flutter analyze --no-pub > "$LOG_FILE" 2>&1; then
    osascript -e "display notification \"⚠️ flutter analyze 에러 — $LOG_FILE 확인\" with title \"Runtify QA\" sound name \"Basso\""
  fi
) >/dev/null 2>&1 &
disown 2>/dev/null

exit 0
