from __future__ import annotations

import os
from pathlib import Path

import pytest

pytestmark = pytest.mark.integration


@pytest.mark.skipif(
    os.getenv("ASADB_RUN_REAL_TESTS") != "1",
    reason="Set ASADB_RUN_REAL_TESTS=1 inside a complete AsaDB checkout.",
)
def test_repository_contract():
    repo = Path(os.environ["ASADB_REPO_ROOT"])
    web = (repo / "src" / "asadb_web.pl").read_text(encoding="utf-8")
    assert "root('api/query')" in web
    assert "root('api/backup')" in web
    assert "root('api/reservoir/jobs')" in web
    assert (repo / "web" / "index.html").exists()
