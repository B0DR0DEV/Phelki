#!/usr/bin/env bash
# Проверка онлайн-охоты: сервер и два клиента (дачник на автопилоте и пчела) играют матч.
set -uo pipefail
PORT=8915
godot --headless --path . -- --server --port=$PORT > server.log 2>&1 &
SERVER=$!
sleep 4
godot --headless --path . -- --netclient=ws://127.0.0.1:$PORT --side=bee > bee.log 2>&1 &
BEE=$!
timeout 400 godot --headless --path . -- --netclient=ws://127.0.0.1:$PORT --side=human --autopilot > human.log 2>&1
HUMAN_EXIT=$?
wait $BEE; BEE_EXIT=$?
kill $SERVER 2>/dev/null
grep -h "\[server\]" server.log
grep -h "NETTEST" human.log bee.log
if grep -q "SCRIPT ERROR" server.log human.log bee.log; then
  grep -h -m5 "SCRIPT ERROR" server.log human.log bee.log
  exit 1
fi
[ "$HUMAN_EXIT" = 0 ] && [ "$BEE_EXIT" = 0 ]
