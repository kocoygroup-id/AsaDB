#!/usr/bin/env python3
"""Offline, per-user Python runtime bootstrap for AsaDB Server Mode.

The AsaDB pack directory can be read-only.  This program deliberately writes
only beneath ASADB_HOME (or the platform's normal user-data directory), and
installs only from the wheelhouse bundled in the AsaDB source tree.
"""

from __future__ import annotations

import hashlib
import json
import os
import platform
import secrets
import shutil
import subprocess
import sys
import tempfile
import time
import venv
import zipfile
from pathlib import Path
from typing import Any


MINIMUM_PYTHON = (3, 10)
MAXIMUM_PYTHON = (3, 13)
ROOT = Path(__file__).resolve().parents[2]
SERVER_ROOT = ROOT / "flaskserver"
WHEELHOUSE = SERVER_ROOT / "wheels"
LOCKFILE = SERVER_ROOT / "requirements-bundled.txt"
MANIFEST = SERVER_ROOT / "MANIFEST.sha256"


def fail(message: str) -> None:
    print(f"AsaDB Python bootstrap: {message}", file=sys.stderr)
    raise SystemExit(1)


def supported_python() -> bool:
    current = sys.version_info[:2]
    return MINIMUM_PYTHON <= current <= MAXIMUM_PYTHON


def platform_home() -> Path:
    override = os.getenv("ASADB_HOME")
    if override:
        return Path(override).expanduser().resolve()
    if os.name == "nt":
        return Path(os.getenv("LOCALAPPDATA", Path.home() / "AppData" / "Local")) / "AsaDB"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "AsaDB"
    return Path(os.getenv("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "asadb"


def layout() -> dict[str, Path]:
    home = platform_home()
    return {
        "home": home,
        "venv": home / "python-env",
        "data": home / "data",
        "state": home / "server-state",
        "temp": home / "tmp",
        "config": home / "server-state" / "launcher.json",
        "secrets": home / "server-state" / "launcher-secrets.json",
        "marker": home / "python-env" / ".asadb-runtime.json",
    }


def runtime_python(paths: dict[str, Path]) -> Path:
    return paths["venv"] / ("Scripts/python.exe" if os.name == "nt" else "bin/python")


def source_version() -> str:
    version_file = ROOT / "VERSION"
    return version_file.read_text(encoding="utf-8").strip() if version_file.exists() else "unknown"


def bundle_digest() -> str:
    digest = hashlib.sha256()
    for path in (LOCKFILE, MANIFEST, SERVER_ROOT / "pyproject.toml"):
        if not path.is_file():
            fail(f"required bundled file is missing: {path}")
        digest.update(path.read_bytes())
    return digest.hexdigest()


def write_json_private(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True), encoding="utf-8")
    os.replace(temporary, path)
    try:
        path.chmod(0o600)
    except OSError:
        pass


def read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def ensure_layout(paths: dict[str, Path]) -> None:
    for key in ("home", "data", "state", "temp"):
        paths[key].mkdir(parents=True, exist_ok=True)
        try:
            paths[key].chmod(0o700)
        except OSError:
            pass
    config = read_json(paths["config"])
    if not config:
        write_json_private(
            paths["config"],
            {
                "schemaVersion": 1,
                "createdAt": int(time.time()),
                "host": "127.0.0.1",
                "port": 7879,
                "publicUrl": "http://127.0.0.1:7879",
                "dataDirectory": str(paths["data"]),
                # The primary portal still requires login.  This setting only
                # controls whether a loopback user can select Local Workspace
                # after signing in.
                "allowLocalOnly": True,
            },
        )
    secret_values = read_json(paths["secrets"])
    if not secret_values:
        write_json_private(
            paths["secrets"],
            {
                "schemaVersion": 1,
                "secretKey": secrets.token_urlsafe(48),
                "clusterKey": secrets.token_urlsafe(48),
            },
        )


def child_environment(paths: dict[str, Path]) -> dict[str, str]:
    config = read_json(paths["config"])
    secret_values = read_json(paths["secrets"])
    configured_data = config.get("dataDirectory")
    data_directory = (
        Path(configured_data).expanduser().resolve()
        if isinstance(configured_data, str) and configured_data.strip()
        else paths["data"]
    )
    environment = os.environ.copy()
    environment.update(
        {
            "ASADB_HOME": str(paths["home"]),
            "ASADB_REPO_ROOT": str(ROOT),
            "ASADB_DATA_DIR": str(data_directory),
            "ASADB_STATE_DIR": str(paths["state"]),
            "ASADB_TEMP_DIR": str(paths["temp"]),
            "ASADB_HOST": str(config.get("host", "127.0.0.1")),
            "ASADB_PORT": str(config.get("port", 7879)),
            "ASADB_PUBLIC_URL": str(config.get("publicUrl", "http://127.0.0.1:7879")),
            "ASADB_SECRET_KEY": str(secret_values["secretKey"]),
            "ASADB_CLUSTER_KEY": str(secret_values["clusterKey"]),
            "ASADB_ALLOW_LOCAL_ONLY": (
                "true" if bool(config.get("allowLocalOnly", True)) else "false"
            ),
        }
    )
    return environment


def run(command: list[str], *, env: dict[str, str] | None = None) -> None:
    completed = subprocess.run(command, env=env, cwd=ROOT)
    if completed.returncode:
        raise SystemExit(completed.returncode)


def wheel_links() -> list[str]:
    if not WHEELHOUSE.is_dir():
        fail("the bundled wheelhouse is missing; reinstall the AsaDB pack.")
    if not any(WHEELHOUSE.glob("*.whl")):
        fail("the bundled wheelhouse is empty; reinstall the AsaDB pack.")
    return ["--find-links", str(WHEELHOUSE)]


def bootstrap_pip(python: Path, paths: dict[str, Path]) -> None:
    pip_wheels = sorted(WHEELHOUSE.glob("pip-*.whl"))
    if not pip_wheels:
        fail("bundled pip wheel is missing; reinstall the AsaDB pack.")
    scratch = Path(tempfile.mkdtemp(prefix="asadb-pip-", dir=paths["temp"]))
    try:
        with zipfile.ZipFile(pip_wheels[-1]) as archive:
            archive.extractall(scratch)
        environment = os.environ.copy()
        environment["PYTHONPATH"] = str(scratch)
        command = [
            # pip itself is currently imported from Scratch via PYTHONPATH;
            # without --ignore-installed it would regard that temporary copy
            # as satisfying the requirement and leave the venv without pip.
            str(python), "-m", "pip", "install", "--ignore-installed", "--no-index", *wheel_links(),
            "pip", "setuptools", "wheel",
        ]
        run(command, env=environment)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def create_venv(paths: dict[str, Path], *, replace: bool) -> Path:
    target = paths["venv"]
    if replace and target.exists():
        shutil.rmtree(target)
    if not target.exists():
        try:
            venv.EnvBuilder(with_pip=False, clear=False).create(target)
        except Exception as error:
            fail(f"could not create Python virtual environment: {error}")
    python = runtime_python(paths)
    if not python.is_file():
        fail("the Python virtual environment was created without its interpreter.")
    return python


def verify_runtime(paths: dict[str, Path]) -> tuple[bool, str]:
    python = runtime_python(paths)
    if not python.is_file():
        return False, "Python environment is not installed"
    command = [
        str(python), "-c",
        "import asadb_server, flask, requests, waitress, click, werkzeug; "
        "assert asadb_server.__version__ == '" + source_version() + "'; "
        "print(asadb_server.__version__)",
    ]
    completed = subprocess.run(command, capture_output=True, text=True)
    if completed.returncode:
        return False, (completed.stderr or completed.stdout or "runtime import failed").strip()
    marker = read_json(paths["marker"])
    if marker.get("bundleDigest") != bundle_digest():
        return False, "bundled source changed; runtime refresh required"
    return True, completed.stdout.strip()


def backup_upgrade_control_plane(paths: dict[str, Path]) -> None:
    """Keep a recoverable copy before refreshing a changed bundled runtime."""
    marker = read_json(paths["marker"])
    if not marker or marker.get("bundleDigest") == bundle_digest():
        return
    backup_directory = paths["state"] / "upgrade-backups" / str(int(time.time()))
    backup_directory.mkdir(parents=True, exist_ok=True)
    for key in ("config", "secrets"):
        source = paths[key]
        if source.is_file():
            shutil.copy2(source, backup_directory / source.name)
    try:
        backup_directory.chmod(0o700)
    except OSError:
        pass


def setup_runtime(paths: dict[str, Path], *, repair: bool = False) -> Path:
    if not supported_python():
        fail(
            "supported Python versions are 3.10 through 3.13; "
            f"found {platform.python_version()}."
        )
    ensure_layout(paths)
    valid, _ = verify_runtime(paths)
    if valid and not repair:
        return runtime_python(paths)
    if not repair:
        backup_upgrade_control_plane(paths)
    python = create_venv(paths, replace=repair)
    bootstrap_pip(python, paths)
    run([
        str(python), "-m", "pip", "install", "--no-index", *wheel_links(),
        "--requirement", str(LOCKFILE),
    ])
    run([
        str(python), "-m", "pip", "install", "--no-index", *wheel_links(),
        "--no-build-isolation", "--no-deps", "--force-reinstall", str(SERVER_ROOT),
    ])
    write_json_private(
        paths["marker"],
        {
            "asadbVersion": source_version(),
            "bundleDigest": bundle_digest(),
            "python": platform.python_version(),
            "createdAt": int(time.time()),
        },
    )
    valid, message = verify_runtime(paths)
    if not valid:
        fail(f"installed runtime failed verification: {message}")
    return python


def doctor(paths: dict[str, Path], *, as_json: bool, repair: bool) -> int:
    checks: list[dict[str, Any]] = []

    def check(name: str, ok: bool, detail: str) -> None:
        checks.append({"name": name, "ok": ok, "detail": detail})

    check("Python runtime (3.10-3.13)", supported_python(), platform.python_version())
    check("AsaDB Core", (ROOT / "src" / "asadb_core.pl").is_file(), str(ROOT / "src"))
    check("AsAPanel assets", (ROOT / "web" / "index.html").is_file(), str(ROOT / "web"))
    check("Bundled wheelhouse", WHEELHOUSE.is_dir() and bool(list(WHEELHOUSE.glob("*.whl"))), str(WHEELHOUSE))
    ensure_layout(paths)
    valid, detail = verify_runtime(paths)
    if repair and not valid:
        try:
            setup_runtime(paths, repair=True)
            valid, detail = verify_runtime(paths)
        except SystemExit as error:
            detail = f"repair failed ({error.code})"
    check("AsaDB Python environment", valid, detail)
    for key in ("data", "state", "temp"):
        check(f"{key.title()} directory", paths[key].is_dir(), str(paths[key]))
    if as_json:
        print(json.dumps({"ok": all(item["ok"] for item in checks), "checks": checks}, indent=2))
    else:
        for item in checks:
            print(f"[{'OK' if item['ok'] else 'FAIL'}] {item['name']}: {item['detail']}")
    return 0 if all(item["ok"] for item in checks) else 1


def print_config(paths: dict[str, Path]) -> None:
    ensure_layout(paths)
    config = read_json(paths["config"])
    configured_data = config.get("dataDirectory", str(paths["data"]))
    print(json.dumps({
        "home": str(paths["home"]),
        "dataDirectory": configured_data,
        "stateDirectory": str(paths["state"]),
        "temporaryDirectory": str(paths["temp"]),
        "runtime": str(paths["venv"]),
        "server": config,
        "secrets": "configured" if paths["secrets"].is_file() else "missing",
    }, indent=2))


def reset(paths: dict[str, Path], kind: str, confirmed: bool) -> None:
    if not confirmed:
        fail("reset requires --yes. Database files are never removed by this command.")
    if kind == "python":
        shutil.rmtree(paths["venv"], ignore_errors=True)
        print(f"Removed only the Python runtime: {paths['venv']}")
        return
    if kind == "config":
        for key in ("config", "secrets"):
            path = paths[key]
            if path.exists():
                backup = path.with_name(path.name + f".backup-{int(time.time())}")
                os.replace(path, backup)
        print(f"Reset launcher configuration. Database files remain in: {paths['data']}")
        return
    fail("reset accepts only 'python' or 'config'.")


def start_arguments(paths: dict[str, Path], arguments: list[str]) -> list[str]:
    """Persist the optional data directory before handing options to Click.

    The public launcher accepts ``--data-dir`` so the extracted-release
    wrappers can retain their historic ``data.asa`` location.  The Flask CLI
    intentionally never receives that implementation option: it only sees a
    safe filename and obtains the selected directory from its environment.
    """
    output: list[str] = []
    position = 0
    data_directory: str | None = None
    while position < len(arguments):
        value = arguments[position]
        if value == "--data-dir":
            if position + 1 >= len(arguments):
                fail("--data-dir requires a directory path.")
            data_directory = arguments[position + 1]
            position += 2
            continue
        output.append(value)
        position += 1
    if data_directory is not None:
        directory = Path(data_directory).expanduser().resolve()
        created = not directory.exists()
        directory.mkdir(parents=True, exist_ok=True)
        if created:
            try:
                directory.chmod(0o700)
            except OSError:
                pass
        config = read_json(paths["config"])
        config["dataDirectory"] = str(directory)
        write_json_private(paths["config"], config)
    return output


def usage() -> None:
    print(
        "Usage: bootstrap_python.py <setup|doctor|repair|reset|config|init|start|server|remote|version> [options]",
        file=sys.stderr,
    )


def main(arguments: list[str]) -> int:
    if not arguments or arguments[0] in {"-h", "--help", "help"}:
        usage()
        return 0
    command, *rest = arguments
    paths = layout()
    if command == "version":
        print(source_version())
        return 0
    if command == "setup":
        setup_runtime(paths)
        print(f"AsaDB Server runtime ready: {runtime_python(paths)}")
        return 0
    if command == "repair":
        setup_runtime(paths, repair=True)
        print(f"AsaDB Server runtime repaired: {runtime_python(paths)}")
        return 0
    if command == "doctor":
        return doctor(paths, as_json="--json" in rest, repair="--repair" in rest)
    if command == "config":
        print_config(paths)
        return 0
    if command == "reset":
        if not rest:
            fail("reset requires 'python' or 'config'.")
        reset(paths, rest[0], "--yes" in rest[1:])
        return 0
    if command == "start":
        ensure_layout(paths)
        rest = start_arguments(paths, rest)
        python = setup_runtime(paths)
        run([str(python), "-m", "asadb_server", "start", *rest], env=child_environment(paths))
        return 0
    if command in {"init", "server", "remote"}:
        python = setup_runtime(paths)
        run([str(python), "-m", "asadb_server", command, *rest], env=child_environment(paths))
        return 0
    fail(f"unknown command '{command}'.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
