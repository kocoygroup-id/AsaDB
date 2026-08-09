# Build with repository root as context:
# docker build -f flaskserver/deploy/Dockerfile -t asadb-flask .
FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends swi-prolog-nox ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/asadb
COPY . /opt/asadb

RUN python -m venv /opt/asadb/flaskserver/.venv \
    && /opt/asadb/flaskserver/.venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/asadb/flaskserver/.venv/bin/pip install --no-cache-dir -e /opt/asadb/flaskserver

RUN useradd --system --home /var/lib/asadb --shell /usr/sbin/nologin asadb \
    && mkdir -p /var/lib/asadb/databases /var/lib/asadb/server-state /var/lib/asadb/tmp \
    && chown -R asadb:asadb /var/lib/asadb

USER asadb
ENV ASADB_REPO_ROOT=/opt/asadb \
    ASADB_DATA_DIR=/var/lib/asadb/databases \
    ASADB_STATE_DIR=/var/lib/asadb/server-state \
    ASADB_TEMP_DIR=/var/lib/asadb/tmp \
    ASADB_HOST=0.0.0.0 \
    ASADB_PORT=2026

EXPOSE 2026
VOLUME ["/var/lib/asadb"]
CMD ["/opt/asadb/flaskserver/.venv/bin/asadb", "server", "--host", "0.0.0.0", "--port", "2026", "--threads", "8"]
