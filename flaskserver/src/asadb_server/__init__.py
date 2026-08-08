"""AsaDB Flask Server package metadata."""

# Server mode is shipped against the matching AsaDB engine release.  Keep this
# value aligned with the root VERSION file and the package metadata so the
# public health endpoint cannot claim compatibility with a different core.
__version__ = "1.5.0"

def create_app(*args, **kwargs):
    from .app import create_app as factory
    return factory(*args, **kwargs)

__all__ = ["create_app"]
