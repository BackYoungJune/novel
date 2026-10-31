#!/usr/bin/env bash
set -euo pipefail

# 서버 문피아 브라우저. 작가 로그인은 noVNC(6080)로, 매일 작업의 AI 조작은 CDP(9222)로 한다.
# 모든 접속 포트는 서버의 127.0.0.1에만 연다. 이미 떠 있으면 그대로 둔다.
state_dir=/home/ubuntu/.local/share/munpia-browser-test
profile_dir=/home/ubuntu/.config/munpia-browser
mkdir -p "$state_dir" "$profile_dir"
chmod 700 "$state_dir" "$profile_dir"

if ! pgrep -x Xvfb >/dev/null; then
  nohup Xvfb :99 -screen 0 1280x900x24 -nolisten tcp \
    >"$state_dir/xvfb.log" 2>&1 </dev/null &
fi

if ! pgrep -x x11vnc >/dev/null; then
  nohup x11vnc -display :99 -localhost -rfbport 5900 -forever -shared -nopw \
    >"$state_dir/x11vnc.log" 2>&1 </dev/null &
fi

if ! pgrep -f '[w]ebsockify --web=/usr/share/novnc 127.0.0.1:6080' >/dev/null; then
  nohup websockify --web=/usr/share/novnc 127.0.0.1:6080 127.0.0.1:5900 \
    >"$state_dir/websockify.log" 2>&1 </dev/null &
fi

if ! pgrep -x chrome >/dev/null; then
  nohup env DISPLAY=:99 google-chrome-stable \
    --no-first-run --disable-gpu --disable-dev-shm-usage \
    --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 \
    --user-data-dir="$profile_dir" --new-window \
    'https://library.munpia.com/qordud2/novel/detail?novelId=617128&menu=chapter' \
    >"$state_dir/chrome.log" 2>&1 </dev/null &
fi
