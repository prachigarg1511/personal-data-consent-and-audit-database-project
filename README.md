# Personal Data Consent & Audit Database Project (MySQL + Node.js + VS Code)

A privacy-first **consent ledger** and **audit logging** system for managing personal data access.  
This project models how controllers/processors request access to specific data fields for defined purposes, while maintaining an immutable-style audit trail and enabling consent lifecycle actions (grant, revoke, expire, deletion requests).

---

## Highlights

- **Consent Ledger**: Track consent grants per subject, controller, purpose, and time window.
- **Field-Level Scope**: Consent can be limited to specific data fields (e.g., EMAIL, PHONE).
- **Audit Logging**: Every access request is recorded with an allow/deny decision and reason.
- **Lifecycle Automation**:
  - Auto-generate UUIDs (triggers)
  - Auto-expire consents (procedure)
  - Track consent changes in history (triggers)
- **SQL-first design** with clear relational constraints and integrity checks.

---

## Tech Stack

- **Database:** MySQL (InnoDB, utf8mb4)
- **Backend:** Node.js + Express (REST API)
- **Frontend:** HTML + CSS + JavaScript (simple UI)
- **Tools:** VS Code + SQLTools extension

---

## Architecture (High-Level)

```text
Frontend (Browser)
   |
   | fetch() REST calls
   v
Backend (Node/Express @ :8080)
   |
   | SQL queries / stored procedures
   v
MySQL Database (consent_ledger)
```

---

## Data Model (Core Tables)

- `data_subject` — personal data subject registry  
- `controller` — data controller (e.g., CampusApp)  
- `processor_user` — processor accounts under a controller  
- `purpose` — purpose of processing (AUTH, BILLING, NOTIFY, ANALYTICS)  
- `data_field` — field catalog (EMAIL, PHONE, DOB, etc.)  
- `purpose_min_field` — minimum required fields per purpose (data minimization)  
- `consent_grant` — consent ledger entries (status, validity window, versioning)  
- `consent_scope_field` — field-level scope per consent  
- `consent_history` — consent changes (create/update/revoke/expire)  
- `access_event` — audit log for each access request  
- `deletion_request` — “right to deletion” request workflow

Views:
- `v_active_consents`
- `v_access_denied_summary`

---

## Features (What You Can Do)

### Consent Management
- Grant consent for a subject + purpose for a valid duration
- Revoke consent
- Expire old consents automatically

### Access Auditing
- Request access to a specific field
- System returns **ALLOWED** or **DENIED**
- If denied, a reason is stored (e.g., NO_ACTIVE_CONSENT, FIELD_NOT_IN_SCOPE)

### Deletion Requests
- Create deletion request
- Complete deletion request (revokes active consents for that subject/controller)

---

## Setup (Local Development)

### Prerequisites
- MySQL Server (8.x recommended)
- Node.js (LTS recommended)
- VS Code + SQLTools extension

---

## 1) Database Setup

#### Option A (Recommended in VS Code): SQLTools-friendly script
Use the SQLTools-friendly script (no `DELIMITER`) and run it in chunks:
- schema + views
- triggers (one by one)
- procedures (one by one)
- seed data
- procedure calls

> If you don’t have it yet, create it as:
`database/consent_ledger_full_sqltools.sql`

Then verify:

```sql
USE consent_ledger;
SHOW TABLES;
SELECT * FROM data_subject;
SELECT * FROM consent_grant;
```

#### Option B: Use MySQL CLI / Workbench (supports DELIMITER)
If you use MySQL Workbench / MySQL CLI, you can run the original script with `DELIMITER`.

---

## 2) Backend Setup

Go to backend folder:

```bash
cd backend
npm install
```

Create `.env` (example):

```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=YOUR_PASSWORD
DB_NAME=consent_ledger
DB_PORT=3306

PORT=8080
```

Run backend:

```bash
npm start
```

Health check (open in browser):

- `http://127.0.0.1:8080/api/health`

---

## 3) Frontend Setup

Run a simple static server:

```bash
cd frontend
npx http-server -p 5500 --cors
```

Open:

- `http://127.0.0.1:5500/index.html`

---

## API (Examples)

> Your exact routes may vary based on `backend/server.js`.

### Get subjects
```bash
curl http://127.0.0.1:8080/api/subjects
```

### Test from Browser Console
```js
fetch("http://127.0.0.1:8080/api/subjects")
  .then(r => r.json())
  .then(console.log)
  .catch(console.error);
```

---

## Troubleshooting

### “Unknown database 'consent_ledger'”
- Run `CREATE DATABASE consent_ledger;`
- Ensure `.env` DB_NAME matches exactly.

### SQLTools error near `DELIMITER`
- SQLTools often fails on `DELIMITER`.
- Use the SQLTools-friendly script and run triggers/procedures individually.

### Frontend shows “Failed to fetch”
- Backend must be running at `http://127.0.0.1:8080`
- Ensure CORS is enabled in backend
- Ensure frontend API base URL is correct

---

## Screenshots (Optional)
Add screenshots here:

- `docs/screenshots/home.png`
- `docs/screenshots/subjects.png`

Then embed:

```md
![Home](docs/screenshots/home.png)
```

---

## Roadmap (Ideas)
- Role-based access control in backend
- JWT authentication for processor users
- Pagination and filtering for audit logs
- Export reports (CSV) for denied access summary

---

## License
This project is for educational / academic use.  
Add a license if you plan to publish it as open source.

---

## Author
**Prachi Garg**  
GitHub: https://github.com/prachigarg1511
