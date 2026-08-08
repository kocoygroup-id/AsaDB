"use strict";

/* Server mode never stores authentication tokens in Web Storage.  Clear the
 * panel's fallback cache only when the user confirms logout, while preserving
 * harmless language/theme preferences as promised by the UI contract. */
document.querySelector(".logout-form")?.addEventListener("submit", () => {
  for (const key of [
    "asadb-sandbox-v2",
    "asadb-sandbox",
    "asadb-active-reservoir-job-v1",
  ]) {
    try { localStorage.removeItem(key); } catch (_) { /* storage unavailable */ }
  }
});
