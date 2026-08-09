import stat
from pathlib import Path

from asadb_server.config import Settings, default_repo_root


def test_default_repo_root_finds_checkout_from_package_location():
    root = default_repo_root()
    assert (root / "src" / "asadb_web.pl").is_file()
    assert (root / "web" / "index.html").is_file()


def test_prepare_never_chmods_an_existing_database_root(monkeypatch, tmp_path: Path):
    data_directory = tmp_path / "existing-data-root"
    data_directory.mkdir()
    data_directory.chmod(0o755)
    monkeypatch.setenv("ASADB_DATA_DIR", str(data_directory))
    monkeypatch.setenv("ASADB_STATE_DIR", str(tmp_path / "state"))
    monkeypatch.setenv("ASADB_TEMP_DIR", str(tmp_path / "tmp"))

    Settings.load().prepare()

    assert stat.S_IMODE(data_directory.stat().st_mode) == 0o755


def test_default_listener_uses_the_documented_2026_port(monkeypatch):
    monkeypatch.delenv("ASADB_PORT", raising=False)
    monkeypatch.delenv("ASADB_PUBLIC_URL", raising=False)

    settings = Settings.load()

    assert settings.port == 2026
    assert settings.public_url == "http://127.0.0.1:2026"
