const API = "http://127.0.0.1:8080/api";

const $ = (id) => document.getElementById(id);

function opt(value, label) {
  const o = document.createElement("option");
  o.value = value;
  o.textContent = label;
  return o;
}

async function jsonFetch(url, options = {}) {
  const res = await fetch(url, {
    headers: { "Content-Type": "application/json" },
    ...options
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || "Request failed");
  return data;
}

async function loadMasters() {
  const [subjects, controllers, purposes, fields, processors, consents, deletions] =
    await Promise.all([
      jsonFetch(`${API}/subjects`),
      jsonFetch(`${API}/controllers`),
      jsonFetch(`${API}/purposes`),
      jsonFetch(`${API}/fields`),
      jsonFetch(`${API}/processors`),
      jsonFetch(`${API}/consents`),
      jsonFetch(`${API}/deletions`)
    ]);

  // Subjects selects
  const subjectSelects = ["g_subject","a_subject","d_subject"];
  subjectSelects.forEach((sid) => {
    const s = $(sid);
    s.innerHTML = "";
    subjects.forEach(sub => s.appendChild(opt(sub.subject_id, `${sub.subject_id} - ${sub.full_name}`)));
  });

  // Controllers selects
  const controllerSelects = ["g_controller","a_controller","d_controller"];
  controllerSelects.forEach((cid) => {
    const s = $(cid);
    s.innerHTML = "";
    controllers.forEach(c => s.appendChild(opt(c.controller_id, `${c.controller_id} - ${c.name}`)));
  });

  // Purposes selects
  const purposeSelects = ["g_purpose","a_purpose"];
  purposeSelects.forEach((pid) => {
    const s = $(pid);
    s.innerHTML = "";
    purposes.forEach(p => s.appendChild(opt(p.purpose_id, `${p.purpose_code} - ${p.description}`)));
  });

  // Fields
  const fieldSel = $("a_field");
  fieldSel.innerHTML = "";
  fields.forEach(f => fieldSel.appendChild(opt(f.field_id, `${f.field_code} (${f.sensitivity})`)));

  // Processors
  const procSel = $("a_processor");
  procSel.innerHTML = "";
  processors.forEach(p => procSel.appendChild(opt(p.processor_id, `${p.username} (${p.role_name})`)));

  const delCreatedBy = $("d_created_by");
  delCreatedBy.innerHTML = "";
  processors.forEach(p => delCreatedBy.appendChild(opt(p.processor_id, `${p.username}`)));

  // Consents for revoke
  const consentSel = $("r_consent");
  consentSel.innerHTML = "";
  consents.forEach(cg => consentSel.appendChild(opt(cg.consent_id, `${cg.consent_id} - ${cg.full_name} - ${cg.purpose_code} - ${cg.status}`)));

  // Deletion requests for complete
  const delReqSel = $("d_request");
  delReqSel.innerHTML = "";
  deletions.forEach(dr => delReqSel.appendChild(opt(dr.request_id, `${dr.request_id} - ${dr.full_name} - ${dr.status}`)));

  await refreshAudit();
  await refreshDenied();
  await refreshDeletionsTable();
}

async function refreshAudit() {
  const rows = await jsonFetch(`${API}/audit`);
  const tbody = $("auditTable").querySelector("tbody");
  tbody.innerHTML = "";
  rows.forEach(r => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${r.access_id}</td>
      <td>${r.accessed_at}</td>
      <td>${r.decision}</td>
      <td>${r.deny_reason}</td>
      <td>${r.username}</td>
      <td>${r.full_name}</td>
      <td>${r.controller_name}</td>
      <td>${r.purpose_code}</td>
      <td>${r.field_code}</td>
      <td>${r.client_ip || ""}</td>
    `;
    tbody.appendChild(tr);
  });
}

async function refreshDenied() {
  const rows = await jsonFetch(`${API}/reports/denied-summary`);
  const tbody = $("deniedTable").querySelector("tbody");
  tbody.innerHTML = "";
  rows.forEach(r => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${r.controller_id}</td>
      <td>${r.deny_reason}</td>
      <td>${r.denied_count}</td>
      <td>${r.first_seen}</td>
      <td>${r.last_seen}</td>
    `;
    tbody.appendChild(tr);
  });
}

async function refreshDeletionsTable() {
  const rows = await jsonFetch(`${API}/deletions`);
  const tbody = $("deleteTable").querySelector("tbody");
  tbody.innerHTML = "";
  rows.forEach(r => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${r.request_id}</td>
      <td>${r.request_uid}</td>
      <td>${r.full_name}</td>
      <td>${r.controller_name}</td>
      <td>${r.status}</td>
      <td>${r.requested_at}</td>
      <td>${r.completed_at || ""}</td>
      <td>${r.notes || ""}</td>
    `;
    tbody.appendChild(tr);
  });
}

document.addEventListener("DOMContentLoaded", async () => {
  // Forms
  $("subjectForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      const payload = {
        external_ref: $("sub_external_ref").value,
        full_name: $("sub_full_name").value,
        dob: $("sub_dob").value,
        email: $("sub_email").value,
        phone: $("sub_phone").value
      };
      const data = await jsonFetch(`${API}/subjects`, { method: "POST", body: JSON.stringify(payload) });
      $("subjectResult").textContent = JSON.stringify(data, null, 2);
      await loadMasters();
    } catch (err) {
      $("subjectResult").textContent = err.message;
    }
  });

  $("grantForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      const payload = {
        subject_id: Number($("g_subject").value),
        controller_id: Number($("g_controller").value),
        purpose_id: Number($("g_purpose").value),
        valid_days: Number($("g_days").value),
        note: $("g_note").value
      };
      const data = await jsonFetch(`${API}/consents/grant`, { method: "POST", body: JSON.stringify(payload) });
      $("grantResult").textContent = JSON.stringify(data, null, 2);
      await loadMasters();
    } catch (err) {
      $("grantResult").textContent = err.message;
    }
  });

  $("accessForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      const payload = {
        processor_id: Number($("a_processor").value),
        subject_id: Number($("a_subject").value),
        controller_id: Number($("a_controller").value),
        purpose_id: Number($("a_purpose").value),
        field_id: Number($("a_field").value)
      };
      const data = await jsonFetch(`${API}/access/request`, { method: "POST", body: JSON.stringify(payload) });
      $("accessResult").textContent = JSON.stringify(data, null, 2);
      await refreshAudit();
      await refreshDenied();
    } catch (err) {
      $("accessResult").textContent = err.message;
    }
  });

  $("revokeForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      const payload = {
        consent_id: Number($("r_consent").value),
        note: $("r_note").value
      };
      const data = await jsonFetch(`${API}/consents/revoke`, { method: "POST", body: JSON.stringify(payload) });
      $("revokeResult").textContent = JSON.stringify(data, null, 2);
      await loadMasters();
    } catch (err) {
      $("revokeResult").textContent = err.message;
    }
  });

  $("refreshAudit").addEventListener("click", refreshAudit);
  $("refreshDenied").addEventListener("click", refreshDenied);

  $("deleteForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      const payload = {
        subject_id: Number($("d_subject").value),
        controller_id: Number($("d_controller").value),
        created_by_processor_id: Number($("d_created_by").value),
        notes: $("d_notes").value
      };
      const data = await jsonFetch(`${API}/deletions/create`, { method: "POST", body: JSON.stringify(payload) });
      $("deleteResult").textContent = JSON.stringify(data, null, 2);
      await loadMasters();
    } catch (err) {
      $("deleteResult").textContent = err.message;
    }
  });

  $("completeDeleteForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    try {
      const payload = {
        request_id: Number($("d_request").value),
        notes: $("d_complete_notes").value
      };
      const data = await jsonFetch(`${API}/deletions/complete`, { method: "POST", body: JSON.stringify(payload) });
      $("deleteResult").textContent = JSON.stringify(data, null, 2);
      await loadMasters();
    } catch (err) {
      $("deleteResult").textContent = err.message;
    }
  });

  await loadMasters();
});