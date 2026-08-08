from __future__ import annotations

from pathlib import Path

from asadb_server.fts import FullTextManager
from asadb_server.jobs import JobQueue


class FakeBackend:
    def stream_query_pages_in_database(self, logical_database, sql, page_size):
        yield from self.stream_query_pages(sql, page_size)

    def stream_query_pages(self, sql, page_size):
        yield {
            "page": 0,
            "offset": 0,
            "columns": ["id", "title", "body"],
            "rows": [
                [1, "AsaDB database", "Prolog storage and Python server"],
                [2, "Python Flask", "Remote database client"],
            ],
            "hasMore": False,
            "raw": {
                "columns": ["id", "title", "body"],
                "rows": [
                    [1, "AsaDB database", "Prolog storage and Python server"],
                    [2, "Python Flask", "Remote database client"],
                ],
            },
        }


class FakeBackends:
    def get(self, database_id):
        return FakeBackend()


def test_fts_build_and_search(tmp_path: Path):
    jobs = JobQueue(tmp_path, workers=1)
    fts = FullTextManager(tmp_path, FakeBackends(), jobs, page_size=500)
    fts.define(
        "main",
        "docs",
        source_sql="SELECT id,title,body FROM docs;",
        id_column="id",
        text_columns=["title", "body"],
        logical_database="app",
    )

    class Context:
        job_id = "test"
        def check_cancelled(self): pass
        def progress(self, *args, **kwargs): pass

    result = fts._job_rebuild(Context(), {
        "databaseId": "main",
        "indexName": "docs",
    })
    assert result["documents"] == 2
    search = fts.search("main", "docs", "prolog python", limit=10)
    assert search["hits"]
    assert search["hits"][0]["id"] in {"1", "2"}
    jobs.shutdown()
