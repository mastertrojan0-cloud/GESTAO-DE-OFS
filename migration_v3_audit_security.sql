-- ============================================================================
-- MIGRATION v3 — SEGURANÇA E AUDITORIA (MÓDULO OFS)
-- Security Dynamics | PostgreSQL 16
-- Data: 13/05/2026
-- ============================================================================

-- ============================================================================
-- 1. TABELA audit_logs
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id              BIGSERIAL       PRIMARY KEY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    user_id         UUID            REFERENCES users(id) ON DELETE SET NULL,
    username        VARCHAR(300),
    action          VARCHAR(50)     NOT NULL,
    entity          VARCHAR(100)    NOT NULL,
    entity_id       VARCHAR(255),
    details         JSONB           NOT NULL DEFAULT '{}',
    ip_address      VARCHAR(45),
    user_agent      TEXT,
    severity        VARCHAR(20)     NOT NULL DEFAULT 'INFO'
                                    CHECK (severity IN ('INFO','WARN','CRITICAL')),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS 'Log de auditoria imutável — todas as ações críticas do sistema';
COMMENT ON COLUMN audit_logs.action IS 'OFC_CREATE | OFC_UPDATE | OFC_CANCEL | OFC_RESTORE | OFC_EXPORT_PDF | OFC_EXPORT_CSV | LOGIN_SUCCESS | LOGIN_FAILED | PERMISSION_DENIED';
COMMENT ON COLUMN audit_logs.severity IS 'INFO = rotina | WARN = modificação/cancelamento | CRITICAL = restauração/backup';

-- Índices audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_ts          ON audit_logs (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_user        ON audit_logs (user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_action       ON audit_logs (action, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity       ON audit_logs (entity, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_severity     ON audit_logs (severity, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_details      ON audit_logs USING GIN (details);


-- ============================================================================
-- 2. AJUSTES na tabela ofc_edit_log existente
--    - Remover FK CASCADE para sobreviver a soft-delete sem perder histórico
--    - Adicionar colunas de snapshot
-- ============================================================================
DO $$
BEGIN
    -- Remove FK com CASCADE se existir
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'ofc_edit_log_ofc_record_id_fkey'
          AND table_name = 'ofc_edit_log'
    ) THEN
        ALTER TABLE ofc_edit_log DROP CONSTRAINT ofc_edit_log_ofc_record_id_fkey;
    END IF;

    -- Adiciona coluna de snapshot se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ofc_edit_log' AND column_name = 'ofc_sequential_number'
    ) THEN
        ALTER TABLE ofc_edit_log ADD COLUMN ofc_sequential_number INT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ofc_edit_log' AND column_name = 'edited_by_name'
    ) THEN
        ALTER TABLE ofc_edit_log ADD COLUMN edited_by_name VARCHAR(300);
    END IF;
END;
$$;


-- ============================================================================
-- 3. TRIGGER: IMPEDE DELETE físico em ofc_records
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_prevent_ofc_physical_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_seq INT;
BEGIN
    v_seq := OLD.sequential_number;
    RAISE EXCEPTION 'EXCLUSAO_FISICA_BLOQUEADA: OFS #% não pode ser excluída fisicamente. '
                    'Use o fluxo de cancelamento (soft delete) via API.',
                    v_seq;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_ofc_delete ON ofc_records;
CREATE TRIGGER trg_prevent_ofc_delete
    BEFORE DELETE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_ofc_physical_delete();


-- ============================================================================
-- 4. TRIGGER: IMPEDE DELETE físico em ofc_edit_log (imutável)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_prevent_editlog_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'EXCLUSAO_FISICA_BLOQUEADA: Histórico de edição é imutável. '
                    'Registro de auditoria não pode ser removido.';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_editlog_delete ON ofc_edit_log;
CREATE TRIGGER trg_prevent_editlog_delete
    BEFORE DELETE ON ofc_edit_log
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_editlog_delete();


-- ============================================================================
-- 5. TRIGGER: IMPEDE UPDATE/DELETE em audit_logs (imutável)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_prevent_audit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'AUDIT_LOG_IMUTAVEL: A tabela audit_logs é imutável. '
                    'Registros de auditoria não podem ser alterados ou removidos.';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_audit_update ON audit_logs;
CREATE TRIGGER trg_prevent_audit_update
    BEFORE UPDATE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_audit_mutation();

DROP TRIGGER IF EXISTS trg_prevent_audit_delete ON audit_logs;
CREATE TRIGGER trg_prevent_audit_delete
    BEFORE DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_audit_mutation();


-- ============================================================================
-- 6. PERMISSÕES DE BANCO — Princípio do mínimo privilégio
-- ============================================================================
-- ofc_edit_log: apenas INSERT + SELECT (imutável)
REVOKE UPDATE, DELETE ON ofc_edit_log FROM ofs_app;

-- audit_logs: apenas INSERT + SELECT (imutável)
REVOKE UPDATE, DELETE ON audit_logs FROM ofs_app;

-- ofc_records: não conceder DELETE (trigger já bloqueia, mas reforça no permissionamento)
REVOKE DELETE ON ofc_records FROM ofs_app;


-- ============================================================================
-- 7. VERIFICAÇÃO DE INTEGRIDADE
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE 'Migration v3 aplicada com sucesso.';
    RAISE NOTICE 'Triggers ativos:';
    RAISE NOTICE '  - trg_prevent_ofc_delete      → bloqueia DELETE em ofc_records';
    RAISE NOTICE '  - trg_prevent_editlog_delete   → bloqueia DELETE em ofc_edit_log';
    RAISE NOTICE '  - trg_prevent_audit_update     → bloqueia UPDATE em audit_logs';
    RAISE NOTICE '  - trg_prevent_audit_delete     → bloqueia DELETE em audit_logs';
    RAISE NOTICE 'Permissões revogadas: UPDATE/DELETE em ofc_edit_log e audit_logs';
END;
$$;
