#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT=50053

cleanup() {
    echo "--- Cleaning up ---"
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "=== Step 1: Build C++ server and client ==="
bazel build //cpp_echo_server:cpp_echo_server //cpp_echo_client:cpp_echo_client

SERVER_BIN="$(bazel cquery --output=files //cpp_echo_server:cpp_echo_server 2>/dev/null)"
CLIENT_BIN="$(bazel cquery --output=files //cpp_echo_client:cpp_echo_client 2>/dev/null)"

echo ""
echo "=== Step 2: Start echo server ==="
"$SERVER_BIN" --port "$PORT" &
SERVER_PID=$!
sleep 2

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "FAIL: Server failed to start"
    exit 1
fi
echo "Server started (PID: $SERVER_PID)"

echo ""
echo "=== Step 3: Run echo client ==="
TEST_MESSAGE="Hello from C++ integration test"
OUTPUT=$("$CLIENT_BIN" --port "$PORT" "$TEST_MESSAGE")
echo "Client output:"
echo "$OUTPUT"

echo ""
echo "=== Step 4: Verify response ==="
if echo "$OUTPUT" | grep -q "$TEST_MESSAGE"; then
    echo "PASS: Response contains the sent message"
else
    echo "FAIL: Response does not contain the sent message"
    exit 1
fi

echo ""
echo "=== All C++ tests passed ==="
