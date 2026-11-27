#!/usr/bin/env bash
# Runs a host and a client lockstep session over ENet on localhost and checks
# both reach the same final checksum. Usage: tools/net_selftest.sh [godot-binary]
set -u
GODOT="${1:-godot}"
PORT=$((27000 + RANDOM % 2000))
LOG=$(mktemp -d)
"$GODOT" --headless --path . -s res://tools/net_selftest.gd -- --host --port=$PORT >"$LOG/host.log" 2>&1 &
HOST_PID=$!
sleep 2
"$GODOT" --headless --path . -s res://tools/net_selftest.gd -- --join=127.0.0.1 --port=$PORT >"$LOG/client.log" 2>&1
CLIENT_RC=$?
wait $HOST_PID
HOST_RC=$?
grep -h "NETTEST" "$LOG/host.log" "$LOG/client.log"
H=$(grep -o "checksum=[0-9a-f]*" "$LOG/host.log")
C=$(grep -o "checksum=[0-9a-f]*" "$LOG/client.log")
if [ $HOST_RC -ne 0 ] || [ $CLIENT_RC -ne 0 ] || [ -z "$H" ] || [ "$H" != "$C" ]; then
  echo "net selftest FAILED (host rc=$HOST_RC client rc=$CLIENT_RC host=$H client=$C)"
  cat "$LOG/host.log" "$LOG/client.log" | tail -40
  exit 1
fi
echo "net selftest OK ($H)"
