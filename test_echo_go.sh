#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT=50052

cleanup() {
    echo "--- Cleaning up ---"
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "=== Step 1: Generate proto sources ==="
bash generate_protos.sh

echo ""
echo "=== Step 2: Build Go server and client ==="
go build -o go_echo_server/server ./go_echo_server
go build -o go_echo_client/client ./go_echo_client

echo ""
echo "=== Step 3: Start echo server ==="
./go_echo_server/server --port "$PORT" &
SERVER_PID=$!
sleep 2

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "FAIL: Server failed to start"
    exit 1
fi
echo "Server started (PID: $SERVER_PID)"

echo ""
echo "=== Step 4: Run echo client ==="
TEST_MESSAGE="Hello from Go integration test"
OUTPUT=$(./go_echo_client/client --port "$PORT" "$TEST_MESSAGE")
echo "Client output:"
echo "$OUTPUT"

echo ""
echo "=== Step 5: Verify response ==="
if echo "$OUTPUT" | grep -q "$TEST_MESSAGE"; then
    echo "PASS: Response contains the sent message"
else
    echo "FAIL: Response does not contain the sent message"
    exit 1
fi

echo ""
echo "=== All Go tests passed ==="
