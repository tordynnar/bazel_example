#!/usr/bin/env bash
# Builds proto sources via Bazel and copies them into the native Go/Rust source trees.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building Go proto sources ==="
bazel build //go_package:all_go_compile

echo "=== Building Rust proto sources ==="
bazel build //rust_package:all_rust_prost

# --- Go: copy generated .pb.go files into go_package/ ---
GO_OUT="bazel-bin/go_package/all_go_compile"
# Remove stale generated files (Bazel outputs are read-only)
rm -rf go_package/demo
for service_dir in "$GO_OUT"/demo/*/v1; do
    rel="${service_dir#"$GO_OUT/"}"   # e.g. demo/echo/v1
    dest="go_package/$rel"
    mkdir -p "$dest"
    cp "$service_dir"/*.go "$dest/"
done
echo "Go sources copied to go_package/demo/"

# --- Rust: copy generated .rs file into rust_package/src/ ---
rm -f rust_package/src/lib.rs
cp bazel-bin/all_protos.lib.rs rust_package/src/lib.rs
echo "Rust source copied to rust_package/src/lib.rs"

echo ""
echo "Done. You can now build with:"
echo "  Go:   go build ./go_echo_server && go build ./go_echo_client"
echo "  Rust: cargo build"
