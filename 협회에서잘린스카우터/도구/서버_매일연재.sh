#!/usr/bin/env bash
# 서버 매일 연재 실행. cron이 부른다. 지시 내용은 서버_매일연재_지시.md에 있다.
# 같은 서버의 AutoTrader를 보호하려고 메모리가 부족하면 실행하지 않는다.
set -euo pipefail
# cron의 PATH에는 pwsh(snap)와 claude가 없다.
export PATH=/home/ubuntu/.local/bin:/snap/bin:/usr/local/bin:/usr/bin:/bin

repo=/home/ubuntu/novel
log_dir=/home/ubuntu/.local/share/novel-daily
mkdir -p "$log_dir"
log="$log_dir/$(TZ=Asia/Seoul date +%F).log"
exec >>"$log" 2>&1
echo "=== $(TZ=Asia/Seoul date '+%F %T %Z') 시작"

exec 9>"$log_dir/lock"
if ! flock -n 9; then
  echo "이전 실행이 아직 끝나지 않아 건너뜀"
  exit 0
fi

avail_mb=$(awk '/MemAvailable|SwapFree/ {s+=$2} END {print int(s/1024)}' /proc/meminfo)
if [ "$avail_mb" -lt 700 ]; then
  echo "메모리 여유 ${avail_mb}MB < 700MB, AutoTrader 보호를 위해 건너뜀"
  exit 0
fi

bash /home/ubuntu/start-munpia-browser.sh
sleep 5
if ! curl -fs http://127.0.0.1:9222/json/version >/dev/null; then
  echo "브라우저 CDP 연결 실패, 건너뜀"
  exit 1
fi

cd "$repo"
git pull --ff-only -q origin main

prompt=$(cat "$repo/협회에서잘린스카우터/도구/서버_매일연재_지시.md")
status=0
timeout 3h /home/ubuntu/.local/bin/claude -p "$prompt" \
  --permission-mode acceptEdits \
  --allowedTools "Read,Edit,Write,Glob,Grep,Skill,mcp__munpia-browser,Bash(git:*),Bash(pwsh:*),Bash(ls:*),Bash(cat:*),Bash(head:*),Bash(tail:*),Bash(wc:*),Bash(grep:*),Bash(sed -n:*),Bash(diff:*),Bash(date:*),Bash(sha256sum:*)" \
  --output-format text || status=$?
echo "=== $(TZ=Asia/Seoul date '+%F %T %Z') 종료 (상태 $status)"
