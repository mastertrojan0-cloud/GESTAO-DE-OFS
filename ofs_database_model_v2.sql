-- ============================================================================
-- SISTEMA DE FEEDBACK COMPORTAMENTAL OFS/OFS — MODELAGEM REVISADA v2
-- Security Dynamics | PostgreSQL 16 | Python/FastAPI + SQLAlchemy 2.0 (async)
-- 100% TEXTUAL — sem anexos, uploads, mídia ou arquivos binários
-- Data: 13/05/2026
-- ============================================================================

-- ============================================================================
-- 1. EXTENSÕES
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";       -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "unaccent";       -- remoção de acentos para busca
CREATE EXTENSION IF NOT EXISTS "pg_trgm";         -- trigramas para LIKE/ILIKE

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'portuguese') THEN
        CREATE TEXT SEARCH CONFIGURATION portuguese (COPY = pg_catalog.simple);
    END IF;
END;
$$;


-- ============================================================================
-- 2. SEQUENCES
-- ============================================================================
CREATE SEQUENCE seq_ofc_sequential
    START WITH 1
    INCREMENT BY 1
    NO CYCLE
    CACHE 10;


-- ============================================================================
-- 3. TABELAS ESSENCIAIS (10 tabelas)
-- ============================================================================

-- --------------------------------------------------------------------------
-- 3.1 companies — Empresas/organizações (multi-tenant)
-- --------------------------------------------------------------------------
CREATE TABLE companies (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(200)    NOT NULL UNIQUE,
    document    VARCHAR(18)     UNIQUE,              -- CNPJ (somente dígitos)
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE companies IS 'Empresas/organizações participantes do sistema';
COMMENT ON COLUMN companies.document IS 'CNPJ com 14 dígitos, sem pontuação';


-- --------------------------------------------------------------------------
-- 3.2 departments — Departamentos (hierárquico)
-- --------------------------------------------------------------------------
CREATE TABLE departments (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID            NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    parent_id   UUID            REFERENCES departments(id) ON DELETE SET NULL,
    name        VARCHAR(200)    NOT NULL,
    manager_id  UUID            REFERENCES users(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED,
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE departments IS 'Estrutura organizacional hierárquica (diretorias, gerências, setores)';
COMMENT ON COLUMN departments.parent_id IS 'Departamento superior na hierarquia (NULL = raiz)';


-- --------------------------------------------------------------------------
-- 3.3 users — Usuários do sistema
-- --------------------------------------------------------------------------
CREATE TABLE users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id      UUID            NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    department_id   UUID            REFERENCES departments(id) ON DELETE SET NULL,
    manager_id      UUID            REFERENCES users(id) ON DELETE SET NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,
    full_name       VARCHAR(300)    NOT NULL,
    role            VARCHAR(20)     NOT NULL DEFAULT 'employee'
                                    CHECK (role IN ('admin','manager','supervisor','employee')),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    last_login      TIMESTAMPTZ,
    login_attempts  INT             NOT NULL DEFAULT 0,
    locked_until    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE users IS 'Usuários autenticados do sistema (todos os perfis)';
COMMENT ON COLUMN users.manager_id IS 'Gestor/líder direto (reporting line)';
COMMENT ON COLUMN users.role IS 'admin | manager | supervisor | employee';


-- --------------------------------------------------------------------------
-- 3.4 competencies — Catálogo de competências comportamentais (hierárquico)
-- --------------------------------------------------------------------------
CREATE TABLE competencies (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID            NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    parent_id   UUID            REFERENCES competencies(id) ON DELETE SET NULL,
    name        VARCHAR(300)    NOT NULL,
    description TEXT,
    is_group    BOOLEAN         NOT NULL DEFAULT FALSE,  -- TRUE = categoria/agrupador
    sort_order  INT             NOT NULL DEFAULT 0,
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE competencies IS 'Catálogo de competências comportamentais avaliáveis';
COMMENT ON COLUMN competencies.is_group IS 'TRUE = nó agrupador (ex: Liderança), FALSE = competência avaliável (ex: Delegação)';


-- --------------------------------------------------------------------------
-- 3.5 evaluation_cycles — Ciclos avaliativos
-- --------------------------------------------------------------------------
CREATE TABLE evaluation_cycles (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  UUID            NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    title       VARCHAR(300)    NOT NULL,
    description TEXT,
    start_date  DATE            NOT NULL,
    end_date    DATE            NOT NULL,
    status      VARCHAR(20)     NOT NULL DEFAULT 'draft'
                                CHECK (status IN ('draft','active','closed')),
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_cycle_dates CHECK (end_date > start_date)
);

COMMENT ON TABLE evaluation_cycles IS 'Períodos de avaliação (trimestral, semestral, anual)';
COMMENT ON COLUMN evaluation_cycles.status IS 'draft = rascunho | active = em andamento | closed = encerrado';


-- --------------------------------------------------------------------------
-- 3.6 cycle_goals — Metas individuais por ciclo (cálculo automático via trigger)
-- --------------------------------------------------------------------------
CREATE TABLE cycle_goals (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    cycle_id        UUID            NOT NULL REFERENCES evaluation_cycles(id) ON DELETE CASCADE,
    user_id         UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    competency_id   UUID            REFERENCES competencies(id) ON DELETE CASCADE,
    target_positive INT             NOT NULL DEFAULT 0 CHECK (target_positive >= 0),
    max_negative    INT             NOT NULL DEFAULT 0 CHECK (max_negative >= 0),
    actual_positive INT             NOT NULL DEFAULT 0,
    actual_negative INT             NOT NULL DEFAULT 0,
    is_achieved     BOOLEAN         NOT NULL DEFAULT FALSE,
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_cycle_user_competency UNIQUE (cycle_id, user_id, competency_id)
);

COMMENT ON TABLE cycle_goals IS 'Metas comportamentais por usuário, ciclo e competência';
COMMENT ON COLUMN cycle_goals.competency_id IS 'NULL = meta global do ciclo (agregada)';
COMMENT ON COLUMN cycle_goals.target_positive IS 'Quantidade mínima de OFCs positivas esperadas';
COMMENT ON COLUMN cycle_goals.max_negative IS 'Quantidade máxima de OFCs negativas toleradas';
COMMENT ON COLUMN cycle_goals.actual_positive IS 'Calculado automaticamente via trigger (OFCs positivas realizadas)';
COMMENT ON COLUMN cycle_goals.actual_negative IS 'Calculado automaticamente via trigger (OFCs negativas realizadas)';


-- --------------------------------------------------------------------------
-- 3.7 ofc_records — Observações de Fato Comportamental (TABELA PRINCIPAL)
-- --------------------------------------------------------------------------
CREATE TABLE ofc_records (
    -- Identificação
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    sequential_number   INT             NOT NULL DEFAULT nextval('seq_ofc_sequential'),
    company_id          UUID            NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    department_id       UUID            REFERENCES departments(id) ON DELETE SET NULL,
    cycle_id            UUID            REFERENCES evaluation_cycles(id) ON DELETE SET NULL,

    -- Observador
    observer_id         UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    -- Observado (externo = nome livre; interno = FK para users)
    observed_name       VARCHAR(300)    NOT NULL,
    observed_user_id    UUID            REFERENCES users(id) ON DELETE SET NULL,

    -- Competência observada
    competency_id       UUID            REFERENCES competencies(id) ON DELETE SET NULL,

    -- Datas
    observation_date    DATE            NOT NULL DEFAULT CURRENT_DATE
                                        CHECK (observation_date <= CURRENT_DATE),

    -- Classificação
    shift               VARCHAR(50),
    classification      VARCHAR(20)     NOT NULL DEFAULT 'positive'
                                        CHECK (classification IN ('positive','negative','neutral')),
    severity            VARCHAR(20)     DEFAULT 'low'
                                        CHECK (severity IN ('low','medium','high','critical')),

    -- Conteúdo textual (100% textual)
    behavior_description TEXT           NOT NULL,
    context             TEXT,
    location            VARCHAR(300),
    activity_context    VARCHAR(300),

    -- Status e rastreabilidade
    status              VARCHAR(20)     NOT NULL DEFAULT 'open'
                                        CHECK (status IN ('open','acknowledged','discussed','closed','cancelled')),
    cancel_reason       TEXT,
    cancelled_by        UUID            REFERENCES users(id) ON DELETE SET NULL,
    cancelled_at        TIMESTAMPTZ,
    created_by          UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE ofc_records IS 'Registros de Observação de Fato Comportamental (OFS) — tabela principal do sistema';
COMMENT ON COLUMN ofc_records.sequential_number IS 'Número sequencial visível (OFS #1523)';
COMMENT ON COLUMN ofc_records.observed_name IS 'Nome da pessoa observada (obrigatório; pode ser usuário interno ou pessoa externa)';
COMMENT ON COLUMN ofc_records.observed_user_id IS 'NULL se pessoa externa; preenchido se for usuário do sistema';
COMMENT ON COLUMN ofc_records.classification IS 'positive = comportamento seguro/desejado | negative = comportamento inseguro/indesejado | neutral = observação neutra';
COMMENT ON COLUMN ofc_records.status IS 'open | acknowledged | discussed | closed | cancelled';


-- --------------------------------------------------------------------------
-- 3.8 ofc_edit_log — Histórico de edições nos registros OFS
-- --------------------------------------------------------------------------
CREATE TABLE ofc_edit_log (
    id              BIGSERIAL       PRIMARY KEY,
    ofc_record_id   UUID            NOT NULL REFERENCES ofc_records(id) ON DELETE CASCADE,
    edited_by       UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    field_name      VARCHAR(100)    NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    edited_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE ofc_edit_log IS 'Histórico de alterações campo a campo nos registros OFS';


-- --------------------------------------------------------------------------
-- 3.9 ofs_records — Sessões de Feedback Situacional (OFS)
-- --------------------------------------------------------------------------
CREATE TABLE ofs_records (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id      UUID            NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    cycle_id        UUID            REFERENCES evaluation_cycles(id) ON DELETE SET NULL,
    ofc_record_id   UUID            REFERENCES ofc_records(id) ON DELETE SET NULL,

    -- Participantes
    provider_id     UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    receiver_id     UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    -- Conteúdo
    title           VARCHAR(300)    NOT NULL,
    content         TEXT            NOT NULL,
    session_date    DATE            NOT NULL DEFAULT CURRENT_DATE,
    feedback_type   VARCHAR(30)     NOT NULL DEFAULT 'developmental'
                                    CHECK (feedback_type IN ('recognition','developmental','corrective','evaluative')),

    -- Status
    status          VARCHAR(20)     NOT NULL DEFAULT 'draft'
                                    CHECK (status IN ('draft','shared','acknowledged','closed')),
    acknowledged_at TIMESTAMPTZ,

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_ofs_participants CHECK (provider_id <> receiver_id)
);

COMMENT ON TABLE ofs_records IS 'Sessões de feedback situacional entre usuários do sistema';
COMMENT ON COLUMN ofs_records.feedback_type IS 'recognition | developmental | corrective | evaluative';
COMMENT ON COLUMN ofs_records.status IS 'draft | shared | acknowledged | closed';


-- --------------------------------------------------------------------------
-- 3.10 action_plans — Planos de ação (PDI — Plano de Desenvolvimento Individual)
-- --------------------------------------------------------------------------
CREATE TABLE action_plans (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id      UUID            NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    user_id         UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ofs_record_id   UUID            REFERENCES ofs_records(id) ON DELETE SET NULL,
    competency_id   UUID            REFERENCES competencies(id) ON DELETE SET NULL,
    title           VARCHAR(300)    NOT NULL,
    description     TEXT,
    target_date     DATE,
    progress        INT             NOT NULL DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    status          VARCHAR(20)     NOT NULL DEFAULT 'pending'
                                    CHECK (status IN ('pending','in_progress','completed','cancelled')),
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE action_plans IS 'Planos de ação/desenvolvimento individual decorrentes de feedbacks';


-- ============================================================================
-- 4. ÍNDICES OTIMIZADOS
-- ============================================================================

-- --------------------------------------------------------------------------
-- 4.1 ofc_records — Índices de alta criticidade (95% das consultas)
-- --------------------------------------------------------------------------

-- Consulta por período (MAIS IMPORTANTE)
CREATE INDEX idx_ofc_obs_date        ON ofc_records (observation_date DESC);

-- Métricas: empresa + data + classificação (índice composto mais usado)
CREATE INDEX idx_ofc_metrics         ON ofc_records (company_id, observation_date, classification)
                                     WHERE status != 'cancelled';

-- Filtro por observador
CREATE INDEX idx_ofc_observer        ON ofc_records (observer_id, observation_date DESC);

-- Filtro por observado (usuário interno)
CREATE INDEX idx_ofc_observed_user   ON ofc_records (observed_user_id, observation_date DESC)
                                     WHERE observed_user_id IS NOT NULL;

-- Filtro por ciclo avaliativo
CREATE INDEX idx_ofc_cycle           ON ofc_records (cycle_id, observation_date DESC)
                                     WHERE cycle_id IS NOT NULL;

-- Filtro por competência
CREATE INDEX idx_ofc_competency      ON ofc_records (competency_id)
                                     WHERE competency_id IS NOT NULL;

-- Filtro por departamento
CREATE INDEX idx_ofc_department      ON ofc_records (department_id)
                                     WHERE department_id IS NOT NULL;

-- Filtro por status
CREATE INDEX idx_ofc_status          ON ofc_records (status, observation_date DESC);

-- Busca por classificação
CREATE INDEX idx_ofc_classification  ON ofc_records (classification, observation_date DESC);

-- Número sequencial (lookup por nº OFS)
CREATE UNIQUE INDEX idx_ofc_sequential ON ofc_records (sequential_number);

-- Busca por turno
CREATE INDEX idx_ofc_shift           ON ofc_records (shift)
                                     WHERE shift IS NOT NULL;

-- Full-Text Search em português (busca textual nos campos descritivos)
CREATE INDEX idx_ofc_fts             ON ofc_records
    USING GIN (to_tsvector('portuguese',
        COALESCE(observed_name, '')     || ' ' ||
        COALESCE(behavior_description, '') || ' ' ||
        COALESCE(context, '')          || ' ' ||
        COALESCE(location, '')         || ' ' ||
        COALESCE(activity_context, '')
    ));

-- Busca por nome do observado com trigramas (suporte a LIKE '%nome%')
CREATE INDEX idx_ofc_observed_name_trgm ON ofc_records
    USING GIN (observed_name gin_trgm_ops);


-- --------------------------------------------------------------------------
-- 4.2 users — Índices
-- --------------------------------------------------------------------------
CREATE INDEX idx_users_company       ON users (company_id);
-- email já é UNIQUE (índice implícito)
CREATE INDEX idx_users_role          ON users (role) WHERE is_active = TRUE;
CREATE INDEX idx_users_department    ON users (department_id) WHERE department_id IS NOT NULL;
CREATE INDEX idx_users_manager       ON users (manager_id) WHERE manager_id IS NOT NULL;


-- --------------------------------------------------------------------------
-- 4.3 departments — Índices
-- --------------------------------------------------------------------------
CREATE INDEX idx_dept_company        ON departments (company_id);
CREATE INDEX idx_dept_parent         ON departments (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_dept_manager        ON departments (manager_id) WHERE manager_id IS NOT NULL;


-- --------------------------------------------------------------------------
-- 4.4 competencies — Índices
-- --------------------------------------------------------------------------
CREATE INDEX idx_comp_company        ON competencies (company_id);
CREATE INDEX idx_comp_parent         ON competencies (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_comp_active         ON competencies (company_id, is_group, sort_order)
                                     WHERE is_active = TRUE;


-- --------------------------------------------------------------------------
-- 4.5 evaluation_cycles — Índices
-- --------------------------------------------------------------------------
CREATE INDEX idx_cycle_company       ON evaluation_cycles (company_id, start_date DESC);
CREATE INDEX idx_cycle_active        ON evaluation_cycles (company_id, status, start_date)
                                     WHERE status = 'active';


-- --------------------------------------------------------------------------
-- 4.6 cycle_goals — Índices
-- --------------------------------------------------------------------------
CREATE INDEX idx_goal_cycle          ON cycle_goals (cycle_id);
CREATE INDEX idx_goal_user           ON cycle_goals (user_id);
-- UNIQUE (cycle_id, user_id, competency_id) já cria índice composto


-- --------------------------------------------------------------------------
-- 4.7 ofc_edit_log — Índices
-- --------------------------------------------------------------------------
CREATE INDEX idx_edit_log_ofc        ON ofc_edit_log (ofc_record_id, edited_at DESC);
CREATE INDEX idx_edit_log_editor     ON ofc_edit_log (edited_by, edited_at DESC);


-- --------------------------------------------------------------------------
-- 4.8 ofs_records — Índices
-- --------------------------------------------------------------------------
CREATE INDEX idx_ofs_provider        ON ofs_records (provider_id, session_date DESC);
CREATE INDEX idx_ofs_receiver        ON ofs_records (receiver_id, session_date DESC);
CREATE INDEX idx_ofs_cycle           ON ofs_records (cycle_id) WHERE cycle_id IS NOT NULL;
CREATE INDEX idx_ofs_company_date    ON ofs_records (company_id, session_date DESC);
CREATE INDEX idx_ofs_status          ON ofs_records (status) WHERE status != 'closed';
CREATE INDEX idx_ofs_ofc_link        ON ofs_records (ofc_record_id) WHERE ofc_record_id IS NOT NULL;


-- --------------------------------------------------------------------------
-- 4.9 action_plans — Índices
-- --------------------------------------------------------------------------
CREATE INDEX idx_plan_user           ON action_plans (user_id, status);
CREATE INDEX idx_plan_ofs            ON action_plans (ofs_record_id) WHERE ofs_record_id IS NOT NULL;
CREATE INDEX idx_plan_status_date    ON action_plans (status, target_date)
                                     WHERE status IN ('pending','in_progress');
CREATE INDEX idx_plan_company        ON action_plans (company_id);


-- ============================================================================
-- 5. TRIGGERS
-- ============================================================================

-- --------------------------------------------------------------------------
-- 5.1 updated_at automático (aplica-se a todas as tabelas com updated_at)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplica o trigger em todas as tabelas com coluna updated_at
DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN
        SELECT table_name
        FROM information_schema.columns
        WHERE column_name = 'updated_at'
          AND table_schema = 'public'
          AND table_name NOT IN ('ofc_edit_log')  -- não tem updated_at
    LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_%I_updated_at
             BEFORE UPDATE ON %I
             FOR EACH ROW
             EXECUTE FUNCTION fn_set_updated_at()',
            tbl, tbl
        );
    END LOOP;
END;
$$;


-- --------------------------------------------------------------------------
-- 5.2 Cálculo automático de metas (cycle_goals) ao modificar ofc_records
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_recalc_cycle_goals()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_cycle_id UUID;
    v_user_id  UUID;
BEGIN
    -- Determina ciclo e usuário afetados (INSERT, UPDATE ou DELETE)
    v_cycle_id := COALESCE(NEW.cycle_id, OLD.cycle_id);
    v_user_id  := COALESCE(NEW.observed_user_id, OLD.observed_user_id);

    -- Só recalcula se houver ciclo e usuário interno vinculado
    IF v_cycle_id IS NOT NULL AND v_user_id IS NOT NULL THEN
        -- Atualiza metas GLOBAIS (competency_id IS NULL)
        UPDATE cycle_goals cg
        SET
            actual_positive = COALESCE((
                SELECT COUNT(*)
                FROM ofc_records
                WHERE cycle_id = v_cycle_id
                  AND observed_user_id = v_user_id
                  AND classification = 'positive'
                  AND status != 'cancelled'
            ), 0),
            actual_negative = COALESCE((
                SELECT COUNT(*)
                FROM ofc_records
                WHERE cycle_id = v_cycle_id
                  AND observed_user_id = v_user_id
                  AND classification = 'negative'
                  AND status != 'cancelled'
            ), 0),
            is_achieved = (
                COALESCE((
                    SELECT COUNT(*)
                    FROM ofc_records
                    WHERE cycle_id = v_cycle_id
                      AND observed_user_id = v_user_id
                      AND classification = 'positive'
                      AND status != 'cancelled'
                ), 0) >= cg.target_positive
                AND
                COALESCE((
                    SELECT COUNT(*)
                    FROM ofc_records
                    WHERE cycle_id = v_cycle_id
                      AND observed_user_id = v_user_id
                      AND classification = 'negative'
                      AND status != 'cancelled'
                ), 0) <= cg.max_negative
            ),
            updated_at = NOW()
        WHERE cycle_id = v_cycle_id
          AND user_id = v_user_id
          AND competency_id IS NULL;

        -- Atualiza metas POR COMPETÊNCIA (competency_id IS NOT NULL)
        UPDATE cycle_goals cg
        SET
            actual_positive = COALESCE((
                SELECT COUNT(*)
                FROM ofc_records
                WHERE cycle_id = v_cycle_id
                  AND observed_user_id = v_user_id
                  AND competency_id = cg.competency_id
                  AND classification = 'positive'
                  AND status != 'cancelled'
            ), 0),
            actual_negative = COALESCE((
                SELECT COUNT(*)
                FROM ofc_records
                WHERE cycle_id = v_cycle_id
                  AND observed_user_id = v_user_id
                  AND competency_id = cg.competency_id
                  AND classification = 'negative'
                  AND status != 'cancelled'
            ), 0),
            is_achieved = (
                COALESCE((
                    SELECT COUNT(*)
                    FROM ofc_records
                    WHERE cycle_id = v_cycle_id
                      AND observed_user_id = v_user_id
                      AND competency_id = cg.competency_id
                      AND classification = 'positive'
                      AND status != 'cancelled'
                ), 0) >= cg.target_positive
                AND
                COALESCE((
                    SELECT COUNT(*)
                    FROM ofc_records
                    WHERE cycle_id = v_cycle_id
                      AND observed_user_id = v_user_id
                      AND competency_id = cg.competency_id
                      AND classification = 'negative'
                      AND status != 'cancelled'
                ), 0) <= cg.max_negative
            ),
            updated_at = NOW()
        WHERE cycle_id = v_cycle_id
          AND user_id = v_user_id
          AND competency_id IS NOT NULL;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_ofc_recalc_goals
    AFTER INSERT OR UPDATE OF classification, status, cycle_id, observed_user_id
    ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_recalc_cycle_goals();

CREATE TRIGGER trg_ofc_recalc_goals_del
    AFTER DELETE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_recalc_cycle_goals();


-- ============================================================================
-- 6. VIEWS (Métricas e Consultas)
-- ============================================================================

-- 6.1 Métricas semanais agregadas
CREATE OR REPLACE VIEW vw_weekly_metrics AS
SELECT
    DATE_TRUNC('week', o.observation_date)::DATE            AS week_start,
    (DATE_TRUNC('week', o.observation_date) + INTERVAL '6 days')::DATE AS week_end,
    EXTRACT(WEEK FROM o.observation_date)::INT               AS week_number,
    EXTRACT(YEAR FROM o.observation_date)::INT               AS year_number,
    c.id                                                     AS company_id,
    c.name                                                   AS company_name,
    COUNT(*)                                                 AS total_records,
    COUNT(*) FILTER (WHERE o.classification = 'positive')    AS positive_count,
    COUNT(*) FILTER (WHERE o.classification = 'negative')    AS negative_count,
    COUNT(*) FILTER (WHERE o.classification = 'neutral')     AS neutral_count,
    ROUND(
        COUNT(*) FILTER (WHERE o.classification = 'positive')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                        AS safe_percentage,
    COUNT(DISTINCT o.observer_id)                            AS unique_observers,
    COUNT(DISTINCT o.observed_name)                          AS unique_observed,
    COUNT(DISTINCT o.observation_date)                       AS days_with_records
FROM ofc_records o
INNER JOIN companies c ON c.id = o.company_id
WHERE o.status != 'cancelled'
GROUP BY
    DATE_TRUNC('week', o.observation_date)::DATE,
    EXTRACT(WEEK FROM o.observation_date),
    EXTRACT(YEAR FROM o.observation_date),
    c.id, c.name
ORDER BY week_start DESC, c.name;


-- 6.2 Resumo diário
CREATE OR REPLACE VIEW vw_daily_summary AS
SELECT
    o.observation_date,
    o.company_id,
    c.name                                                   AS company_name,
    COUNT(*)                                                 AS total_records,
    COUNT(*) FILTER (WHERE o.classification = 'positive')    AS positive_count,
    COUNT(*) FILTER (WHERE o.classification = 'negative')    AS negative_count,
    COUNT(DISTINCT o.observer_id)                            AS unique_observers
FROM ofc_records o
INNER JOIN companies c ON c.id = o.company_id
WHERE o.status != 'cancelled'
GROUP BY o.observation_date, o.company_id, c.name
ORDER BY o.observation_date DESC, c.name;


-- 6.3 Progresso de metas por ciclo (visão gerencial)
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
             (cg.actual_positive::NUMERIC / cg.target_positive) >= 0.8 THEN 'ATENÇÃO'
        WHEN cg.target_positive > 0 THEN 'ALERTA'
        ELSE 'SEM_META'
    END                                                     AS goal_status
FROM cycle_goals cg
INNER JOIN evaluation_cycles ec ON ec.id = cg.cycle_id
INNER JOIN users u ON u.id = cg.user_id
LEFT JOIN competencies comp ON comp.id = cg.competency_id
ORDER BY ec.start_date DESC, u.full_name, comp.sort_order;


-- ============================================================================
-- 7. FUNÇÕES
-- ============================================================================

-- 7.1 Função de métricas por período (usada pela API de métricas)
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
    FROM ofc_records o
    INNER JOIN companies c ON c.id = o.company_id
    WHERE o.status != 'cancelled'
      AND o.observation_date BETWEEN p_start_date AND p_end_date
      AND (p_company_id IS NULL OR o.company_id = p_company_id)
    GROUP BY c.id, c.name
    ORDER BY c.name;
$$;


-- 7.2 Função de limpeza de tokens expirados (para cron job diário)
CREATE OR REPLACE FUNCTION cleanup_expired_tokens()
RETURNS INT
LANGUAGE sql
AS $$
    WITH deleted AS (
        DELETE FROM revoked_tokens
        WHERE expires_at < NOW()
        RETURNING id
    )
    SELECT COUNT(*)::INT FROM deleted;
$$;


-- ============================================================================
-- 8. SEED DATA
-- ============================================================================

-- 8.1 Empresas (15 registros)
INSERT INTO companies (id, name, document) VALUES
    ('a1000000-0000-0000-0000-000000000001', 'Security Dynamics',    '00123456000199'),
    ('a1000000-0000-0000-0000-000000000002', 'Polo Norte',           '00234567000188'),
    ('a1000000-0000-0000-0000-000000000003', 'G4S',                  '00345678000177'),
    ('a1000000-0000-0000-0000-000000000004', 'ERA',                  '00456789000166'),
    ('a1000000-0000-0000-0000-000000000005', 'Innovatec',            '00567890000155'),
    ('a1000000-0000-0000-0000-000000000006', 'Conin',                '00678901000144'),
    ('a1000000-0000-0000-0000-000000000007', 'FM',                   '00789012000133'),
    ('a1000000-0000-0000-0000-000000000008', 'Sodexo',               '00890123000122'),
    ('a1000000-0000-0000-0000-000000000009', 'Engecom',              '00901234000111'),
    ('a1000000-0000-0000-0000-000000000010', 'P&G',                  '01012345000100'),
    ('a1000000-0000-0000-0000-000000000011', 'Yusen',                '01123456000199'),
    ('a1000000-0000-0000-0000-000000000012', 'Mainpower',            '01234567000188'),
    ('a1000000-0000-0000-0000-000000000013', 'Aduana',               '01345678000177'),
    ('a1000000-0000-0000-0000-000000000014', 'Prosegur',             '01456789000166'),
    ('a1000000-0000-0000-0000-000000000015', 'Outros',               NULL)
ON CONFLICT (id) DO NOTHING;


-- 8.2 Departamento padrão (Security Dynamics)
INSERT INTO departments (id, company_id, name) VALUES
    ('b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'Diretoria'),
    ('b1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000001', 'Operações'),
    ('b1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000001', 'Recursos Humanos'),
    ('b1000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000001', 'Tecnologia')
ON CONFLICT (id) DO NOTHING;


-- 8.3 Competências comportamentais padrão (Security Dynamics)
-- Grupos (is_group = TRUE)
INSERT INTO competencies (id, company_id, parent_id, name, description, is_group, sort_order) VALUES
    ('c1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', NULL,
     'Comunicação', 'Habilidades de comunicação interpessoal', TRUE, 1),
    ('c1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000001', NULL,
     'Trabalho em Equipe', 'Colaboração e cooperação', TRUE, 2),
    ('c1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000001', NULL,
     'Liderança', 'Capacidade de liderar e influenciar', TRUE, 3),
    ('c1000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000001', NULL,
     'Segurança do Trabalho', 'Comportamentos relacionados à segurança ocupacional', TRUE, 4),
    ('c1000000-0000-0000-0000-000000000005', 'a1000000-0000-0000-0000-000000000001', NULL,
     'Resultados', 'Orientação a resultados e produtividade', TRUE, 5)
ON CONFLICT (id) DO NOTHING;

-- Competências folha (is_group = FALSE)
INSERT INTO competencies (id, company_id, parent_id, name, description, is_group, sort_order) VALUES
    -- Comunicação
    ('c1000000-0000-0000-0000-000000000010', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000001', 'Clareza na Comunicação',
     'Expressa ideias de forma clara e objetiva', FALSE, 1),
    ('c1000000-0000-0000-0000-000000000011', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000001', 'Escuta Ativa',
     'Demonstra atenção e compreensão ao ouvir o outro', FALSE, 2),
    -- Trabalho em Equipe
    ('c1000000-0000-0000-0000-000000000020', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000002', 'Cooperação',
     'Colabora ativamente com colegas para atingir objetivos comuns', FALSE, 1),
    ('c1000000-0000-0000-0000-000000000021', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000002', 'Resolução de Conflitos',
     'Aborda divergências de forma construtiva', FALSE, 2),
    -- Liderança
    ('c1000000-0000-0000-0000-000000000030', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000003', 'Delegação',
     'Distribui tarefas de forma equilibrada e confia na equipe', FALSE, 1),
    ('c1000000-0000-0000-0000-000000000031', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000003', 'Tomada de Decisão',
     'Analisa cenários e decide com agilidade e critério', FALSE, 2),
    -- Segurança do Trabalho
    ('c1000000-0000-0000-0000-000000000040', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000004', 'Uso de EPIs',
     'Utiliza corretamente os equipamentos de proteção individual', FALSE, 1),
    ('c1000000-0000-0000-0000-000000000041', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000004', 'Prevenção de Riscos',
     'Identifica e reporta situações de risco proativamente', FALSE, 2),
    ('c1000000-0000-0000-0000-000000000042', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000004', 'Procedimentos Operacionais',
     'Segue rigorosamente os procedimentos operacionais padrão', FALSE, 3),
    -- Resultados
    ('c1000000-0000-0000-0000-000000000050', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000005', 'Proatividade',
     'Antecipa problemas e age antes de ser solicitado', FALSE, 1),
    ('c1000000-0000-0000-0000-000000000051', 'a1000000-0000-0000-0000-000000000001',
     'c1000000-0000-0000-0000-000000000005', 'Qualidade',
     'Entrega trabalhos com alto padrão de qualidade', FALSE, 2)
ON CONFLICT (id) DO NOTHING;


-- 8.4 Usuário administrador
-- Senha: admin123 → bcrypt cost 12
-- ⚠️ ALTERAR EM PRODUÇÃO
INSERT INTO users (id, company_id, department_id, email, password_hash, full_name, role) VALUES
    ('d1000000-0000-0000-0000-000000000001',
     'a1000000-0000-0000-0000-000000000001',   -- Security Dynamics
     'b1000000-0000-0000-0000-000000000001',   -- Diretoria
     'admin@securitydynamics.com.br',
     '$2b$12$LJ3m4ys3GZfnYMz8kVsKaemhGQhfqB7xRVG4ED4xpDG7Xw5ZqWTEu',
     'Administrador do Sistema',
     'admin')
ON CONFLICT (id) DO NOTHING;


-- 8.5 Ciclo avaliativo ativo (2026 Q2)
INSERT INTO evaluation_cycles (id, company_id, title, description, start_date, end_date, status) VALUES
    ('e1000000-0000-0000-0000-000000000001',
     'a1000000-0000-0000-0000-000000000001',
     'Ciclo 2026 Q2 — Abril a Junho',
     'Segundo trimestre de 2026 — Avaliação de competências comportamentais',
     '2026-04-01', '2026-06-30', 'active')
ON CONFLICT (id) DO NOTHING;


-- 8.6 Meta global do admin para o ciclo ativo
INSERT INTO cycle_goals (cycle_id, user_id, competency_id, target_positive, max_negative) VALUES
    ('e1000000-0000-0000-0000-000000000001',
     'd1000000-0000-0000-0000-000000000001',
     NULL,    -- meta global
     10,      -- mínimo 10 observações positivas
     2)       -- máximo 2 observações negativas
ON CONFLICT (cycle_id, user_id, competency_id) DO NOTHING;


-- ============================================================================
-- 9. CONFIGURAÇÃO DE AUTOVACUUM (tabela de alto volume)
-- ============================================================================
ALTER TABLE ofc_records SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.005,
    autovacuum_vacuum_cost_delay = 5,
    autovacuum_vacuum_cost_limit = 2000,
    fillfactor = 85
);

ALTER TABLE ofc_edit_log SET (
    autovacuum_vacuum_scale_factor = 0.05,
    fillfactor = 90
);

ALTER TABLE ofs_records SET (
    autovacuum_vacuum_scale_factor = 0.02,
    fillfactor = 85
);
