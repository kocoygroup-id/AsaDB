"use strict";

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body?.error?.message || `HTTP ${response.status}`);
  return body;
}

function pretty(value) {
  return JSON.stringify(value, null, 2);
}

async function loadAll() {
  const [dbs, users, nodes, jobs, config, audit] = await Promise.all([
    api("/api/v1/databases"),
    api("/api/v1/users"),
    api("/api/v1/cluster/nodes"),
    api("/api/v1/jobs"),
    api("/api/v1/config"),
    api("/api/v1/audit?limit=100")
  ]);
  document.getElementById("databases").innerHTML = `
    <table><thead><tr><th>ID</th><th>File</th><th>Role</th><th>Backend</th><th>Panel</th></tr></thead>
    <tbody>${dbs.databases.map(db => `<tr>
      <td>${db.id}</td><td>${db.filename}</td><td>${db.localRole}</td>
      <td>${db.backend?.alive ? "online" : "stopped"}
        ${db.replicationLogicalDatabase ? `· repl ${db.replicationLogicalDatabase}` : ""}</td>
      <td><a href="/panel/select/${encodeURIComponent(db.id)}">Open</a></td>
    </tr>`).join("")}</tbody></table>`;
  document.getElementById("users").textContent = pretty(users.users);
  document.getElementById("nodes").textContent = pretty(nodes.nodes);
  document.getElementById("jobs").textContent = pretty(jobs.jobs);
  document.getElementById("workers").textContent = pretty(
    dbs.databases.map(x => ({ id: x.id, backend: x.backend }))
  );
  document.getElementById("config").value = pretty(config.config);
  document.getElementById("audit").textContent = pretty(audit.events);
}

document.querySelector("[data-action=reload]").addEventListener("click", loadAll);

document.getElementById("database-form").addEventListener("submit", async event => {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  await api("/api/v1/databases", {
    method: "POST",
    body: JSON.stringify({
      id: form.get("id"),
      filename: form.get("filename"),
      replicationLogicalDatabase: form.get("logicalDatabase") || null,
      replicaNodes: String(form.get("replicaNodes") || "")
        .split(",").map(x => x.trim()).filter(Boolean)
    })
  });
  event.currentTarget.reset();
  await loadAll();
});

document.getElementById("user-form").addEventListener("submit", async event => {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  await api("/api/v1/users", {
    method: "POST",
    body: JSON.stringify({
      username: form.get("username"),
      password: form.get("password"),
      bindings: [{ role: form.get("role"), scope: "*" }]
    })
  });
  event.currentTarget.reset();
  await loadAll();
});

document.getElementById("node-form").addEventListener("submit", async event => {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  await api("/api/v1/cluster/nodes", {
    method: "POST",
    body: JSON.stringify({ id: form.get("id"), url: form.get("url") })
  });
  event.currentTarget.reset();
  await loadAll();
});

document.getElementById("save-config").addEventListener("click", async () => {
  const value = JSON.parse(document.getElementById("config").value || "{}");
  await api("/api/v1/config", { method: "PUT", body: JSON.stringify(value) });
  alert("Saved. Restart the service to apply.");
});

loadAll().catch(error => {
  document.getElementById("audit").textContent = String(error);
});
setInterval(() => loadAll().catch(() => {}), 5000);
