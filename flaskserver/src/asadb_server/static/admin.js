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

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, character => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[character]);
}

function badge(label, state = "") {
  return `<span class="admin-badge ${escapeHtml(state)}">${escapeHtml(label)}</span>`;
}

function empty(message) {
  return `<p class="admin-empty">${escapeHtml(message)}</p>`;
}

function table(headings, rows, emptyMessage) {
  if (!rows.length) return empty(emptyMessage);
  return `<table><thead><tr>${headings.map(heading => `<th>${escapeHtml(heading)}</th>`).join("")}</tr></thead><tbody>${rows.join("")}</tbody></table>`;
}

function formatBytes(value) {
  const bytes = Number(value || 0);
  if (!Number.isFinite(bytes) || bytes <= 0) return "—";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KiB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MiB`;
}

function renderUsers(users) {
  return table(["User", "Role & scope", "Status"], users.map(user => {
    const bindings = Array.isArray(user.bindings) ? user.bindings : [];
    const roles = bindings.map(binding => `${escapeHtml(binding.role || "reader")} · ${escapeHtml(binding.scope || "*")}`).join("<br>") || "reader · *";
    return `<tr><td><strong>${escapeHtml(user.username)}</strong></td><td>${roles}</td><td>${badge(user.enabled ? "Enabled" : "Disabled", user.enabled ? "ok" : "danger")}</td></tr>`;
  }), "No user accounts are registered.");
}

function renderNodes(nodes) {
  return table(["Node", "Address", "State"], nodes.map(node =>
    `<tr><td><strong>${escapeHtml(node.id)}</strong>${node.local ? " <span class=\"admin-badge\">local</span>" : ""}</td><td><code>${escapeHtml(node.url || "—")}</code></td><td>${badge(node.status || "unknown", node.status === "online" ? "ok" : "warn")}</td></tr>`
  ), "No cluster nodes are registered.");
}

function renderWorkers(databases) {
  return table(["Database", "Role", "Backend"], databases.map(database => {
    const online = Boolean(database.backend?.alive);
    return `<tr><td><strong>${escapeHtml(database.id)}</strong></td><td>${escapeHtml(database.localRole || "primary")}</td><td>${badge(online ? "Online" : "Stopped", online ? "ok" : "warn")}</td></tr>`;
  }), "No database workers are registered.");
}

function renderJobs(jobs) {
  return table(["Job", "State", "Progress", "Message"], jobs.map(job => {
    const state = String(job.status || "unknown");
    const stateClass = state === "completed" ? "ok" : ["failed", "cancelled", "interrupted"].includes(state) ? "danger" : "warn";
    const progress = Number(job.progress);
    return `<tr><td><code>${escapeHtml(job.kind || job.id || "job")}</code></td><td>${badge(state, stateClass)}</td><td>${Number.isFinite(progress) ? `${Math.round(progress)}%` : "—"}</td><td>${escapeHtml(job.message || "—")}</td></tr>`;
  }), "No background jobs are active.");
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
  document.getElementById("databases").innerHTML = table(
    ["Database", "File", "Size", "Role", "Backend", "Workspace"],
    dbs.databases.map(db => {
      const online = Boolean(db.backend?.alive);
      return `<tr><td><strong>${escapeHtml(db.id)}</strong>${db.replicationLogicalDatabase ? `<br><small>replication: ${escapeHtml(db.replicationLogicalDatabase)}</small>` : ""}</td><td><code>${escapeHtml(db.filename)}</code></td><td>${formatBytes(db.sizeBytes)}</td><td>${escapeHtml(db.localRole || "primary")}</td><td>${badge(online ? "Online" : "Stopped", online ? "ok" : "warn")}</td><td><a href="/panel/select/${encodeURIComponent(db.id)}">Open</a></td></tr>`;
    }),
    "No database files are registered."
  );
  document.getElementById("users").innerHTML = renderUsers(users.users || []);
  document.getElementById("nodes").innerHTML = renderNodes(nodes.nodes || []);
  document.getElementById("jobs").innerHTML = renderJobs(jobs.jobs || []);
  document.getElementById("workers").innerHTML = renderWorkers(dbs.databases || []);
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
