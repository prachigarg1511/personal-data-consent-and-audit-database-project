DROP DATABASE IF EXISTS consent_ledger;
CREATE DATABASE consent_ledger CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE consent_ledger;

CREATE TABLE data_subject (
  subject_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  external_ref VARCHAR(64) NULL,
  full_name VARCHAR(120) NOT NULL,
  dob DATE NULL,
  email VARCHAR(190) UNIQUE,
  phone VARCHAR(20) UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE controller (
  controller_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(120) NOT NULL UNIQUE,
  domain_type ENUM('CAMPUS_APP','HOSPITAL','ECOMMERCE','FINTECH','OTHER') NOT NULL DEFAULT 'CAMPUS_APP',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE processor_user (
  processor_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  controller_id BIGINT NOT NULL,
  username VARCHAR(80) NOT NULL,
  display_name VARCHAR(120) NULL,
  role_name ENUM('ADMIN','STAFF','SERVICE') NOT NULL DEFAULT 'STAFF',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (controller_id, username),
  CONSTRAINT fk_processor_controller
    FOREIGN KEY (controller_id) REFERENCES controller(controller_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE purpose (
  purpose_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  purpose_code VARCHAR(50) NOT NULL UNIQUE,
  description VARCHAR(255) NOT NULL,
  legal_basis ENUM('CONSENT','CONTRACT','LEGAL_OBLIGATION','VITAL_INTEREST','PUBLIC_TASK','LEGITIMATE_INTEREST')
    NOT NULL DEFAULT 'CONSENT'
) ENGINE=InnoDB;

CREATE TABLE data_field (
  field_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  field_code VARCHAR(50) NOT NULL UNIQUE,
  display_name VARCHAR(80) NOT NULL,
  sensitivity ENUM('LOW','MEDIUM','HIGH') NOT NULL DEFAULT 'LOW',
  is_personal BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE purpose_min_field (
  purpose_id BIGINT NOT NULL,
  field_id BIGINT NOT NULL,
  PRIMARY KEY (purpose_id, field_id),
  CONSTRAINT fk_pmf_purpose FOREIGN KEY (purpose_id) REFERENCES purpose(purpose_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pmf_field FOREIGN KEY (field_id) REFERENCES data_field(field_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE retention_policy (
  policy_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  controller_id BIGINT NOT NULL,
  purpose_id BIGINT NOT NULL,
  retention_days INT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(controller_id, purpose_id),
  CONSTRAINT fk_rp_controller FOREIGN KEY (controller_id) REFERENCES controller(controller_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rp_purpose FOREIGN KEY (purpose_id) REFERENCES purpose(purpose_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_retention_days CHECK (retention_days BETWEEN 1 AND 36500)
) ENGINE=InnoDB;

CREATE TABLE consent_grant (
  consent_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  consent_uid CHAR(36) NOT NULL,
  version_no INT NOT NULL DEFAULT 1,

  subject_id BIGINT NOT NULL,
  controller_id BIGINT NOT NULL,
  purpose_id BIGINT NOT NULL,

  granted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  valid_from DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  valid_until DATETIME NOT NULL,

  status ENUM('ACTIVE','REVOKED','EXPIRED') NOT NULL DEFAULT 'ACTIVE',
  revoked_at DATETIME NULL,

  note VARCHAR(255) NULL,

  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_consent_lookup (subject_id, controller_id, purpose_id, status, valid_from, valid_until),
  INDEX idx_consent_uid (consent_uid),

  CONSTRAINT fk_consent_subject FOREIGN KEY (subject_id) REFERENCES data_subject(subject_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_consent_controller FOREIGN KEY (controller_id) REFERENCES controller(controller_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_consent_purpose FOREIGN KEY (purpose_id) REFERENCES purpose(purpose_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT chk_consent_dates CHECK (valid_until > valid_from)
) ENGINE=InnoDB;

CREATE TABLE consent_scope_field (
  consent_id BIGINT NOT NULL,
  field_id BIGINT NOT NULL,
  PRIMARY KEY (consent_id, field_id),
  CONSTRAINT fk_scope_consent FOREIGN KEY (consent_id) REFERENCES consent_grant(consent_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_scope_field FOREIGN KEY (field_id) REFERENCES data_field(field_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE consent_history (
  history_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  consent_id BIGINT NOT NULL,
  consent_uid CHAR(36) NOT NULL,
  version_no INT NOT NULL,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  change_type ENUM('CREATE','UPDATE','REVOKE','EXPIRE') NOT NULL,
  old_status ENUM('ACTIVE','REVOKED','EXPIRED') NULL,
  new_status ENUM('ACTIVE','REVOKED','EXPIRED') NULL,
  old_valid_until DATETIME NULL,
  new_valid_until DATETIME NULL,
  changed_by_processor_id BIGINT NULL,
  note VARCHAR(255) NULL,
  INDEX idx_hist_consent (consent_id, changed_at),
  CONSTRAINT fk_hist_consent FOREIGN KEY (consent_id) REFERENCES consent_grant(consent_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_hist_processor FOREIGN KEY (changed_by_processor_id) REFERENCES processor_user(processor_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE access_event (
  access_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  accessed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  processor_id BIGINT NOT NULL,
  subject_id BIGINT NOT NULL,
  controller_id BIGINT NOT NULL,
  purpose_id BIGINT NOT NULL,
  field_id BIGINT NOT NULL,

  consent_id BIGINT NULL,

  decision ENUM('ALLOWED','DENIED') NOT NULL,
  deny_reason ENUM('NONE','NO_ACTIVE_CONSENT','EXPIRED','REVOKED','FIELD_NOT_IN_SCOPE','PROCESSOR_INACTIVE','CONTROLLER_MISMATCH','MIN_FIELD_VIOLATION')
    NOT NULL DEFAULT 'NONE',

  client_ip VARCHAR(45) NULL,
  user_agent VARCHAR(255) NULL,

  CONSTRAINT fk_ae_processor FOREIGN KEY (processor_id) REFERENCES processor_user(processor_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ae_subject FOREIGN KEY (subject_id) REFERENCES data_subject(subject_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ae_controller FOREIGN KEY (controller_id) REFERENCES controller(controller_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ae_purpose FOREIGN KEY (purpose_id) REFERENCES purpose(purpose_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ae_field FOREIGN KEY (field_id) REFERENCES data_field(field_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ae_consent FOREIGN KEY (consent_id) REFERENCES consent_grant(consent_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  INDEX idx_ae_reporting (controller_id, purpose_id, field_id, accessed_at),
  INDEX idx_ae_subject (subject_id, accessed_at),
  INDEX idx_ae_decision (decision, deny_reason, accessed_at)
) ENGINE=InnoDB;

CREATE TABLE deletion_request (
  request_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  request_uid CHAR(36) NOT NULL,
  subject_id BIGINT NOT NULL,
  controller_id BIGINT NOT NULL,

  requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status ENUM('PENDING','IN_PROGRESS','COMPLETED','REJECTED') NOT NULL DEFAULT 'PENDING',
  completed_at DATETIME NULL,
  notes VARCHAR(255) NULL,

  created_by_processor_id BIGINT NULL,

  UNIQUE(request_uid),
  INDEX idx_del_status (status, requested_at),

  CONSTRAINT fk_del_subject FOREIGN KEY (subject_id) REFERENCES data_subject(subject_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_del_controller FOREIGN KEY (controller_id) REFERENCES controller(controller_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_del_creator FOREIGN KEY (created_by_processor_id) REFERENCES processor_user(processor_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW v_active_consents AS
SELECT
  cg.consent_id, cg.consent_uid, cg.version_no,
  cg.subject_id, cg.controller_id, cg.purpose_id,
  cg.valid_from, cg.valid_until, cg.status
FROM consent_grant cg
WHERE cg.status='ACTIVE' AND NOW() BETWEEN cg.valid_from AND cg.valid_until;

CREATE OR REPLACE VIEW v_access_denied_summary AS
SELECT
  controller_id,
  deny_reason,
  COUNT(*) AS denied_count,
  MIN(accessed_at) AS first_seen,
  MAX(accessed_at) AS last_seen
FROM access_event
WHERE decision='DENIED'
GROUP BY controller_id, deny_reason;

DELIMITER $$

CREATE TRIGGER trg_consent_uuid
BEFORE INSERT ON consent_grant
FOR EACH ROW
BEGIN
  IF NEW.consent_uid IS NULL OR NEW.consent_uid = '' THEN
    SET NEW.consent_uid = UUID();
  END IF;
END$$

CREATE TRIGGER trg_deletion_uuid
BEFORE INSERT ON deletion_request
FOR EACH ROW
BEGIN
  IF NEW.request_uid IS NULL OR NEW.request_uid = '' THEN
    SET NEW.request_uid = UUID();
  END IF;
END$$

CREATE TRIGGER trg_consent_history_create
AFTER INSERT ON consent_grant
FOR EACH ROW
BEGIN
  INSERT INTO consent_history(consent_id, consent_uid, version_no, change_type, new_status, new_valid_until, note)
  VALUES (NEW.consent_id, NEW.consent_uid, NEW.version_no, 'CREATE', NEW.status, NEW.valid_until, NEW.note);
END$$

CREATE TRIGGER trg_consent_set_revoked_at
BEFORE UPDATE ON consent_grant
FOR EACH ROW
BEGIN
  IF NEW.status='REVOKED' AND OLD.status <> 'REVOKED' THEN
    SET NEW.revoked_at = NOW();
  END IF;
END$$

CREATE TRIGGER trg_consent_history_update
AFTER UPDATE ON consent_grant
FOR EACH ROW
BEGIN
  IF (OLD.status <> NEW.status) OR (OLD.valid_until <> NEW.valid_until) THEN
    INSERT INTO consent_history(
      consent_id, consent_uid, version_no, change_type,
      old_status, new_status, old_valid_until, new_valid_until, note
    )
    VALUES (
      NEW.consent_id, NEW.consent_uid, NEW.version_no,
      CASE
        WHEN NEW.status='REVOKED' THEN 'REVOKE'
        WHEN NEW.status='EXPIRED' THEN 'EXPIRE'
        ELSE 'UPDATE'
      END,
      OLD.status, NEW.status, OLD.valid_until, NEW.valid_until, NEW.note
    );
  END IF;
END$$

CREATE PROCEDURE sp_expire_consents()
BEGIN
  UPDATE consent_grant
  SET status='EXPIRED', version_no = version_no + 1, note = CONCAT(IFNULL(note,''), ' | auto-expired')
  WHERE status='ACTIVE' AND valid_until < NOW();
END$$

CREATE PROCEDURE sp_grant_consent(
  IN p_subject_id BIGINT,
  IN p_controller_id BIGINT,
  IN p_purpose_id BIGINT,
  IN p_valid_days INT,
  IN p_note VARCHAR(255)
)
BEGIN
  DECLARE v_new_consent_id BIGINT;

  IF p_valid_days IS NULL OR p_valid_days < 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'p_valid_days must be >= 1';
  END IF;

  CALL sp_expire_consents();

  INSERT INTO consent_grant(subject_id, controller_id, purpose_id, valid_from, valid_until, status, note)
  VALUES (p_subject_id, p_controller_id, p_purpose_id, NOW(), DATE_ADD(NOW(), INTERVAL p_valid_days DAY), 'ACTIVE', p_note);

  SET v_new_consent_id = LAST_INSERT_ID();

  INSERT INTO consent_scope_field(consent_id, field_id)
  SELECT v_new_consent_id, pmf.field_id
  FROM purpose_min_field pmf
  WHERE pmf.purpose_id = p_purpose_id;

  SELECT * FROM consent_grant WHERE consent_id = v_new_consent_id;
END$$

CREATE PROCEDURE sp_add_scope_field(
  IN p_consent_id BIGINT,
  IN p_field_id BIGINT
)
BEGIN
  INSERT IGNORE INTO consent_scope_field(consent_id, field_id)
  VALUES (p_consent_id, p_field_id);

  SELECT * FROM consent_scope_field WHERE consent_id = p_consent_id;
END$$

CREATE PROCEDURE sp_revoke_consent(
  IN p_consent_id BIGINT,
  IN p_note VARCHAR(255)
)
BEGIN
  UPDATE consent_grant
  SET status='REVOKED',
      note = p_note,
      version_no = version_no + 1
  WHERE consent_id = p_consent_id;

  SELECT * FROM consent_grant WHERE consent_id = p_consent_id;
END$$

CREATE PROCEDURE sp_request_access(
  IN p_processor_id BIGINT,
  IN p_subject_id BIGINT,
  IN p_controller_id BIGINT,
  IN p_purpose_id BIGINT,
  IN p_field_id BIGINT,
  IN p_client_ip VARCHAR(45),
  IN p_user_agent VARCHAR(255)
)
BEGIN
  DECLARE v_proc_controller BIGINT;
  DECLARE v_proc_active BOOLEAN;
  DECLARE v_consent_id BIGINT DEFAULT NULL;

  /* 1) processor check */
  SELECT controller_id, is_active INTO v_proc_controller, v_proc_active
  FROM processor_user WHERE processor_id = p_processor_id;

  IF v_proc_active IS NULL OR v_proc_active = FALSE THEN
    INSERT INTO access_event(processor_id, subject_id, controller_id, purpose_id, field_id, consent_id,
      decision, deny_reason, client_ip, user_agent)
    VALUES (p_processor_id, p_subject_id, p_controller_id, p_purpose_id, p_field_id, NULL,
      'DENIED', 'PROCESSOR_INACTIVE', p_client_ip, p_user_agent);

    SELECT * FROM access_event WHERE access_id = LAST_INSERT_ID();
  ELSEIF v_proc_controller <> p_controller_id THEN
    INSERT INTO access_event(processor_id, subject_id, controller_id, purpose_id, field_id, consent_id,
      decision, deny_reason, client_ip, user_agent)
    VALUES (p_processor_id, p_subject_id, p_controller_id, p_purpose_id, p_field_id, NULL,
      'DENIED', 'CONTROLLER_MISMATCH', p_client_ip, p_user_agent);

    SELECT * FROM access_event WHERE access_id = LAST_INSERT_ID();
  ELSE
    /* 2) expire old consents */
    CALL sp_expire_consents();

    /* 3) find valid consent */
    SELECT cg.consent_id INTO v_consent_id
    FROM consent_grant cg
    WHERE cg.subject_id = p_subject_id
      AND cg.controller_id = p_controller_id
      AND cg.purpose_id = p_purpose_id
      AND cg.status='ACTIVE'
      AND NOW() BETWEEN cg.valid_from AND cg.valid_until
    ORDER BY cg.valid_until DESC
    LIMIT 1;

    IF v_consent_id IS NULL THEN
      INSERT INTO access_event(processor_id, subject_id, controller_id, purpose_id, field_id, consent_id,
        decision, deny_reason, client_ip, user_agent)
      VALUES (p_processor_id, p_subject_id, p_controller_id, p_purpose_id, p_field_id, NULL,
        'DENIED', 'NO_ACTIVE_CONSENT', p_client_ip, p_user_agent);

      SELECT * FROM access_event WHERE access_id = LAST_INSERT_ID();
    ELSEIF NOT EXISTS (
      SELECT 1 FROM consent_scope_field csf
      WHERE csf.consent_id = v_consent_id AND csf.field_id = p_field_id
    ) THEN
      INSERT INTO access_event(processor_id, subject_id, controller_id, purpose_id, field_id, consent_id,
        decision, deny_reason, client_ip, user_agent)
      VALUES (p_processor_id, p_subject_id, p_controller_id, p_purpose_id, p_field_id, v_consent_id,
        'DENIED', 'FIELD_NOT_IN_SCOPE', p_client_ip, p_user_agent);

      SELECT * FROM access_event WHERE access_id = LAST_INSERT_ID();
    ELSE
      INSERT INTO access_event(processor_id, subject_id, controller_id, purpose_id, field_id, consent_id,
        decision, deny_reason, client_ip, user_agent)
      VALUES (p_processor_id, p_subject_id, p_controller_id, p_purpose_id, p_field_id, v_consent_id,
        'ALLOWED', 'NONE', p_client_ip, p_user_agent);

      SELECT * FROM access_event WHERE access_id = LAST_INSERT_ID();
    END IF;
  END IF;
END$$

CREATE PROCEDURE sp_create_deletion_request(
  IN p_subject_id BIGINT,
  IN p_controller_id BIGINT,
  IN p_created_by_processor_id BIGINT,
  IN p_notes VARCHAR(255)
)
BEGIN
  INSERT INTO deletion_request(subject_id, controller_id, created_by_processor_id, notes)
  VALUES (p_subject_id, p_controller_id, p_created_by_processor_id, p_notes);

  SELECT * FROM deletion_request WHERE request_id = LAST_INSERT_ID();
END$$

CREATE PROCEDURE sp_complete_deletion_request(
  IN p_request_id BIGINT,
  IN p_notes VARCHAR(255)
)
BEGIN
  DECLARE v_subject_id BIGINT;
  DECLARE v_controller_id BIGINT;

  SELECT subject_id, controller_id INTO v_subject_id, v_controller_id
  FROM deletion_request WHERE request_id = p_request_id;

  UPDATE consent_grant
  SET status='REVOKED', version_no = version_no + 1, note = CONCAT(IFNULL(note,''), ' | deletion: ', p_notes)
  WHERE subject_id=v_subject_id AND controller_id=v_controller_id AND status='ACTIVE';

  UPDATE deletion_request
  SET status='COMPLETED', completed_at=NOW(), notes = p_notes
  WHERE request_id=p_request_id;

  SELECT * FROM deletion_request WHERE request_id = p_request_id;
END$$

DELIMITER ;

-- Seed data
INSERT INTO controller(name, domain_type) VALUES ('CampusApp', 'CAMPUS_APP');

INSERT INTO processor_user(controller_id, username, display_name, role_name)
VALUES
  (1,'it_admin','IT Admin','ADMIN'),
  (1,'fee_office','Fee Office Staff','STAFF'),
  (1,'analytics_bot','Analytics Service','SERVICE');

INSERT INTO purpose(purpose_code, description, legal_basis)
VALUES
  ('AUTH','Login/Authentication','CONTRACT'),
  ('BILLING','Fee collection & receipts','CONTRACT'),
  ('NOTIFY','Notifications (SMS/Email)','CONSENT'),
  ('ANALYTICS','Usage analytics','LEGITIMATE_INTEREST');

INSERT INTO data_field(field_code, display_name, sensitivity, is_personal)
VALUES
  ('EMAIL','Email Address','MEDIUM', TRUE),
  ('PHONE','Phone Number','HIGH', TRUE),
  ('ADDRESS','Home Address','HIGH', TRUE),
  ('DOB','Date of Birth','HIGH', TRUE),
  ('ROLLNO','Roll Number','LOW', TRUE),
  ('DEVICE_ID','Device Identifier','MEDIUM', TRUE);

INSERT INTO purpose_min_field(purpose_id, field_id)
SELECT p.purpose_id, f.field_id
FROM purpose p JOIN data_field f
WHERE p.purpose_code='AUTH' AND f.field_code IN ('EMAIL','DEVICE_ID');

INSERT INTO purpose_min_field(purpose_id, field_id)
SELECT p.purpose_id, f.field_id
FROM purpose p JOIN data_field f
WHERE p.purpose_code='BILLING' AND f.field_code IN ('EMAIL','ROLLNO');

INSERT INTO purpose_min_field(purpose_id, field_id)
SELECT p.purpose_id, f.field_id
FROM purpose p JOIN data_field f
WHERE p.purpose_code='NOTIFY' AND f.field_code IN ('EMAIL','PHONE');

INSERT INTO purpose_min_field(purpose_id, field_id)
SELECT p.purpose_id, f.field_id
FROM purpose p JOIN data_field f
WHERE p.purpose_code='ANALYTICS' AND f.field_code IN ('DEVICE_ID');

INSERT INTO retention_policy(controller_id, purpose_id, retention_days, is_active)
SELECT 1, purpose_id,
  CASE purpose_code
    WHEN 'AUTH' THEN 365
    WHEN 'BILLING' THEN 2555
    WHEN 'NOTIFY' THEN 180
    WHEN 'ANALYTICS' THEN 730
    ELSE 365
  END,
  TRUE
FROM purpose;

INSERT INTO data_subject(external_ref, full_name, dob, email, phone)
VALUES
  ('22BCS001','Prachi Garg','2004-08-11','prachi@example.com','9999911111'),
  ('22BCS002','Aman Verma','2004-02-10','aman@example.com','9999922222'),
  ('22BCS003','Neha Singh','2003-12-21','neha@example.com','9999933333');

-- Create initial consents
CALL sp_grant_consent(1, 1, (SELECT purpose_id FROM purpose WHERE purpose_code='NOTIFY'), 45, 'Opt-in notifications');
CALL sp_grant_consent(1, 1, (SELECT purpose_id FROM purpose WHERE purpose_code='BILLING'), 30, 'Fee processing consent');