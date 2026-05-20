-- ============================================================================
-- SISTEMA OFS/OFS — AUTHENTICATION, SESSION, AUDIT & TRACEABILITY
-- Security Dynamics | PostgreSQL 16 | Python/FastAPI + SQLAlchemy 2.0 (async)
-- 100% English naming | Delivered: 2026-05-13
-- ============================================================================

-- ============================================================================
-- 1. EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";       -- gen_random_uuid(), crypt(), gen_salt()
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";       -- uuid_generate_v4() (fallback)


-- ============================================================================
-- 2. TABLES (DDL)
-- ============================================================================

-- --------------------------------------------------------------------------
-- 2.1 users — System users (authentication)
-- --------------------------------------------------------------------------
CREATE TABLE users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(100)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,
    full_name       VARCHAR(300)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    role            VARCHAR(20)     NOT NULL DEFAULT 'employee'
                                    CHECK (role IN ('admin','manager','supervisor','employee','auditor')),
    company_id      UUID,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    login_attempts  INT             NOT NULL DEFAULT 0,
    locked_until    TIMESTAMPTZ,
    last_login      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  users IS 'Authenticated system users (all roles)';
COMMENT ON COLUMN users.role IS 'admin | manager | supervisor | employee | auditor';
COMMENT ON COLUMN users.login_attempts IS 'Consecutive failed login count; resets on successful login';
COMMENT ON COLUMN users.locked_until IS 'Account locked until this timestamp (NULL = not locked)';


-- --------------------------------------------------------------------------
-- 2.2 revoked_tokens — JWT token blacklist (logout / forced invalidation)
-- --------------------------------------------------------------------------
CREATE TABLE revoked_tokens (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    jti             VARCHAR(255)    NOT NULL UNIQUE,
    user_id         UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at      TIMESTAMPTZ     NOT NULL,
    revoked_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  revoked_tokens IS 'JWT token identifiers revoked before natural expiry';
COMMENT ON COLUMN revoked_tokens.jti IS 'JWT Token ID (jti claim) — unique per token';
COMMENT ON COLUMN revoked_tokens.expires_at IS 'Original token expiry — used for cleanup pruning';


-- --------------------------------------------------------------------------
-- 2.3 password_history — Prevents reuse of last 5 passwords
-- --------------------------------------------------------------------------
CREATE TABLE password_history (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    password_hash   VARCHAR(255)    NOT NULL,
    changed_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  password_history IS 'Historical password hashes — last 5 entries per user are checked for reuse';
COMMENT ON COLUMN password_history.changed_at IS 'Timestamp when this password was set';


-- --------------------------------------------------------------------------
-- 2.4 audit_logs — Immutable system-wide audit trail
-- --------------------------------------------------------------------------
CREATE TABLE audit_logs (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    user_id         UUID            REFERENCES users(id) ON DELETE SET NULL,
    username        VARCHAR(100)    NOT NULL,
    action          VARCHAR(50)     NOT NULL,
    resource        VARCHAR(100)    NOT NULL,
    resource_id     VARCHAR(255),
    details         JSONB           DEFAULT '{}'::JSONB,
    ip_address      INET,
    severity        VARCHAR(10)     NOT NULL DEFAULT 'INFO'
                                    CHECK (severity IN ('DEBUG','INFO','WARNING','ERROR','CRITICAL')),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  audit_logs IS 'Immutable audit trail — append-only, never updated or deleted';
COMMENT ON COLUMN audit_logs.timestamp IS 'Wall-clock time of the audited action';
COMMENT ON COLUMN audit_logs.username IS 'Denormalized username — survives user deletion';
COMMENT ON COLUMN audit_logs.details IS 'Arbitrary JSON payload with action context';
COMMENT ON COLUMN audit_logs.severity IS 'DEBUG | INFO | WARNING | ERROR | CRITICAL';


-- --------------------------------------------------------------------------
-- 2.5 ofc_edit_log — Per-field change tracking for OFS records
-- --------------------------------------------------------------------------
CREATE TABLE ofc_edit_log (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    ofc_record_id   UUID            NOT NULL,
    edited_by       UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    field_changed   VARCHAR(100)    NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    edited_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  ofc_edit_log IS 'Field-level change history for OFS records — traceability';
COMMENT ON COLUMN ofc_edit_log.ofc_record_id IS 'References ofc_records.id (no FK — survives record deletion)';
COMMENT ON COLUMN ofc_edit_log.old_value IS 'NULL when field was previously empty (first assignment)';
COMMENT ON COLUMN ofc_edit_log.new_value IS 'NULL when field was cleared';

-- Prevent self-referencing FK deadlock on ofc_record_id
-- ofc_edit_log.ofc_record_id intentionally has NO FK constraint to allow
-- audit trail survival after OFS record deletion (ON DELETE RESTRICT would
-- block deletions; ON DELETE CASCADE would lose audit history).


-- ============================================================================
-- 3. INDEXES (Performance)
-- ============================================================================

-- --------------------------------------------------------------------------
-- 3.1 users
-- --------------------------------------------------------------------------
-- Login: lookup by username
-- (UNIQUE constraint already creates a B-tree index on username)
-- But we also need: WHERE is_active = TRUE for filtering locked accounts
CREATE INDEX idx_users_email            ON users (email)
    WHERE is_active = TRUE;
CREATE INDEX idx_users_company_id       ON users (company_id);
CREATE INDEX idx_users_role             ON users (role);
CREATE INDEX idx_users_locked_until     ON users (locked_until)
    WHERE locked_until IS NOT NULL AND locked_until > NOW();
CREATE INDEX idx_users_active           ON users (id, is_active)
    WHERE is_active = TRUE;

-- --------------------------------------------------------------------------
-- 3.2 revoked_tokens
-- --------------------------------------------------------------------------
-- jti UNIQUE already provides an index for O(1) token validation
CREATE INDEX idx_revoked_tokens_user_id    ON revoked_tokens (user_id);
CREATE INDEX idx_revoked_tokens_expires    ON revoked_tokens (expires_at)
    WHERE expires_at < NOW();  -- partial index: only expired tokens (cleanup target)

-- --------------------------------------------------------------------------
-- 3.3 password_history
-- --------------------------------------------------------------------------
-- Password reuse check: last 5 entries per user, ordered by most recent first
CREATE INDEX idx_password_history_user_time ON password_history (user_id, changed_at DESC);

-- --------------------------------------------------------------------------
-- 3.4 audit_logs
-- --------------------------------------------------------------------------
CREATE INDEX idx_audit_logs_timestamp       ON audit_logs (timestamp DESC);
CREATE INDEX idx_audit_logs_user_id         ON audit_logs (user_id);
CREATE INDEX idx_audit_logs_action          ON audit_logs (action);
CREATE INDEX idx_audit_logs_resource        ON audit_logs (resource, resource_id);
CREATE INDEX idx_audit_logs_severity        ON audit_logs (severity);
CREATE INDEX idx_audit_logs_user_action     ON audit_logs (user_id, action, timestamp DESC);

-- GIN index for JSONB details queries (e.g., details->>'field' = 'value')
CREATE INDEX idx_audit_logs_details_gin     ON audit_logs USING GIN (details jsonb_path_ops);

-- --------------------------------------------------------------------------
-- 3.5 ofc_edit_log
-- --------------------------------------------------------------------------
CREATE INDEX idx_ofc_edit_log_record        ON ofc_edit_log (ofc_record_id, edited_at DESC);
CREATE INDEX idx_ofc_edit_log_editor        ON ofc_edit_log (edited_by, edited_at DESC);
CREATE INDEX idx_ofc_edit_log_field         ON ofc_edit_log (field_changed);


-- ============================================================================
-- 4. FUNCTIONS
-- ============================================================================

-- --------------------------------------------------------------------------
-- 4.1 Auto-update updated_at column
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- --------------------------------------------------------------------------
-- 4.2 Cleanup expired revoked tokens — returns count of deleted rows
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cleanup_expired_tokens()
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
AS $$
    WITH deleted AS (
        DELETE FROM revoked_tokens
        WHERE expires_at < NOW()
        RETURNING id
    )
    SELECT COUNT(*)::INT FROM deleted;
$$;

COMMENT ON FUNCTION cleanup_expired_tokens() IS
'Deletes all revoked_tokens past their original expiry. Schedule via pg_cron or OS cron: SELECT cleanup_expired_tokens();';

-- --------------------------------------------------------------------------
-- 4.3 Check password history — prevents reuse of last 5 passwords
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_password_history(
    p_user_id           UUID,
    p_new_password_hash VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_match_count INT;
BEGIN
    SELECT COUNT(*) INTO v_match_count
    FROM (
        SELECT password_hash
        FROM password_history
        WHERE user_id = p_user_id
        ORDER BY changed_at DESC
        LIMIT 5
    ) recent
    WHERE recent.password_hash = p_new_password_hash;

    IF v_match_count > 0 THEN
        RAISE EXCEPTION 'Password reuse detected: this password was used within the last 5 changes.';
    END IF;

    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION check_password_history(UUID, VARCHAR) IS
'Validates that p_new_password_hash is NOT among the last 5 passwords for p_user_id. Raises exception on reuse.';

-- --------------------------------------------------------------------------
-- 4.4 Check password expiration — 90-day policy
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_password_expired(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_last_change TIMESTAMPTZ;
BEGIN
    SELECT changed_at INTO v_last_change
    FROM password_history
    WHERE user_id = p_user_id
    ORDER BY changed_at DESC
    LIMIT 1;

    IF v_last_change IS NULL THEN
        RETURN TRUE;  -- no history = treat as expired (must set initial password)
    END IF;

    RETURN (v_last_change + INTERVAL '90 days') < NOW();
END;
$$;

COMMENT ON FUNCTION is_password_expired(UUID) IS
'Returns TRUE if the latest password change for p_user_id is older than 90 days.';

-- --------------------------------------------------------------------------
-- 4.5 Record password change — inserts history + enforces reuse policy
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION record_password_change(
    p_user_id           UUID,
    p_new_password_hash VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check reuse policy (raises exception if violated)
    PERFORM check_password_history(p_user_id, p_new_password_hash);

    -- Insert new password into history
    INSERT INTO password_history (user_id, password_hash, changed_at)
    VALUES (p_user_id, p_new_password_hash, NOW());

    -- Update user's current password and reset lock counters
    UPDATE users
    SET password_hash  = p_new_password_hash,
        login_attempts = 0,
        locked_until   = NULL,
        updated_at     = NOW()
    WHERE id = p_user_id;

    -- Prune history: keep only last 5 entries per user
    DELETE FROM password_history
    WHERE user_id = p_user_id
      AND id NOT IN (
          SELECT id
          FROM password_history
          WHERE user_id = p_user_id
          ORDER BY changed_at DESC
          LIMIT 5
      );
END;
$$;

COMMENT ON FUNCTION record_password_change(UUID, VARCHAR) IS
'Atomically: checks reuse policy, inserts history, updates user password, prunes old history to last 5 entries.';


-- ============================================================================
-- 5. TRIGGERS
-- ============================================================================

-- --------------------------------------------------------------------------
-- 5.1 users.updated_at — auto-set on every UPDATE
-- --------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_users_updated_at'
    ) THEN
        CREATE TRIGGER trg_users_updated_at
            BEFORE UPDATE ON users
            FOR EACH ROW
            EXECUTE FUNCTION trigger_set_updated_at();
    END IF;
END;
$$;

-- --------------------------------------------------------------------------
-- 5.2 Auto-cleanup expired tokens on INSERT to revoked_tokens
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_cleanup_expired_tokens()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Opportunistic cleanup: remove any tokens past their expiry
    -- (New revocation triggers a quick sweep of expired entries)
    DELETE FROM revoked_tokens WHERE expires_at < NOW();
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_revoked_tokens_cleanup'
    ) THEN
        CREATE TRIGGER trg_revoked_tokens_cleanup
            AFTER INSERT ON revoked_tokens
            FOR EACH STATEMENT
            EXECUTE FUNCTION trigger_cleanup_expired_tokens();
    END IF;
END;
$$;


-- ============================================================================
-- 6. SEED DATA — Initial admin user
-- ============================================================================

-- Admin credentials: username='admin', password='Admin@123'
-- Password hash generated via pgcrypto bcrypt (cost 12, Blowfish)
INSERT INTO users (username, password_hash, full_name, email, role, is_active, login_attempts)
VALUES (
    'admin',
    crypt('Admin@123', gen_salt('bf', 12)),
    'System Administrator',
    'admin@ofs.local',
    'admin',
    TRUE,
    0
)
ON CONFLICT (username) DO NOTHING;

-- Record the initial password in history so it can't be reused
INSERT INTO password_history (user_id, password_hash, changed_at)
SELECT id, password_hash, NOW()
FROM users
WHERE username = 'admin'
  AND NOT EXISTS (
      SELECT 1 FROM password_history ph
      WHERE ph.user_id = users.id
        AND ph.password_hash = users.password_hash
  );


-- ============================================================================
-- 7. PASSWORD POLICY — Usage Examples
-- ============================================================================

-- 7.1 How to verify password history on password change
--
-- Call from application layer (FastAPI) BEFORE updating the password:
--
--   SELECT check_password_history(
--       'd1000000-0000-0000-0000-000000000001',  -- user UUID
--       '$2b$12$...'                              -- new bcrypt hash
--   );
--
--   -- Returns TRUE if passable, raises EXCEPTION if reused.
--
-- Recommended: use record_password_change() which bundles all steps:
--
--   SELECT record_password_change(
--       'd1000000-0000-0000-0000-000000000001',
--       crypt('new_password', gen_salt('bf', 12))
--   );

-- 7.2 How to verify password expiration (90 days)
--
-- Call at login time or via scheduled check:
--
--   SELECT is_password_expired(
--       'd1000000-0000-0000-0000-000000000001'
--   );
--
--   -- TRUE  → force user to change password before granting access
--   -- FALSE → password is still within the 90-day window
--
-- Application-side enforcement example:
--
--   if is_password_expired(user_id):
--       return 403, {"error": "password_expired", "action": "change_password"}
--
-- For bulk notification (users whose password expires within 7 days):
--
--   SELECT u.id, u.username, u.email, ph.changed_at
--   FROM users u
--   JOIN LATERAL (
--       SELECT changed_at FROM password_history
--       WHERE user_id = u.id
--       ORDER BY changed_at DESC
--       LIMIT 1
--   ) ph ON TRUE
--   WHERE u.is_active = TRUE
--     AND ph.changed_at + INTERVAL '90 days' BETWEEN NOW() AND NOW() + INTERVAL '7 days';


-- ============================================================================
-- 8. BACKUP STRATEGY
-- ============================================================================

-- 8.1 Selective backup of these tables (pg_dump)
--
-- Full dump (custom format, compressed):
--   pg_dump -h <host> -U <user> -d ofs_db \
--       --format=custom \
--       --compress=9 \
--       --table=users \
--       --table=revoked_tokens \
--       --table=password_history \
--       --table=audit_logs \
--       --table=ofc_edit_log \
--       --file=auth_tables_$(date +%Y%m%d).dump
--
-- Schema-only backup (structure + functions):
--   pg_dump -h <host> -U <user> -d ofs_db \
--       --schema-only \
--       --table=users \
--       --table=revoked_tokens \
--       --table=password_history \
--       --table=audit_logs \
--       --table=ofc_edit_log \
--       --file=auth_schema_$(date +%Y%m%d).sql
--
-- Plain SQL backup (for disaster recovery):
--   pg_dump -h <host> -U <user> -d ofs_db \
--       --format=plain \
--       --inserts \
--       --table=users \
--       --table=revoked_tokens \
--       --table=password_history \
--       --table=audit_logs \
--       --table=ofc_edit_log \
--       --file=auth_data_$(date +%Y%m%d).sql

-- 8.2 WAL Archiving (for Point-in-Time Recovery)
--
-- Add to postgresql.conf:
--   wal_level = replica             (or 'logical' if using replication slots)
--   archive_mode = on
--   archive_command = 'cp %p /backup/wal/%f'
--   archive_timeout = 300           (5 min max delay before forcing WAL segment)
--   wal_keep_size = 1024            (keep 1 GB of WAL for standby)

-- 8.3 Backup Schedule Recommendation
--
--   Frequency   | Type                | Retention
--   ----------- | ------------------- | -----------
--   Hourly      | WAL archive         | 7 days
--   Daily       | Full pg_dump (Fc)   | 30 days
--   Weekly      | Full pg_dump (Fc)   | 12 weeks
--   Monthly     | Full pg_dump (Fc)   | 12 months
--   On demand   | Pre-deploy snapshot | Until next deploy

-- 8.4 Restore Procedure
--
--   # Stop application
--   # Restore from custom dump:
--   pg_restore -h <host> -U <user> -d ofs_db \
--       --clean --if-exists --no-owner --no-acl \
--       --verbose auth_tables_YYYYMMDD.dump
--
--   # Or restore plain SQL:
--   psql -h <host> -U <user> -d ofs_db -f auth_data_YYYYMMDD.sql
--
--   # For PITR: recover WAL to specific timestamp
--   # (requires full base backup + WAL segments)


-- ============================================================================
-- 9. SECURITY — Roles, Permissions & pg_hba.conf
-- ============================================================================

-- --------------------------------------------------------------------------
-- 9.1 Database Roles
-- --------------------------------------------------------------------------

-- ofs_admin_role: schema owner, DDL + DML (used by Alembic migrations)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ofs_admin_role') THEN
        CREATE ROLE ofs_admin_role WITH LOGIN PASSWORD 'CHANGE_ME_ADMIN_PASSWORD'
            INHERIT CONNECTION LIMIT 5;
    END IF;
END;
$$;

-- ofs_app_role: application runtime, DML only (used by FastAPI)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ofs_app_role') THEN
        CREATE ROLE ofs_app_role WITH LOGIN PASSWORD 'CHANGE_ME_APP_PASSWORD'
            INHERIT CONNECTION LIMIT 50;
    END IF;
END;
$$;

-- ofs_auditor_role: read-only on audit/log tables (used by compliance/reports)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ofs_auditor_role') THEN
        CREATE ROLE ofs_auditor_role WITH LOGIN PASSWORD 'CHANGE_ME_AUDITOR_PASSWORD'
            INHERIT CONNECTION LIMIT 5;
    END IF;
END;
$$;

-- --------------------------------------------------------------------------
-- 9.2 Schema Permissions
-- --------------------------------------------------------------------------

-- Schema-level
GRANT USAGE ON SCHEMA public TO ofs_admin_role, ofs_app_role, ofs_auditor_role;

-- ofs_admin_role: full ownership
ALTER SCHEMA public OWNER TO ofs_admin_role;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO ofs_admin_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ofs_admin_role;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ofs_admin_role;

-- ofs_app_role: DML on operational tables, append-only on audit tables
GRANT SELECT, INSERT, UPDATE, DELETE ON users, revoked_tokens, password_history TO ofs_app_role;
GRANT SELECT, INSERT                  ON audit_logs, ofc_edit_log           TO ofs_app_role;
GRANT USAGE ON ALL SEQUENCES          IN SCHEMA public TO ofs_app_role;
GRANT EXECUTE ON FUNCTION check_password_history(UUID, VARCHAR)  TO ofs_app_role;
GRANT EXECUTE ON FUNCTION is_password_expired(UUID)              TO ofs_app_role;
GRANT EXECUTE ON FUNCTION record_password_change(UUID, VARCHAR)  TO ofs_app_role;
GRANT EXECUTE ON FUNCTION cleanup_expired_tokens()               TO ofs_app_role;

-- ofs_auditor_role: read-only on everything
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ofs_auditor_role;

-- Future objects inherit these defaults
ALTER DEFAULT PRIVILEGES FOR ROLE ofs_admin_role IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES    TO ofs_app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE ofs_admin_role IN SCHEMA public
    GRANT SELECT                           ON TABLES    TO ofs_auditor_role;
ALTER DEFAULT PRIVILEGES FOR ROLE ofs_admin_role IN SCHEMA public
    GRANT USAGE                            ON SEQUENCES  TO ofs_app_role;
ALTER DEFAULT PRIVILEGES FOR ROLE ofs_admin_role IN SCHEMA public
    GRANT EXECUTE                          ON FUNCTIONS  TO ofs_app_role;


-- --------------------------------------------------------------------------
-- 9.3 pg_hba.conf — Recommended Configuration
-- --------------------------------------------------------------------------

-- Add the following entries to your PostgreSQL pg_hba.conf file
-- (located at: PGDATA/pg_hba.conf — find with: SHOW hba_file;)
--
-- # =====================================================================
-- # SISTEMA OFS/OFS — Client Authentication
-- # =====================================================================
--
-- # TYPE  DATABASE  USER               ADDRESS          METHOD
-- # ----  --------  -----------------  ---------------  ---------------
--
-- # Local connections (Unix socket / Windows named pipe)
-- local   ofs_db    ofs_admin_role                      scram-sha-256
-- local   ofs_db    ofs_app_role                        scram-sha-256
-- local   ofs_db    ofs_auditor_role                    scram-sha-256
-- local   all       postgres                            peer
--
-- # IPv4 — Application server (FastAPI)
-- hostssl ofs_db   ofs_app_role       10.0.0.0/8        scram-sha-256
-- hostssl ofs_db   ofs_app_role       172.16.0.0/12     scram-sha-256
-- hostssl ofs_db   ofs_app_role       192.168.0.0/16    scram-sha-256
--
-- # IPv4 — Admin / DBA subnet (migrations, maintenance)
-- hostssl ofs_db   ofs_admin_role     10.10.0.0/24      scram-sha-256
--
-- # IPv4 — Auditor workstation (compliance, reports)
-- hostssl ofs_db   ofs_auditor_role   10.10.1.0/24      scram-sha-256
--
-- # IPv4 — Replication (standby server)
-- hostssl replication  replicator     10.10.0.10/32     scram-sha-256
--
-- # Deny all other connections
-- host    all      all                0.0.0.0/0         reject

-- After editing pg_hba.conf, reload without restart:
--   SELECT pg_reload_conf();


-- --------------------------------------------------------------------------
-- 9.4 postgresql.conf — Security Hardening
-- --------------------------------------------------------------------------

-- Recommended security-related settings:
--
--   # Authentication
--   password_encryption = scram-sha-256
--   listen_addresses = 'localhost,10.0.0.0'  -- only internal interfaces
--
--   # SSL
--   ssl = on
--   ssl_cert_file = '/etc/pgsql/ssl/server.crt'
--   ssl_key_file  = '/etc/pgsql/ssl/server.key'
--   ssl_ca_file   = '/etc/pgsql/ssl/ca.crt'
--   ssl_min_protocol_version = 'TLSv1.2'
--
--   # Connection limits
--   max_connections = 200
--   superuser_reserved_connections = 5
--
--   # Resource limits (prevent abuse)
--   statement_timeout = 30000           -- 30s max per query
--   idle_in_transaction_session_timeout = 60000  -- 60s max idle in transaction
--   log_connections = on
--   log_disconnections = on
--   log_line_prefix = '%t [%p] %u@%d %r '
--   log_statement = 'ddl'               -- log all DDL changes
--
--   # Audit via log (complement to audit_logs table)
--   log_statement_stats = off
--   log_duration = on
--   log_min_duration_statement = 1000   -- log queries > 1s


-- --------------------------------------------------------------------------
-- 9.5 Row-Level Security (RLS) — Optional Multi-Tenant Isolation
-- --------------------------------------------------------------------------

-- Enable RLS for multi-tenant data isolation (if company_id is enforced):
--
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
--
-- CREATE POLICY users_company_isolation ON users
--     FOR ALL
--     TO ofs_app_role
--     USING (company_id = current_setting('app.current_company_id')::UUID);
--
-- The application sets the context before each request:
--   SELECT set_config('app.current_company_id', $1::TEXT, FALSE);


-- ============================================================================
-- 10. SCHEDULED MAINTENANCE (pg_cron)
-- ============================================================================

-- If pg_cron extension is available, schedule periodic cleanup:
--
--   CREATE EXTENSION IF NOT EXISTS pg_cron;
--
--   -- Hourly: clean expired revoked tokens
--   SELECT cron.schedule(
--       'cleanup-expired-tokens',
--       '0 * * * *',
--       'SELECT cleanup_expired_tokens();'
--   );
--
--   -- Daily at 03:00: prune old audit logs (> 2 years, archive first)
--   SELECT cron.schedule(
--       'prune-audit-logs',
--       '0 3 * * *',
--       $$DELETE FROM audit_logs WHERE timestamp < NOW() - INTERVAL '2 years'$$
--   );
--
--   -- Weekly: notify users with expiring passwords
--   SELECT cron.schedule(
--       'notify-password-expiry',
--       '0 9 * * 1',
--       $$SELECT u.email, u.full_name
--         FROM users u
--         WHERE u.is_active = TRUE AND is_password_expired(u.id)$$
--   );


-- ============================================================================
-- 11. VALIDATION QUERIES (Run after deployment to verify schema)
-- ============================================================================

-- Check all tables exist:
--   SELECT table_name FROM information_schema.tables
--   WHERE table_schema = 'public'
--     AND table_name IN ('users','revoked_tokens','password_history','audit_logs','ofc_edit_log')
--   ORDER BY table_name;

-- Check all triggers:
--   SELECT tgname, tgrelid::regclass FROM pg_trigger
--   WHERE tgname IN ('trg_users_updated_at','trg_revoked_tokens_cleanup')
--   ORDER BY tgname;

-- Check all indexes:
--   SELECT indexname, tablename FROM pg_indexes
--   WHERE schemaname = 'public'
--     AND tablename IN ('users','revoked_tokens','password_history','audit_logs','ofc_edit_log')
--   ORDER BY tablename, indexname;

-- Check admin user exists:
--   SELECT id, username, email, role, is_active FROM users WHERE username = 'admin';

-- Check functions are callable:
--   SELECT proname FROM pg_proc
--   WHERE proname IN ('check_password_history','is_password_expired',
--                     'record_password_change','cleanup_expired_tokens')
--   ORDER BY proname;
