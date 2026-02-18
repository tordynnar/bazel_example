Critical Instructions:

- Confirm whether a Python venv exists (in the `.venv` folder)
- If a Python venv doesn't exist, create it with `uv venv`
- All packages should be installed with `uv pip install`
- Perform lint and type checking on Python code with `ruff` and `pyright`
- Do not perform link and type checking on generated Python code (eg. gRPC/protobuf bindings)
