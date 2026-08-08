import os

from asadb_server.file_client import FileApiClient

client = FileApiClient("/var/lib/asadb/server-state/file-api")
response = client.request(
    "query",
    {
        "auth": {"token": os.environ["ASADB_TOKEN"]},
        "databaseId": "main",
        "logicalDatabase": "app",
        "sql": "SELECT * FROM users LIMIT 10;",
    },
)
print(response)
