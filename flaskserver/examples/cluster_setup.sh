#!/bin/sh
set -eu

NODE1=${NODE1:-https://node-1.example}
TOKEN=${TOKEN:?set TOKEN}

curl -fsS -X POST "$NODE1/api/v1/cluster/nodes" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id":"node-2","url":"https://node-2.example"}'

curl -fsS -X PATCH "$NODE1/api/v1/databases/main" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "primaryNode":"node-1",
    "replicaNodes":["node-2"],
    "replicationLogicalDatabase":"app"
  }'
