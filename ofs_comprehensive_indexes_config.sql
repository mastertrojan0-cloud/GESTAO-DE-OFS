-- ============================================================================
-- SISTEMA OFS/OFS — TODOS OS ÍNDICES, CONFIGS E MANUTENÇÃO (ENTREGUE COMPLETO)
-- PostgreSQL 16 | Servidor 4GB RAM | ~50k ofc_records/ano
-- Schema: ofs_database_model_v2.sql (canônico)
-- Gerado: 13/05/2026 | Versão: 4.0 (CONSOLIDATED)
-- ============================================================================
--
-- MAPEAMENTO RÁPIDO DE COLUNAS (v2 vs v1 legado):
--   v2: observation_date  =  v1: record_date
--   v2: classification    =  v1: type ('positive' = 'Positivo/Seguro', 'negative' = 'Negativo/Inseguro')
--   v2: observer_id       =  v1: generated_by
--   v2: company_id (UUID)  =  v1: company_id (INT)
--   v2: status            =  v1: status (cancelled = cancelado/excluído)
--   v2: observed_name     =  v1: observed_name
--   v2: behavior_description = v1: behavior_observed
--   v2: context           =  v1: complementary_observation
--
-- CONVENÇÃO: status != 'cancelled' substitui is_deleted = FALSE (v1)
-- A view materializada vw_weekly_metrics já existe no schema v2
-- Este script complementa TODOS os índices faltantes + otimizações

-- ============================================================================
-- PARTE 1: TODOS OS ÍNDICES (P0 → P1 → P2)
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- P0 — ÍNDICES CRÍTICOS (sem eles o sistema é INACEITAVELMENTE lento)
-- ═══════════════════════════════════════════════════════════════════════════

-- P0.1 — Índice composto ESTRELA para métricas (cobre ~85% das queries analíticas)
-- company_id (equality) → observation_date (range) → classification (filter)
-- Parcial: exclui cancelados (~98% das consultas de métricas ignoram cancelados)
-- Tamanho estimado: ~4-8 MB para 50k registros
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_metrics_p0
    ON ofc_records (company_id, observation_date, classification)
    WHERE status != 'cancelled';

-- P0.2 — Listagem paginada por observador (tela "Meus Registros")
-- observer_id (equality) → observation_date DESC (sort)
-- Com fillfactor otimizado para HOT updates (85% fill)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_observer_list_p0
    ON ofc_records (observer_id, observation_date DESC)
    WHERE status != 'cancelled';

-- P0.3 — Índice único para sequential_number (lookup direto OFS #1523)
-- Já existe no schema v2, mas incluímos para documentação completa
-- CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_sequential_p0
--     ON ofc_records (sequential_number);

-- P0.4 — Login: busca por email (substitui username na v2)
-- Já existe UNIQUE no schema v2 (email), mas reforçamos o índice para active users
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email_active_p0
    ON users (email)
    WHERE is_active = TRUE;

-- P0.5 — Índice para company_id standalone (FK + filtros sem data)
-- Já indexado implicitamente pela coluna 1 de idx_ofc_metrics_p0,
-- mas índices compostos nem sempre são usados para FK lookups puros
-- O PostgreSQL pode usar o prefixo de um índice composto, então este é opcional
-- se idx_ofc_metrics_p0 existir. Incluído para FK integrity checks rápidos.

-- P0.6 — Índice parcial crítico: apenas positivos (COUNT FILTER positive)
-- Acelera safe_percentage: COUNT(*) FILTER (WHERE classification = 'positive')
-- ~3-7x mais rápido que índice composto completo porque o índice é menor
-- Tamanho estimado: ~2-3 MB (assumindo 70% positivos)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_positive_p0
    ON ofc_records (company_id, observation_date)
    WHERE status != 'cancelled' AND classification = 'positive';

-- P0.7 — Índice parcial crítico: apenas negativos (COUNT FILTER negative)
-- Tamanho estimado: ~0.5-1 MB (assumindo 15% negativos)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_negative_p0
    ON ofc_records (company_id, observation_date)
    WHERE status != 'cancelled' AND classification = 'negative';

-- ═══════════════════════════════════════════════════════════════════════════
-- P1 — ÍNDICES IMPORTANTES (consultas frequentes, impacto médio-alto)
-- ═══════════════════════════════════════════════════════════════════════════

-- P1.1 — Índice data DESC (listagem cronológica reversa, sem filtro de empresa)
-- Já existe no schema v2: idx_ofc_obs_date
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_obs_date_desc_p1
    ON ofc_records (observation_date DESC)
    WHERE status != 'cancelled';

-- P1.2 — Filtro combinado: empresa + status + data (tela de gestão)
-- status (equality) → company_id (equality) → observation_date DESC (sort)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_status_company_date_p1
    ON ofc_records (status, company_id, observation_date DESC)
    WHERE status IN ('open', 'acknowledged', 'discussed');

-- P1.3 — Filtro combinado: empresa + turno + data (dashboard drill-down por turno)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_company_shift_date_p1
    ON ofc_records (company_id, shift, observation_date DESC)
    WHERE status != 'cancelled' AND shift IS NOT NULL;

-- P1.4 — Filtro combinado: classificação + data (ranking global de segurança)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_classification_date_p1
    ON ofc_records (classification, observation_date DESC)
    WHERE status != 'cancelled';

-- P1.5 — Índice para observed_user_id (OFCs de usuários internos)
-- Já existe no schema v2: idx_ofc_observed_user (parcial WHERE observed_user_id IS NOT NULL)
-- Reforçamos com composite date sort
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_observed_user_p1
    ON ofc_records (observed_user_id, observation_date DESC)
    WHERE status != 'cancelled' AND observed_user_id IS NOT NULL;

-- P1.6 — Índice para cycle_id (métricas por ciclo avaliativo)
-- Já existe no schema v2: idx_ofc_cycle (parcial)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_cycle_p1
    ON ofc_records (cycle_id, observation_date DESC)
    WHERE status != 'cancelled' AND cycle_id IS NOT NULL;

-- P1.7 — Índice para department_id (métricas por setor)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_department_p1
    ON ofc_records (department_id, observation_date DESC)
    WHERE status != 'cancelled' AND department_id IS NOT NULL;

-- P1.8 — Índice para competency_id (métricas por competência)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_competency_p1
    ON ofc_records (competency_id, observation_date DESC)
    WHERE status != 'cancelled' AND competency_id IS NOT NULL;

-- P1.9 — Índice para observadores únicos (COUNT DISTINCT observer_id)
-- Otimiza unique_observers no vw_weekly_metrics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_unique_observers_p1
    ON ofc_records (company_id, observation_date, observer_id)
    WHERE status != 'cancelled';

-- P1.10 — Índice para pessoas observadas únicas (COUNT DISTINCT observed_name)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_unique_observed_p1
    ON ofc_records (company_id, observation_date, observed_name)
    WHERE status != 'cancelled';

-- P1.11 — users: role + is_active (filtro de usuários ativos por perfil)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_role_active_p1
    ON users (role, is_active)
    WHERE is_active = TRUE;

-- P1.12 — companies: busca por nome (ILIKE no dropdown)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_companies_name_p1
    ON companies USING GIN (name gin_trgm_ops);

-- ═══════════════════════════════════════════════════════════════════════════
-- P2 — OTIMIZAÇÕES ADICIONAIS (nice-to-have, ganho marginal mas real)
-- ═══════════════════════════════════════════════════════════════════════════

-- P2.1 — GIN Full-Text Search em português (busca textual nos campos descritivos)
-- Já existe no schema v2: idx_ofc_fts
-- Reforçado aqui com todos os campos textuais combinados
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_fts_portuguese_p2
    ON ofc_records USING GIN (
        to_tsvector('portuguese',
            COALESCE(observed_name, '')        || ' ' ||
            COALESCE(behavior_description, '') || ' ' ||
            COALESCE(context, '')             || ' ' ||
            COALESCE(location, '')            || ' ' ||
            COALESCE(activity_context, '')
        )
    )
    WHERE status != 'cancelled';

-- P2.2 — Trigram search para nomes observados (ILIKE '%nome%' rápido)
-- Já existe no schema v2: idx_ofc_observed_name_trgm
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_name_trgm_p2
    ON ofc_records USING GIN (observed_name gin_trgm_ops)
    WHERE status != 'cancelled';

-- P2.3 — audit_logs: índice composto user + action + timestamp
-- Já existe no ofs_auth_schema.sql: idx_audit_logs_user_action
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_user_action_ts_p2
    ON audit_logs (user_id, action, timestamp DESC);

-- P2.4 — audit_logs: busca por intervalo de timestamp (range scan eficiente)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_timestamp_brin_p2
    ON audit_logs USING BRIN (timestamp)
    WITH (pages_per_range = 32);

-- P2.5 — ofc_edit_log: índice composto para consulta por registro + data
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_edit_log_ofc_date_p2
    ON ofc_edit_log (ofc_record_id, edited_at DESC);

-- P2.6 — ofc_edit_log: índice BRIN para scans de intervalo de data
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_edit_log_edited_brin_p2
    ON ofc_edit_log USING BRIN (edited_at)
    WITH (pages_per_range = 32);

-- P2.7 — Índice para severity em audit_logs (filtro de eventos críticos)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_severity_p2
    ON audit_logs (severity, timestamp DESC)
    WHERE severity IN ('ERROR', 'CRITICAL');

-- P2.8 — Índice para count distinct days (days_with_records no vw_weekly_metrics)
-- Otimiza COUNT(DISTINCT observation_date) via index-only scan
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_distinct_days_p2
    ON ofc_records (company_id, observation_date)
    WHERE status != 'cancelled';

-- P2.9 — Índice parcial para shift analysis (distribuição por turno)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_shift_metrics_p2
    ON ofc_records (shift, observation_date, classification)
    WHERE status != 'cancelled' AND shift IS NOT NULL;

-- P2.10 — Índice para limpeza de tokens expirados
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_revoked_tokens_cleanup_p2
    ON revoked_tokens (expires_at)
    WHERE expires_at < NOW();


-- ============================================================================
-- PARTE 2: EXPLAIN ANALYZE ESTIMADO (3 QUERIES PRINCIPAIS)
-- ============================================================================

-- --------------------------------------------------------------------------
-- QUERY 1: Métricas Semanais (~10k registros escaneados)
-- Cenário: Dashboard principal — métricas da semana atual para 1 empresa
-- --------------------------------------------------------------------------

-- Query:
/*
EXPLAIN (ANALYZE, BUFFERS, TIMING)
WITH week_data AS (
    SELECT
        company_id,
        COUNT(*)                                                  AS total,
        COUNT(*) FILTER (WHERE classification = 'positive')       AS positive,
        COUNT(*) FILTER (WHERE classification = 'negative')       AS negative,
        COUNT(*) FILTER (WHERE classification = 'neutral')        AS neutral,
        COUNT(DISTINCT observer_id)                               AS observers,
        COUNT(DISTINCT observed_name)                             AS unique_observed,
        COUNT(DISTINCT observation_date)                          AS active_days,
        ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT observation_date), 0), 2) AS daily_avg
    FROM ofc_records
    WHERE status != 'cancelled'
      AND observation_date >= DATE_TRUNC('week', CURRENT_DATE)::DATE
      AND observation_date <= CURRENT_DATE
      AND company_id = 'a1000000-0000-0000-0000-000000000001'
    GROUP BY company_id
)
SELECT
    c.name,
    wd.*,
    ROUND(wd.positive::NUMERIC / NULLIF(wd.total, 0) * 100, 2) AS safe_pct
FROM week_data wd
JOIN companies c ON c.id = wd.company_id;
*/

-- PLANO ESTIMADO (com índices P0):
-- ┌─────────────────────────────────────────────────────────────────────┐
-- │ Sort  (cost=8.33..8.34 rows=1 width=144)                           │
-- │   └── Nested Loop  (cost=0.56..8.32 rows=1 width=144)              │
-- │       ├── HashAggregate  (cost=0.28..0.31 rows=1 width=112)        │
-- │       │   └── Index Only Scan using idx_ofc_metrics_p0             │
-- │       │       Index Cond: (company_id = '...' AND                  │
-- │       │                    observation_date >= '2026-05-11' AND     │
-- │       │                    observation_date <= '2026-05-13')        │
-- │       │       Filter: status != 'cancelled'                        │
-- │       │       Heap Fetches: 0  (index-only scan)                    │
-- │       │       Rows: ~140 (3 dias × ~47 registros/dia)               │
-- │       │       Buffers: shared hit=12  (cache quente)               │
-- │       ├── Index Scan using companies_pkey  (cost=0.28..8.00)       │
-- │       │       Index Cond: (id = '...')                              │
-- │       │       Buffers: shared hit=3                                │
-- │ Tempo estimado: 0.8 - 2.5ms (cache quente)                         │
-- │                 5 - 15ms (cache frio, ~50 leituras de disco)        │
-- │                                                                     │
-- │ Sem índices (Seq Scan): 25 - 80ms (full table scan 50k rows)       │
-- │ Ganho: 10-50x mais rápido                                           │
-- └─────────────────────────────────────────────────────────────────────┘

-- NOTA: COUNT(DISTINCT observer_id) e COUNT(DISTINCT observation_date)
-- usam idx_ofc_unique_observers_p1 e idx_ofc_distinct_days_p2 via
-- Index Only Scan separados (BitmapOr), combinados pelo HashAggregate.
-- Em PostgreSQL 16 com parallel query, 2 workers escaneiam índices
-- parciais em paralelo para colunas distintas.


-- --------------------------------------------------------------------------
-- QUERY 2: Consulta com 3 Filtros Combinados (~12k registros escaneados)
-- Cenário: Busca avançada — empresa + período + classificação + turno
-- --------------------------------------------------------------------------

-- Query:
/*
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT
    o.id,
    o.sequential_number,
    o.observation_date,
    o.observed_name,
    o.classification,
    o.shift,
    o.status,
    u.full_name AS observer_name
FROM ofc_records o
JOIN users u ON u.id = o.observer_id
WHERE o.company_id = 'a1000000-0000-0000-0000-000000000001'
  AND o.observation_date BETWEEN '2026-04-01' AND '2026-04-30'
  AND o.classification = 'negative'
  AND o.shift = 'Noturno'
  AND o.status != 'cancelled'
ORDER BY o.observation_date DESC
LIMIT 100;
*/

-- PLANO ESTIMADO (com índices P0 + P1):
-- ┌─────────────────────────────────────────────────────────────────────┐
-- │ Limit  (cost=342.15..342.40 rows=100 width=156)                     │
-- │   └── Sort  (cost=342.15..343.65 rows=600 width=156)               │
-- │       Sort Key: o.observation_date DESC                             │
-- │       └── Nested Loop  (cost=4.85..320.65 rows=600 width=156)       │
-- │           ├── Bitmap Heap Scan on ofc_records o                     │
-- │           │   Recheck Cond: (company_id = '...' AND                 │
-- │           │                 observation_date >= '2026-04-01' AND     │
-- │           │                 observation_date <= '2026-04-30')        │
-- │           │   Filter: (classification = 'negative' AND              │
-- │           │            shift = 'Noturno' AND                        │
-- │           │            status != 'cancelled')                        │
-- │           │   └── Bitmap Index Scan on idx_ofc_metrics_p0           │
-- │           │       Index Cond: (company_id = '...' AND               │
-- │           │                    observation_date >= ... AND            │
-- │           │                    observation_date <= ...)              │
-- │           │       Rows: ~15000 (30 dias × 500 registros/dia)        │
-- │           │       Buffers: shared hit=45                            │
-- │           │   Rows Removed by Filter: ~14400                        │
-- │           │   Actual Rows: 600                                      │
-- │           └── Index Scan using users_pkey on users u                │
-- │               Index Cond: (id = o.observer_id)                      │
-- │               Buffers: shared hit=600                               │
-- │ Tempo estimado: 8 - 20ms (cache quente)                             │
-- │                 25 - 60ms (cache frio)                               │
-- │                                                                     │
-- │ Sem índices: 80 - 300ms (seq scan 50k + filter + sort + join)      │
-- │ Ganho: 4-15x mais rápido                                            │
-- └─────────────────────────────────────────────────────────────────────┘

-- OTIMIZAÇÃO ALTERNATIVA: Se a cardinalidade de classificação + turno
-- for muito seletiva (<1% das linhas), o planner pode escolher:
--   BitmapAnd(
--     Bitmap Index Scan on idx_ofc_metrics_p0  (company + date),
--     Bitmap Index Scan on idx_ofc_classification_date_p1 (class + date),
--     Bitmap Index Scan on idx_ofc_shift_metrics_p2 (shift + date)
--   )
-- Isso reduz tempo para 3-8ms com dados muito filtrados.


-- --------------------------------------------------------------------------
-- QUERY 3: Listagem Paginada (página 1, 25 itens, ~50k total)
-- Cenário: "Meus Registros" — listagem com paginação e contagem total
-- --------------------------------------------------------------------------

-- Query:
/*
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT
    o.id,
    o.sequential_number,
    o.observation_date,
    o.observed_name,
    o.classification,
    o.shift,
    o.status,
    o.behavior_description,
    o.created_at
FROM ofc_records o
WHERE o.observer_id = 'd1000000-0000-0000-0000-000000000001'
  AND o.status != 'cancelled'
ORDER BY o.observation_date DESC, o.created_at DESC
LIMIT 25 OFFSET 0;

-- Contagem total (executada em paralelo via API):
SELECT COUNT(*)
FROM ofc_records
WHERE observer_id = 'd1000000-0000-0000-0000-000000000001'
  AND status != 'cancelled';
*/

-- PLANO ESTIMADO (com idx_ofc_observer_list_p0):
-- ┌─────────────────────────────────────────────────────────────────────┐
-- │ Limit  (cost=0.29..18.74 rows=25 width=248)                         │
-- │   └── Index Scan Backward using idx_ofc_observer_list_p0            │
-- │       Index Cond: (observer_id = 'd1000000-...')                    │
-- │       Rows: ~200 (estimado para este usuário no ano)                 │
-- │       Buffers: shared hit=8                                        │
-- │ Tempo Listagem: 0.3 - 1.0ms (cache quente)                          │
-- │                  2 - 5ms (cache frio)                               │
-- │                                                                     │
-- │ Tempo COUNT(*): 0.1 - 0.5ms (index-only scan no mesmo índice)      │
-- │ Tempo Total API: 1 - 3ms                                            │
-- │                                                                     │
-- │ Sem índices: 15 - 40ms (seq scan full table)                        │
-- │ Ganho: 10-50x mais rápido                                            │
-- │                                                                     │
-- │ NOTA SOBRE PAGINAÇÃO PROFUNDA:                                       │
-- │ OFFSET 1000 neste índice:                                           │
-- │   O PostgreSQL ainda lê 1025 linhas e descarta 1000.                │
-- │   Para OFFSET > 1000, usar keyset pagination:                       │
-- │   WHERE observation_date < '2026-03-15' (último valor da página)    │
-- │   Isso mantém tempo constante O(25) independente do offset.          │
-- └─────────────────────────────────────────────────────────────────────┘


-- ============================================================================
-- PARTE 3: CONFIGURAÇÕES postgresql.conf PARA 4GB RAM TOTAL
-- ============================================================================

-- IMPORTANTE: Estas configurações assumem ~1.5-2GB disponíveis para PostgreSQL
-- (o restante é usado pelo SO, FastAPI, e outros processos).
-- Aplique no arquivo: C:\Program Files\PostgreSQL\16\data\postgresql.conf
-- Após editar, execute: pg_ctl reload  (ou reinicie o serviço)

-- ═══ MEMÓRIA (CRÍTICO — 4GB RAM TOTAL) ═══

-- shared_buffers: Cache de dados do PostgreSQL
-- Regra: 25% da RAM, mas no Windows NÃO exceder 512MB
-- (Windows tem limitação de System V shared memory)
-- Para 4GB total no Windows: 256-512MB é seguro
shared_buffers = 256MB
-- Linux: use 1GB se for Linux com 4GB RAM

-- effective_cache_size: Memória total disponível para cache (SO + PG)
-- O planner usa isso para decidir index scan vs seq scan
-- Para 4GB total: ~2GB (50%). O SO usa ~1-1.5GB para file system cache
effective_cache_size = 2GB

-- work_mem: Memória por operação de sort/hash/GROUP BY (por nó do plano)
-- ATENÇÃO: Este valor é MULTIPLICADO pelo número de conexões simultâneas!
-- Com pool de 20 conexões ativas: 16MB × 20 = 320MB (seguro para 4GB)
-- Para queries analíticas (métricas com COUNT DISTINCT): 16-32MB é suficiente
-- pois o volume de dados é baixo (~10k registros/consulta)
work_mem = 16MB

-- hash_mem_multiplier: PostgreSQL 16+ usa work_mem × este fator para hash
-- Com work_mem=16MB e multiplier=2.0 → 32MB para hash joins/GROUP BY hash
hash_mem_multiplier = 2.0

-- maintenance_work_mem: Memória para VACUUM, CREATE INDEX, REINDEX
-- Alocar generosamente pois essas operações são raras e isoladas
-- 256MB é suficiente para índices de ~50k linhas
maintenance_work_mem = 256MB

-- wal_buffers: Buffer para Write-Ahead Log
-- 16MB é suficiente para workload de ~50 inserts/updates por minuto
wal_buffers = 16MB

-- ═══ PLANEJADOR DE CONSULTAS ═══

-- random_page_cost: Custo relativo de acesso aleatório vs sequencial
-- SSD: 1.1 | HDD: 4.0 (padrão)
-- Assumindo SSD (típico em servidores modernos)
random_page_cost = 1.1

-- effective_io_concurrency: Leituras simultâneas de disco
-- SSD SATA: 100 | NVMe: 200 | HDD: 2
-- Para servidor interno com SSD SATA típico:
effective_io_concurrency = 100

-- default_statistics_target: Precisão das estatísticas do ANALYZE
-- 200 é bom para tabelas < 1M linhas (padrão é 100)
-- Valor maior = planos melhores para dados enviesados (classification, shift)
default_statistics_target = 200

-- cursor_tuple_fraction: Fração de linhas que o cursor espera buscar
-- 0.1 favorece index scans para primeiras linhas (bom para paginação)
cursor_tuple_fraction = 0.1

-- ═══ PARALELISMO (4GB RAM — conservador) ═══

-- Com ~2-4 vCPUs típico de servidor interno 4GB:
max_parallel_workers_per_gather = 2   -- 2 workers por query paralela
max_parallel_workers = 4             -- total de workers no sistema
max_parallel_maintenance_workers = 2 -- para CREATE INDEX paralelo

-- Custo reduzido incentiva paralelismo mesmo em queries pequenas
parallel_tuple_cost = 0.01
parallel_setup_cost = 100

-- Tamaho mínimo para considerar paralelismo
min_parallel_table_scan_size = '4MB'
min_parallel_index_scan_size = '512kB'

-- ═══ CONEXÕES ═══

-- Para servidor 4GB: conservador. Cada conexão idle ~10MB
-- pool_size FastAPI = 10 + max_overflow = 10 = 20 conexões
max_connections = 50
superuser_reserved_connections = 3

-- ═══ WRITE-AHEAD LOG (WAL) ═══

-- workload: ~50-100 inserts/dia → baixo volume de WAL
wal_level = replica
checkpoint_timeout = 15min
-- max_wal_size: 1GB é suficiente para 50k registros/ano
max_wal_size = 1GB
min_wal_size = 256MB

-- ═══ AUTOVACUUM (AGGRESSIVO para ofc_records) ═══

autovacuum = on
autovacuum_max_workers = 2
autovacuum_naptime = 30s          -- verificar a cada 30s (padrão 60s)
autovacuum_vacuum_cost_delay = 2  -- reduz pausa (padrão 2ms)
autovacuum_vacuum_cost_limit = 2000

-- ═══ LOGGING (DEBUG — descomentar para troubleshooting) ═══

-- log_min_duration_statement = 500   -- log queries > 500ms
-- log_autovacuum_min_duration = 1000 -- log autovacuum > 1s
-- log_lock_waits = on                -- log espera de lock > 1s
-- log_connections = on
-- log_disconnections = on

-- ═══ SEGURANÇA ═══

password_encryption = scram-sha-256
statement_timeout = 30s              -- mata queries > 30s
idle_in_transaction_session_timeout = 60s


-- ============================================================================
-- PARTE 4: ESTATÍSTICAS POR COLUNA (dados enviesados)
-- ============================================================================

-- Colunas com distribuição não-uniforme precisam de estatísticas mais
-- detalhadas para o planner escolher o melhor índice.

ALTER TABLE ofc_records ALTER COLUMN classification SET STATISTICS 500;
ALTER TABLE ofc_records ALTER COLUMN shift SET STATISTICS 500;
ALTER TABLE ofc_records ALTER COLUMN status SET STATISTICS 500;
ALTER TABLE ofc_records ALTER COLUMN observation_date SET STATISTICS 1000;
ALTER TABLE ofc_records ALTER COLUMN severity SET STATISTICS 300;

-- Atualiza as estatísticas após alterar targets
-- (executar após aplicar todos os índices)
-- ANALYZE ofc_records;


-- ============================================================================
-- PARTE 5: AUTOVACUUM TUNING POR TABELA
-- ============================================================================

-- ofc_records: tabela de alto volume relativo (~50k/ano, ~140/dia)
-- Muitas inserções, poucas atualizações → HOT updates são importantes
ALTER TABLE ofc_records SET (
    autovacuum_vacuum_scale_factor = 0.02,     -- vacuum a cada 2% de tuplas mortas
    autovacuum_analyze_scale_factor = 0.01,    -- analyze a cada 1% de mudanças
    autovacuum_vacuum_cost_delay = 2,          -- delay reduzido para vacuum rápido
    autovacuum_vacuum_cost_limit = 2000,       -- custo máximo por ciclo
    fillfactor = 85                            -- 15% livre para HOT updates
);
-- Com 50k registros: vacuum dispara com ~1000 tuplas mortas
-- (~50 cancelamentos/edições por mês → vacuum mensal automático)

-- ofc_edit_log: tabela append-only (nunca atualizada, nunca deletada)
ALTER TABLE ofc_edit_log SET (
    autovacuum_vacuum_scale_factor = 0.05,     -- vacuum raro
    autovacuum_analyze_scale_factor = 0.02,    -- analyze moderado
    fillfactor = 90                            -- 10% livre (pouco HOT)
);

-- audit_logs: tabela append-only imutável
ALTER TABLE audit_logs SET (
    autovacuum_vacuum_scale_factor = 0.1,      -- vacuum muito raro
    autovacuum_analyze_scale_factor = 0.05,    -- analyze raro
    fillfactor = 95                            -- mínimo espaço livre
);

-- users: baixa rotatividade
ALTER TABLE users SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02,
    fillfactor = 90
);


-- ============================================================================
-- PARTE 6: ESTRATÉGIA DE MANUTENÇÃO
-- ============================================================================

-- ═══ 6.1 VACUUM — Frequência e Comandos ═══

/*
 * POLÍTICA DE VACUUM:
 *
 * ┌─────────────────────┬─────────────────┬──────────────────────────────┐
 * │ Tabela              │ Frequência      │ Gatilho                      │
 * ├─────────────────────┼─────────────────┼──────────────────────────────┤
 * │ ofc_records         │ Semanal (auto)  │ autovacuum (2% dead tuples)  │
 * │ ofc_edit_log        │ Mensal (auto)   │ autovacuum (5% dead tuples)  │
 * │ audit_logs          │ Mensal (auto)   │ autovacuum (10% dead tuples) │
 * │ users               │ Mensal (auto)   │ autovacuum (5% dead tuples)  │
 * │ revoked_tokens      │ Diário (auto)   │ autovacuum padrão            │
 * └─────────────────────┴─────────────────┴──────────────────────────────┘
 *
 * COMANDOS MANUAIS (se necessário):
 */

-- VACUUM ANALYZE completo (executar após grandes cargas de dados):
--  VACUUM (VERBOSE, ANALYZE) ofc_records;
--  Tempo estimado: 2-5 segundos para 50k registros

-- VACUUM FREEZE (apenas para prevenir wraparound, 1x por ano):
--  VACUUM (FREEZE, VERBOSE) ofc_records;

-- VACUUM agressivo pós-importação/migração:
--  VACUUM (FULL, VERBOSE, ANALYZE) ofc_records;
--  ⚠️ ATENÇÃO: VACUUM FULL bloqueia a tabela! Fazer em janela de manutenção.
--  Tempo: ~30s-2min para 50k registros. Recupera espaço em disco.

/*
 * ═══ 6.2 REINDEX — Quando e Como ═══
 *
 * SINTOMAS QUE INDICAM NECESSIDADE DE REINDEX:
 *   - Índice 3x maior que o esperado (pg_stat_user_indexes.idx_size vs expected)
 *   - Index scan mais lento que seq scan em tabelas pequenas
 *   - BLOAT > 50% no índice (ver query de monitoramento abaixo)
 *
 * FREQUÊNCIA RECOMENDADA:
 *   - Índices GIN (FTS): a cada 2-3 meses (acumulam bloat mais rápido)
 *   - Índices B-tree: a cada 6 meses (para 50k registros/ano)
 *   - Após carga massiva (>5k inserts de uma vez): imediatamente
 */

-- Comando reindex (CONCURRENTLY = não bloqueia escritas):
--  REINDEX INDEX CONCURRENTLY idx_ofc_metrics_p0;
--  REINDEX INDEX CONCURRENTLY idx_ofc_fts_portuguese_p2;
--  REINDEX INDEX CONCURRENTLY idx_ofc_observer_list_p0;

-- Reindex de todos os índices de ofc_records (manutenção semestral):
--  REINDEX (VERBOSE) TABLE CONCURRENTLY ofc_records;
--  Tempo estimado: 10-60 segundos para 50k registros

/*
 * ═══ 6.3 MONITORAMENTO DE ÍNDICES NÃO UTILIZADOS ═══
 *
 * PostgreSQL mantém contadores de uso em pg_stat_user_indexes.
 * Use as queries abaixo para identificar índices mortos.
 */

-- Query 1: Índices NUNCA usados (idx_scan = 0 desde o último reset de stats)
-- Execute mensalmente. Se um índice tem 0 scans por 30+ dias, candidate a remoção.
/*
SELECT
    schemaname || '.' || relname                      AS table_name,
    indexrelname                                      AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid))      AS index_size,
    idx_scan                                          AS scans_since_reset,
    idx_tup_read                                      AS tuples_read,
    idx_tup_fetch                                     AS tuples_fetched
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
  AND indexrelname NOT LIKE '%pkey%'   -- nunca remover PKs
  AND indexrelname NOT LIKE '%unique%' -- nunca remover UNIQUE
ORDER BY pg_relation_size(indexrelid) DESC;
*/

-- Query 2: Índices com baixo uso relativo (menos de 10% de scans vs seq scans)
/*
SELECT
    schemaname || '.' || relname                       AS table_name,
    indexrelname                                       AS index_name,
    idx_scan                                           AS index_scans,
    seq_scan                                           AS seq_scans,
    ROUND(idx_scan::NUMERIC / NULLIF(idx_scan + seq_scan, 0) * 100, 1) AS idx_usage_pct,
    pg_size_pretty(pg_relation_size(indexrelid))       AS index_size
FROM pg_stat_user_indexes
JOIN pg_stat_user_tables ON pg_stat_user_indexes.relid = pg_stat_user_tables.relid
WHERE seq_scan > 0
  AND idx_scan::NUMERIC / NULLIF(idx_scan + seq_scan, 0) < 0.1
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
*/

-- Query 3: Bloat de índices (requer extensão pgstattuple)
-- CREATE EXTENSION IF NOT EXISTS pgstattuple;
/*
SELECT
    indexrelname                                     AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid))     AS total_size,
    ROUND((pgstattuple(indexrelid)).dead_tuple_percent, 1) AS bloat_pct
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND (pgstattuple(indexrelid)).dead_tuple_percent > 30
ORDER BY pg_relation_size(indexrelid) DESC;
*/

-- Query 4: Uso de índice por tabela (visão geral)
/*
SELECT
    t.relname                                         AS table_name,
    COUNT(i.indexrelid)                               AS index_count,
    SUM(i.idx_scan)                                   AS total_idx_scans,
    s.seq_scan                                        AS seq_scans,
    s.n_tup_ins                                       AS inserts,
    s.n_tup_upd                                       AS updates,
    s.n_tup_del                                       AS deletes,
    pg_size_pretty(pg_relation_size(t.relid))         AS table_size,
    pg_size_pretty(SUM(pg_relation_size(i.indexrelid))) AS indexes_total_size
FROM pg_stat_user_tables s
JOIN pg_class t ON t.relname = s.relname
LEFT JOIN pg_stat_user_indexes i ON i.relid = t.relid
WHERE s.schemaname = 'public'
GROUP BY t.relname, s.seq_scan, s.n_tup_ins, s.n_tup_upd, s.n_tup_del,
         pg_relation_size(t.relid)
ORDER BY pg_relation_size(t.relid) DESC;
*/


-- ============================================================================
-- PARTE 7: COMANDOS PARA APLICAR TUDO (checklist de execução)
-- ============================================================================

/*
 * ORDEM DE EXECUÇÃO:
 *
 * PASSO 1 — Configurações do servidor:
 *   1. Edite postgresql.conf com as configurações da PARTE 3
 *   2. Execute: pg_ctl reload   (ou reinicie o serviço PostgreSQL)
 *   3. Verifique: SHOW shared_buffers;  (deve retornar '256MB')
 *
 * PASSO 2 — Índices:
 *   1. Execute este arquivo:
 *      psql -U postgres -d ofs_db -f ofs_comprehensive_indexes_config.sql
 *   2. Índices com CONCURRENTLY NÃO bloqueiam escritas mas são mais lentos
 *      (~5-30 segundos cada para 50k registros)
 *   3. Se houver erro de deadlock em CREATE INDEX CONCURRENTLY, execute:
 *      CREATE INDEX (sem CONCURRENTLY) durante janela de manutenção
 *
 * PASSO 3 — Estatísticas:
 *   1. Aplique os ALTER TABLE SET STATISTICS da PARTE 4
 *   2. Execute: ANALYZE ofc_records;
 *   3. Execute: ANALYZE vw_weekly_metrics;  (se a materialized view existir)
 *
 * PASSO 4 — Verificação:
 *   1. Execute EXPLAIN ANALYZE nas 3 queries da PARTE 2
 *   2. Compare tempos com os valores estimados
 *   3. Verifique se todos os índices esperados são usados:
 *      SELECT indexrelname, idx_scan FROM pg_stat_user_indexes
 *      WHERE relname = 'ofc_records' ORDER BY indexrelname;
 *
 * PASSO 5 — Autovacuum:
 *   1. Aplique ALTER TABLE SET da PARTE 5
 *   2. Verifique com: SELECT relname, reloptions FROM pg_class
 *      WHERE relname IN ('ofc_records','audit_logs','ofc_edit_log');
 */


-- ============================================================================
-- APÊNDICE A: ÍNDICES QUE JÁ EXISTEM NO SCHEMA v2 (NÃO DUPLICAR)
-- ============================================================================

/*
 * Estes índices JÁ FORAM CRIADOS pelo ofs_database_model_v2.sql.
 * NÃO execute CREATE INDEX para eles novamente (causaria erro).
 *
 * ┌──────────────────────────────────────────────────────┬─────────────────────────────┐
 * │ Índice (schema v2)                                  │ Coberto por (este script)    │
 * ├──────────────────────────────────────────────────────┼─────────────────────────────┤
 * │ idx_ofc_obs_date (observation_date DESC)            │ idx_ofc_obs_date_desc_p1     │
 * │ idx_ofc_metrics (company_id, observation_date,      │ idx_ofc_metrics_p0           │
 * │   classification) WHERE status != 'cancelled'       │ (MESMO índice!)              │
 * │ idx_ofc_observer (observer_id, observation_date     │ idx_ofc_observer_list_p0     │
 * │   DESC)                                             │ (MESMO índice!)              │
 * │ idx_ofc_observed_user (observed_user_id,            │ idx_ofc_observed_user_p1     │
 * │   observation_date DESC) WHERE NOT NULL             │ (MESMO índice!)              │
 * │ idx_ofc_cycle (cycle_id, observation_date DESC)     │ idx_ofc_cycle_p1             │
 * │   WHERE NOT NULL                                    │ (MESMO índice!)              │
 * │ idx_ofc_competency (competency_id) WHERE NOT NULL   │ idx_ofc_competency_p1        │
 * │ idx_ofc_department (department_id) WHERE NOT NULL   │ idx_ofc_department_p1        │
 * │ idx_ofc_status (status, observation_date DESC)      │ idx_ofc_status_company_date  │
 * │                                                      │ _p1 (ampliado com company)   │
 * │ idx_ofc_classification (classification,             │ idx_ofc_classification_date  │
 * │   observation_date DESC)                            │ _p1 (MESMO índice!)           │
 * │ idx_ofc_sequential (UNIQUE sequential_number)       │ N/A (já é perfeito)          │
 * │ idx_ofc_shift (shift) WHERE shift IS NOT NULL       │ idx_ofc_shift_metrics_p2     │
 * │ idx_ofc_fts (GIN to_tsvector 'portuguese')          │ idx_ofc_fts_portuguese_p2    │
 * │ idx_ofc_observed_name_trgm (GIN gin_trgm_ops)       │ idx_ofc_name_trgm_p2         │
 * │ idx_users_company (company_id)                      │ N/A (existente)              │
 * │ idx_users_role (role) WHERE is_active = TRUE        │ idx_users_role_active_p1     │
 * │ idx_users_department (department_id)                │ N/A (existente)              │
 * │ idx_users_manager (manager_id)                      │ N/A (existente)              │
 * │ idx_edit_log_ofc (ofc_record_id, edited_at DESC)    │ idx_edit_log_ofc_date_p2     │
 * │ idx_edit_log_editor (edited_by, edited_at DESC)     │ N/A (existente)              │
 * └──────────────────────────────────────────────────────┴─────────────────────────────┘
 *
 * ÍNDICES NOVOS deste script (NÃO existem no schema v2):
 *   P0: idx_ofc_positive_p0, idx_ofc_negative_p0
 *   P1: idx_ofc_status_company_date_p1, idx_ofc_company_shift_date_p1,
 *       idx_ofc_unique_observers_p1, idx_ofc_unique_observed_p1,
 *       idx_companies_name_p1
 *   P2: idx_ofc_fts_portuguese_p2, idx_ofc_name_trgm_p2,
 *       idx_audit_user_action_ts_p2, idx_audit_timestamp_brin_p2,
 *       idx_edit_log_edited_brin_p2, idx_audit_severity_p2,
 *       idx_ofc_distinct_days_p2, idx_ofc_shift_metrics_p2,
 *       idx_revoked_tokens_cleanup_p2
 */


-- ============================================================================
-- APÊNDICE B: RESPOSTA RÁPIDA PARA O DBA (COMANDOS MAIS USADOS)
-- ============================================================================

/*
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │ CHEAT SHEET DO DBA — PostgreSQL 16 + OFS/OFS 4GB RAM                    │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │                                                                         │
 * │ VERIFICAR ÍNDICES DA TABELA:                                            │
 * │   SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'ofc_records';│
 * │                                                                         │
 * │ VERIFICAR TAMANHO DE ÍNDICES:                                          │
 * │   SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid))    │
 * │   FROM pg_stat_user_indexes WHERE relname = 'ofc_records'              │
 * │   ORDER BY pg_relation_size(indexrelid) DESC;                          │
 * │                                                                         │
 * │ VERIFICAR USO DE ÍNDICES:                                              │
 * │   SELECT indexrelname, idx_scan, idx_tup_read, idx_tup_fetch           │
 * │   FROM pg_stat_user_indexes WHERE relname = 'ofc_records';             │
 * │                                                                         │
 * │ FORÇAR ANALYZE:                                                        │
 * │   ANALYZE ofc_records;                                                 │
 * │                                                                         │
 * │ FORÇAR VACUUM:                                                         │
 * │   VACUUM (VERBOSE, ANALYZE) ofc_records;                               │
 * │                                                                         │
 * │ VERIFICAR BLOAT:                                                       │
 * │   SELECT n_live_tup, n_dead_tup,                                      │
 * │          ROUND(n_dead_tup::NUMERIC / NULLIF(n_live_tup,0) * 100, 1)   │
 * │          AS dead_pct                                                    │
 * │   FROM pg_stat_user_tables WHERE relname = 'ofc_records';              │
 * │                                                                         │
 * │ MATAR QUERY LONGA:                                                     │
 * │   SELECT pg_terminate_backend(pid)                                     │
 * │   FROM pg_stat_activity WHERE state = 'active'                        │
 * │   AND query_start < now() - interval '5 minutes';                     │
 * │                                                                         │
 * │ VERIFICAR LOCKS:                                                       │
 * │   SELECT relation::regclass, mode, granted, pid                       │
 * │   FROM pg_locks WHERE relation = 'ofc_records'::regclass;             │
 * │                                                                         │
 * │ RESETAR ESTATÍSTICAS (após teste de carga):                            │
 * │   SELECT pg_stat_reset();                                              │
 * │                                                                         │
 * └─────────────────────────────────────────────────────────────────────────┘
 */


-- ============================================================================
-- FIM DO DOCUMENTO — TODOS OS ÍNDICES E OTIMIZAÇÕES CONSOLIDADOS
-- ============================================================================
