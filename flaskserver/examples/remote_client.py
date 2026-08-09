from asadb_server.client import AsaDBClient

client = AsaDBClient("http://127.0.0.1:2026")
client.login("admin", "replace-this-password")

result = client.query(
    "main",
    "SELECT * FROM users LIMIT 20;",
    logical_database="app",
)
print(result)

for page in client.stream_query(
    "main",
    "SELECT * FROM audit_events ORDER BY id;",
    logical_database="app",
    page_size=500,
):
    print(page["page"], len(page["rows"]))
