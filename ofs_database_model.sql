-- ======================================================================
-- SISTEMA DE FEEDBACK COMPORTAMENTAL OFS/OFS
-- Security Dynamics | Modelo Relacional Completo
-- PostgreSQL 16 | Python/FastAPI + SQLAlchemy 2.0 (async) + Alembic
-- ======================================================================

-- ======================================================================
-- 1. EXTENSÕES NECESSÁRIAS
-- ======================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Configuração de busca textual em português (fallback: simple)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'portuguese') THEN
        CREATE TEXT SEARCH CONFIGURATION portuguese (COPY = pg_catalog.simple);
    END IF;
END;
$$;


-- ======================================================================
-- 2. TABELAS
-- ======================================================================

-- 2.1 Companies (Empresas)
CREATE TABLE companies (
    id              SERIAL          PRIMARY KEY,
    name            VARCHAR(150)    NOT NULL UNIQUE,
    is_custom       BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- 2.2 Users (Usuários do sistema)
CREATE TABLE users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(100)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,
    full_name       VARCHAR(200)    NOT NULL,
    email           VARCHAR(200),
    role            VARCHAR(20)     NOT NULL CHECK (role IN ('observador','supervisor','gestor','admin')),
    company_id      INT             REFERENCES companies(id) ON DELETE RESTRICT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    last_login      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ
);


-- 2.3 Contracts (Contratos / Áreas de atuação)
CREATE TABLE contracts (
    id              SERIAL          PRIMARY KEY,
    name            VARCHAR(200)    NOT NULL,
    company_id      INT             NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    description     TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- 2.4 Targets (Metas de OFS por pessoa/contrato)
CREATE TABLE targets (
    id              SERIAL          PRIMARY KEY,
    company_id      INT             REFERENCES companies(id) ON DELETE RESTRICT,
    contract_id     INT             REFERENCES contracts(id) ON DELETE CASCADE,
    daily_target    INT             NOT NULL DEFAULT 5,
    weekly_target   INT             NOT NULL DEFAULT 25,
    active_people   INT             NOT NULL DEFAULT 1,
    active_users    INT             NOT NULL DEFAULT 1,
    valid_from      DATE            NOT NULL,
    valid_until     DATE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_targets_valid_range CHECK (valid_until IS NULL OR valid_until >= valid_from)
);


-- 2.5 OFS Records (Registros principais de Observação de Feedback Comportamental)
CREATE SEQUENCE seq_ofc_sequential START 1 INCREMENT 1 NO CYCLE;

CREATE TABLE ofc_records (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    sequential_number       INT             NOT NULL DEFAULT nextval('seq_ofc_sequential'),
    record_date             DATE            NOT NULL,
    record_time             TIME            NOT NULL DEFAULT (NOW()::TIME),
    generated_by            UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    observed_name           VARCHAR(200)    NOT NULL,
    activity_observed       VARCHAR(300)    NOT NULL,
    location_observed       VARCHAR(200)    NOT NULL,
    company_id              INT             NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    shift                   VARCHAR(50)     NOT NULL,
    type                    VARCHAR(20)     NOT NULL CHECK (type IN ('Positivo/Seguro', 'Negativo/Inseguro')),
    behavior_observed       TEXT            NOT NULL,
    complementary_observation TEXT,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo','editado','cancelado')),
    is_deleted              BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ,
    deleted_at              TIMESTAMPTZ,
    deleted_by              UUID            REFERENCES users(id) ON DELETE SET NULL,

    CONSTRAINT chk_ofc_record_date CHECK (record_date <= CURRENT_DATE)
);


-- 2.6 OFS Edit Log (Histórico de edições nos registros)
CREATE TABLE ofc_edit_log (
    id              BIGSERIAL       PRIMARY KEY,
    ofc_record_id   UUID            NOT NULL REFERENCES ofc_records(id) ON DELETE CASCADE,
    edited_by       UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    field_changed   VARCHAR(100)    NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    edited_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- 2.7 Audit Logs (Registro de ações no sistema)
CREATE TABLE audit_logs (
    id              BIGSERIAL       PRIMARY KEY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    user_id         UUID            REFERENCES users(id) ON DELETE SET NULL,
    action          VARCHAR(50)     NOT NULL,
    resource        VARCHAR(100)    NOT NULL,
    resource_id     VARCHAR(255),
    details         JSONB,
    ip_address      VARCHAR(45)
);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs (timestamp DESC);
CREATE INDEX idx_audit_logs_user_id  ON audit_logs (user_id);
CREATE INDEX idx_audit_logs_ts_user  ON audit_logs (timestamp DESC, user_id);
CREATE INDEX idx_audit_logs_resource ON audit_logs (resource, resource_id);


-- 2.8 Reports (Relatórios gerados)
CREATE TABLE reports (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    type            VARCHAR(50)     NOT NULL,
    title           VARCHAR(200),
    parameters      JSONB           NOT NULL,
    file_path       VARCHAR(500),
    file_size_bytes BIGINT,
    page_count      INT,
    generated_by    UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- 2.9 Backups
CREATE TABLE backups (
    id              SERIAL          PRIMARY KEY,
    filename        VARCHAR(300)    NOT NULL,
    file_path       VARCHAR(500)    NOT NULL,
    size_bytes      BIGINT,
    type            VARCHAR(20)     NOT NULL DEFAULT 'auto' CHECK (type IN ('auto','manual')),
    status          VARCHAR(20)     NOT NULL DEFAULT 'success' CHECK (status IN ('success','failed')),
    error_message   TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- 2.10 Revoked Tokens (JWT revogados)
CREATE TABLE revoked_tokens (
    id              SERIAL          PRIMARY KEY,
    jti             VARCHAR(255)    NOT NULL UNIQUE,
    user_id         UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at      TIMESTAMPTZ     NOT NULL,
    revoked_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- ======================================================================
-- 3. ÍNDICES (Otimização)
-- ======================================================================

-- ofc_records: busca por data
CREATE INDEX idx_ofc_records_record_date ON ofc_records (record_date DESC);

-- ofc_records: busca por empresa
CREATE INDEX idx_ofc_records_company_id ON ofc_records (company_id);

-- ofc_records: busca por tipo (Positivo/Seguro vs Negativo/Inseguro)
CREATE INDEX idx_ofc_records_type ON ofc_records (type);

-- ofc_records: busca por usuário gerador
CREATE INDEX idx_ofc_records_generated_by ON ofc_records (generated_by);

-- ofc_records: busca composta por período + empresa (métricas)
CREATE INDEX idx_ofc_records_date_company ON ofc_records (record_date, company_id);

-- ofc_records: consulta por status
CREATE INDEX idx_ofc_records_status ON ofc_records (status);

-- ofc_records: full-text search em português
CREATE INDEX idx_ofc_records_fts ON ofc_records
    USING GIN (to_tsvector('portuguese',
        coalesce(observed_name, '')   || ' ' ||
        coalesce(behavior_observed, '') || ' ' ||
        coalesce(complementary_observation, '')
    ));

-- ofc_records: busca por nome da pessoa observada (LIKE)
CREATE INDEX idx_ofc_records_observed_name_trgm ON ofc_records
    USING GIN (observed_name gin_trgm_ops);

-- ofc_records: índice parcial para registros ativos (maioria das consultas)
CREATE INDEX idx_ofc_records_active_date ON ofc_records (record_date DESC, company_id)
    WHERE is_deleted = FALSE AND status = 'ativo';

-- ofc_records: índice para sequential_number (consultas por nº OFS)
CREATE UNIQUE INDEX idx_ofc_records_sequential ON ofc_records (sequential_number);

-- ofc_edit_log: busca por registro OFS
CREATE INDEX idx_ofc_edit_log_record_id ON ofc_edit_log (ofc_record_id);

-- ofc_edit_log: busca por data de edição
CREATE INDEX idx_ofc_edit_log_edited_at ON ofc_edit_log (edited_at DESC);

-- users: busca por username (login)
CREATE INDEX idx_users_username ON users (username);

-- users: busca por company_id
CREATE INDEX idx_users_company_id ON users (company_id);

-- users: busca por role
CREATE INDEX idx_users_role ON users (role);

-- contracts: busca por company_id
CREATE INDEX idx_contracts_company_id ON contracts (company_id);

-- targets: busca por company e período de vigência
CREATE INDEX idx_targets_company_valid ON targets (company_id, valid_from, valid_until);

-- targets: busca por contract_id
CREATE INDEX idx_targets_contract_id ON targets (contract_id);

-- reports: busca por gerador
CREATE INDEX idx_reports_generated_by ON reports (generated_by, created_at DESC);

-- revoked_tokens: busca por jti (validação de token)
CREATE INDEX idx_revoked_tokens_jti ON revoked_tokens (jti);

-- revoked_tokens: limpeza de tokens expirados
CREATE INDEX idx_revoked_tokens_expires ON revoked_tokens (expires_at)
    WHERE expires_at < NOW();


-- ======================================================================
-- 4. VIEWS
-- ======================================================================

-- 4.1 View de métricas semanais agregadas
CREATE OR REPLACE VIEW vw_weekly_metrics AS
SELECT
    date_trunc('week', o.record_date)::DATE          AS week_start,
    (date_trunc('week', o.record_date) + INTERVAL '6 days')::DATE AS week_end,
    EXTRACT(WEEK FROM o.record_date)::INT             AS week_number,
    EXTRACT(YEAR FROM o.record_date)::INT             AS year_number,
    c.id                                              AS company_id,
    c.name                                            AS company_name,
    COUNT(*)                                          AS total_records,
    COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')    AS positive_count,
    COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro')  AS negative_count,
    ROUND(
        COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                 AS percentage_safe,
    ROUND(COUNT(*)::NUMERIC / 7, 2)                   AS daily_average,
    COUNT(DISTINCT o.generated_by)                    AS unique_observers,
    COUNT(DISTINCT o.record_date)                     AS days_with_records,
    COUNT(DISTINCT o.observed_name)                   AS unique_observed,
    COUNT(*) FILTER (WHERE o.shift = 'Diurno')        AS diurno_count,
    COUNT(*) FILTER (WHERE o.shift = 'Noturno')       AS noturno_count,
    COUNT(*) FILTER (WHERE o.shift = 'Misto')         AS misto_count
FROM ofc_records o
INNER JOIN companies c ON c.id = o.company_id
WHERE o.is_deleted = FALSE
GROUP BY
    date_trunc('week', o.record_date)::DATE,
    EXTRACT(WEEK FROM o.record_date),
    EXTRACT(YEAR FROM o.record_date),
    c.id,
    c.name
ORDER BY week_start DESC, c.name;


-- 4.2 View de contagem diária por empresa
CREATE OR REPLACE VIEW vw_daily_counts AS
SELECT
    o.record_date,
    o.company_id,
    c.name AS company_name,
    COUNT(*)                                                              AS total_records,
    COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')   AS positive_count,
    COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro') AS negative_count,
    COUNT(DISTINCT o.generated_by)                                       AS unique_observers
FROM ofc_records o
INNER JOIN companies c ON c.id = o.company_id
WHERE o.is_deleted = FALSE
GROUP BY o.record_date, o.company_id, c.name
ORDER BY o.record_date DESC, c.name;


-- ======================================================================
-- 5. FUNÇÕES
-- ======================================================================

-- 5.1 Função de cálculo de métricas semanais com metas
CREATE OR REPLACE FUNCTION calculate_weekly_metrics(
    p_week_start DATE,
    p_company_id INT DEFAULT NULL
)
RETURNS TABLE (
    company_name        VARCHAR,
    week_start          DATE,
    week_end            DATE,
    total_records       BIGINT,
    positive_count      BIGINT,
    negative_count      BIGINT,
    percentage_safe     NUMERIC(5,2),
    daily_average       NUMERIC(5,2),
    unique_observers    BIGINT,
    days_with_records   BIGINT,
    expected_weekly     BIGINT,
    active_people       INT,
    target_achieved     NUMERIC(5,2)
)
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    WITH week_records AS (
        SELECT
            o.company_id,
            c.name AS company_name,
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro') AS positive,
            COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro') AS negative,
            COUNT(DISTINCT o.generated_by) AS observers,
            COUNT(DISTINCT o.record_date) AS active_days
        FROM ofc_records o
        INNER JOIN companies c ON c.id = o.company_id
        WHERE o.is_deleted = FALSE
          AND o.record_date >= p_week_start
          AND o.record_date < (p_week_start + INTERVAL '7 days')
          AND (p_company_id IS NULL OR o.company_id = p_company_id)
        GROUP BY o.company_id, c.name
    ),
    relevant_targets AS (
        SELECT
            t.company_id,
            t.weekly_target,
            t.active_people,
            (t.weekly_target * t.active_people) AS expected
        FROM targets t
        WHERE t.is_active = TRUE
          AND t.valid_from <= p_week_start
          AND (t.valid_until IS NULL OR t.valid_until >= p_week_start)
          AND (p_company_id IS NULL OR t.company_id = p_company_id)
    )
    SELECT
        wr.company_name,
        p_week_start::DATE,
        (p_week_start + INTERVAL '6 days')::DATE,
        wr.total::BIGINT,
        wr.positive::BIGINT,
        wr.negative::BIGINT,
        ROUND(wr.positive::NUMERIC / NULLIF(wr.total, 0) * 100, 2),
        ROUND(wr.total::NUMERIC / 7, 2),
        wr.observers::BIGINT,
        wr.active_days::BIGINT,
        rt.expected::BIGINT,
        rt.active_people::INT,
        ROUND(wr.total::NUMERIC / NULLIF(rt.expected, 0) * 100, 2)
    FROM week_records wr
    LEFT JOIN relevant_targets rt ON rt.company_id = wr.company_id
    ORDER BY wr.company_name;
$$;


-- 5.2 Função auxiliar: contagem de registros por tipo em um período
CREATE OR REPLACE FUNCTION count_by_type(
    p_start_date DATE,
    p_end_date   DATE,
    p_company_id INT DEFAULT NULL
)
RETURNS TABLE (
    company_name    VARCHAR,
    type            VARCHAR,
    record_count    BIGINT
)
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT
        c.name,
        o.type,
        COUNT(*)::BIGINT
    FROM ofc_records o
    INNER JOIN companies c ON c.id = o.company_id
    WHERE o.is_deleted = FALSE
      AND o.record_date BETWEEN p_start_date AND p_end_date
      AND (p_company_id IS NULL OR o.company_id = p_company_id)
    GROUP BY c.name, o.type
    ORDER BY c.name, o.type;
$$;


-- 5.3 Função de trigger: atualiza updated_at automaticamente
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


-- 5.4 Trigger: users.updated_at
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


-- 5.5 Trigger: ofc_records.updated_at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'trg_ofc_records_updated_at'
    ) THEN
        CREATE TRIGGER trg_ofc_records_updated_at
            BEFORE UPDATE ON ofc_records
            FOR EACH ROW
            EXECUTE FUNCTION trigger_set_updated_at();
    END IF;
END;
$$;


-- 5.6 Função de limpeza de tokens expirados (para cron job)
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


-- ======================================================================
-- 6. DADOS DE SEED
-- ======================================================================

-- 6.1 Empresas iniciais
INSERT INTO companies (name, is_custom) VALUES
    ('Security Dynamics', FALSE),
    ('Polo Norte',        FALSE),
    ('G4S',               FALSE),
    ('ERA',               FALSE),
    ('Innovatec',         FALSE),
    ('Conin',             FALSE),
    ('FM',                FALSE),
    ('Sodexo',            FALSE),
    ('Engecom',           FALSE),
    ('P&G',               FALSE),
    ('Yusen',             FALSE),
    ('Mainpower',         FALSE),
    ('Aduana',            FALSE),
    ('Prosegur',          FALSE),
    ('Outros',            TRUE)
ON CONFLICT (name) DO NOTHING;


-- 6.2 Usuário administrador padrão
-- Senha: admin123 (bcrypt, cost 12)
INSERT INTO users (username, password_hash, full_name, role, company_id) VALUES
    ('admin',
     '$2b$12$LJ3m4ys3GZfnYMz8kVsKaemhGQhfqB7xRVG4ED4xpDG7Xw5ZqWTEu',
     'Administrador do Sistema',
     'admin',
     1)
ON CONFLICT (username) DO NOTHING;


-- ======================================================================
-- 7. ESTRATÉGIA DE PARTITIONING (ofc_records por mês/ano)
-- ======================================================================
--
-- Quando o volume ultrapassar ~5 milhões de registros, migre a tabela
-- ofc_records para particionamento por RANGE em record_date.
--
-- Script de migração (via Alembic) para PostgreSQL 16:
--
-- -- Passo 1: Criar tabela particionada substituta
-- CREATE TABLE ofc_records_partitioned (
--     id                      UUID            DEFAULT gen_random_uuid(),
--     sequential_number       INT             NOT NULL DEFAULT nextval('seq_ofc_sequential'),
--     record_date             DATE            NOT NULL,
--     record_time             TIME            NOT NULL DEFAULT (NOW()::TIME),
--     generated_by            UUID            NOT NULL,
--     observed_name           VARCHAR(200)    NOT NULL,
--     activity_observed       VARCHAR(300)    NOT NULL,
--     location_observed       VARCHAR(200)    NOT NULL,
--     company_id              INT             NOT NULL,
--     shift                   VARCHAR(50)     NOT NULL,
--     type                    VARCHAR(20)     NOT NULL,
--     behavior_observed       TEXT            NOT NULL,
--     complementary_observation TEXT,
--     status                  VARCHAR(20)     NOT NULL DEFAULT 'ativo',
--     is_deleted              BOOLEAN         NOT NULL DEFAULT FALSE,
--     created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
--     updated_at              TIMESTAMPTZ,
--     deleted_at              TIMESTAMPTZ,
--     deleted_by              UUID,
--     CONSTRAINT pk_ofc_records_part PRIMARY KEY (id, record_date),
--     CONSTRAINT fk_ofc_records_generated_by FOREIGN KEY (generated_by) REFERENCES users(id),
--     CONSTRAINT fk_ofc_records_company FOREIGN KEY (company_id) REFERENCES companies(id),
--     CONSTRAINT fk_ofc_records_deleted_by FOREIGN KEY (deleted_by) REFERENCES users(id),
--     CONSTRAINT chk_ofc_record_type CHECK (type IN ('Positivo/Seguro', 'Negativo/Inseguro')),
--     CONSTRAINT chk_ofc_record_status CHECK (status IN ('ativo','editado','cancelado')),
--     CONSTRAINT chk_ofc_record_date CHECK (record_date <= CURRENT_DATE)
-- ) PARTITION BY RANGE (record_date);
--
-- -- Passo 2: Criar partições mensais (exemplo para 2025-2026)
-- CREATE TABLE ofc_records_2025_01 PARTITION OF ofc_records_partitioned
--     FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
-- CREATE TABLE ofc_records_2025_02 PARTITION OF ofc_records_partitioned
--     FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
-- -- ... (criar para todos os meses)
--
-- -- Passo 3: Migrar dados, renomear tabelas, recriar índices nas partições
--
-- -- Passo 4: Automatizar criação mensal com pg_partman ou cron job:
-- CREATE OR REPLACE FUNCTION create_monthly_partition()
-- RETURNS VOID LANGUAGE plpgsql AS $$
-- DECLARE
--     v_start  DATE := date_trunc('month', NOW()) + INTERVAL '1 month';
--     v_end    DATE := date_trunc('month', NOW()) + INTERVAL '2 months';
--     v_name   TEXT := 'ofc_records_' || to_char(v_start, 'YYYY_MM');
-- BEGIN
--     EXECUTE format(
--         'CREATE TABLE IF NOT EXISTS %I PARTITION OF ofc_records_partitioned
--          FOR VALUES FROM (%L) TO (%L)',
--         v_name, v_start, v_end
--     );
-- END;
-- $$;
--
-- NOTA: sequential_number NÃO será globalmente único em tabela particionada.
-- A sequence garante unicidade prática, mas a constraint UNIQUE não pode ser
-- aplicada sem incluir record_date. Para nº OFS determinístico, considere
-- usar UUID curto ou composto (ano-mês-seq).


-- ======================================================================
-- 8. ESTRATÉGIA DE OTIMIZAÇÃO
-- ======================================================================

-- 8.1 Configuração de Autovacuum para tabela de alto volume
-- Adicionar ao postgresql.conf ou via ALTER TABLE:
ALTER TABLE ofc_records SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.005,
    autovacuum_vacuum_cost_delay = 5,
    autovacuum_vacuum_cost_limit = 2000,
    autovacuum_freeze_max_age = 200000000,
    fillfactor = 85
);

-- 8.2 Full-Text Search em Português
-- Para stemming e dicionário pt-BR completo, instalar no servidor PostgreSQL:
--
--   sudo apt install postgresql-16-ptbr-dict  (ou equivalente)
--
-- Depois recriar a configuração:
--   DROP TEXT SEARCH CONFIGURATION IF EXISTS portuguese CASCADE;
--   CREATE TEXT SEARCH CONFIGURATION portuguese (COPY = pg_catalog.english);
--   ALTER TEXT SEARCH CONFIGURATION portuguese
--       ALTER MAPPING FOR hword, hword_part, word
--       WITH unaccent, portuguese_stem;
--   -- Recriar índice FTS
--   CREATE INDEX CONCURRENTLY idx_ofc_records_fts ON ofc_records
--       USING GIN (to_tsvector('portuguese', ...));
--
-- A configuração com 'simple' atual já permite busca textual,
-- apenas sem stemming (radicalização) de palavras em português.

-- 8.3 Pool de Conexões Recomendado
--
-- Para SQLAlchemy 2.0 async (asyncpg):
--   pool_size = (2 * CPU cores) + 1           -- conexões mantidas
--   max_overflow = 10                          -- conexões extras sob demanda
--   pool_recycle = 3600                        -- reciclar após 1h
--   pool_pre_ping = True                       -- verificar conexão antes de usar
--   connect_args = {
--       "statement_cache_size": 0,              -- desabilitar cache do asyncpg
--       "prepared_statement_cache_size": 0
--   }
--
-- Para PostgreSQL 16 no servidor:
--   max_connections = 200
--   shared_buffers = 25% da RAM total
--   effective_cache_size = 75% da RAM total
--   work_mem = 64MB a 256MB
--   maintenance_work_mem = 512MB

-- 8.4 Sugestão de REINDEX periódico (cron mensal)
-- REINDEX INDEX CONCURRENTLY idx_ofc_records_fts;
-- REINDEX INDEX CONCURRENTLY idx_ofc_records_date_company;


-- ======================================================================
-- 9. ESTRATÉGIA DE MIGRAÇÃO PARA CLOUD
-- ======================================================================

-- 9.1 Compatibilidade de Tipos de Dados
--
-- Todos os tipos usados são padronizados SQL e compatíveis com:
--   - Azure Database for PostgreSQL (Flexible Server)
--   - Amazon RDS for PostgreSQL / Aurora PostgreSQL
--   - Google Cloud SQL for PostgreSQL
--
-- Tipos usados e compatibilidade:
--   UUID          → nativo em todos (PostgreSQL 13+)
--   SERIAL/BIGSERIAL → nativo
--   TIMESTAMPTZ   → nativo (TIMESTAMP WITH TIME ZONE)
--   JSONB         → nativo
--   TEXT/VARCHAR  → nativo
--   BOOLEAN       → nativo

-- 9.2 Exportação (pg_dump custom format)
--
--   pg_dump -h <host> -U <user> -d ofs_db \
--       --format=custom \
--       --compress=9 \
--       --no-owner \
--       --no-acl \
--       --verbose \
--       --file=ofs_db_backup.dump
--
-- Para exportar schema apenas:
--   pg_dump -h <host> -U <user> -d ofs_db --schema-only --no-owner > schema.sql

-- 9.3 Importação para Cloud
--
-- Azure:
--   pg_restore -h <azure-host>.postgres.database.azure.com \
--       -U <admin>@<server> -d ofs_db \
--       --no-owner --verbose ofs_db_backup.dump
--
-- AWS RDS:
--   pg_restore -h <rds-endpoint>.rds.amazonaws.com \
--       -U <master_user> -d ofs_db \
--       --no-owner --verbose ofs_db_backup.dump
--
-- Google Cloud SQL:
--   pg_restore -h <instance-ip> \
--       -U <user> -d ofs_db \
--       --no-owner --verbose ofs_db_backup.dump

-- 9.4 Preparação para Replicação
--
-- Antes de migrar, configurar WAL no servidor atual:
--   wal_level = logical       (postgresql.conf)
--   max_wal_senders = 5
--   max_replication_slots = 5
--   wal_keep_size = 1024      (1 GB mínimo)
--
-- Para migração com downtime mínimo, usar:
--   1. pg_dump schema-only (estrutura)
--   2. Restore schema no cloud
--   3. Configurar replicação lógica (CREATE PUBLICATION / SUBSCRIPTION)
--   4. Sincronizar dados via replicação
--   5. Corte (switchover) após sincronização completa
--
-- Alternativa: AWS DMS, Azure Database Migration Service, Google DMS
-- para migração gerenciada com CDC (Change Data Capture).


-- ======================================================================
-- 10. PERMISSÕES RECOMENDADAS
-- ======================================================================

-- Aplicação FastAPI: usuário com privilégios DML
-- CREATE ROLE ofs_app WITH LOGIN PASSWORD '<senha_segura>';
-- GRANT CONNECT ON DATABASE ofs_db TO ofs_app;
-- GRANT USAGE ON SCHEMA public TO ofs_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ofs_app;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO ofs_app;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO ofs_app;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public
--     GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ofs_app;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public
--     GRANT USAGE ON SEQUENCES TO ofs_app;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public
--     GRANT EXECUTE ON FUNCTIONS TO ofs_app;

-- Migrações Alembic: usuário com DDL
-- CREATE ROLE ofs_migration WITH LOGIN PASSWORD '<senha_segura>';
-- GRANT CONNECT ON DATABASE ofs_db TO ofs_migration;
-- GRANT CREATE ON SCHEMA public TO ofs_migration;
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ofs_migration;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ofs_migration;
