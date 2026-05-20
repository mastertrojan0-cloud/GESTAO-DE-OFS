-- ============================================================
-- Security Dynamics - OFS Feedback System
-- Tabelas de Seguranca, Auditoria e Infraestrutura
-- ============================================================

-- Extensoes
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Historico de Senhas (evitar reuso)
CREATE TABLE IF NOT EXISTS password_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    password_hash   TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_password_history_user ON password_history(user_id, created_at DESC);

-- 2. Refresh Tokens (gerenciamento de sessao)
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token_hash      TEXT NOT NULL UNIQUE,
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked         BOOLEAN NOT NULL DEFAULT FALSE,
    revoked_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_hash ON refresh_tokens(token_hash);
CREATE INDEX idx_refresh_tokens_expiry ON refresh_tokens(expires_at) WHERE revoked = FALSE;

-- 3. Tentativas de Login (bloqueio por falhas)
CREATE TABLE IF NOT EXISTS login_attempts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        VARCHAR(100) NOT NULL,
    success         BOOLEAN NOT NULL,
    ip_address      INET,
    user_agent      TEXT,
    failure_reason  VARCHAR(100),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_login_attempts_user ON login_attempts(username, created_at DESC);
CREATE INDEX idx_login_attempts_ip ON login_attempts(ip_address, created_at DESC);

-- 4. Tokens Revogados (blacklist JWT)
CREATE TABLE IF NOT EXISTS revoked_tokens (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    jti             VARCHAR(255) NOT NULL UNIQUE,
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_revoked_tokens_expiry ON revoked_tokens(expires_at);

-- 5. Auditoria
CREATE TABLE IF NOT EXISTS audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    usuario_id      UUID REFERENCES usuarios(id),
    username        VARCHAR(100),
    full_name       VARCHAR(200),
    role            VARCHAR(20),
    action          VARCHAR(50) NOT NULL,
    resource        VARCHAR(50) NOT NULL,
    resource_id     UUID,
    details         JSONB DEFAULT '{}',
    ip_address      INET,
    user_agent      TEXT,
    severity        VARCHAR(10) NOT NULL DEFAULT 'INFO'
);
CREATE INDEX idx_audit_timestamp   ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_user        ON audit_logs(usuario_id);
CREATE INDEX idx_audit_action      ON audit_logs(action);
CREATE INDEX idx_audit_resource    ON audit_logs(resource);
CREATE INDEX idx_audit_severity    ON audit_logs(severity);
CREATE INDEX idx_audit_user_action ON audit_logs(usuario_id, action);

-- 6. Historico de Edicao de OFSS
CREATE TABLE IF NOT EXISTS ofc_edit_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ofc_id          UUID NOT NULL REFERENCES OFSS(id) ON DELETE CASCADE,
    campo           VARCHAR(100) NOT NULL,
    valor_anterior  TEXT,
    valor_novo      TEXT,
    editado_por     UUID NOT NULL REFERENCES usuarios(id),
    editado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_ofc_edit_log_ofc_id ON ofc_edit_log(ofc_id);
CREATE INDEX idx_ofc_edit_log_data ON ofc_edit_log(editado_em DESC);

-- 7. Registro de Backups
CREATE TABLE IF NOT EXISTS backups (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    arquivo         VARCHAR(500) NOT NULL,
    tamanho_bytes   BIGINT,
    tipo            VARCHAR(20) NOT NULL CHECK (tipo IN ('automatico', 'manual')),
    status          VARCHAR(20) NOT NULL DEFAULT 'sucesso' CHECK (status IN ('sucesso', 'falha', 'restaurado')),
    erro            TEXT,
    criado_por      UUID REFERENCES usuarios(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_backups_created ON backups(created_at DESC);

-- 8. Modo Manutencao
CREATE TABLE IF NOT EXISTS app_state (
    key             VARCHAR(100) PRIMARY KEY,
    value           TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO app_state (key, value) VALUES ('maintenance_mode', 'false')
    ON CONFLICT (key) DO NOTHING;
