-- ============================================================================
-- SISTEMA OFS/OFS — MIGRATION v4: INTEGRIDADE DE DADOS COMPLETA
-- Security Dynamics | PostgreSQL 16 | Ambiente Offline / Intranet
-- Data: 13/05/2026
-- ============================================================================
-- COBRE:
--   Seção 1  → FOREIGN KEYS (ON DELETE auditado por tabela)
--   Seção 2  → CHECK constraints para enums + regras de negócio
--   Seção 3  → UNIQUE + NOT NULL (constraints faltantes)
--   Seção 4  → TRIGGERS de integridade (impedir DELETE físico, cancelamento, etc.)
--   Seção 5  → SOFT DELETE (is_deleted, trigger, view filtrada)
--   Seção 6  → SNAPSHOTS (política, auditoria, verificação)
--   Seção 7  → RETENÇÃO E LIMPEZA (revoked_tokens, audit_logs, ofc_records)
--   Seção 8  → INTEGRIDADE REFERENCIAL (cascata de inativação)
--   Seção 9  → SCRIPT DE VERIFICAÇÃO DE INTEGRIDADE (órfãos, snapshots, inconsistências)
-- ============================================================================


-- ============================================================================
-- SEÇÃO 1: POLÍTICA DE FOREIGN KEYS — ON DELETE POR TABELA
-- ============================================================================
--
-- REGRA GERAL:
--  RESTRICT  → O registro pai NÃO pode ser deletado se existir filho.
--              Use para entidades CORE (companies, users que criaram registros).
--  CASCADE   → Filhos são automaticamente deletados junto com o pai.
--              Use quando o filho NÃO tem significado sem o pai.
--  SET NULL  → FK vira NULL, o registro filho sobrevive sem referência.
--              Use para referências OPCIONAIS/ANCILARES.
--
-- TABELA              | COLUNA FK           | REFERENCIA         | ON DELETE  | JUSTIFICATIVA
-- ------------------- | ------------------- | ------------------ | ---------- | -------------
-- departments         | company_id          | companies(id)      | RESTRICT   | Departamento sem empresa não faz sentido. Inative a empresa, não delete.
-- departments         | parent_id           | departments(id)    | SET NULL   | Se o depto pai for removido, o filho vira raiz (não perde a hierarquia).
-- departments         | manager_id          | users(id)          | SET NULL   | Gestor pode sair; departamento continua existindo sem manager.
-- users               | company_id          | companies(id)      | RESTRICT   | Usuário precisa de empresa. Inative o usuário se empresa for desativada.
-- users               | department_id       | departments(id)    | SET NULL   | Usuário pode ser transferido/movido entre departamentos.
-- users               | manager_id          | users(id)          | SET NULL   | Gestor pode sair; subordinado continua sem manager definido.
-- competencies        | company_id          | companies(id)      | RESTRICT   | Competência pertence à empresa. Inative, não delete.
-- competencies        | parent_id           | competencies(id)   | SET NULL   | Grupo pai removido → competência vira raiz (órfã de grupo).
-- evaluation_cycles   | company_id          | companies(id)      | RESTRICT   | Ciclo pertence à empresa.
-- cycle_goals         | cycle_id            | evaluation_cycles  | CASCADE    | Meta sem ciclo não tem significado.
-- cycle_goals         | user_id             | users(id)          | CASCADE    | Se usuário for removido, metas dele são irrelevantes.
-- cycle_goals         | competency_id       | competencies(id)   | CASCADE    | Se competência sumir, meta atrelada some junto.
-- ofc_records         | company_id          | companies(id)      | RESTRICT   | OFS pertence à empresa. Nunca delete empresa com OFCs.
-- ofc_records         | department_id       | departments(id)    | SET NULL   | OFS sobrevive sem departamento (referência contextual).
-- ofc_records         | cycle_id            | evaluation_cycles  | SET NULL   | OFS pode existir fora de ciclo avaliativo.
-- ofc_records         | observer_id         | users(id)          | RESTRICT   | Observador NUNCA pode ser deletado se tem OFCs.
-- ofc_records         | observed_user_id    | users(id)          | SET NULL   | Pessoa observada pode sair; OFS mantém o nome (observed_name).
-- ofc_records         | competency_id       | competencies(id)   | SET NULL   | OFS sobrevive sem competência associada.
-- ofc_records         | cancelled_by        | users(id)          | SET NULL   | Quem cancelou pode sair; o cancelamento fica registrado.
-- ofc_records         | created_by          | users(id)          | RESTRICT   | Criador do registro NUNCA pode ser deletado.
-- ofc_edit_log        | ofc_record_id       | ofc_records(id)    | CASCADE    | Histórico de edição sem OFS não tem valor. (Apenas em v2; v3 remove FK)
-- ofc_edit_log        | edited_by           | users(id)          | RESTRICT   | Rastreabilidade: quem editou precisa existir.
-- ofs_records         | company_id          | companies(id)      | RESTRICT   | Sessão OFS pertence à empresa.
-- ofs_records         | cycle_id            | evaluation_cycles  | SET NULL   | OFS pode existir fora de ciclo.
-- ofs_records         | ofc_record_id       | ofc_records(id)    | SET NULL   | OFS sobrevive sem OFS vinculada.
-- ofs_records         | provider_id         | users(id)          | RESTRICT   | Provedor do feedback não pode ser deletado.
-- ofs_records         | receiver_id         | users(id)          | RESTRICT   | Receptor do feedback não pode ser deletado.
-- action_plans        | company_id          | companies(id)      | RESTRICT   | PDI pertence à empresa.
-- action_plans        | user_id             | users(id)          | CASCADE    | Se usuário for removido, PDI dele some junto.
-- action_plans        | ofs_record_id       | ofs_records(id)    | SET NULL   | PDI sobrevive sem sessão OFS vinculada.
-- action_plans        | competency_id       | competencies(id)   | SET NULL   | PDI sobrevive sem competência específica.
-- revoked_tokens      | user_id             | users(id)          | CASCADE    | Se usuário for deletado, tokens dele perdem sentido.
-- password_history    | user_id             | users(id)          | CASCADE    | Histórico some com o usuário.
-- audit_logs          | user_id             | users(id)          | SET NULL   | Trilha de auditoria sobrevive ao usuário (username fica denormalizado).

-- ============================================================================
-- AJUSTES DE FK QUE JÁ ESTÃO CORRETAS NO SCHEMA V2:
-- ============================================================================
-- Todas as FKs listadas acima já existem no schema ofs_database_model_v2.sql.
-- Nenhuma alteração necessária. Esta seção é documental/política.
--
-- ÚNICO PONTO DE ATENÇÃO: ofc_edit_log.ofc_record_id
-- No schema v2: ON DELETE CASCADE (histórico some com o registro)
-- Na migration v3: FK removida intencionalmente (histórico sobrevive ao soft delete)
-- Decisão final: MANTER sem FK em ofc_edit_log.ofc_record_id (como na v3).
-- O campo existe como UUID solto para consultas, mas não bloqueia exclusão lógica.


-- ============================================================================
-- SEÇÃO 2: CHECK CONSTRAINTS — ENUMS E REGRAS DE NEGÓCIO
-- ============================================================================
-- Constraints já existentes no schema v2 (mantidas):
--   users.role              IN ('admin','manager','supervisor','employee')
--   evaluation_cycles.status IN ('draft','active','closed')
--   ofc_records.classification IN ('positive','negative','neutral')
--   ofc_records.severity    IN ('low','medium','high','critical')
--   ofc_records.status      IN ('open','acknowledged','discussed','closed','cancelled')
--   ofs_records.feedback_type IN ('recognition','developmental','corrective','evaluative')
--   ofs_records.status      IN ('draft','shared','acknowledged','closed')
--   action_plans.status     IN ('pending','in_progress','completed','cancelled')
--   audit_logs.severity     IN ('DEBUG','INFO','WARNING','ERROR','CRITICAL')
--
-- Constraints adicionais que DEVEM ser criadas (ausentes no schema v2):

-- 2.1 Cancelamento exige motivo (já existe no schema legado, ausente no v2)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_ofc_cancel_requires_reason'
          AND table_name = 'ofc_records'
    ) THEN
        ALTER TABLE ofc_records ADD CONSTRAINT chk_ofc_cancel_requires_reason
            CHECK (
                (status = 'cancelled' AND cancel_reason IS NOT NULL AND cancelled_by IS NOT NULL AND cancelled_at IS NOT NULL)
                OR
                (status <> 'cancelled')
            );
    END IF;
END;
$$;

-- 2.2 Empresa observada: se não tem FK, nome livre é obrigatório
--     (Conceito do schema legado: empresa_observada_outros NOT NULL quando empresa_observada_id IS NULL)
--     No v2: observed_name é sempre NOT NULL, observed_user_id é opcional.
--     Essa constraint já está coberta pelo NOT NULL de observed_name.
--     Mas adicionamos a validação explícita para clareza:

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_ofc_observed_consistency'
          AND table_name = 'ofc_records'
    ) THEN
        ALTER TABLE ofc_records ADD CONSTRAINT chk_ofc_observed_consistency
            CHECK (
                observed_user_id IS NOT NULL OR observed_name IS NOT NULL
                -- Sempre verdade pois observed_name é NOT NULL. A constraint existe
                -- como documentação ativa da regra de negócio.
            );
    END IF;
END;
$$;

-- 2.3 Data de observação não pode ser futura (já existe no v2, mas reforçamos)
--     CHECK (observation_date <= CURRENT_DATE) — OK.

-- 2.4 Progresso de action_plan entre 0 e 100 (já existe no v2) — OK.

-- 2.5 Ciclo avaliativo: end_date > start_date (já existe no v2) — OK.

-- 2.6 Participantes OFS não podem ser a mesma pessoa (já existe no v2) — OK.

-- 2.7 Validação de sequential_number > 0
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'chk_ofc_sequential_positive'
          AND table_name = 'ofc_records'
    ) THEN
        ALTER TABLE ofc_records ADD CONSTRAINT chk_ofc_sequential_positive
            CHECK (sequential_number > 0);
    END IF;
END;
$$;


-- ============================================================================
-- SEÇÃO 3: CONSTRAINTS UNIQUE + NOT NULL (FALTANTES)
-- ============================================================================

-- 3.1 ofc_records: sequential_number UNIQUE (já existe índice único idx_ofc_sequential)
--     Transformar em constraint formal:

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'uq_ofc_sequential_number'
          AND table_name = 'ofc_records'
    ) THEN
        ALTER TABLE ofc_records ADD CONSTRAINT uq_ofc_sequential_number
            UNIQUE (sequential_number);
    END IF;
END;
$$;

-- 3.2 cycle_goals: UNIQUE (cycle_id, user_id, competency_id) — já existe no v2.
-- 3.3 companies.document UNIQUE (já existe no v2) — OK.
-- 3.4 users.email UNIQUE (já existe no v2) — OK.
-- 3.5 revoked_tokens.jti UNIQUE (já existe) — OK.

-- 3.6 NOT NULL: verificar colunas críticas sem NOT NULL explícito
--     ofc_records.cancel_reason → pode ser NULL (só obrigatório se status='cancelled')
--     ofc_records.cancelled_by → pode ser NULL (idem)
--     ofc_records.cancelled_at → pode ser NULL (idem)
--     users.last_login → opcional (NULL = nunca logou) — OK.
--     users.locked_until → opcional (NULL = não bloqueado) — OK.


-- ============================================================================
-- SEÇÃO 4: TRIGGERS DE INTEGRIDADE
-- ============================================================================

-- --------------------------------------------------------------------------
-- 4.1 IMPEDIR DELETE FÍSICO em ofc_records
--     OFS nunca é deletada. Usa-se cancelamento (status='cancelled') ou
--     soft delete (is_deleted = TRUE). DELETE físico é barrado.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_ofc_physical_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_seq INT;
BEGIN
    v_seq := OLD.sequential_number;
    RAISE EXCEPTION 'EXCLUSAO_FISICA_BLOQUEADA: OFS #% não pode ser excluída fisicamente. '
                    'Use o fluxo de cancelamento (status=cancelled) ou soft delete (is_deleted=TRUE).',
                    v_seq;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_ofc_delete ON ofc_records;
CREATE TRIGGER trg_prevent_ofc_delete
    BEFORE DELETE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_ofc_physical_delete();


-- --------------------------------------------------------------------------
-- 4.2 IMPEDIR UPDATE em audit_logs (tabela imutável — append-only)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_audit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'AUDIT_LOG_IMUTAVEL: A tabela audit_logs é append-only. '
                        'Registros de auditoria não podem ser alterados.';
    ELSIF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'AUDIT_LOG_IMUTAVEL: Registros de auditoria não podem ser removidos. '
                        'A retenção é gerenciada por particionamento e política de expurgo (2 anos).';
    END IF;
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


-- --------------------------------------------------------------------------
-- 4.3 IMPEDIR DELETE em ofc_edit_log (histórico de edição imutável)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_editlog_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'EXCLUSAO_FISICA_BLOQUEADA: Histórico de edição é imutável. '
                    'Registro de auditoria de alterações não pode ser removido.';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_editlog_delete ON ofc_edit_log;
CREATE TRIGGER trg_prevent_editlog_delete
    BEFORE DELETE ON ofc_edit_log
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_editlog_delete();


-- --------------------------------------------------------------------------
-- 4.4 VALIDAR CANCELAMENTO: se status='cancelled', cancel_reason é NOT NULL
--     (Reforço via trigger além da CHECK constraint — gera erro amigável)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_ofc_cancellation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'cancelled' THEN
        IF NEW.cancel_reason IS NULL OR TRIM(NEW.cancel_reason) = '' THEN
            RAISE EXCEPTION 'CANCELAMENTO_INVALIDO: Todo cancelamento exige motivo (cancel_reason).';
        END IF;
        IF NEW.cancelled_by IS NULL THEN
            RAISE EXCEPTION 'CANCELAMENTO_INVALIDO: Todo cancelamento exige identificação do responsável (cancelled_by).';
        END IF;
        -- Preenche timestamp automaticamente se não informado
        IF NEW.cancelled_at IS NULL THEN
            NEW.cancelled_at := NOW();
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_ofc_cancel ON ofc_records;
CREATE TRIGGER trg_validate_ofc_cancel
    BEFORE UPDATE OF status ON ofc_records
    FOR EACH ROW
    WHEN (NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled')
    EXECUTE FUNCTION fn_validate_ofc_cancellation();


-- --------------------------------------------------------------------------
-- 4.5 IMPEDIR reabertura de OFS cancelada
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_ofc_uncancel()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.status = 'cancelled' AND NEW.status <> 'cancelled' THEN
        RAISE EXCEPTION 'REATIVACAO_BLOQUEADA: OFS #% está cancelada e não pode ser reativada. '
                        'Crie um novo registro se necessário.',
                        OLD.sequential_number;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_ofc_uncancel ON ofc_records;
CREATE TRIGGER trg_prevent_ofc_uncancel
    BEFORE UPDATE OF status ON ofc_records
    FOR EACH ROW
    WHEN (OLD.status = 'cancelled' AND NEW.status <> 'cancelled')
    EXECUTE FUNCTION fn_prevent_ofc_uncancel();


-- --------------------------------------------------------------------------
-- 4.6 AUDIT TRAIL AUTOMÁTICO: Registrar no audit_logs ao cancelar OFS
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_audit_ofc_cancellation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
        INSERT INTO audit_logs (
            timestamp, user_id, username,
            action, resource, resource_id,
            details, severity
        ) VALUES (
            NOW(),
            NEW.cancelled_by,
            COALESCE(
                (SELECT u.full_name FROM users u WHERE u.id = NEW.cancelled_by),
                'SISTEMA'
            ),
            'OFC_CANCEL',
            'ofc_records',
            NEW.id::TEXT,
            jsonb_build_object(
                'sequential_number', NEW.sequential_number,
                'cancel_reason', NEW.cancel_reason,
                'previous_status', OLD.status,
                'classification', NEW.classification,
                'observed_name', NEW.observed_name
            ),
            'WARNING'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_ofc_cancel ON ofc_records;
CREATE TRIGGER trg_audit_ofc_cancel
    AFTER UPDATE OF status ON ofc_records
    FOR EACH ROW
    WHEN (NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled')
    EXECUTE FUNCTION fn_audit_ofc_cancellation();


-- --------------------------------------------------------------------------
-- 4.7 IMPEDIR INSERT/UPDATE com created_at ou id manipulados
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_system_field_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        -- Impede alteração manual de created_at e id
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'VIOLACAO_INTEGRIDADE: O campo id é imutável.';
        END IF;
        IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            RAISE EXCEPTION 'VIOLACAO_INTEGRIDADE: O campo created_at é imutável.';
        END IF;
        IF NEW.created_by IS DISTINCT FROM OLD.created_by THEN
            RAISE EXCEPTION 'VIOLACAO_INTEGRIDADE: O campo created_by é imutável.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_tampering ON ofc_records;
CREATE TRIGGER trg_prevent_tampering
    BEFORE UPDATE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_system_field_tampering();


-- ============================================================================
-- SEÇÃO 5: POLÍTICA DE SOFT DELETE
-- ============================================================================
--
-- CONCEITO: Nenhum registro OFS é fisicamente deletado.
-- O DELETE lógico é implementado via flag is_deleted = TRUE.
-- Métricas, views e consultas SEMPRE filtram is_deleted = FALSE.
-- Usuários sem permissão de admin NUNCA veem registros deletados.
-- Admins podem ver dados deletados via auditoria.

-- --------------------------------------------------------------------------
-- 5.1 Adicionar coluna is_deleted em ofc_records (ausente no v2)
-- --------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ofc_records' AND column_name = 'is_deleted'
    ) THEN
        ALTER TABLE ofc_records
            ADD COLUMN is_deleted     BOOLEAN     NOT NULL DEFAULT FALSE,
            ADD COLUMN deleted_at     TIMESTAMPTZ,
            ADD COLUMN deleted_by     UUID        REFERENCES users(id) ON DELETE SET NULL,
            ADD COLUMN deleted_reason TEXT;
    END IF;
END;
$$;

COMMENT ON COLUMN ofc_records.is_deleted     IS 'Soft delete: TRUE = registro logicamente excluído';
COMMENT ON COLUMN ofc_records.deleted_at     IS 'Timestamp da exclusão lógica';
COMMENT ON COLUMN ofc_records.deleted_by     IS 'Usuário que executou a exclusão lógica';
COMMENT ON COLUMN ofc_records.deleted_reason IS 'Motivo da exclusão lógica (obrigatório)';


-- --------------------------------------------------------------------------
-- 5.2 TRIGGER: Transforma DELETE físico em soft delete
--     Quando um DELETE é executado na tabela, o trigger intercepta e
--     transforma em UPDATE (is_deleted = TRUE) + registra os metadados.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ofc_soft_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Se já está deletado, permite seguir (o trigger 4.1 barra DELETE físico de qualquer forma)
    -- Mas aqui interceptamos antes: transformamos DELETE em UPDATE de soft delete

    -- Nota: Este trigger roda BEFORE DELETE. Se is_deleted já for TRUE,
    -- significa que é uma tentativa de DELETE físico pós-soft-delete.
    -- Nesse caso, barramos completamente (administrador deve usar purge controlado).

    IF OLD.is_deleted = TRUE THEN
        RAISE EXCEPTION 'EXCLUSAO_BLOQUEADA: OFS #% já está em soft delete. '
                        'Remoção física requer procedimento de purge administrativo.',
                        OLD.sequential_number;
    END IF;

    -- Intercepta o DELETE e transforma em UPDATE de soft delete
    -- Usa current_setting para capturar o usuário logado (setado pela aplicação)
    UPDATE ofc_records
    SET is_deleted     = TRUE,
        deleted_at     = NOW(),
        deleted_by     = current_setting('app.current_user_id', TRUE)::UUID,
        deleted_reason = 'Soft delete via API',
        updated_at     = NOW()
    WHERE id = OLD.id;

    -- Cancela o DELETE original (a linha já foi atualizada pelo UPDATE acima)
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_ofc_soft_delete ON ofc_records;
CREATE TRIGGER trg_ofc_soft_delete
    BEFORE DELETE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_ofc_soft_delete();

-- NOTA: Este trigger substitui o trg_prevent_ofc_delete (seção 4.1) na prática,
-- pois intercepta o DELETE antes que o trigger de bloqueio o veja.
-- MANTEMOS AMBOS: o soft delete intercepta primeiro (BEFORE),
-- o prevent_delete é a última barreira. Se o soft delete falhar por algum motivo,
-- o prevent_delete garante que nenhum DELETE físico ocorra.


-- --------------------------------------------------------------------------
-- 5.3 VIEW: ofc_records_active (filtra soft-deleted)
--     Use esta view para TODAS as consultas de negócio.
--     A tabela base ofc_records é acessada apenas para auditoria/admin.
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ofc_records_active AS
SELECT *
FROM ofc_records
WHERE is_deleted = FALSE;

COMMENT ON VIEW vw_ofc_records_active IS
'View de trabalho: filtra automaticamente registros em soft delete.
 Use em todas as queries de negócio. Acesso a ofc_records direta = admin/auditor.';


-- --------------------------------------------------------------------------
-- 5.4 VIEW: ofc_records_deleted (apenas soft-deleted, para auditoria)
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ofc_records_deleted AS
SELECT *
FROM ofc_records
WHERE is_deleted = TRUE;

COMMENT ON VIEW vw_ofc_records_deleted IS
'View de auditoria: apenas registros em soft delete. Acesso restrito a admin.';


-- --------------------------------------------------------------------------
-- 5.5 ÍNDICE PARCIAL para soft-deleted (otimiza auditoria)
-- --------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ofc_soft_deleted
    ON ofc_records (deleted_at, deleted_by)
    WHERE is_deleted = TRUE;


-- --------------------------------------------------------------------------
-- 5.6 COMO MÉTRICAS E CONSULTAS IGNORAM SOFT-DELETED
-- --------------------------------------------------------------------------
-- Todas as views existentes já filtram status != 'cancelled'.
-- Agora devem também filtrar is_deleted = FALSE:
--
--   WHERE o.status != 'cancelled' AND o.is_deleted = FALSE
--
-- OU, mais simples, usar a view vw_ofc_records_active no lugar da tabela base.
--
-- Exemplo de atualização da view vw_weekly_metrics (já existente no v2):
--   Substituir:
--     FROM ofc_records o
--   Por:
--     FROM vw_ofc_records_active o
--
-- Isso garante que TODAS as métricas ignorem registros soft-deleted.
-- O mesmo vale para calculate_period_metrics(), count_by_type(), etc.

-- ============================================================================
-- ATUALIZAÇÃO DAS VIEWS EXISTENTES para usar vw_ofc_records_active
-- ============================================================================

-- 5.6.1 vw_weekly_metrics
CREATE OR REPLACE VIEW vw_weekly_metrics AS
SELECT
    DATE_TRUNC('week', o.observation_date)::DATE                                   AS week_start,
    (DATE_TRUNC('week', o.observation_date) + INTERVAL '6 days')::DATE             AS week_end,
    EXTRACT(WEEK FROM o.observation_date)::INT                                     AS week_number,
    EXTRACT(YEAR FROM o.observation_date)::INT                                     AS year_number,
    c.id                                                                            AS company_id,
    c.name                                                                          AS company_name,
    COUNT(*)                                                                        AS total_records,
    COUNT(*) FILTER (WHERE o.classification = 'positive')                          AS positive_count,
    COUNT(*) FILTER (WHERE o.classification = 'negative')                          AS negative_count,
    COUNT(*) FILTER (WHERE o.classification = 'neutral')                           AS neutral_count,
    ROUND(
        COUNT(*) FILTER (WHERE o.classification = 'positive')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                                               AS safe_percentage,
    COUNT(DISTINCT o.observer_id)                                                   AS unique_observers,
    COUNT(DISTINCT o.observed_name)                                                 AS unique_observed,
    COUNT(DISTINCT o.observation_date)                                              AS days_with_records
FROM vw_ofc_records_active o
INNER JOIN companies c ON c.id = o.company_id
WHERE o.status != 'cancelled'
GROUP BY
    DATE_TRUNC('week', o.observation_date)::DATE,
    EXTRACT(WEEK FROM o.observation_date),
    EXTRACT(YEAR FROM o.observation_date),
    c.id, c.name
ORDER BY week_start DESC, c.name;


-- 5.6.2 vw_daily_summary
CREATE OR REPLACE VIEW vw_daily_summary AS
SELECT
    o.observation_date,
    o.company_id,
    c.name                                                          AS company_name,
    COUNT(*)                                                        AS total_records,
    COUNT(*) FILTER (WHERE o.classification = 'positive')          AS positive_count,
    COUNT(*) FILTER (WHERE o.classification = 'negative')          AS negative_count,
    COUNT(DISTINCT o.observer_id)                                   AS unique_observers
FROM vw_ofc_records_active o
INNER JOIN companies c ON c.id = o.company_id
WHERE o.status != 'cancelled'
GROUP BY o.observation_date, o.company_id, c.name
ORDER BY o.observation_date DESC, c.name;


-- 5.6.3 vw_cycle_goals_progress
CREATE OR REPLACE VIEW vw_cycle_goals_progress AS
SELECT
    ec.id                                                   AS cycle_id,
    ec.title                                                AS cycle_title,
    ec.start_date,
    ec.end_date,
    ec.status                                               AS cycle_status,
    u.id                                                    AS user_id,
    u.full_name                                             AS user_name,
    comp.id                                                 AS competency_id,
    comp.name                                               AS competency_name,
    cg.target_positive,
    cg.max_negative,
    cg.actual_positive,
    cg.actual_negative,
    cg.is_achieved,
    CASE
        WHEN cg.is_achieved THEN 'OK'
        WHEN cg.target_positive > 0 AND
             (cg.actual_positive::NUMERIC / NULLIF(cg.target_positive, 0)) >= 0.8 THEN 'ATENCAO'
        WHEN cg.target_positive > 0 THEN 'ALERTA'
        ELSE 'SEM_META'
    END                                                     AS goal_status
FROM cycle_goals cg
INNER JOIN evaluation_cycles ec ON ec.id = cg.cycle_id
INNER JOIN users u ON u.id = cg.user_id
LEFT JOIN competencies comp ON comp.id = cg.competency_id
ORDER BY ec.start_date DESC, u.full_name, comp.sort_order;


-- 5.6.4 Atualizar função calculate_period_metrics
CREATE OR REPLACE FUNCTION calculate_period_metrics(
    p_start_date DATE,
    p_end_date   DATE,
    p_company_id UUID DEFAULT NULL
)
RETURNS TABLE (
    company_name        VARCHAR,
    total_records       BIGINT,
    positive_count      BIGINT,
    negative_count      BIGINT,
    neutral_count       BIGINT,
    safe_percentage     NUMERIC(5,2),
    unique_observers    BIGINT,
    unique_observed     BIGINT,
    days_active         BIGINT
)
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT
        c.name,
        COUNT(*)::BIGINT,
        COUNT(*) FILTER (WHERE o.classification = 'positive')::BIGINT,
        COUNT(*) FILTER (WHERE o.classification = 'negative')::BIGINT,
        COUNT(*) FILTER (WHERE o.classification = 'neutral')::BIGINT,
        ROUND(
            COUNT(*) FILTER (WHERE o.classification = 'positive')::NUMERIC
            / NULLIF(COUNT(*), 0) * 100, 2
        ),
        COUNT(DISTINCT o.observer_id)::BIGINT,
        COUNT(DISTINCT o.observed_name)::BIGINT,
        COUNT(DISTINCT o.observation_date)::BIGINT
    FROM vw_ofc_records_active o
    INNER JOIN companies c ON c.id = o.company_id
    WHERE o.status != 'cancelled'
      AND o.observation_date BETWEEN p_start_date AND p_end_date
      AND (p_company_id IS NULL OR o.company_id = p_company_id)
    GROUP BY c.id, c.name
    ORDER BY c.name;
$$;


-- ============================================================================
-- SEÇÃO 6: POLÍTICA DE SNAPSHOTS
-- ============================================================================
--
-- CONCEITO: Snapshots são cópias de dados voláteis no momento do registro.
-- Garantem rastreabilidade mesmo se a entidade original for alterada ou removida.
--
-- TABELA ofc_records — CAMPOS QUE SÃO SNAPSHOTS:
--
-- | Coluna                  | É snapshot? | Justificativa                                  |
-- |------------------------|-------------|------------------------------------------------|
-- | observed_name          | SIM         | Nome da pessoa no momento. Sobrevive a          |
-- |                        |             | alteração de nome do usuário ou saída.          |
-- | observer_id            | NÃO         | FK RESTRICT: observador não pode ser deletado. |
-- |                        |             | Mas o NOME do observador pode mudar.            |
-- | company_id             | NÃO         | FK RESTRICT: empresa não pode ser deletada.    |
-- |                        |             | Mas o NOME da empresa pode mudar.               |
-- | competency_id          | NÃO (SET NULL) | Se competência for deletada, referência some. |
--
-- PROBLEMA IDENTIFICADO: Se o nome do observador mudar (ex: casamento),
-- o nome exibido no registro antigo muda retroativamente, perdendo
-- a fidelidade histórica. Isso viola o princípio de imutabilidade
-- de registros de auditoria.
--
-- SOLUÇÃO: Adicionar colunas de snapshot para observer e company.
-- --------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'ofc_records' AND column_name = 'observer_name_snapshot'
    ) THEN
        ALTER TABLE ofc_records
            ADD COLUMN observer_name_snapshot VARCHAR(300),
            ADD COLUMN company_name_snapshot  VARCHAR(200);
    END IF;
END;
$$;

COMMENT ON COLUMN ofc_records.observer_name_snapshot IS
'Snapshot do nome do observador no momento do registro. Imutável após criação.';
COMMENT ON COLUMN ofc_records.company_name_snapshot IS
'Snapshot do nome da empresa no momento do registro. Imutável após criação.';


-- --------------------------------------------------------------------------
-- 6.1 TRIGGER: Preencher snapshots automaticamente no INSERT
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_fill_ofc_snapshots()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Preenche snapshot do observador
    IF NEW.observer_name_snapshot IS NULL AND NEW.observer_id IS NOT NULL THEN
        SELECT u.full_name INTO NEW.observer_name_snapshot
        FROM users u WHERE u.id = NEW.observer_id;
    END IF;

    -- Preenche snapshot da empresa
    IF NEW.company_name_snapshot IS NULL AND NEW.company_id IS NOT NULL THEN
        SELECT c.name INTO NEW.company_name_snapshot
        FROM companies c WHERE c.id = NEW.company_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ofc_fill_snapshots ON ofc_records;
CREATE TRIGGER trg_ofc_fill_snapshots
    BEFORE INSERT ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_fill_ofc_snapshots();


-- --------------------------------------------------------------------------
-- 6.2 TRIGGER: Impedir UPDATE nos snapshots (campos imutáveis após INSERT)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_snapshot_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.observer_name_snapshot IS DISTINCT FROM OLD.observer_name_snapshot THEN
        RAISE EXCEPTION 'SNAPSHOT_IMUTAVEL: observer_name_snapshot não pode ser alterado após criação.';
    END IF;
    IF NEW.company_name_snapshot IS DISTINCT FROM OLD.company_name_snapshot THEN
        RAISE EXCEPTION 'SNAPSHOT_IMUTAVEL: company_name_snapshot não pode ser alterado após criação.';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ofc_snapshot_immutable ON ofc_records;
CREATE TRIGGER trg_ofc_snapshot_immutable
    BEFORE UPDATE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_snapshot_update();


-- --------------------------------------------------------------------------
-- 6.3 COMPORTAMENTO ON DELETE SET NULL vs RESTRICT nos snapshots
-- --------------------------------------------------------------------------
--
-- CENÁRIO: O que acontece se o USUÁRIO ORIGINAL (observer_id) for deletado?
--
-- Situação atual: observer_id tem ON DELETE RESTRICT.
--   → IMPEDE a deleção do usuário se ele tiver OFCs registradas.
--   → VANTAGEM: preserva a FK, rastreabilidade total.
--   → DESVANTAGEM: admin não consegue remover ex-funcionários que criaram OFCs.
--
-- Alternativa: ON DELETE SET NULL + observer_name_snapshot.
--   → Permite deletar o usuário, mas mantém o nome no snapshot.
--   → VANTAGEM: flexibilidade operacional (RH pode remover ex-funcionários).
--   → DESVANTAGEM: perde o vínculo FK (não dá pra clicar e ver perfil do observador).
--
-- DECISÃO PARA ESTE SISTEMA: Manter RESTRICT no observer_id e created_by.
-- Justificativa:
--   1. Sistema offline/intranet — volume de rotatividade é conhecido.
--   2. Rastreabilidade completa é REQUISITO do sistema de feedback comportamental.
--   3. Em vez de deletar usuários, INATIVE-OS (is_active = FALSE).
--      Isso preserva FKs e permite auditoria.
--   4. Se um usuário REALMENTE precisar ser removido (LGPD), faça:
--      a) Anonimização: substituir full_name por '[REMOVIDO]', email por NULL.
--      b) Manter o id e as FKs intactas.
--      c) O snapshot observer_name_snapshot nos registros antigos permanece
--         com o nome original (NÃO é alterado pela anonimização).
--
-- Para a empresa (company_id):
--   Idem: RESTRICT. Empresas não são deletadas, são desativadas (is_active = FALSE).
--
-- Para observed_user_id (pessoa observada):
--   SET NULL. Se o usuário sair, o nome fica preservado em observed_name.
--   Perde-se o vínculo com o perfil, mas o registro sobrevive.


-- ============================================================================
-- SEÇÃO 7: RETENÇÃO E LIMPEZA
-- ============================================================================

-- --------------------------------------------------------------------------
-- 7.1 revoked_tokens: DELETE diário de tokens expirados
-- --------------------------------------------------------------------------
-- Função já existe (cleanup_expired_tokens). Agendamento:

-- Via pg_cron (se disponível):
-- SELECT cron.schedule('cleanup-expired-tokens', '0 3 * * *',
--     'SELECT cleanup_expired_tokens();'
-- );

-- Via aplicação (apscheduler no FastAPI):
-- scheduler.add_job(
--     cleanup_expired_tokens,
--     trigger=CronTrigger(hour=3, minute=0),
--     id='cleanup_expired_tokens'
-- )

-- Trigger oportunístico: ao inserir novo token revogado, limpa expirados.
-- (Já implementado em ofs_auth_schema.sql: trg_revoked_tokens_cleanup)

COMMENT ON FUNCTION cleanup_expired_tokens() IS
'Deleta todos os revoked_tokens cujo expires_at < NOW().
 Agendar via pg_cron diariamente às 3h ou via apscheduler.';


-- --------------------------------------------------------------------------
-- 7.2 audit_logs: Particionamento por mês, retenção 2 anos
-- --------------------------------------------------------------------------

-- 7.2.1 Script de migração para particionamento
-- (Execute como superuser em janela de manutenção)

/*
-- PASSO 1: Criar tabela particionada substituta
CREATE TABLE audit_logs_partitioned (
    id              UUID            DEFAULT gen_random_uuid(),
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
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_audit_logs_part PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

-- PASSO 2: Criar partições para o mês atual e próximos 3 meses
CREATE TABLE audit_logs_2026_05 PARTITION OF audit_logs_partitioned
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE audit_logs_2026_06 PARTITION OF audit_logs_partitioned
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE audit_logs_2026_07 PARTITION OF audit_logs_partitioned
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE audit_logs_2026_08 PARTITION OF audit_logs_partitioned
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

-- PASSO 3: Migrar dados existentes
INSERT INTO audit_logs_partitioned SELECT * FROM audit_logs;

-- PASSO 4: Renomear tabelas
ALTER TABLE audit_logs RENAME TO audit_logs_old;
ALTER TABLE audit_logs_partitioned RENAME TO audit_logs;

-- PASSO 5: Recriar índices
CREATE INDEX idx_audit_ts        ON audit_logs (timestamp DESC);
CREATE INDEX idx_audit_user      ON audit_logs (user_id);
CREATE INDEX idx_audit_action    ON audit_logs (action);
CREATE INDEX idx_audit_resource  ON audit_logs (resource, resource_id);
CREATE INDEX idx_audit_severity  ON audit_logs (severity);
CREATE INDEX idx_audit_details   ON audit_logs USING GIN (details);

-- PASSO 6: Recriar triggers de imutabilidade
CREATE TRIGGER trg_prevent_audit_update
    BEFORE UPDATE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION fn_prevent_audit_mutation();
CREATE TRIGGER trg_prevent_audit_delete
    BEFORE DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION fn_prevent_audit_mutation();

-- PASSO 7: Dropar tabela antiga (após verificar migração)
-- DROP TABLE audit_logs_old;
*/


-- 7.2.2 Função automatizada: criar partição do próximo mês
CREATE OR REPLACE FUNCTION fn_create_next_audit_partition()
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_next_month_start DATE;
    v_next_month_end   DATE;
    v_partition_name   TEXT;
BEGIN
    -- Calcula o mês seguinte ao atual
    v_next_month_start := DATE_TRUNC('month', NOW()) + INTERVAL '1 month';
    v_next_month_end   := DATE_TRUNC('month', NOW()) + INTERVAL '2 months';
    v_partition_name   := 'audit_logs_' || TO_CHAR(v_next_month_start, 'YYYY_MM');

    -- Verifica se a partição já existe
    IF EXISTS (
        SELECT 1 FROM pg_class
        WHERE relname = v_partition_name
    ) THEN
        RETURN; -- Partição já existe, nada a fazer
    END IF;

    -- Cria a partição
    EXECUTE format(
        'CREATE TABLE %I PARTITION OF audit_logs
         FOR VALUES FROM (%L) TO (%L)',
        v_partition_name, v_next_month_start, v_next_month_end
    );

    RAISE NOTICE 'Partição criada: % (de % a %)', v_partition_name, v_next_month_start, v_next_month_end;
END;
$$;

COMMENT ON FUNCTION fn_create_next_audit_partition() IS
'Cria automaticamente a partição mensal do mês seguinte para audit_logs.
 Agendar via pg_cron no dia 25 de cada mês:
   SELECT cron.schedule(''create-audit-partition'', ''0 0 25 * *'',
       ''SELECT fn_create_next_audit_partition();'');';


-- 7.2.3 Função de expurgo: DROP partições com mais de 2 anos
CREATE OR REPLACE FUNCTION fn_purge_old_audit_partitions()
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_cutoff DATE := DATE_TRUNC('month', NOW()) - INTERVAL '2 years';
BEGIN
    FOR r IN
        SELECT
            c.relname AS partition_name,
            pg_catalog.pg_get_expr(c.relpartbound, c.oid) AS range_expr
        FROM pg_class c
        JOIN pg_inherits i ON i.inhrelid = c.oid
        JOIN pg_class p ON p.oid = i.inhparent
        WHERE p.relname = 'audit_logs'
          AND c.relname LIKE 'audit_logs_%'
          AND c.relname ~ '^audit_logs_\d{4}_\d{2}$'
        ORDER BY c.relname
    LOOP
        -- Extrai ano e mês do nome: audit_logs_2024_04
        DECLARE
            v_part_year  INT := SUBSTRING(r.partition_name FROM '_(\d{4})_\d{2}$')::INT;
            v_part_month INT := SUBSTRING(r.partition_name FROM '_\d{4}_(\d{2})$')::INT;
            v_part_date  DATE := MAKE_DATE(v_part_year, v_part_month, 1);
        BEGIN
            IF v_part_date < v_cutoff THEN
                -- Remove os triggers de bloqueio TEMPORARIAMENTE para esta operação
                -- (DROP TABLE não dispara triggers BEFORE DELETE por linha)
                EXECUTE format('DROP TABLE IF EXISTS %I', r.partition_name);
                RETURN NEXT format('EXPURGADA: % (data: %s)', r.partition_name, v_part_date);
            END IF;
        END;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION fn_purge_old_audit_partitions() IS
'Remove partições de audit_logs com mais de 2 anos.
 Agendar via pg_cron mensalmente no dia 1 às 4h:
   SELECT cron.schedule(''purge-old-audit'', ''0 4 1 * *'',
       ''SELECT fn_purge_old_audit_partitions();'');';


-- 7.2.4 Agendamento completo para audit_logs
/*
-- pg_cron setup (execute como superuser):

-- Dia 25 de cada mês: criar partição do mês seguinte
SELECT cron.schedule('create-audit-partition', '0 0 25 * *',
    'SELECT fn_create_next_audit_partition();');

-- Dia 1 de cada mês às 4h: expurgar partições > 2 anos
SELECT cron.schedule('purge-old-audit', '0 4 1 * *',
    'SELECT fn_purge_old_audit_partitions();');

-- Diário às 3h: limpar tokens expirados
SELECT cron.schedule('cleanup-expired-tokens', '0 3 * * *',
    'SELECT cleanup_expired_tokens();');
*/


-- --------------------------------------------------------------------------
-- 7.3 ofc_records: Nunca deletar, apenas soft delete
-- --------------------------------------------------------------------------
-- Política:
--   1. Usuários NORMAIS: soft delete (is_deleted = TRUE) via API.
--      O trigger trg_ofc_soft_delete intercepta o DELETE.
--   2. Usuário ADMIN: pode usar status='cancelled' para cancelar.
--   3. NENHUM usuário: DELETE físico. O trigger trg_prevent_ofc_delete
--      é a última barreira.
--   4. PURGE real: apenas DBA, com procedimento documentado, se
--      absolutamente necessário (LGPD, ordem judicial). Nesse caso,
--      desabilitar triggers temporariamente:
--        ALTER TABLE ofc_records DISABLE TRIGGER trg_prevent_ofc_delete;
--        -- executar purge
--        ALTER TABLE ofc_records ENABLE TRIGGER trg_prevent_ofc_delete;
--      Registrar a operação em audit_logs manualmente.


-- ============================================================================
-- SEÇÃO 8: INTEGRIDADE REFERENCIAL — CASCATA DE INATIVAÇÃO
-- ============================================================================

-- --------------------------------------------------------------------------
-- 8.1 O que fazer quando uma EMPRESA é desativada
-- --------------------------------------------------------------------------
--
-- DECISÃO: RESTRICT no FK. Empresa NÃO é deletada, apenas desativada.
--
-- Fluxo de inativação de empresa:
--   1. UPDATE companies SET is_active = FALSE WHERE id = $1;
--   2. O sistema DEVE impedir login de usuários dessa empresa (via aplicação).
--   3. Departamentos e competências da empresa continuam existindo
--      (podem ser reativados se a empresa voltar).
--   4. OFCs existentes PERMANECEM. A empresa foi desativada, não extinta.
--      Os registros históricos têm valor de auditoria.
--   5. Se for necessário OCULTAR a empresa de listagens, usar o filtro
--      is_active = TRUE nas queries de listagem.
--
-- CÓDIGO DA APLICAÇÃO (FastAPI):
--   async def deactivate_company(company_id: UUID) -> bool:
--       # Verifica se há usuários ativos
--       active_users = await db.execute(
--           select(func.count()).select_from(User)
--           .where(User.company_id == company_id, User.is_active == True)
--       )
--       if active_users > 0:
--           # Opção: inativar todos os usuários em cascata
--           await db.execute(
--               update(User)
--               .where(User.company_id == company_id)
--               .values(is_active=False)
--           )
--       await db.execute(
--           update(Company)
--           .where(Company.id == company_id)
--           .values(is_active=False)
--       )
--       return True

-- --------------------------------------------------------------------------
-- 8.2 O que fazer quando um USUÁRIO é removido
-- --------------------------------------------------------------------------
--
-- DECISÃO: Usuário NUNCA é deletado do banco. Apenas desativado.
--
-- Fluxo de desativação de usuário:
--   1. UPDATE users SET is_active = FALSE WHERE id = $1;
--   2. Bloquear login (is_active = FALSE já impede).
--   3. SET NULL nos campos opcionais (department_id, manager_id).
--   4. FKs RESTRICT (observer_id, created_by) continuam válidas
--      porque o registro do usuário ainda existe.
--   5. Para LGPD: anonimizar dados pessoais do usuário inativo:
--        UPDATE users SET
--            full_name = '[REMOVIDO ' || TO_CHAR(NOW(), 'YYYY-MM') || ']',
--            email = NULL,
--            password_hash = NULL
--        WHERE id = $1 AND is_active = FALSE;
--      O id e as FKs permanecem, mas dados pessoais são limpos.
--      Os snapshots (observer_name_snapshot) NÃO são alterados.
--
-- CÓDIGO DA APLICAÇÃO:
--   async def anonymize_user(user_id: UUID) -> bool:
--       await db.execute(
--           update(User)
--           .where(User.id == user_id, User.is_active == False)
--           .values(
--               full_name=f'[REMOVIDO {datetime.now().strftime("%Y-%m")}]',
--               email=None,
--           )
--       )
--       return True

-- --------------------------------------------------------------------------
-- 8.3 Cascata de inativação
-- --------------------------------------------------------------------------
--
-- Empresa desativada → TODOS os usuários da empresa são desativados.
-- Usuário desativado → Ciclos de meta mantidos (histórico).
--                    → OFCs do usuário mantidas (observador/observado).
--                    → Planos de ação (PDI) concluídos mantidos, pendentes cancelados.
--
-- NADA é deletado. Tudo é desativado ou mantido.
-- A única exceção é CASCADE em cycle_goals (se usuário for REALMENTE deletado,
-- o que não deve acontecer em operação normal).


-- ============================================================================
-- SEÇÃO 9: SCRIPT DE VERIFICAÇÃO DE INTEGRIDADE
-- ============================================================================

-- --------------------------------------------------------------------------
-- 9.1 VIEW: vw_integrity_issues — Visão consolidada de problemas
-- --------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_integrity_issues AS

-- 9.1.1 ÓRFÃOS: FK apontando para registro inexistente
SELECT
    'ORFAO'::TEXT                                     AS issue_type,
    'CRITICAL'::TEXT                                  AS severity,
    'ofc_records.company_id'::TEXT                    AS constraint_name,
    'OFS #' || o.sequential_number || ' referencia empresa inexistente (' || o.company_id || ')' AS description,
    o.id                                              AS record_id,
    'ofc_records'::TEXT                               AS table_name
FROM ofc_records o
LEFT JOIN companies c ON c.id = o.company_id
WHERE c.id IS NULL

UNION ALL

SELECT
    'ORFAO', 'CRITICAL',
    'ofc_records.observer_id',
    'OFS #' || o.sequential_number || ' referencia observador inexistente (' || o.observer_id || ')',
    o.id, 'ofc_records'
FROM ofc_records o
LEFT JOIN users u ON u.id = o.observer_id
WHERE u.id IS NULL

UNION ALL

SELECT
    'ORFAO', 'CRITICAL',
    'ofc_records.created_by',
    'OFS #' || o.sequential_number || ' referencia criador inexistente (' || o.created_by || ')',
    o.id, 'ofc_records'
FROM ofc_records o
LEFT JOIN users u ON u.id = o.created_by
WHERE u.id IS NULL

UNION ALL

SELECT
    'ORFAO', 'WARNING',
    'ofc_records.observed_user_id',
    'OFS #' || o.sequential_number || ' referencia observado inexistente (' || o.observed_user_id || ')',
    o.id, 'ofc_records'
FROM ofc_records o
WHERE o.observed_user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM users u WHERE u.id = o.observed_user_id)

UNION ALL

SELECT
    'ORFAO', 'WARNING',
    'ofc_records.department_id',
    'OFS #' || o.sequential_number || ' referencia departamento inexistente (' || o.department_id || ')',
    o.id, 'ofc_records'
FROM ofc_records o
WHERE o.department_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM departments d WHERE d.id = o.department_id)

UNION ALL

SELECT
    'ORFAO', 'WARNING',
    'ofc_records.competency_id',
    'OFS #' || o.sequential_number || ' referencia competencia inexistente (' || o.competency_id || ')',
    o.id, 'ofc_records'
FROM ofc_records o
WHERE o.competency_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM competencies comp WHERE comp.id = o.competency_id)

UNION ALL

SELECT
    'ORFAO', 'WARNING',
    'ofc_records.cycle_id',
    'OFS #' || o.sequential_number || ' referencia ciclo inexistente (' || o.cycle_id || ')',
    o.id, 'ofc_records'
FROM ofc_records o
WHERE o.cycle_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM evaluation_cycles ec WHERE ec.id = o.cycle_id)

UNION ALL

SELECT
    'ORFAO', 'WARNING',
    'ofs_records.provider_id',
    'OFS #' || ofs.id || ' referencia provedor inexistente (' || ofs.provider_id || ')',
    ofs.id, 'ofs_records'
FROM ofs_records ofs
LEFT JOIN users u ON u.id = ofs.provider_id
WHERE u.id IS NULL

UNION ALL

SELECT
    'ORFAO', 'WARNING',
    'ofs_records.receiver_id',
    'OFS #' || ofs.id || ' referencia receptor inexistente (' || ofs.receiver_id || ')',
    ofs.id, 'ofs_records'
FROM ofs_records ofs
LEFT JOIN users u ON u.id = ofs.receiver_id
WHERE u.id IS NULL

-- 9.1.2 INCONSISTÊNCIAS DE NEGÓCIO

UNION ALL

SELECT
    'INCONSISTENCIA', 'CRITICAL',
    'chk_ofc_cancel_requires_reason',
    'OFS #' || sequential_number || ' está cancelada mas cancel_reason é NULL',
    id, 'ofc_records'
FROM ofc_records
WHERE status = 'cancelled' AND (cancel_reason IS NULL OR TRIM(cancel_reason) = '')

UNION ALL

SELECT
    'INCONSISTENCIA', 'CRITICAL',
    'chk_ofc_cancel_requires_reason',
    'OFS #' || sequential_number || ' está cancelada mas cancelled_by é NULL',
    id, 'ofc_records'
FROM ofc_records
WHERE status = 'cancelled' AND cancelled_by IS NULL

UNION ALL

SELECT
    'INCONSISTENCIA', 'CRITICAL',
    'chk_ofc_cancel_requires_reason',
    'OFS #' || sequential_number || ' está cancelada mas cancelled_at é NULL',
    id, 'ofc_records'
FROM ofc_records
WHERE status = 'cancelled' AND cancelled_at IS NULL

UNION ALL

SELECT
    'INCONSISTENCIA', 'WARNING',
    'chk_ofc_observed_consistency',
    'OFS #' || sequential_number || ' não tem observed_user_id nem observed_name (ambos NULL)',
    id, 'ofc_records'
FROM ofc_records
WHERE observed_user_id IS NULL AND (observed_name IS NULL OR TRIM(observed_name) = '')

UNION ALL

SELECT
    'INCONSISTENCIA', 'WARNING',
    'chk_ofc_observation_date',
    'OFS #' || sequential_number || ' tem data de observação futura: ' || observation_date,
    id, 'ofc_records'
FROM ofc_records
WHERE observation_date > CURRENT_DATE

UNION ALL

SELECT
    'INCONSISTENCIA', 'WARNING',
    'chk_cycle_dates',
    'Ciclo #' || id || ' (' || title || ') tem end_date (' || end_date || ') <= start_date (' || start_date || ')',
    id, 'evaluation_cycles'
FROM evaluation_cycles
WHERE end_date <= start_date

UNION ALL

SELECT
    'INCONSISTENCIA', 'INFO',
    'chk_ofs_participants',
    'OFS #' || id || ' tem provider_id = receiver_id (auto-feedback)',
    id, 'ofs_records'
FROM ofs_records
WHERE provider_id = receiver_id

-- 9.1.3 SNAPSHOTS NÃO PREENCHIDOS

UNION ALL

SELECT
    'SNAPSHOT_VAZIO', 'WARNING',
    'observer_name_snapshot',
    'OFS #' || sequential_number || ' tem observer_name_snapshot NULL',
    id, 'ofc_records'
FROM ofc_records
WHERE observer_name_snapshot IS NULL AND observer_id IS NOT NULL

UNION ALL

SELECT
    'SNAPSHOT_VAZIO', 'INFO',
    'company_name_snapshot',
    'OFS #' || sequential_number || ' tem company_name_snapshot NULL',
    id, 'ofc_records'
FROM ofc_records
WHERE company_name_snapshot IS NULL AND company_id IS NOT NULL

-- 9.1.4 SNAPSHOTS DIVERGENTES (snapshot não reflete valor atual)

UNION ALL

SELECT
    'SNAPSHOT_DIVERGENTE', 'INFO',
    'observer_name_snapshot',
    'OFS #' || o.sequential_number ||
    ' snapshot observador = "' || o.observer_name_snapshot ||
    '" vs atual = "' || u.full_name || '"',
    o.id, 'ofc_records'
FROM ofc_records o
JOIN users u ON u.id = o.observer_id
WHERE o.observer_name_snapshot IS NOT NULL
  AND o.observer_name_snapshot <> u.full_name

UNION ALL

SELECT
    'SNAPSHOT_DIVERGENTE', 'INFO',
    'company_name_snapshot',
    'OFS #' || o.sequential_number ||
    ' snapshot empresa = "' || o.company_name_snapshot ||
    '" vs atual = "' || c.name || '"',
    o.id, 'ofc_records'
FROM ofc_records o
JOIN companies c ON c.id = o.company_id
WHERE o.company_name_snapshot IS NOT NULL
  AND o.company_name_snapshot <> c.name

-- 9.1.5 CICLOS COM STATUS INVÁLIDO

UNION ALL

SELECT
    'INCONSISTENCIA', 'WARNING',
    'cycle_status',
    'Ciclo #' || id || ' (' || title || ') está ativo fora do período: ' || start_date || ' a ' || end_date,
    id, 'evaluation_cycles'
FROM evaluation_cycles
WHERE status = 'active'
  AND (CURRENT_DATE < start_date OR CURRENT_DATE > end_date)

-- 9.1.6 DEPARTAMENTOS CIRCULARES (auto-referência)
-- Detecta se um departamento é pai de si mesmo (direto ou indireto)
-- Usa CTE recursiva para detectar ciclos

UNION ALL

WITH RECURSIVE dept_tree AS (
    SELECT id, parent_id, name, ARRAY[id] AS path, 0 AS depth
    FROM departments
    WHERE parent_id IS NOT NULL
    UNION ALL
    SELECT d.id, d.parent_id, d.name, dt.path || d.id, dt.depth + 1
    FROM departments d
    JOIN dept_tree dt ON dt.parent_id = d.id
    WHERE NOT d.id = ANY(dt.path)  -- evita loop infinito
      AND dt.depth < 50            -- limite de segurança
)
SELECT
    'REFERENCIA_CIRCULAR', 'CRITICAL',
    'departments.parent_id',
    'Departamento #' || id || ' (' || name || ') em ciclo hierárquico',
    id, 'departments'
FROM (
    SELECT DISTINCT id, name FROM dept_tree
    WHERE parent_id = ANY(path)  -- detecta ciclo
) sub

-- 9.1.7 COMPETÊNCIAS CIRCULARES (auto-referência)

UNION ALL

WITH RECURSIVE comp_tree AS (
    SELECT id, parent_id, name, ARRAY[id] AS path, 0 AS depth
    FROM competencies
    WHERE parent_id IS NOT NULL
    UNION ALL
    SELECT c.id, c.parent_id, c.name, ct.path || c.id, ct.depth + 1
    FROM competencies c
    JOIN comp_tree ct ON ct.parent_id = c.id
    WHERE NOT c.id = ANY(ct.path)
      AND ct.depth < 50
)
SELECT
    'REFERENCIA_CIRCULAR', 'CRITICAL',
    'competencies.parent_id',
    'Competencia #' || id || ' (' || name || ') em ciclo hierárquico',
    id, 'competencies'
FROM (
    SELECT DISTINCT id, name FROM comp_tree
    WHERE parent_id = ANY(path)
) sub

-- 9.1.8 USUÁRIOS COM GESTOR CIRCULAR

UNION ALL

WITH RECURSIVE mgr_tree AS (
    SELECT id, manager_id, full_name, ARRAY[id] AS path, 0 AS depth
    FROM users
    WHERE manager_id IS NOT NULL
    UNION ALL
    SELECT u.id, u.manager_id, u.full_name, mt.path || u.id, mt.depth + 1
    FROM users u
    JOIN mgr_tree mt ON mt.manager_id = u.id
    WHERE NOT u.id = ANY(mt.path)
      AND mt.depth < 50
)
SELECT
    'REFERENCIA_CIRCULAR', 'CRITICAL',
    'users.manager_id',
    'Usuario #' || id || ' (' || full_name || ') em ciclo de gestor',
    id, 'users'
FROM (
    SELECT DISTINCT id, full_name FROM mgr_tree
    WHERE manager_id = ANY(path)
) sub;


COMMENT ON VIEW vw_integrity_issues IS
'Visão consolidada de problemas de integridade: órfãos, inconsistências,
 snapshots vazios/divergentes e referências circulares.
 Execute: SELECT * FROM vw_integrity_issues ORDER BY severity, issue_type;';


-- --------------------------------------------------------------------------
-- 9.2 FUNÇÃO: Verificação rápida de integridade (retorna contagem por tipo)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_integrity()
RETURNS TABLE (
    issue_type    TEXT,
    severity      TEXT,
    issue_count   BIGINT
)
LANGUAGE sql
STABLE
AS $$
    SELECT issue_type, severity, COUNT(*)::BIGINT
    FROM vw_integrity_issues
    GROUP BY issue_type, severity
    ORDER BY
        CASE severity
            WHEN 'CRITICAL' THEN 1
            WHEN 'WARNING'  THEN 2
            WHEN 'INFO'     THEN 3
        END,
        issue_type;
$$;

COMMENT ON FUNCTION fn_check_integrity() IS
'Retorna contagem de problemas de integridade por tipo e severidade.
 Execução rápida (< 100ms para volumes típicos). Use em health checks.';


-- --------------------------------------------------------------------------
-- 9.3 QUERY: Encontrar órfãos específicos (útil para debugging)
-- --------------------------------------------------------------------------
-- OFCs sem empresa:
-- SELECT * FROM ofc_records o
-- WHERE NOT EXISTS (SELECT 1 FROM companies c WHERE c.id = o.company_id);

-- OFCs sem observador:
-- SELECT * FROM ofc_records o
-- WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = o.observer_id);

-- OFCs sem criador:
-- SELECT * FROM ofc_records o
-- WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = o.created_by);

-- Departamentos sem empresa:
-- SELECT * FROM departments d
-- WHERE NOT EXISTS (SELECT 1 FROM companies c WHERE c.id = d.company_id);

-- Usuários sem empresa:
-- SELECT * FROM users u
-- WHERE NOT EXISTS (SELECT 1 FROM companies c WHERE c.id = u.company_id);


-- --------------------------------------------------------------------------
-- 9.4 QUERY: Validar snapshots (comparação com valores atuais)
-- --------------------------------------------------------------------------
-- Observadores cujo nome snapshot diverge do nome atual:
-- SELECT
--     o.id, o.sequential_number,
--     o.observer_name_snapshot AS snapshot,
--     u.full_name              AS atual,
--     o.created_at
-- FROM ofc_records o
-- JOIN users u ON u.id = o.observer_id
-- WHERE o.observer_name_snapshot IS NOT NULL
--   AND o.observer_name_snapshot <> u.full_name
-- ORDER BY o.created_at DESC
-- LIMIT 100;

-- Empresas cujo nome snapshot diverge do nome atual:
-- SELECT
--     o.id, o.sequential_number,
--     o.company_name_snapshot AS snapshot,
--     c.name                  AS atual,
--     o.created_at
-- FROM ofc_records o
-- JOIN companies c ON c.id = o.company_id
-- WHERE o.company_name_snapshot IS NOT NULL
--   AND o.company_name_snapshot <> c.name
-- ORDER BY o.created_at DESC
-- LIMIT 100;


-- --------------------------------------------------------------------------
-- 9.5 QUERY: Encontrar inconsistências de cancelamento
-- --------------------------------------------------------------------------
-- OFCs canceladas sem motivo, sem cancelled_by ou sem cancelled_at:
-- SELECT id, sequential_number, status, cancel_reason, cancelled_by, cancelled_at
-- FROM ofc_records
-- WHERE status = 'cancelled'
--   AND (cancel_reason IS NULL OR cancelled_by IS NULL OR cancelled_at IS NULL)
-- ORDER BY sequential_number;


-- --------------------------------------------------------------------------
-- 9.6 QUERY: Verificar violações de sequential_number
-- --------------------------------------------------------------------------
-- Números sequenciais duplicados:
-- SELECT sequential_number, COUNT(*) AS ocorrencias
-- FROM ofc_records
-- GROUP BY sequential_number
-- HAVING COUNT(*) > 1
-- ORDER BY sequential_number;

-- Gaps na sequência (números ausentes):
-- SELECT seq AS missing_sequential
-- FROM generate_series(1, (SELECT MAX(sequential_number) FROM ofc_records)) AS seq
-- WHERE NOT EXISTS (
--     SELECT 1 FROM ofc_records WHERE sequential_number = seq
-- )
-- ORDER BY seq;


-- ============================================================================
-- SEÇÃO 10: PERMISSÕES — REFORÇO DE PRIVILÉGIOS MÍNIMOS
-- ============================================================================

-- 10.1 ofc_edit_log: apenas INSERT + SELECT (histórico imutável)
-- (Já feito na migration v3, reforçado aqui)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ofs_app_role') THEN
        REVOKE UPDATE, DELETE ON ofc_edit_log FROM ofs_app_role;
    END IF;
END;
$$;

-- 10.2 audit_logs: apenas INSERT + SELECT (append-only)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ofs_app_role') THEN
        REVOKE UPDATE, DELETE ON audit_logs FROM ofs_app_role;
    END IF;
END;
$$;

-- 10.3 ofc_records: REVOGAR DELETE do role da aplicação
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ofs_app_role') THEN
        REVOKE DELETE ON ofc_records FROM ofs_app_role;
    END IF;
END;
$$;

-- 10.4 ofc_records: REVOGAR UPDATE dos snapshots (imutáveis)
--     (O trigger já barra, mas revogar na permissão é defesa em profundidade)
--     Não revogamos UPDATE total porque a aplicação precisa editar outros campos.
--     O trigger trg_ofc_snapshot_immutable cuida disso.


-- ============================================================================
-- SEÇÃO 11: VERIFICAÇÃO PÓS-MIGRAÇÃO
-- ============================================================================
DO $$
DECLARE
    v_trigger_count INT;
    v_issue_count   BIGINT;
BEGIN
    -- Conta triggers de integridade ativos
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger
    WHERE tgname IN (
        'trg_prevent_ofc_delete',
        'trg_prevent_audit_update',
        'trg_prevent_audit_delete',
        'trg_prevent_editlog_delete',
        'trg_validate_ofc_cancel',
        'trg_prevent_ofc_uncancel',
        'trg_audit_ofc_cancel',
        'trg_prevent_tampering',
        'trg_ofc_soft_delete',
        'trg_ofc_fill_snapshots',
        'trg_ofc_snapshot_immutable'
    );

    RAISE NOTICE '============================================';
    RAISE NOTICE 'MIGRATION v4 — VERIFICAÇÃO PÓS-MIGRAÇÃO';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Triggers de integridade ativos: %', v_trigger_count;

    -- Verifica problemas de integridade
    SELECT COUNT(*) INTO v_issue_count FROM vw_integrity_issues WHERE severity = 'CRITICAL';
    IF v_issue_count > 0 THEN
        RAISE WARNING 'ATENÇÃO: % problemas CRITICAL encontrados! Execute: SELECT * FROM vw_integrity_issues WHERE severity = ''CRITICAL'';', v_issue_count;
    ELSE
        RAISE NOTICE 'Nenhum problema CRITICAL encontrado.';
    END IF;

    SELECT COUNT(*) INTO v_issue_count FROM vw_integrity_issues WHERE severity = 'WARNING';
    IF v_issue_count > 0 THEN
        RAISE NOTICE 'Problemas WARNING: %. Execute: SELECT * FROM vw_integrity_issues WHERE severity = ''WARNING'';', v_issue_count;
    END IF;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'Triggers implementados:';
    RAISE NOTICE '  1. trg_prevent_ofc_delete        → Bloqueia DELETE físico em ofc_records';
    RAISE NOTICE '  2. trg_prevent_audit_update       → Bloqueia UPDATE em audit_logs';
    RAISE NOTICE '  3. trg_prevent_audit_delete       → Bloqueia DELETE em audit_logs';
    RAISE NOTICE '  4. trg_prevent_editlog_delete     → Bloqueia DELETE em ofc_edit_log';
    RAISE NOTICE '  5. trg_validate_ofc_cancel        → Valida cancelamento (motivo+responsável)';
    RAISE NOTICE '  6. trg_prevent_ofc_uncancel       → Impede reabertura de OFS cancelada';
    RAISE NOTICE '  7. trg_audit_ofc_cancel           → Registra cancelamento no audit_logs';
    RAISE NOTICE '  8. trg_prevent_tampering          → Impede alteração de id/created_at/created_by';
    RAISE NOTICE '  9. trg_ofc_soft_delete            → Transforma DELETE em soft delete';
    RAISE NOTICE ' 10. trg_ofc_fill_snapshots         → Preenche snapshots no INSERT';
    RAISE NOTICE ' 11. trg_ofc_snapshot_immutable     → Bloqueia UPDATE nos snapshots';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Constraints adicionadas:';
    RAISE NOTICE '  - chk_ofc_cancel_requires_reason  → Cancelamento exige motivo';
    RAISE NOTICE '  - chk_ofc_observed_consistency    → Consistência observado';
    RAISE NOTICE '  - chk_ofc_sequential_positive     → sequential_number > 0';
    RAISE NOTICE '  - uq_ofc_sequential_number        → UNIQUE sequential_number';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Colunas adicionadas em ofc_records:';
    RAISE NOTICE '  - is_deleted, deleted_at, deleted_by, deleted_reason (soft delete)';
    RAISE NOTICE '  - observer_name_snapshot, company_name_snapshot (snapshots)';
    RAISE NOTICE '============================================';
END;
$$;


-- ============================================================================
-- RESUMO DAS DECISÕES DE INTEGRIDADE
-- ============================================================================
--
-- 1. FOREIGN KEYS:
--    - RESTRICT para entidades CORE (companies, users criadores/observadores)
--    - CASCADE para dependentes (cycle_goals, action_plans de usuário removido)
--    - SET NULL para referências opcionais/contextuais
--
-- 2. DELETE FÍSICO: NUNCA em ofc_records, audit_logs, ofc_edit_log
--
-- 3. SOFT DELETE: Via is_deleted=TRUE. View vw_ofc_records_active filtra automaticamente.
--
-- 4. SNAPSHOTS: observer_name_snapshot + company_name_snapshot preenchidos no INSERT.
--    Imutáveis após criação. Garantem rastreabilidade mesmo se nomes mudarem.
--
-- 5. INATIVAÇÃO > DELEÇÃO: Empresas e usuários são desativados (is_active=FALSE),
--    nunca deletados. Anonimização para LGPD preserva FKs.
--
-- 6. RETENÇÃO:
--    - revoked_tokens: limpeza diária (expired)
--    - audit_logs: particionamento mensal, expurgo de partições > 2 anos
--    - ofc_records: retenção permanente (soft delete apenas)
--
-- 7. VERIFICAÇÃO: View vw_integrity_issues para monitoramento contínuo.
--    Função fn_check_integrity() para health checks rápidos.
--
-- ============================================================================
-- FIM DA MIGRAÇÃO v4 — INTEGRIDADE DE DADOS COMPLETA
-- ============================================================================
