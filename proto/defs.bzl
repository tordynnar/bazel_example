"""Macros for proto package auto-discovery."""

def proto_init_files(name, proto_srcs, **kwargs):
    """Generate __init__.py and py.typed for every directory in the proto source tree.

    Args:
        name: Target name.
        proto_srcs: List of .proto file paths (from glob).
        **kwargs: Passed to genrule.
    """
    dirs = {}
    for src in proto_srcs:
        parts = src.split("/")
        for i in range(1, len(parts)):
            dirs["/".join(parts[:i])] = True

    # Include py.typed marker (PEP 561) in the top-level package directory
    top_level = sorted(dirs)[0] if dirs else None
    outs = [d + "/__init__.py" for d in sorted(dirs)]
    if top_level:
        outs.append(top_level + "/py.typed")

    native.genrule(
        name = name,
        outs = outs,
        cmd = "for f in $(OUTS); do mkdir -p $$(dirname $$f) && touch $$f; done",
        **kwargs
    )
