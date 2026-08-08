from asadb_server.client import AsaDBClient

client = AsaDBClient("http://127.0.0.1:7879")
client.login("admin", "replace-this-password")

definition = client.request(
    "POST",
    "/api/v1/fts",
    {
        "databaseId": "main",
        "logicalDatabase": "app",
        "name": "articles",
        "sourceSql": "SELECT id, title, body FROM articles ORDER BY id;",
        "idColumn": "id",
        "textColumns": ["title", "body"],
    },
)
print(definition)

job = client.request(
    "POST",
    "/api/v1/fts/main/articles/rebuild",
    {},
)
print(job)
