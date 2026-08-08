from asadb_server.client import AsaDBClient

client = AsaDBClient("http://127.0.0.1:7879")
client.login("admin", "replace-this-password")

session = client.create_session("main", "app")["session"]
session_id = session["id"]

client.begin(session_id)
try:
    client.query(
        "_",
        "UPDATE accounts SET balance = balance - 10 WHERE id = 1;",
        session_id=session_id,
    )
    client.query(
        "_",
        "UPDATE accounts SET balance = balance + 10 WHERE id = 2;",
        session_id=session_id,
    )
    client.commit(session_id)
except Exception:
    client.rollback(session_id)
    raise
finally:
    client.close_session(session_id)
