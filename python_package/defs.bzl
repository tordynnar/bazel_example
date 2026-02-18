"""Rules for proto package auto-discovery."""

def _proto_init_files_impl(ctx):
    """Generate __init__.py and py.typed for every directory in the proto source tree."""
    dirs = {}
    prefix = ctx.attr.strip_prefix
    for src in ctx.files.proto_srcs:
        path = src.short_path
        if prefix and path.startswith(prefix):
            path = path[len(prefix):]
        parts = path.split("/")
        for i in range(1, len(parts)):
            dirs["/".join(parts[:i])] = True

    outputs = []
    for d in sorted(dirs):
        init_file = ctx.actions.declare_file(d + "/__init__.py")
        ctx.actions.write(init_file, "")
        outputs.append(init_file)

    # Include py.typed marker (PEP 561) in the top-level package directory
    if dirs:
        top_level = sorted(dirs)[0]
        py_typed = ctx.actions.declare_file(top_level + "/py.typed")
        ctx.actions.write(py_typed, "")
        outputs.append(py_typed)

    return [DefaultInfo(files = depset(outputs))]

proto_init_files = rule(
    implementation = _proto_init_files_impl,
    attrs = {
        "proto_srcs": attr.label(allow_files = [".proto"]),
        "strip_prefix": attr.string(default = "proto/"),
    },
)
