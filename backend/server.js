const path = require("path");
require("dotenv").config({ path: path.join(__dirname, ".env") });
const express = require("express");
console.log("ENV DB_USER =", process.env.DB_USER);
console.log("ENV DB_NAME =", process.env.DB_NAME);
const cors = require("cors");
const pool = require("./db");

const app = express();
app.use(cors());
app.use(express.json());
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch((err) => {
      console.error("DB/API error:", err);
      res.status(500).json({ error: err.message, code: err.code });
    });
  };
}

// Health
// Health
app.get("/api/health", (req, res) => res.json({ ok: true }));

// Home (so you don't see Cannot GET /)
app.get("/", (req, res) => {
  res.send("ConsentLedger backend is running. Use /api/health");
});

/* ========= MASTER LISTS ========= */
app.get("/api/controllers", async (req, res) => {
  const [rows] = await pool.query("SELECT * FROM controller ORDER BY controller_id");
  res.json(rows);
});

app.get("/api/purposes", async (req, res) => {
  const [rows] = await pool.query("SELECT * FROM purpose ORDER BY purpose_code");
  res.json(rows);
});

app.get("/api/fields", async (req, res) => {
  const [rows] = await pool.query("SELECT * FROM data_field ORDER BY field_code");
  res.json(rows);
});

app.get("/api/processors", async (req, res) => {
  const [rows] = await pool.query(
    "SELECT processor_id, controller_id, username, display_name, role_name, is_active FROM processor_user ORDER BY username"
  );
  res.json(rows);
});

/* ========= SUBJECTS ========= */
app.get("/api/subjects", asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    "SELECT subject_id, external_ref, full_name, dob, email, phone FROM data_subject ORDER BY subject_id DESC"
  );
  res.json(rows);
}));

app.post("/api/subjects", async (req, res) => {
  const { external_ref, full_name, dob, email, phone } = req.body;
  if (!full_name) return res.status(400).json({ error: "full_name is required" });

  const [result] = await pool.query(
    "INSERT INTO data_subject(external_ref, full_name, dob, email, phone) VALUES (?,?,?,?,?)",
    [external_ref || null, full_name, dob || null, email || null, phone || null]
  );
  const [rows] = await pool.query("SELECT * FROM data_subject WHERE subject_id=?", [result.insertId]);
  res.json(rows[0]);
});

/* ========= CONSENT ========= */
app.get("/api/consents", async (req, res) => {
  const [rows] = await pool.query(`
    SELECT cg.consent_id, cg.consent_uid, cg.version_no, cg.status, cg.valid_from, cg.valid_until, cg.note,
           ds.full_name, ds.external_ref,
           c.name AS controller_name,
           p.purpose_code
    FROM consent_grant cg
    JOIN data_subject ds ON ds.subject_id = cg.subject_id
    JOIN controller c ON c.controller_id = cg.controller_id
    JOIN purpose p ON p.purpose_id = cg.purpose_id
    ORDER BY cg.consent_id DESC
    LIMIT 200
  `);
  res.json(rows);
});

app.post("/api/consents/grant", async (req, res) => {
  const { subject_id, controller_id, purpose_id, valid_days, note } = req.body;
  if (!subject_id || !controller_id || !purpose_id || !valid_days) {
    return res.status(400).json({ error: "subject_id, controller_id, purpose_id, valid_days required" });
  }

  const [rows] = await pool.query("CALL sp_grant_consent(?,?,?,?,?)", [
    subject_id, controller_id, purpose_id, valid_days, note || null
  ]);

  // MySQL returns procedure results as nested arrays; first resultset in rows[0]
  res.json(rows[0]);
});

app.post("/api/consents/revoke", async (req, res) => {
  const { consent_id, note } = req.body;
  if (!consent_id) return res.status(400).json({ error: "consent_id required" });

  const [rows] = await pool.query("CALL sp_revoke_consent(?,?)", [consent_id, note || "Revoked by user"]);
  res.json(rows[0]);
});

app.get("/api/consents/:consentId/scope", async (req, res) => {
  const consentId = req.params.consentId;
  const [rows] = await pool.query(`
    SELECT df.field_id, df.field_code, df.display_name, df.sensitivity
    FROM consent_scope_field csf
    JOIN data_field df ON df.field_id = csf.field_id
    WHERE csf.consent_id = ?
    ORDER BY df.field_code
  `, [consentId]);
  res.json(rows);
});

app.post("/api/consents/scope/add", async (req, res) => {
  const { consent_id, field_id } = req.body;
  if (!consent_id || !field_id) return res.status(400).json({ error: "consent_id and field_id required" });

  const [rows] = await pool.query("CALL sp_add_scope_field(?,?)", [consent_id, field_id]);
  res.json(rows[0]);
});

/* ========= ACCESS REQUEST ========= */
app.post("/api/access/request", async (req, res) => {
  const { processor_id, subject_id, controller_id, purpose_id, field_id } = req.body;
  if (!processor_id || !subject_id || !controller_id || !purpose_id || !field_id) {
    return res.status(400).json({ error: "processor_id, subject_id, controller_id, purpose_id, field_id required" });
  }

  const clientIp = req.headers["x-forwarded-for"]?.toString()?.split(",")[0] || req.socket.remoteAddress || null;
  const userAgent = req.headers["user-agent"] || null;

  const [rows] = await pool.query("CALL sp_request_access(?,?,?,?,?,?,?)", [
    processor_id, subject_id, controller_id, purpose_id, field_id, clientIp, userAgent
  ]);

  res.json(rows[0]);
});

/* ========= AUDIT ========= */
app.get("/api/audit", async (req, res) => {
  const [rows] = await pool.query(`
    SELECT ae.access_id, ae.accessed_at, ae.decision, ae.deny_reason, ae.client_ip,
           pu.username,
           ds.full_name,
           c.name AS controller_name,
           p.purpose_code,
           df.field_code
    FROM access_event ae
    JOIN processor_user pu ON pu.processor_id = ae.processor_id
    JOIN data_subject ds ON ds.subject_id = ae.subject_id
    JOIN controller c ON c.controller_id = ae.controller_id
    JOIN purpose p ON p.purpose_id = ae.purpose_id
    JOIN data_field df ON df.field_id = ae.field_id
    ORDER BY ae.access_id DESC
    LIMIT 200
  `);
  res.json(rows);
});

app.get("/api/reports/denied-summary", async (req, res) => {
  const [rows] = await pool.query("SELECT * FROM v_access_denied_summary ORDER BY denied_count DESC");
  res.json(rows);
});

/* ========= DELETION ========= */
app.get("/api/deletions", async (req, res) => {
  const [rows] = await pool.query(`
    SELECT dr.request_id, dr.request_uid, dr.subject_id, dr.controller_id, dr.requested_at,
           dr.status, dr.completed_at, dr.notes,
           ds.full_name, c.name AS controller_name
    FROM deletion_request dr
    JOIN data_subject ds ON ds.subject_id = dr.subject_id
    JOIN controller c ON c.controller_id = dr.controller_id
    ORDER BY dr.request_id DESC
    LIMIT 200
  `);
  res.json(rows);
});

app.post("/api/deletions/create", async (req, res) => {
  const { subject_id, controller_id, created_by_processor_id, notes } = req.body;
  if (!subject_id || !controller_id) return res.status(400).json({ error: "subject_id and controller_id required" });

  const [rows] = await pool.query("CALL sp_create_deletion_request(?,?,?,?)", [
    subject_id, controller_id, created_by_processor_id || null, notes || null
  ]);
  res.json(rows[0]);
});

app.post("/api/deletions/complete", async (req, res) => {
  const { request_id, notes } = req.body;
  if (!request_id) return res.status(400).json({ error: "request_id required" });

  const [rows] = await pool.query("CALL sp_complete_deletion_request(?,?)", [request_id, notes || "Completed"]);
  res.json(rows[0]);
});

/* ========= START ========= */
const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`Backend running on http://localhost:${port}`));