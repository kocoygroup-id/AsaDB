from __future__ import annotations

import gzip
import json
import math
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from .backend import BackendManager
from .errors import AsaServerError
from .file_store import AtomicJsonStore
from .jobs import JobContext, JobQueue
from .util import rows_as_dicts, safe_id, utc_now

TOKEN_RE = re.compile(r"[\w]+", re.UNICODE)


def tokenize(text: str) -> list[str]:
    return [token.casefold() for token in TOKEN_RE.findall(text) if len(token) >= 2]


class FullTextManager:
    """
    Python sidecar FTS for AsaDB.

    Indexes are file based and eventually consistent. The source of truth
    remains AsaDB; rebuilds page through the official backend query endpoint.
    """

    def __init__(
        self,
        state_dir: Path,
        backends: BackendManager,
        jobs: JobQueue,
        page_size: int,
        availability_guard=None,
    ):
        self.root = state_dir / "fts"
        self.root.mkdir(parents=True, exist_ok=True)
        self.configs = AtomicJsonStore(self.root / "definitions")
        self.backends = backends
        self.jobs = jobs
        self.page_size = page_size
        self.availability_guard = availability_guard
        self.jobs.register("fts_rebuild", self._job_rebuild)

    def _key(self, database_id: str, index_name: str) -> str:
        safe_id(database_id, "database id")
        safe_id(index_name, "FTS index name")
        return f"{database_id}--{index_name}"

    def _index_file(self, key: str) -> Path:
        return self.root / "data" / f"{key}.json.gz"

    def define(
        self,
        database_id: str,
        index_name: str,
        *,
        source_sql: str,
        id_column: str,
        text_columns: list[str],
        logical_database: str | None = None,
    ) -> dict[str, Any]:
        if not source_sql.lstrip().upper().startswith("SELECT"):
            raise AsaServerError("FTS_SELECT_REQUIRED", "FTS source must be a SELECT query.", 400)
        if not text_columns:
            raise AsaServerError("FTS_COLUMNS_REQUIRED", "At least one text column is required.", 400)
        key = self._key(database_id, index_name)
        definition = {
            "id": key,
            "databaseId": database_id,
            "name": index_name,
            "sourceSql": source_sql,
            "idColumn": id_column,
            "textColumns": text_columns,
            "logicalDatabase": logical_database,
            "status": "defined",
            "documents": 0,
            "terms": 0,
            "createdAt": utc_now(),
            "updatedAt": utc_now(),
        }
        self.configs.write(key, definition)
        return definition

    def get(self, database_id: str, index_name: str) -> dict[str, Any]:
        key = self._key(database_id, index_name)
        definition = self.configs.read(key)
        if not isinstance(definition, dict):
            raise AsaServerError("FTS_INDEX_NOT_FOUND", "FTS index does not exist.", 404)
        return definition

    def list(self, database_id: str | None = None) -> list[dict[str, Any]]:
        values = self.configs.list()
        if database_id is not None:
            values = [x for x in values if x.get("databaseId") == database_id]
        return values

    def submit_rebuild(
        self,
        database_id: str,
        index_name: str,
        *,
        user_id: str,
    ) -> dict[str, Any]:
        self.get(database_id, index_name)
        return self.jobs.submit(
            "fts_rebuild",
            {"databaseId": database_id, "indexName": index_name},
            user_id=user_id,
            database_id=database_id,
        )

    def _job_rebuild(self, context: JobContext, payload: dict[str, Any]) -> dict[str, Any]:
        database_id = str(payload["databaseId"])
        index_name = str(payload["indexName"])
        definition = self.get(database_id, index_name)
        if self.availability_guard is not None:
            self.availability_guard(database_id)
        backend = self.backends.get(database_id)
        postings: dict[str, dict[str, int]] = defaultdict(dict)
        documents: dict[str, dict[str, Any]] = {}
        total_docs = 0

        logical_database = definition.get("logicalDatabase")
        page_iterator = (
            backend.stream_query_pages_in_database(
                str(logical_database),
                str(definition["sourceSql"]),
                self.page_size,
            )
            if logical_database
            else backend.stream_query_pages(
                str(definition["sourceSql"]),
                self.page_size,
            )
        )
        for page in page_iterator:
            context.check_cancelled()
            for row in rows_as_dicts(page["raw"]):
                document_id = str(row.get(definition["idColumn"], ""))
                if not document_id:
                    continue
                text = " ".join(str(row.get(column, "")) for column in definition["textColumns"])
                counts = Counter(tokenize(text))
                for token, count in counts.items():
                    postings[token][document_id] = count
                documents[document_id] = {
                    "fields": {
                        column: row.get(column)
                        for column in definition["textColumns"]
                    },
                    "length": sum(counts.values()),
                }
                total_docs += 1
            approximate = min(95.0, 5.0 + page["page"] * 2.0)
            context.progress(
                approximate,
                f"Indexed {total_docs} documents.",
                documents=total_docs,
            )
            if not page["hasMore"]:
                break

        payload_out = {
            "version": 1,
            "databaseId": database_id,
            "name": index_name,
            "documents": documents,
            "postings": postings,
            "builtAt": utc_now(),
        }
        key = self._key(database_id, index_name)
        path = self._index_file(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_suffix(".tmp")
        with gzip.open(temp, "wt", encoding="utf-8") as handle:
            json.dump(payload_out, handle, ensure_ascii=False, separators=(",", ":"))
        try:
            temp.chmod(0o600)
        except OSError:
            pass
        temp.replace(path)

        definition.update({
            "status": "ready",
            "documents": len(documents),
            "terms": len(postings),
            "updatedAt": utc_now(),
            "builtAt": payload_out["builtAt"],
        })
        self.configs.write(key, definition)
        return {
            "databaseId": database_id,
            "indexName": index_name,
            "documents": len(documents),
            "terms": len(postings),
        }

    def search(
        self,
        database_id: str,
        index_name: str,
        query: str,
        *,
        limit: int = 20,
    ) -> dict[str, Any]:
        definition = self.get(database_id, index_name)
        key = self._key(database_id, index_name)
        path = self._index_file(key)
        if not path.exists():
            raise AsaServerError("FTS_NOT_BUILT", "FTS index has not been built.", 409)
        with gzip.open(path, "rt", encoding="utf-8") as handle:
            index = json.load(handle)
        terms = tokenize(query)
        if not terms:
            return {"query": query, "terms": [], "hits": []}

        documents = index.get("documents", {})
        postings = index.get("postings", {})
        scores: dict[str, float] = defaultdict(float)
        document_count = max(1, len(documents))
        for term in terms:
            posting = postings.get(term, {})
            df = max(1, len(posting))
            idf = math.log((document_count + 1) / df) + 1.0
            for document_id, tf in posting.items():
                length = max(1, int(documents.get(document_id, {}).get("length", 1)))
                scores[document_id] += (1.0 + math.log(max(1, int(tf)))) * idf / math.sqrt(length)

        ranked = sorted(scores.items(), key=lambda x: (-x[1], x[0]))[: max(1, min(limit, 500))]
        hits = [
            {
                "id": document_id,
                "score": round(score, 6),
                "fields": documents.get(document_id, {}).get("fields", {}),
            }
            for document_id, score in ranked
        ]
        return {
            "databaseId": database_id,
            "indexName": index_name,
            "query": query,
            "terms": terms,
            "hits": hits,
            "index": definition,
        }
