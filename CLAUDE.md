# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the Python wheel (includes all proto services + type stubs)
bazel build //python_package:grpc_services_wheel

# Build C++ gRPC libraries and echo apps (Bazel-only)
bazel build //cpp_package:echo_cpp_grpc //cpp_echo_server //cpp_echo_client

# Generate Go + Rust proto sources from Bazel (copies into native source trees)
bash generate_protos.sh

# Build Go echo apps (native go build, requires generate_protos.sh first)
go build -o go_echo_server/server ./go_echo_server
go build -o go_echo_client/client ./go_echo_client

# Build Rust echo apps (native cargo build, requires generate_protos.sh first)
cargo build -p rust_echo_server -p rust_echo_client

# Run integration tests (build, server/client round-trip)
bash test_echo.sh        # Python (port 50051)
bash test_echo_cpp.sh    # C++    (port 50053)
bash test_echo_go.sh     # Go     (port 50052)
bash test_echo_rust.sh   # Rust   (port 50054)

# Lint Python code (not generated code)
.venv/bin/ruff check echo_server/server.py echo_client/client.py

# Type check Python code in strict mode
.venv/bin/pyright --pythonpath .venv/bin/python

# Install the built wheel into the dev venv
WHEEL_PATH="$(bazel cquery --output=files //python_package:grpc_services_wheel 2>/dev/null)"
uv pip install --python .venv/bin/python --force-reinstall "$WHEEL_PATH"
```

## Python Environment

- Venv must exist at `.venv`. Create with `uv venv` if missing.
- All packages installed with `uv pip install`.
- Do not lint or type-check generated code (gRPC/protobuf bindings).
- Pyright runs in strict mode (`pyrightconfig.json`).

## Architecture

This project compiles `.proto` gRPC service definitions into typed packages for **Python**, **C++**, **Go**, and **Rust** using Bazel.

**Proto definitions** (`proto/demo/{service}/v1/*.proto`): Three services — Echo, User, Notification. Package names follow `demo.{service}.v1` convention. Proto files include `option go_package` for Go code generation. The root `BUILD.bazel` defines both a combined `all_protos` target (for Python/Rust) and per-service targets (`echo_proto`, `user_proto`, `notification_proto`) for Go, C++, and Rust.

**Build pipeline** (`python_package/BUILD.bazel`): The single build pipeline that chains together:
1. `proto_init_files` (custom Starlark rule in `defs.bzl`) — auto-generates `__init__.py` and `py.typed` from the proto directory structure
2. `python_grpc_compile` — runs protoc with three plugins: proto (messages), grpc (service stubs), pyi (message type stubs)
3. `mypy_grpc_plugin` — custom `proto_plugin` wrapping `mypy-protobuf` to generate `_pb2_grpc.pyi` stubs (not available from built-in plugins)
4. `py_wheel` — packages everything into `demo-0.1.0-py3-none-any.whl`

**Why `python_grpc_compile` instead of `python_grpc_library`**: The `python_grpc_library` macro has a bug where `generate_pyi=True` always sets `extra_plugins` internally, conflicting with any user-supplied `extra_plugins`. Using the lower-level `python_grpc_compile` directly avoids this.

**Why `proto_library` is in the root BUILD**: `proto_library` enforces that `srcs` must be in the same Bazel package. Since `proto/` has no `BUILD.bazel`, its files belong to the root package.

**C++ package** (`cpp_package/BUILD.bazel`): Uses `cpp_grpc_library` from `rules_proto_grpc_cpp` for each service. C++ echo apps are Bazel targets (`cc_binary`).

**Go package** (`go_package/BUILD.bazel`): Uses `go_grpc_compile` to generate `.pb.go` source files only. `generate_protos.sh` copies them into `go_package/demo/` for native `go build`. Echo apps (`go_echo_server/`, `go_echo_client/`) are built with standard `go build`.

**Rust package** (`rust_package/BUILD.bazel`): Uses `rust_prost_library` from `rules_rust_prost` to generate a combined `.rs` file. `generate_protos.sh` copies it to `rust_package/src/lib.rs`. Echo apps (`rust_echo_server/`, `rust_echo_client/`) are built with `cargo build` via a workspace `Cargo.toml`.

**Python consumer apps** (`echo_server/`, `echo_client/`): Standalone Python apps that `pip install` the built wheel. They import from `demo.echo.v1` and are not Bazel targets — they run with a standard Python venv.

## Bazel Constraints

- Pinned to Bazel 8.2.1 (`.bazelversion`) — Bazel 9 is incompatible with `rules_proto_grpc_python` 5.8.0.
- `strip_import_prefix = "/proto"` on `proto_library` makes protoc generate imports matching the `demo.*` package structure.
- `strip_path_prefixes` on `py_wheel` normalizes output paths from both the compile step and the init file generator.
- Go requires `option go_package` in proto files and a `go.mod` at the workspace root for dependency resolution.
- `rules_rust_prost` is a separate BCR module from `rules_rust` (both at 0.66.0). It uses the default prost toolchain.
