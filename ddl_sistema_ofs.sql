-- ============================================================
-- SISTEMA OFS/OFS - Security Dynamics
-- PostgreSQL 16 - DDL Completo
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. TABLES
-- ============================================================

-- companies
CREATE TABLE companies (
    id          SERIAL       PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    is_custom   BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- users
CREATE TABLE users (
    id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    username            VARCHAR(100) NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,
    full_name           VARCHAR(200) NOT NULL,
    email               VARCHAR(200),
    role                VARCHAR(20)  NOT NULL CHECK (role IN ('observador','supervisor','gestor','admin')),
    company_id          INT          REFERENCES companies(id),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    login_attempts      INT          NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    last_login          TIMESTAMPTZ,
    password_expires_at TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- contracts
CREATE TABLE contracts (
    id          SERIAL       PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    description TEXT,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- targets
CREATE TABLE targets (
    id                  SERIAL       PRIMARY KEY,
    company_id          INT          NOT NULL REFERENCES companies(id),
    contract_id         INT          NOT NULL REFERENCES contracts(id),
    week_start          DATE         NOT NULL,
    active_people       INT          NOT NULL CHECK (active_people >= 0),
    weekly_target       INT          NOT NULL CHECK (weekly_target >= 1),
    active_users        INT          NOT NULL CHECK (active_users >= 0),
    meta_ofc_programada INT          NOT NULL DEFAULT 0,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (company_id, contract_id, week_start)
);

-- ofc_seq_control
CREATE TABLE ofc_seq_control (
    ano      INT NOT NULL,
    semana   INT NOT NULL CHECK (semana BETWEEN 1 AND 53),
    last_seq INT NOT NULL DEFAULT 0,
    PRIMARY KEY (ano, semana)
);

-- TABELA PRINCIPAL: ofc_records
CREATE TABLE ofc_records (
    id                        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo                    VARCHAR(17)  UNIQUE,
    data_registro             DATE         NOT NULL DEFAULT CURRENT_DATE,
    hora_registro             TIME         NOT NULL DEFAULT CURRENT_TIME,
    semana                    INT,
    mes                       INT,
    ano                       INT,
    usuario_id                UUID         NOT NULL REFERENCES users(id),
    usuario_nome_snapshot     VARCHAR(200),
    usuario_login_snapshot    VARCHAR(100),
    usuario_email_snapshot    VARCHAR(200),
    usuario_perfil_snapshot   VARCHAR(20),
    empresa_usuario_snapshot  VARCHAR(150),
    contrato_id               INT          REFERENCES contracts(id),
    empresa_observada_id      INT          REFERENCES companies(id),
    empresa_observada_outros  VARCHAR(150),
    nome_observado            VARCHAR(200) NOT NULL,
    atividade_observada       VARCHAR(200) NOT NULL,
    local_observado           VARCHAR(200),
    turno                     VARCHAR(20)  NOT NULL CHECK (turno IN ('Diurno','Noturno','Administrativo','Turno 1','Turno 2','Turno 3')),
    tipo_observacao           VARCHAR(20)  NOT NULL CHECK (tipo_observacao IN ('Positivo/Seguro','Negativo/Inseguro')),
    comportamento_observado   TEXT,
    observacao_complementar   TEXT,
    status_registro           VARCHAR(20)  NOT NULL DEFAULT 'Gerado' CHECK (status_registro IN ('Gerado','Editado','Cancelado')),
    is_deleted                BOOLEAN      NOT NULL DEFAULT FALSE,
    edit_count                INT          NOT NULL DEFAULT 0,
    criado_por                UUID         NOT NULL REFERENCES users(id),
    criado_em                 TIMESTAMPTZ  NOT NULL DEFAULT now(),
    editado_por               UUID         REFERENCES users(id),
    editado_em                TIMESTAMPTZ,
    cancelado_por             UUID         REFERENCES users(id),
    cancelado_em              TIMESTAMPTZ,
    motivo_cancelamento       TEXT,
    deleted_at                TIMESTAMPTZ,
    deleted_by                UUID         REFERENCES users(id),
    updated_at                TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ofc_edit_log
CREATE TABLE ofc_edit_log (
    id             BIGSERIAL    PRIMARY KEY,
    ofc_record_id  UUID         NOT NULL REFERENCES ofc_records(id),
    edited_by      UUID         NOT NULL REFERENCES users(id),
    field_changed  VARCHAR(100) NOT NULL,
    old_value      TEXT,
    new_value      TEXT,
    edited_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- audit_logs
CREATE TABLE audit_logs (
    id          BIGSERIAL    PRIMARY KEY,
    timestamp   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    user_id     UUID         REFERENCES users(id),
    username    VARCHAR(100),
    action      VARCHAR(100) NOT NULL,
    resource    VARCHAR(100),
    resource_id VARCHAR(100),
    details     JSONB,
    ip_address  VARCHAR(45),
    severity    VARCHAR(20)  NOT NULL DEFAULT 'INFO',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- password_history
CREATE TABLE password_history (
    id            BIGSERIAL    PRIMARY KEY,
    user_id       UUID         NOT NULL REFERENCES users(id),
    password_hash VARCHAR(255) NOT NULL,
    changed_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- revoked_tokens
CREATE TABLE revoked_tokens (
    jti         VARCHAR(255) PRIMARY KEY,
    user_id     UUID         NOT NULL REFERENCES users(id),
    expires_at  TIMESTAMPTZ,
    revoked_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- reports
CREATE TABLE reports (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    type         VARCHAR(20)  NOT NULL CHECK (type IN ('individual','semanal')),
    parameters   JSONB,
    file_path    VARCHAR(500),
    file_size    BIGINT,
    generated_by UUID         NOT NULL REFERENCES users(id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- system_params
CREATE TABLE system_params (
    id          SERIAL       PRIMARY KEY,
    chave       VARCHAR(100) NOT NULL UNIQUE,
    valor       TEXT,
    descricao   TEXT,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. INDEXES
-- ============================================================

-- ofc_records: indexes for primary query patterns
CREATE INDEX idx_ofc_data          ON ofc_records (data_registro);
CREATE INDEX idx_ofc_empresa       ON ofc_records (empresa_observada_id);
CREATE INDEX idx_ofc_tipo          ON ofc_records (tipo_observacao);
CREATE INDEX idx_ofc_status        ON ofc_records (status_registro);
CREATE INDEX idx_ofc_turno         ON ofc_records (turno);
CREATE INDEX idx_ofc_usuario       ON ofc_records (usuario_id);

-- Composite indexes for metrics
CREATE INDEX idx_ofc_empresa_data  ON ofc_records (empresa_observada_id, data_registro);
CREATE INDEX idx_ofc_usuario_data  ON ofc_records (usuario_id, data_registro);
CREATE INDEX idx_ofc_contrato_data ON ofc_records (contrato_id, data_registro);
CREATE INDEX idx_ofc_ano_semana    ON ofc_records (ano, semana);
CREATE INDEX idx_ofc_tipo_status   ON ofc_records (tipo_observacao, status_registro);
CREATE INDEX idx_ofc_empresa_semana_ano ON ofc_records (empresa_observada_id, ano, semana);

-- Partial indexes (WHERE is_deleted = FALSE)
CREATE INDEX idx_ofc_valid_empresa_data ON ofc_records (empresa_observada_id, data_registro)
    WHERE is_deleted = FALSE;
CREATE INDEX idx_ofc_valid_usuario_data ON ofc_records (usuario_id, data_registro)
    WHERE is_deleted = FALSE;
CREATE INDEX idx_ofc_valid_tipo_status  ON ofc_records (tipo_observacao, status_registro)
    WHERE is_deleted = FALSE;
CREATE INDEX idx_ofc_valid_status       ON ofc_records (status_registro)
    WHERE is_deleted = FALSE;

-- GIN index for full-text search (portuguese)
CREATE INDEX idx_ofc_fts ON ofc_records
    USING gin (to_tsvector('portuguese',
        coalesce(comportamento_observado, '')  || ' ' ||
        coalesce(observacao_complementar, '')  || ' ' ||
        coalesce(nome_observado, '')           || ' ' ||
        coalesce(atividade_observada, '')      || ' ' ||
        coalesce(local_observado, '')
    ));

-- Unique indexes (already enforced by table constraints, but explicitly created for clarity)
CREATE UNIQUE INDEX IF NOT EXISTS uq_ofc_codigo   ON ofc_records (codigo);
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username ON users (username);

-- Targets composite index
CREATE INDEX idx_targets_company_contract_week ON targets (company_id, contract_id, week_start);

-- Audit logs index for queries
CREATE INDEX idx_audit_timestamp    ON audit_logs (timestamp);
CREATE INDEX idx_audit_user_id      ON audit_logs (user_id);
CREATE INDEX idx_audit_resource     ON audit_logs (resource, resource_id);

-- ofc_edit_log index
CREATE INDEX idx_edit_log_record    ON ofc_edit_log (ofc_record_id);

-- ============================================================
-- 3. FUNCTIONS AND TRIGGERS
-- ============================================================

-- 3.1 Auto-update updated_at for all tables
CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_companies_updated_at
    BEFORE UPDATE ON companies
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_contracts_updated_at
    BEFORE UPDATE ON contracts
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_targets_updated_at
    BEFORE UPDATE ON targets
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_ofc_records_updated_at
    BEFORE UPDATE ON ofc_records
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_system_params_updated_at
    BEFORE UPDATE ON system_params
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

-- 3.2 Generate OFS code and fill semana/mes/ano
CREATE OR REPLACE FUNCTION fn_ofc_before_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_seq INT;
BEGIN
    -- Extract year, month, week from data_registro
    NEW.ano    := EXTRACT(YEAR FROM NEW.data_registro);
    NEW.mes    := EXTRACT(MONTH FROM NEW.data_registro);
    NEW.semana := EXTRACT(WEEK FROM NEW.data_registro);

    -- Generate OFS code using sequence control
    -- Lock to prevent race conditions
    PERFORM pg_advisory_xact_lock(hashtext('ofc_seq_' || NEW.ano::text || '_' || NEW.semana::text));

    SELECT last_seq
    INTO v_seq
    FROM ofc_seq_control
    WHERE ano = NEW.ano AND semana = NEW.semana
    FOR UPDATE;

    IF NOT FOUND THEN
        v_seq := 1;
        INSERT INTO ofc_seq_control (ano, semana, last_seq) VALUES (NEW.ano, NEW.semana, 1);
    ELSE
        v_seq := v_seq + 1;
        UPDATE ofc_seq_control SET last_seq = v_seq WHERE ano = NEW.ano AND semana = NEW.semana;
    END IF;

    NEW.codigo := 'OFS-' || lpad(NEW.ano::text, 4, '0')
                       || '-' || lpad(NEW.semana::text, 2, '0')
                       || '-' || lpad(v_seq::text, 4, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ofc_before_insert
    BEFORE INSERT ON ofc_records
    FOR EACH ROW
    WHEN (NEW.codigo IS NULL)
    EXECUTE FUNCTION fn_ofc_before_insert();

-- 3.3 Prevent physical DELETE on ofc_records
CREATE OR REPLACE FUNCTION fn_prevent_ofc_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Deleção física de registros OFS não é permitida. Use exclusão lógica (is_deleted = TRUE).';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_ofc_delete
    BEFORE DELETE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_ofc_delete();

-- 3.4 Calculate meta_ofc_programada automatically
CREATE OR REPLACE FUNCTION fn_targets_meta()
RETURNS TRIGGER AS $$
BEGIN
    NEW.meta_ofc_programada := NEW.active_people * NEW.weekly_target;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_targets_meta
    BEFORE INSERT OR UPDATE ON targets
    FOR EACH ROW
    EXECUTE FUNCTION fn_targets_meta();

-- ============================================================
-- 4. SEED DATA
-- ============================================================

-- 4.1 Companies (15)
INSERT INTO companies (name, is_custom, is_active) VALUES
    ('Petrobras',              FALSE, TRUE),
    ('Vale',                   FALSE, TRUE),
    ('ArcelorMittal',          FALSE, TRUE),
    ('Braskem',                FALSE, TRUE),
    ('Ultrapar',               FALSE, TRUE),
    ('Raízen',                 FALSE, TRUE),
    ('Suzano',                 FALSE, TRUE),
    ('Klabin',                 FALSE, TRUE),
    ('JBS',                    FALSE, TRUE),
    ('Marfrig',                FALSE, TRUE),
    ('Minerva Foods',          FALSE, TRUE),
    ('Ambev',                  FALSE, TRUE),
    ('Natura & Co',            FALSE, TRUE),
    ('Magazine Luiza',         FALSE, TRUE),
    ('Via Varejo',             FALSE, TRUE);

-- 4.2 Admin user (password bcrypt hash: Admin@123)
INSERT INTO users (username, password_hash, full_name, email, role, company_id, is_active)
VALUES (
    'admin',
    '$2b$12$LJ3m4ys3Lk0TSwHCpNqrIO8mXDZpJqKMGmF0MGZyPFBvfHaaVUwOe',
    'Administrador do Sistema',
    'admin@securitydynamics.com.br',
    'admin',
    NULL,
    TRUE
);

-- 4.3 System parameters
INSERT INTO system_params (chave, valor, descricao) VALUES
    ('nome_sistema',        'Sistema OFS/OFS',              'Nome do sistema exibido na interface'),
    ('tempo_sessao_minutos','480',                          'Tempo máximo de sessão inativa em minutos');

-- ============================================================
-- 5. VIEWS
-- ============================================================

-- 5.1 Valid (non-deleted, non-canceled) OFS records
CREATE OR REPLACE VIEW vw_valid_ofcs AS
SELECT *
FROM ofc_records
WHERE is_deleted = FALSE
  AND status_registro != 'Cancelado';

-- 5.2 Weekly aggregated metrics
CREATE OR REPLACE VIEW vw_weekly_metrics AS
SELECT
    empresa_observada_id,
    ano,
    semana,
    COUNT(*)                                              AS total_registros,
    COUNT(*) FILTER (WHERE tipo_observacao = 'Positivo/Seguro')   AS observacoes_positivas,
    COUNT(*) FILTER (WHERE tipo_observacao = 'Negativo/Inseguro') AS observacoes_negativas,
    COUNT(*) FILTER (WHERE status_registro = 'Gerado')            AS status_gerado,
    COUNT(*) FILTER (WHERE status_registro = 'Editado')           AS status_editado,
    COUNT(*) FILTER (WHERE status_registro = 'Cancelado')         AS status_cancelado,
    COUNT(DISTINCT usuario_id)                                    AS usuarios_ativos
FROM ofc_records
WHERE is_deleted = FALSE
GROUP BY empresa_observada_id, ano, semana
ORDER BY empresa_observada_id, ano DESC, semana DESC;

-- ============================================================
-- FIM DO DDL
-- ============================================================

-- Permissions suggestion (uncomment as needed):
-- GRANT CONNECT ON DATABASE ofc_db TO ofc_app;
-- GRANT USAGE ON SCHEMA public TO ofc_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ofc_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ofc_app;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ofc_app;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ofc_app;
