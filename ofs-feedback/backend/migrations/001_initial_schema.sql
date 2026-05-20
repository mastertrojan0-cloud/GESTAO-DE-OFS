-- ============================================================================
-- MIGRATION 001: INITIAL SCHEMA — SISTEMA OFS/OFS
-- PostgreSQL 16 | Alembic (downgrade: DROP ALL TABLES)
-- Security Dynamics | 2026-05-13
-- ============================================================================

-- ============================================================================
-- 1. EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- 2. TABELAS DE DOMÍNIO
-- ============================================================================

-- 2.1 empresas — Empresas/organizações (multi-tenant)
CREATE TABLE empresas (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome            VARCHAR(200)    NOT NULL,
    cnpj            VARCHAR(18)     UNIQUE,
    is_custom       BOOLEAN         NOT NULL DEFAULT FALSE,
    ativo           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE empresas IS 'Empresas/organizações participantes do sistema';
COMMENT ON COLUMN empresas.is_custom IS 'TRUE = empresa genérica "Outros" para observados não cadastrados';

-- 2.2 contratos — Contratos vigentes
CREATE TABLE contratos (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    empresa_id      UUID            REFERENCES empresas(id) ON DELETE RESTRICT,
    nome            VARCHAR(300)    NOT NULL,
    descricao       TEXT,
    ativo           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE contratos IS 'Contratos associados aos registros OFS/OFS';

-- 2.3 usuarios — Usuários autenticados
CREATE TABLE usuarios (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    username            VARCHAR(100)    NOT NULL UNIQUE,
    password_hash       VARCHAR(255)    NOT NULL,
    nome                VARCHAR(200)    NOT NULL,
    email               VARCHAR(255)    NOT NULL,
    perfil              VARCHAR(20)     NOT NULL DEFAULT 'observador'
                                        CHECK (perfil IN ('observador','supervisor','gestor','admin')),
    empresa_id          UUID            NOT NULL REFERENCES empresas(id) ON DELETE RESTRICT,
    empresa_nome        VARCHAR(200),
    ativo               BOOLEAN         NOT NULL DEFAULT TRUE,
    password_changed_at TIMESTAMPTZ,
    login_attempts      INT             NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    last_login          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE usuarios IS 'Usuários autenticados do sistema (todos os perfis)';
COMMENT ON COLUMN usuarios.perfil IS 'admin | gestor | supervisor | observador';

-- 2.4 system_params — Parâmetros de configuração do sistema
CREATE TABLE system_params (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    chave           VARCHAR(100)    NOT NULL UNIQUE,
    valor           TEXT            NOT NULL,
    descricao       TEXT,
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE system_params IS 'Parâmetros de configuração do sistema (chave-valor)';

-- 2.5 metas — Metas semanais de OFS por empresa
CREATE TABLE metas (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    empresa_id      UUID            NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
    contrato_id     UUID            REFERENCES contratos(id) ON DELETE SET NULL,
    pessoas_ativas  INT             NOT NULL DEFAULT 0,
    meta_diaria     INT             NOT NULL DEFAULT 0,
    meta_semanal    INT             NOT NULL DEFAULT 0,
    usuarios_ativos INT             NOT NULL DEFAULT 0,
    vigencia_inicio DATE            NOT NULL,
    vigencia_fim    DATE,
    ativo           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE metas IS 'Metas de OFS por empresa/contrato/vigência';
COMMENT ON COLUMN metas.pessoas_ativas IS 'Número de pessoas ativas no escopo (colaboradores observáveis)';
COMMENT ON COLUMN metas.meta_semanal IS 'Meta de OFSS por semana';
COMMENT ON COLUMN metas.usuarios_ativos IS 'Número de observadores/usuários ativos no contrato';

-- ============================================================================
-- 3. TABELA PRINCIPAL: OFSS — Registros OFS
-- ============================================================================
CREATE TABLE OFSS (
    id                          UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    data                        VARCHAR(10)     NOT NULL,
    hora                        VARCHAR(5)      NOT NULL,
    usuario_gerador_id          UUID            NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    usuario_gerador_nome        VARCHAR(200),
    usuario_gerador_email       VARCHAR(255),
    usuario_gerador_perfil      VARCHAR(20),
    usuario_gerador_empresa_nome VARCHAR(200),
    codigo                      VARCHAR(50),
    nome_observado              VARCHAR(200)    NOT NULL,
    atividade                   VARCHAR(500)    NOT NULL,
    local                       VARCHAR(200)    NOT NULL,
    empresa_id                  UUID            NOT NULL REFERENCES empresas(id) ON DELETE RESTRICT,
    empresa_nome                VARCHAR(200),
    contrato_id                 UUID            REFERENCES contratos(id) ON DELETE SET NULL,
    contrato_nome               VARCHAR(200),
    turno                       VARCHAR(10)     NOT NULL,
    tipo                        VARCHAR(3)      NOT NULL CHECK (tipo IN ('OFS','OFS')),
    comportamento               TEXT            NOT NULL,
    observacao                  TEXT            DEFAULT '',
    status                      VARCHAR(20)     DEFAULT 'ativo',
    is_deleted                  BOOLEAN         DEFAULT FALSE,
    motivo_cancelamento         TEXT,
    cancelado_por               UUID            REFERENCES usuarios(id) ON DELETE SET NULL,
    cancelado_em                TIMESTAMPTZ,
    restaurado_por              UUID            REFERENCES usuarios(id) ON DELETE SET NULL,
    restaurado_em               TIMESTAMPTZ,
    editado_por                 UUID            REFERENCES usuarios(id) ON DELETE SET NULL,
    editado_em                  TIMESTAMPTZ,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE OFSS IS 'Registros de Observação de Fato Comportamental/Segurança (OFS/OFS)';
COMMENT ON COLUMN OFSS.tipo IS 'OFS = Feedback Comportamental (positivo) | OFS = Feedback de Segurança (negativo/desvio)';

-- ============================================================================
-- 4. TABELAS DE SEGURANÇA E AUDITORIA
-- ============================================================================

-- 4.1 password_history — Histórico de senhas (anti-reuso)
CREATE TABLE password_history (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID            NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    password_hash   VARCHAR(255)    NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE password_history IS 'Histórico das últimas 5 senhas por usuário (anti-reuso)';

-- 4.2 refresh_tokens — Gerenciamento de sessão JWT
CREATE TABLE refresh_tokens (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID            NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token_hash      VARCHAR(255)    NOT NULL UNIQUE,
    expires_at      TIMESTAMPTZ     NOT NULL,
    revoked         BOOLEAN         NOT NULL DEFAULT FALSE,
    revoked_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE refresh_tokens IS 'Refresh tokens JWT — gerenciamento de sessão';

-- 4.3 revoked_tokens — Blacklist de tokens JWT
CREATE TABLE revoked_tokens (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    jti             VARCHAR(255)    NOT NULL UNIQUE,
    expires_at      TIMESTAMPTZ     NOT NULL,
    revoked_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE revoked_tokens IS 'Tokens JWT revogados (blacklist)';

-- 4.4 login_attempts — Tentativas de login (bloqueio por falhas)
CREATE TABLE login_attempts (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        VARCHAR(100)    NOT NULL,
    success         BOOLEAN         NOT NULL,
    ip_address      INET,
    user_agent      TEXT,
    failure_reason  VARCHAR(100),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE login_attempts IS 'Registro de tentativas de login — bloqueio após N falhas';

-- 4.5 audit_logs — Log de auditoria imutável
CREATE TABLE audit_logs (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    usuario_id      UUID            REFERENCES usuarios(id) ON DELETE SET NULL,
    username        VARCHAR(100),
    full_name       VARCHAR(200),
    role            VARCHAR(20),
    action          VARCHAR(50)     NOT NULL,
    resource        VARCHAR(50)     NOT NULL,
    resource_id     UUID,
    details         JSONB           DEFAULT '{}',
    ip_address      INET,
    user_agent      TEXT,
    severity        VARCHAR(10)     NOT NULL DEFAULT 'INFO'
                                    CHECK (severity IN ('DEBUG','INFO','WARNING','ERROR','CRITICAL'))
);
COMMENT ON TABLE audit_logs IS 'Log de auditoria imutável — append-only';

-- 4.6 ofc_edit_log — Histórico de edições nos registros OFS
CREATE TABLE ofc_edit_log (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    ofc_id          UUID            NOT NULL REFERENCES OFSS(id) ON DELETE CASCADE,
    campo           VARCHAR(100)    NOT NULL,
    valor_anterior  TEXT,
    valor_novo      TEXT,
    editado_por     UUID            NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    editado_em      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE ofc_edit_log IS 'Histórico campo-a-campo das edições em registros OFS';

-- 4.7 backups — Registro de backups realizados
CREATE TABLE backups (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    arquivo         VARCHAR(500)    NOT NULL,
    tamanho_bytes   BIGINT,
    tipo            VARCHAR(20)     NOT NULL CHECK (tipo IN ('automatico', 'manual')),
    status          VARCHAR(20)     NOT NULL DEFAULT 'sucesso'
                                    CHECK (status IN ('sucesso', 'falha', 'restaurado')),
    erro            TEXT,
    criado_por      UUID            REFERENCES usuarios(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE backups IS 'Registro de backups automáticos e manuais';

-- 4.8 app_state — Estado da aplicação (chave-valor)
CREATE TABLE app_state (
    key             VARCHAR(100)    PRIMARY KEY,
    value           TEXT,
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE app_state IS 'Estado global da aplicação (modo manutenção, versão, etc.)';

-- ============================================================================
-- 5. ÍNDICES
-- ============================================================================

-- empresas
CREATE INDEX idx_empresas_nome ON empresas (nome);
CREATE INDEX idx_empresas_ativo ON empresas (ativo) WHERE ativo = TRUE;

-- contratos
CREATE INDEX idx_contratos_empresa ON contratos (empresa_id);

-- usuarios
CREATE INDEX idx_usuarios_email    ON usuarios (email) WHERE ativo = TRUE;
CREATE INDEX idx_usuarios_empresa  ON usuarios (empresa_id);
CREATE INDEX idx_usuarios_perfil   ON usuarios (perfil);
CREATE INDEX idx_usuarios_locked   ON usuarios (locked_until) WHERE locked_until IS NOT NULL AND locked_until > NOW();
CREATE INDEX idx_usuarios_ativo    ON usuarios (id, ativo) WHERE ativo = TRUE;

-- OFSS (principais consultas)
CREATE INDEX idx_OFSS_data           ON OFSS (data DESC);
CREATE INDEX idx_OFSS_empresa_data   ON OFSS (empresa_id, data DESC);
CREATE INDEX idx_OFSS_gerador        ON OFSS (usuario_gerador_id, data DESC);
CREATE INDEX idx_OFSS_tipo           ON OFSS (tipo, data DESC);
CREATE INDEX idx_OFSS_status         ON OFSS (status) WHERE is_deleted = FALSE;
CREATE INDEX idx_OFSS_codigo         ON OFSS (codigo) WHERE codigo IS NOT NULL;
CREATE INDEX idx_OFSS_contrato_data  ON OFSS (contrato_id, data DESC) WHERE contrato_id IS NOT NULL;
CREATE INDEX idx_OFSS_not_deleted    ON OFSS (data, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_OFSS_turno          ON OFSS (turno) WHERE turno IS NOT NULL;
CREATE INDEX idx_OFSS_nome_obs_trgm  ON OFSS USING GIN (nome_observado gin_trgm_ops);
CREATE INDEX idx_OFSS_fts            ON OFSS USING GIN (
    to_tsvector('simple', coalesce(nome_observado,'') || ' ' || coalesce(comportamento,'') || ' ' || coalesce(observacao,''))
);

-- password_history
CREATE INDEX idx_password_history_user_time ON password_history (user_id, created_at DESC);

-- refresh_tokens
CREATE INDEX idx_refresh_tokens_user  ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_hash  ON refresh_tokens (token_hash);
CREATE INDEX idx_refresh_tokens_exp   ON refresh_tokens (expires_at) WHERE revoked = FALSE;

-- revoked_tokens
CREATE INDEX idx_revoked_tokens_exp   ON revoked_tokens (expires_at);

-- login_attempts
CREATE INDEX idx_login_attempts_user  ON login_attempts (username, created_at DESC);
CREATE INDEX idx_login_attempts_ip    ON login_attempts (ip_address, created_at DESC);

-- audit_logs
CREATE INDEX idx_audit_timestamp   ON audit_logs (created_at DESC);
CREATE INDEX idx_audit_user        ON audit_logs (usuario_id);
CREATE INDEX idx_audit_action      ON audit_logs (action);
CREATE INDEX idx_audit_resource    ON audit_logs (resource);
CREATE INDEX idx_audit_severity    ON audit_logs (severity);
CREATE INDEX idx_audit_user_action ON audit_logs (usuario_id, action);
CREATE INDEX idx_audit_details_gin ON audit_logs USING GIN (details jsonb_path_ops);

-- ofc_edit_log
CREATE INDEX idx_ofc_edit_log_ofc_id  ON ofc_edit_log (ofc_id);
CREATE INDEX idx_ofc_edit_log_data    ON ofc_edit_log (editado_em DESC);

-- backups
CREATE INDEX idx_backups_created ON backups (created_at DESC);

-- metas
CREATE INDEX idx_metas_empresa    ON metas (empresa_id, vigencia_inicio DESC);
CREATE INDEX idx_metas_ativo      ON metas (empresa_id, ativo) WHERE ativo = TRUE;

-- ============================================================================
-- 6. TRIGGERS
-- ============================================================================

-- 6.1 Auto-update usuarios.updated_at
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_metas_updated_at
    BEFORE UPDATE ON metas
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_OFSS_updated_at
    BEFORE UPDATE ON OFSS
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_system_params_updated_at
    BEFORE UPDATE ON system_params
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();

-- 6.2 Auto-cleanup revoked tokens on insert
CREATE OR REPLACE FUNCTION fn_cleanup_expired_tokens()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM revoked_tokens WHERE expires_at < NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_revoked_tokens_cleanup
    AFTER INSERT ON revoked_tokens
    FOR EACH STATEMENT
    EXECUTE FUNCTION fn_cleanup_expired_tokens();

-- ============================================================================
-- 7. FUNCTIONS
-- ============================================================================

-- 7.1 Limpeza programada de tokens expirados
CREATE OR REPLACE FUNCTION cleanup_expired_tokens()
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
AS $$
    WITH deleted AS (
        DELETE FROM revoked_tokens WHERE expires_at < NOW() RETURNING id
    )
    SELECT COUNT(*)::INT FROM deleted;
$$;

-- 7.2 Verificação de sanidade do banco após migration
CREATE OR REPLACE FUNCTION verify_migration_001()
RETURNS TABLE(tabela TEXT, existe BOOLEAN)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT t.table_name::TEXT, TRUE
    FROM information_schema.tables t
    WHERE t.table_schema = 'public'
      AND t.table_name IN (
          'empresas','contratos','usuarios','system_params','metas',
          'OFSS','password_history','refresh_tokens','revoked_tokens',
          'login_attempts','audit_logs','ofc_edit_log','backups','app_state'
      )
    ORDER BY t.table_name;
END;
$$;

-- ============================================================================
-- FIM DA MIGRATION 001
-- ============================================================================
