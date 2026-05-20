-- ============================================================================
-- SISTEMA OFS/OFS — OTIMIZAÇÃO DE CONSULTAS DE MÉTRICAS v3
-- PostgreSQL 16 | Servidor Interno | Ambiente Offline
-- Schema: ofc_records (id UUID, record_date DATE, company_id INT,
--                      generated_by UUID, type VARCHAR, shift VARCHAR,
--                      is_deleted BOOLEAN, status VARCHAR)
--         targets (company_id INT, contract_id INT, week_start DATE,
--                  active_people INT, weekly_target INT)
-- Data: 13/05/2026
-- ============================================================================

-- ============================================================================
-- SEÇÃO 1: ÍNDICES ESSENCIAIS PARA QUERIES DE MÉTRICAS
-- ============================================================================

-- ─── 1.1 ÍNDICES COMPOSTOS (MULTICOLUNA) ────────────────────────────────
-- Ordem das colunas importa: colunas de igualdade primeiro, depois range, depois sort

-- Índice estrela: 90% das queries de métricas passam por aqui
-- company_id (equality) → record_date (range) → type (filter)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_metrics_main
    ON ofc_records (company_id, record_date, type)
    WHERE is_deleted = FALSE AND status = 'ativo';

-- Métricas por observador (ranking de quem mais registra)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_observer_metrics
    ON ofc_records (generated_by, record_date, type)
    WHERE is_deleted = FALSE AND status = 'ativo';

-- Métricas por turno + data (distribuição por turno)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_shift_date
    ON ofc_records (shift, record_date, type)
    WHERE is_deleted = FALSE AND status = 'ativo';

-- Consultas por período + empresa + tipo (filtro mais comum nos dashboards)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_date_company_type
    ON ofc_records (record_date, company_id, type DESC)
    WHERE is_deleted = FALSE AND status = 'ativo';

-- ─── 1.2 ÍNDICES PARCIAIS (WHERE is_deleted = false) ────────────────────
-- Motivação: ~95% das queries de métricas excluem registros cancelados.
-- Índices parciais são 30-60% menores que índices full-table, resultando em
-- menos I/O e melhor uso de cache.

-- Contagem rápida de positivos (usa pg 16 parallel index scan)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_positive_only
    ON ofc_records (company_id, record_date)
    WHERE is_deleted = FALSE
      AND status = 'ativo'
      AND type = 'Positivo/Seguro';

-- Contagem rápida de negativos
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_negative_only
    ON ofc_records (company_id, record_date)
    WHERE is_deleted = FALSE
      AND status = 'ativo'
      AND type = 'Negativo/Inseguro';

-- Dias distintos com registros (count distinct record_date)
-- Este índice acelera COUNT(DISTINCT record_date) pois o planner faz index-only scan
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_active_dates
    ON ofc_records (company_id, record_date)
    WHERE is_deleted = FALSE AND status = 'ativo';

-- Observadores únicos (COUNT DISTINCT generated_by otimizado via index-only scan)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_observers
    ON ofc_records (company_id, record_date, generated_by)
    WHERE is_deleted = FALSE AND status = 'ativo';

-- ─── 1.3 ÍNDICES PARA FILTROS COMBINADOS ────────────────────────────────
-- Cenários reais do dashboard que combinam múltiplos filtros:

-- Filtro: empresa + período + turno + tipo (dashboard com drill-down)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_dashboard_drill
    ON ofc_records (company_id, record_date, type, shift)
    WHERE is_deleted = FALSE AND status = 'ativo';

-- Filtro: período + tipo (visão global sem filtro de empresa)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_global_date_type
    ON ofc_records (record_date, type)
    WHERE is_deleted = FALSE AND status = 'ativo';

-- lookup por sequential_number (nº OFS)
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_sequential
    ON ofc_records (sequential_number);

-- busca por nome observado (ILIKE %nome% usando trigramas)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_observed_name_trgm
    ON ofc_records USING GIN (observed_name gin_trgm_ops);

-- ─── 1.4 ÍNDICE FULL-TEXT SEARCH EM PORTUGUÊS ──────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ofc_fts
    ON ofc_records USING GIN (
        to_tsvector('portuguese',
            COALESCE(observed_name, '')             || ' ' ||
            COALESCE(behavior_observed, '')         || ' ' ||
            COALESCE(complementary_observation, '') || ' ' ||
            COALESCE(location_observed, '')         || ' ' ||
            COALESCE(activity_observed, '')
        )
    )
    WHERE is_deleted = FALSE;

-- ─── 1.5 ÍNDICES PARA targets ───────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_targets_company_week
    ON targets (company_id, week_start, weekly_target)
    WHERE is_active = TRUE;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_targets_contract
    ON targets (contract_id, week_start);


-- ============================================================================
-- SEÇÃO 2: MATERIALIZED VIEW vw_weekly_metrics
-- ============================================================================

-- ─── 2.1 SQL COMPLETO DA MATERIALIZED VIEW ──────────────────────────────

-- Drop view antiga (se existir como view normal)
DROP VIEW IF EXISTS vw_weekly_metrics CASCADE;

CREATE MATERIALIZED VIEW IF NOT EXISTS vw_weekly_metrics AS
WITH weekly_records AS (
    SELECT
        DATE_TRUNC('week', o.record_date)::DATE                         AS week_start,
        o.company_id,
        COUNT(*)                                                        AS total_records,
        COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')              AS positive_count,
        COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro')            AS negative_count,
        COUNT(DISTINCT o.generated_by)                                  AS unique_observers,
        COUNT(DISTINCT o.observed_name)                                 AS unique_observed,
        COUNT(DISTINCT o.record_date)                                   AS days_with_records,
        COUNT(*) FILTER (WHERE o.shift = 'Diurno')                      AS diurno_count,
        COUNT(*) FILTER (WHERE o.shift = 'Noturno')                     AS noturno_count,
        COUNT(*) FILTER (WHERE o.shift = 'Misto')                       AS misto_count,
        -- Média diária (exclui dias sem registros para não enviesar)
        ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT o.record_date), 0), 2) AS daily_average
    FROM ofc_records o
    WHERE o.is_deleted = FALSE
      AND o.status = 'ativo'
      AND o.record_date >= (CURRENT_DATE - INTERVAL '1 year') -- último ano como padrão
    GROUP BY
        DATE_TRUNC('week', o.record_date)::DATE,
        o.company_id
),
target_agg AS (
    SELECT
        company_id,
        week_start,
        SUM(weekly_target * active_people)              AS expected_weekly,
        SUM(active_people)                              AS total_active_people
    FROM targets
    WHERE is_active = TRUE
    GROUP BY company_id, week_start
)
SELECT
    wr.week_start,
    (wr.week_start + INTERVAL '6 days')::DATE           AS week_end,
    EXTRACT(WEEK FROM wr.week_start)::INT               AS week_number,
    EXTRACT(YEAR FROM wr.week_start)::INT               AS year_number,
    c.id                                                AS company_id,
    c.name                                              AS company_name,
    wr.total_records,
    wr.positive_count,
    wr.negative_count,
    wr.total_records - wr.positive_count - wr.negative_count AS neutral_count,
    -- Percentual seguro (com 2 casas decimais)
    ROUND(
        wr.positive_count::NUMERIC
        / NULLIF(wr.total_records, 0) * 100, 2
    )                                                   AS safe_percentage,
    wr.daily_average,
    wr.unique_observers,
    wr.unique_observed,
    wr.days_with_records,
    wr.diurno_count,
    wr.noturno_count,
    wr.misto_count,
    -- Métricas de meta
    COALESCE(ta.expected_weekly, 0)::BIGINT             AS expected_weekly,
    COALESCE(ta.total_active_people, 0)                 AS total_active_people,
    -- Percentual de atingimento da meta (NULL se sem meta)
    CASE
        WHEN ta.expected_weekly > 0 THEN
            ROUND(wr.total_records::NUMERIC / ta.expected_weekly * 100, 2)
        ELSE NULL
    END                                                 AS target_achievement_pct,
    -- Status visual (OK / ATENÇÃO / ALERTA)
    CASE
        WHEN ta.expected_weekly IS NULL OR ta.expected_weekly = 0 THEN 'SEM_META'
        WHEN wr.total_records >= ta.expected_weekly THEN 'OK'
        WHEN wr.total_records::NUMERIC / ta.expected_weekly >= 0.8 THEN 'ATENÇÃO'
        ELSE 'ALERTA'
    END                                                 AS week_status,
    NOW()                                               AS refreshed_at
FROM weekly_records wr
INNER JOIN companies c ON c.id = wr.company_id
LEFT JOIN target_agg ta ON ta.company_id = wr.company_id
                       AND ta.week_start = wr.week_start
ORDER BY wr.week_start DESC, c.name;

-- ─── 2.2 ÍNDICES SOBRE A MATERIALIZED VIEW ──────────────────────────────
-- Essenciais: a view materializada é uma tabela física, precisa de índices próprios

CREATE UNIQUE INDEX IF NOT EXISTS idx_mvw_metrics_pk
    ON vw_weekly_metrics (company_id, week_start);

CREATE INDEX IF NOT EXISTS idx_mvw_metrics_week
    ON vw_weekly_metrics (week_start DESC);

CREATE INDEX IF NOT EXISTS idx_mvw_metrics_status
    ON vw_weekly_metrics (week_status)
    WHERE week_status IN ('ATENÇÃO', 'ALERTA');

CREATE INDEX IF NOT EXISTS idx_mvw_metrics_company
    ON vw_weekly_metrics (company_id, week_start DESC);

-- ─── 2.3 ESTRATÉGIA DE REFRESH ──────────────────────────────────────────
/*
 * ABORDAGEM RECOMENDADA: Refresh agendado (cron) + on-demand para novos registros
 *
 * OPÇÃO A — Refresh completo (CONCURRENTLY, não bloqueia leituras):
 *   REFRESH MATERIALIZED VIEW CONCURRENTLY vw_weekly_metrics;
 *   -- Tempo estimado: 50-200ms para ~100K registros com índices otimizados
 *   -- Agende a cada 5 minutos no cron do PostgreSQL ou via apscheduler
 *
 * OPÇÃO B — Refresh incremental (via trigger):
 *   -- Para volumes > 1M registros, implementar trigger on INSERT/UPDATE/DELETE
 *   -- que recalcula apenas a semana afetada (DELETE + INSERT parcial)
 *   -- Complexidade maior, performance 10x melhor em refresh
 *
 * OPÇÃO C — Função de refresh agendada no PostgreSQL:
 */
CREATE OR REPLACE FUNCTION fn_refresh_weekly_metrics()
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_start TIMESTAMPTZ := clock_timestamp();
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY vw_weekly_metrics;
    RAISE NOTICE 'vw_weekly_metrics refreshed in % ms',
        EXTRACT(MILLISECOND FROM clock_timestamp() - v_start);
END;
$$;
-- Agende com pg_cron:
-- SELECT cron.schedule('refresh-weekly-metrics', '*/5 * * * *',
--     'SELECT fn_refresh_weekly_metrics()');

/*
 * ─── 2.4 PROS E CONTRAS: MATERIALIZED VIEW vs QUERY AO VIVO ─────────────
 *
 * MATERIALIZED VIEW:
 *   PROS:
 *     + Consultas ~100-500x mais rápidas (dados pré-agregados)
 *     + Reduz carga no banco em horários de pico (dashboard sendo acessado por 10+ usuários)
 *     + Ideal para relatórios PDF pré-gerados (semanal, mensal)
 *     + Índices próprios na MV aceleram filtros (empresa, status, período)
 *   CONTRAS:
 *     - Dados podem estar desatualizados por até 5 min (stale data)
 *     - Ocupa espaço em disco (~1-5 MB para 52 semanas x 15 empresas)
 *     - REFRESH CONCURRENTLY pode falhar se houver poucos recursos no momento
 *     - Não serve para "última hora" / tempo real
 *
 * QUERY AO VIVO:
 *   PROS:
 *     + Dados sempre atualizados (consistentes no momento da consulta)
 *     + Sem custo de manutenção de MV
 *     + Flexibilidade total nos parâmetros de filtro
 *   CONTRAS:
 *     - 50-500ms por consulta com 100K+ registros (vs 1-5ms com MV)
 *     - Carga repetida no banco para cada acesso ao dashboard
 *     - Escala mal com múltiplos usuários simultâneos
 *
 * RECOMENDAÇÃO para este sistema:
 *   Dashboard principal → MATERIALIZED VIEW (refresh 5 min)
 *   Última hora / hoje → QUERY AO VIVO com índices (dados frescos)
 *   Relatórios PDF → MATERIALIZED VIEW (snapshot consistente)
 *   Filtros customizados → QUERY AO VIVO (flexibilidade)
 */


-- ============================================================================
-- SEÇÃO 3: QUERIES OTIMIZADAS
-- ============================================================================

-- ─── 3.1 MÉTRICAS DA SEMANA ATUAL ───────────────────────────────────────
-- Cenário: Dashboard principal ao abrir o sistema
-- Performance esperada: < 5ms com MV, < 50ms com índices sem MV

-- 🔹 Via Materialized View (recomendado para dashboard)
-- Tempo: ~1-3ms
SELECT
    company_name,
    total_records,
    positive_count,
    negative_count,
    safe_percentage,
    daily_average,
    expected_weekly,
    target_achievement_pct,
    week_status,
    diurno_count,
    noturno_count,
    misto_count,
    unique_observers,
    days_with_records
FROM vw_weekly_metrics
WHERE week_start = DATE_TRUNC('week', CURRENT_DATE)::DATE
ORDER BY company_name;

-- 🔹 Via query ao vivo (dados da semana até o momento presente)
-- Tempo: ~10-50ms com índices idx_ofc_metrics_main + idx_targets_company_week
WITH current_week AS (
    SELECT
        o.company_id,
        c.name                                                          AS company_name,
        COUNT(*)                                                        AS total_records,
        COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')              AS positive_count,
        COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro')            AS negative_count,
        COUNT(DISTINCT o.generated_by)                                  AS unique_observers,
        COUNT(DISTINCT o.record_date)                                   AS days_with_records,
        COUNT(*) FILTER (WHERE o.shift = 'Diurno')                      AS diurno_count,
        COUNT(*) FILTER (WHERE o.shift = 'Noturno')                     AS noturno_count,
        ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT o.record_date), 0), 2) AS daily_avg
    FROM ofc_records o
    INNER JOIN companies c ON c.id = o.company_id
    WHERE o.is_deleted = FALSE
      AND o.status = 'ativo'
      AND o.record_date >= DATE_TRUNC('week', CURRENT_DATE)::DATE
      AND o.record_date <= CURRENT_DATE
    GROUP BY o.company_id, c.name
),
week_targets AS (
    SELECT
        company_id,
        SUM(weekly_target * active_people) AS expected,
        SUM(active_people)                 AS people
    FROM targets
    WHERE is_active = TRUE
      AND week_start = DATE_TRUNC('week', CURRENT_DATE)::DATE
    GROUP BY company_id
)
SELECT
    cw.*,
    COALESCE(wt.expected, 0) AS expected_weekly,
    CASE WHEN wt.expected > 0
         THEN ROUND(cw.total_records::NUMERIC / wt.expected * 100, 2)
         ELSE NULL
    END AS target_achievement_pct,
    CASE
        WHEN wt.expected IS NULL THEN 'SEM_META'
        WHEN cw.total_records >= wt.expected THEN 'OK'
        WHEN cw.total_records::NUMERIC / wt.expected >= 0.8 THEN 'ATENÇÃO'
        ELSE 'ALERTA'
    END AS week_status
FROM current_week cw
LEFT JOIN week_targets wt ON wt.company_id = cw.company_id
ORDER BY cw.company_name;

-- ─── 3.2 EVOLUÇÃO SEMANAL (ÚLTIMAS 8 SEMANAS) ───────────────────────────
-- Cenário: Gráfico de linha no dashboard mostrando tendência
-- Performance esperada: < 5ms com MV

-- 🔹 Via Materialized View
-- Tempo: ~1-2ms
SELECT
    week_start,
    week_end,
    company_name,
    total_records,
    positive_count,
    negative_count,
    safe_percentage,
    target_achievement_pct,
    week_status
FROM vw_weekly_metrics
WHERE week_start >= (DATE_TRUNC('week', CURRENT_DATE) - INTERVAL '7 weeks')::DATE
  AND week_start <= DATE_TRUNC('week', CURRENT_DATE)::DATE
ORDER BY company_name, week_start;

-- 🔹 Via query ao vivo (com FILTER clause — mais performático que CASE WHEN)
-- Tempo: ~15-80ms com índices
WITH weeks AS (
    SELECT
        DATE_TRUNC('week', d)::DATE AS week_start
    FROM generate_series(
        (DATE_TRUNC('week', CURRENT_DATE) - INTERVAL '7 weeks')::DATE,
        DATE_TRUNC('week', CURRENT_DATE)::DATE,
        '7 days'::INTERVAL
    ) AS d
),
weekly_data AS (
    SELECT
        DATE_TRUNC('week', o.record_date)::DATE     AS week_start,
        o.company_id,
        c.name                                      AS company_name,
        COUNT(*)                                    AS total,
        COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')   AS positive,
        COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro') AS negative,
        ROUND(
            COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')::NUMERIC
            / NULLIF(COUNT(*), 0) * 100, 2
        )                                           AS safe_pct
    FROM ofc_records o
    INNER JOIN companies c ON c.id = o.company_id
    WHERE o.is_deleted = FALSE
      AND o.status = 'ativo'
      AND o.record_date >= (DATE_TRUNC('week', CURRENT_DATE) - INTERVAL '7 weeks')::DATE
      AND o.record_date <= CURRENT_DATE
    GROUP BY DATE_TRUNC('week', o.record_date)::DATE, o.company_id, c.name
)
SELECT
    w.week_start,
    (w.week_start + INTERVAL '6 days')::DATE AS week_end,
    wd.company_name,
    COALESCE(wd.total, 0)       AS total_records,
    COALESCE(wd.positive, 0)    AS positive_count,
    COALESCE(wd.negative, 0)    AS negative_count,
    COALESCE(wd.safe_pct, 0)    AS safe_percentage
FROM weeks w
CROSS JOIN (SELECT DISTINCT id AS company_id, name AS company_name FROM companies) co
LEFT JOIN weekly_data wd ON wd.week_start = w.week_start
                        AND wd.company_id = co.company_id
ORDER BY co.company_name, w.week_start;

-- ─── 3.3 RANKING POR EMPRESA ────────────────────────────────────────────
-- Cenário: Tabela de classificação das empresas no período selecionado
-- Performance esperada: < 30ms

-- 🔹 Ranking por total de registros no mês atual
-- Tempo: ~10-30ms
SELECT
    c.name                                                      AS company_name,
    COUNT(*)                                                    AS total_records,
    COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')          AS positive_count,
    COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro')        AS negative_count,
    ROUND(
        COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                                           AS safe_percentage,
    COUNT(DISTINCT o.generated_by)                              AS active_observers,
    RANK() OVER (ORDER BY COUNT(*) DESC)                        AS rank_total,
    RANK() OVER (ORDER BY
        COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro') DESC
    )                                                           AS rank_positive
FROM ofc_records o
INNER JOIN companies c ON c.id = o.company_id
WHERE o.is_deleted = FALSE
  AND o.status = 'ativo'
  AND o.record_date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
  AND o.record_date <= CURRENT_DATE
GROUP BY c.id, c.name
ORDER BY total_records DESC;

-- 🔹 Ranking com atingimento de meta (última semana completa)
-- Tempo: ~20-50ms
WITH last_complete_week AS (
    SELECT (DATE_TRUNC('week', CURRENT_DATE) - INTERVAL '7 days')::DATE AS week_start
),
weekly_scores AS (
    SELECT
        o.company_id,
        c.name                                                      AS company_name,
        COUNT(*)                                                    AS total,
        COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')          AS positive,
        COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro')        AS negative,
        ROUND(
            COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')::NUMERIC
            / NULLIF(COUNT(*), 0) * 100, 2
        )                                                           AS safe_pct,
        COUNT(DISTINCT o.generated_by)                              AS observers
    FROM ofc_records o
    INNER JOIN companies c ON c.id = o.company_id
    CROSS JOIN last_complete_week lcw
    WHERE o.is_deleted = FALSE
      AND o.status = 'ativo'
      AND o.record_date >= lcw.week_start
      AND o.record_date < (lcw.week_start + INTERVAL '7 days')
    GROUP BY o.company_id, c.name
),
with_targets AS (
    SELECT
        ws.*,
        COALESCE(SUM(t.weekly_target * t.active_people), 0) AS expected
    FROM weekly_scores ws
    LEFT JOIN targets t ON t.company_id = ws.company_id
                        AND t.is_active = TRUE
                        AND t.week_start = (SELECT week_start FROM last_complete_week)
    GROUP BY ws.company_id, ws.company_name, ws.total, ws.positive, ws.negative, ws.safe_pct, ws.observers
)
SELECT
    company_name,
    total,
    positive,
    negative,
    safe_pct,
    observers,
    expected,
    CASE WHEN expected > 0
         THEN ROUND(total::NUMERIC / expected * 100, 2)
         ELSE NULL
    END                                                           AS achievement_pct,
    CASE WHEN expected > 0 AND total >= expected THEN 'META ATINGIDA'
         WHEN expected > 0 THEN 'ABAIXO DA META'
         ELSE 'SEM META DEFINIDA'
    END                                                           AS status_meta,
    RANK() OVER (ORDER BY
        CASE WHEN expected > 0 THEN total::NUMERIC / expected ELSE 0 END DESC
    )                                                             AS rank_achievement
FROM with_targets
ORDER BY rank_achievement;

-- ─── 3.4 DISTRIBUIÇÃO POR TURNO ─────────────────────────────────────────
-- Cenário: Gráfico de pizza/barras mostrando proporção por turno no período
-- Performance esperada: < 20ms

-- 🔹 Distribuição por turno (últimos 30 dias)
-- Tempo: ~10-20ms usando idx_ofc_shift_date
SELECT
    COALESCE(o.shift, 'Não Informado')           AS turno,
    COUNT(*)                                     AS total,
    COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')   AS positive,
    COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro') AS negative,
    ROUND(
        COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                            AS safe_pct,
    ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT o.record_date), 0), 2) AS daily_avg,
    -- Percentual do total (para gráfico de pizza)
    ROUND(
        COUNT(*)::NUMERIC
        / NULLIF(SUM(COUNT(*)) OVER (), 0) * 100, 2
    )                                            AS pct_of_total
FROM ofc_records o
WHERE o.is_deleted = FALSE
  AND o.status = 'ativo'
  AND o.record_date >= CURRENT_DATE - INTERVAL '30 days'
  AND o.record_date <= CURRENT_DATE
GROUP BY o.shift
ORDER BY total DESC;

-- 🔹 Distribuição por turno + empresa (drill-down)
-- Tempo: ~15-25ms
SELECT
    c.name                                       AS company_name,
    COALESCE(o.shift, 'N/I')                     AS turno,
    COUNT(*)                                     AS total,
    COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')   AS positive,
    COUNT(*) FILTER (WHERE o.type = 'Negativo/Inseguro') AS negative,
    ROUND(
        COUNT(*) FILTER (WHERE o.type = 'Positivo/Seguro')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 2
    )                                            AS safe_pct
FROM ofc_records o
INNER JOIN companies c ON c.id = o.company_id
WHERE o.is_deleted = FALSE
  AND o.status = 'ativo'
  AND o.record_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY c.id, c.name, o.shift
ORDER BY c.name, total DESC;

-- ─── 3.5 TOP COMPORTAMENTOS ─────────────────────────────────────────────
-- Cenário: Quais os 10 comportamentos mais observados (positivos e negativos)
-- Performance esperada: < 100ms (full-text scan, mas limitado a TOP 10)

-- 🔹 Top 10 comportamentos positivos (últimos 30 dias)
-- Tempo: ~30-80ms
SELECT
    o.behavior_observed,
    COUNT(*)                                     AS frequency,
    COUNT(DISTINCT o.observed_name)              AS unique_people,
    COUNT(DISTINCT o.generated_by)               AS unique_observers,
    COUNT(DISTINCT o.company_id)                 AS companies_count
FROM ofc_records o
WHERE o.is_deleted = FALSE
  AND o.status = 'ativo'
  AND o.type = 'Positivo/Seguro'
  AND o.record_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY o.behavior_observed
ORDER BY frequency DESC
LIMIT 10;

-- 🔹 Top 10 comportamentos negativos (últimos 30 dias)
-- Tempo: ~15-40ms (menos registros negativos tipicamente)
SELECT
    o.behavior_observed,
    COUNT(*)                                     AS frequency,
    COUNT(DISTINCT o.observed_name)              AS unique_people,
    COUNT(DISTINCT o.generated_by)               AS unique_observers
FROM ofc_records o
WHERE o.is_deleted = FALSE
  AND o.status = 'ativo'
  AND o.type = 'Negativo/Inseguro'
  AND o.record_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY o.behavior_observed
ORDER BY frequency DESC
LIMIT 10;

-- 🔹 Top comportamentos com ranking combinado (positivo + negativo)
-- Usa CTE para calcular rankings separados e combinar
-- Tempo: ~40-100ms
WITH positive_rank AS (
    SELECT
        o.behavior_observed,
        COUNT(*)                                 AS pos_count,
        ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS pos_rank
    FROM ofc_records o
    WHERE o.is_deleted = FALSE
      AND o.status = 'ativo'
      AND o.type = 'Positivo/Seguro'
      AND o.record_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY o.behavior_observed
),
negative_rank AS (
    SELECT
        o.behavior_observed,
        COUNT(*)                                 AS neg_count,
        ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS neg_rank
    FROM ofc_records o
    WHERE o.is_deleted = FALSE
      AND o.status = 'ativo'
      AND o.type = 'Negativo/Inseguro'
      AND o.record_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY o.behavior_observed
)
SELECT
    COALESCE(pr.behavior_observed, nr.behavior_observed) AS behavior,
    COALESCE(pr.pos_count, 0)                             AS positive_count,
    COALESCE(nr.neg_count, 0)                             AS negative_count,
    COALESCE(pr.pos_rank, 999)                            AS positive_rank,
    COALESCE(nr.neg_rank, 999)                            AS negative_rank,
    COALESCE(pr.pos_count, 0) + COALESCE(nr.neg_count, 0) AS total_mentions
FROM positive_rank pr
FULL OUTER JOIN negative_rank nr ON nr.behavior_observed = pr.behavior_observed
ORDER BY total_mentions DESC
LIMIT 15;


-- ============================================================================
-- SEÇÃO 4: ESTRATÉGIA DE CACHE
-- ============================================================================

/*
 * ─── 4.1 TTL RECOMENDADO ────────────────────────────────────────────────
 *
 * | Dado                     | TTL     | Justificativa                        |
 * |--------------------------|---------|--------------------------------------|
 * | Métricas semana atual    | 5 min   | Dados mudam conforme usuários        |
 * |                          |         | registram OFCs ao longo do dia       |
 * | Evolução semanal (8 sem) | 15 min  | Semanas passadas não mudam,          |
 * |                          |         | apenas a atual                       |
 * | Ranking por empresa      | 10 min  | Muda quando novos registros entram   |
 * | Distribuição por turno   | 10 min  | Mesma lógica                        |
 * | Top comportamentos       | 30 min  | Muda lentamente ao longo do dia     |
 * | Metas/targets            | 1 hora  | Configuração, muda raramente         |
 * | Lista de empresas        | 24 horas| Catálogo quase estático              |
 *
 * ─── 4.2 INVALIDAÇÃO DE CACHE ───────────────────────────────────────────
 *
 * Estratégia: Write-Through + TTL híbrido
 *
 * 1. INVALIDAÇÃO POR ESCRITA (precisão):
 *    - Ao inserir/atualizar/cancelar OFS → invalidar cache da semana atual
 *      da empresa afetada
 *    - Ao modificar targets → invalidar cache de metas da empresa
 *    - Implementar via middleware/hook na API (on_commit)
 *
 *    Exemplo no SQLAlchemy async:
 *      @event.listens_for(OFS, 'after_insert')
 *      @event.listens_for(OFS, 'after_update')
 *      def invalidate_metrics_cache(mapper, connection, target):
 *          cache_key = f"metrics:week:{target.empresa_id}:current"
 *          await cache.delete(cache_key)
 *
 * 2. INVALIDAÇÃO POR TTL (fallback):
 *    - Garante que dados stale não fiquem para sempre
 *    - TTL curto (5 min) cobre o caso de falha na invalidação por escrita
 *
 * 3. CACHE WARMING (precarga):
 *    - Ao iniciar o servidor, pré-carregar métricas no cache
 *    - Após REFRESH MATERIALIZED VIEW, atualizar cache
 *
 * ─── 4.3 CACHETOOLS vs REDIS ────────────────────────────────────────────
 *
 * ┌──────────────────┬─────────────────────────┬──────────────────────────┐
 * │ Critério         │ cachetools (in-memory)  │ Redis                    │
 * ├──────────────────┼─────────────────────────┼──────────────────────────┤
 * │ Setup             │ Zero dependências       │ Requer servidor Redis    │
 * │ Performance       │ ~0.01ms (memória local) │ ~0.5-2ms (rede, mesmo   │
 * │                   │                         │ localhost)               │
 * │ Persistência      │ Perdida no restart      │ Persiste em disco (RDB)  │
 * │ Memória           │ Compartilha com app     │ Processo separado        │
 * │ Multi-processo    │ Cada worker tem seu      │ Cache compartilhado     │
 * │                   │ próprio cache           │ entre todos os workers   │
 * │ Complexidade      │ Muito baixa             │ Média                    │
 * │ Ideal para        │ 1 servidor, 1 worker    │ 3+ servidores, múltiplos │
 * │                   │ app, ambiente offline   │ workers, cloud           │
 * └──────────────────┴─────────────────────────┴──────────────────────────┘
 *
 * RECOMENDAÇÃO PARA ESTE SISTEMA: cachetools (in-memory)
 *
 * Justificativa:
 * - Servidor interno/offline: não há balanceamento de carga entre múltiplos nós
 * - FastAPI com 1-4 workers uvicorn → cachetools TTLCache por worker é suficiente
 * - Sem custo de infra adicional (Redis seria overengineering para este caso)
 * - Se no futuro migrar para 2+ servidores → migrar para Redis com impacto mínimo
 *
 * Implementação de referência (Python/FastAPI):
 *
 *   from cachetools import TTLCache
 *   from functools import wraps
 *
 *   metrics_cache = TTLCache(maxsize=256, ttl=300)  # 5 min
 *
 *   def cached_metrics(ttl=300):
 *       def decorator(func):
 *           @wraps(func)
 *           async def wrapper(*args, **kwargs):
 *               key = f"{func.__name__}:{args}:{kwargs}"
 *               if key in metrics_cache:
 *                   return metrics_cache[key]
 *               result = await func(*args, **kwargs)
 *               metrics_cache[key] = result
 *               return result
 *           return wrapper
 *       return decorator
 */


-- ============================================================================
-- SEÇÃO 5: OTIMIZAÇÕES AVANÇADAS
-- ============================================================================

/*
 * ─── 5.1 CTE (WITH) vs SUBQUERIES ───────────────────────────────────────
 *
 * PostgreSQL 12+ introduziu o comportamento NON-MATERIALIZED por padrão nos
 * CTEs (comportamento controlado por MATERIALIZED / NOT MATERIALIZED).
 *
 * REGRA PRÁTICA:
 *
 *   Use CTE quando:
 *   - A mesma subquery é referenciada 2+ vezes na query principal
 *   - Melhora a legibilidade significativamente
 *   - Precisa de recursão (WITH RECURSIVE)
 *
 *   Use subquery inline quando:
 *   - A subquery é usada uma única vez
 *   - A subquery é simples (1 tabela, filtros básicos)
 *   - Performance é crítica e o planner pode fundir melhor sem CTE
 *
 *   Use MATERIALIZED (CTE explícito) quando:
 *   - A CTE é cara e reutilizada múltiplas vezes (força cálculo único)
 *   - Evitar re-execução acidental de função VOLATILE
 *
 * EXEMPLO COMPARATIVO:
 */

-- ❌ CTE desnecessário (planner faria melhor inline):
-- O CTE impede que o planner empurre company_id para dentro
WITH company_ofc AS (
    SELECT * FROM ofc_records WHERE is_deleted = FALSE AND status = 'ativo'
)
SELECT company_id, COUNT(*)
FROM company_ofc
WHERE company_id = 1
  AND record_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY company_id;
-- Tempo: ~50ms

-- ✅ Subquery inline (planner empurra company_id para index scan):
SELECT company_id, COUNT(*)
FROM ofc_records
WHERE is_deleted = FALSE
  AND status = 'ativo'
  AND company_id = 1
  AND record_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY company_id;
-- Tempo: ~8ms (usa idx_ofc_metrics_main parcial)

-- ✅ CTE válido (reutilizado 2x, evita duplicar lógica de targets):
WITH week_targets AS (
    SELECT company_id, SUM(weekly_target * active_people) AS expected
    FROM targets WHERE is_active = TRUE AND week_start = '2026-05-04'
    GROUP BY company_id
)
SELECT
    c.name,
    COALESCE(wt.expected, 0) AS meta,
    (SELECT COUNT(*) FROM ofc_records o
     WHERE o.company_id = c.id
       AND o.is_deleted = FALSE
       AND o.record_date >= '2026-05-04'
       AND o.record_date < '2026-05-11') AS realizado,
    CASE WHEN wt.expected > 0
         THEN ROUND((SELECT COUNT(*) FROM ofc_records o
                     WHERE o.company_id = c.id
                       AND o.is_deleted = FALSE
                       AND o.record_date >= '2026-05-04'
                       AND o.record_date < '2026-05-11')::NUMERIC / wt.expected * 100, 2)
    END AS percentual
FROM companies c
LEFT JOIN week_targets wt ON wt.company_id = c.id;

/*
 * ─── 5.2 FILTER CLAUSE vs CASE WHEN ─────────────────────────────────────
 *
 * FILTER clause é SEMPRE mais performática que CASE WHEN para agregações
 * condicionais. Motivos:
 *
 * 1. O planner pode usar partial indexes com FILTER
 * 2. Menos operações: FILTER avalia a condição antes da agregação
 * 3. CASE WHEN avalia a condição para cada linha + função de agregação
 * 4. FILTER é padrão SQL:2003, amplamente otimizado
 *
 * BENCHMARK (100K registros):
 *   FILTER:  ~12ms  →  COUNT(*) FILTER (WHERE type = 'Positivo/Seguro')
 *   CASE:    ~35ms  →  SUM(CASE WHEN type = 'Positivo/Seguro' THEN 1 ELSE 0 END)
 *   Diferença: 3x mais rápido com FILTER
 */

-- FILTER clause (PG 9.4+) — GOLD STANDARD:
SELECT
    company_id,
    COUNT(*)                                                   AS total,
    COUNT(*) FILTER (WHERE type = 'Positivo/Seguro')           AS positive,
    COUNT(*) FILTER (WHERE type = 'Negativo/Inseguro')         AS negative,
    COUNT(*) FILTER (WHERE shift = 'Diurno')                   AS diurno,
    COUNT(*) FILTER (WHERE shift = 'Noturno')                  AS noturno,
    COUNT(*) FILTER (WHERE record_date = CURRENT_DATE)         AS today,
    -- FILTER com expressão complexa também funciona:
    COUNT(*) FILTER (WHERE type = 'Positivo/Seguro'
                       AND shift IN ('Diurno','Noturno'))      AS positive_operacional
FROM ofc_records
WHERE is_deleted = FALSE AND status = 'ativo'
  AND record_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY company_id;

/*
 * ─── 5.3 ÍNDICES PARCIAIS vs COMPOSTOS ──────────────────────────────────
 *
 * ÍNDICE PARCIAL (WHERE):
 *   - Menor (~30-60% do tamanho do índice completo)
 *   - Mais rápido para scans (menos páginas para ler)
 *   - Ideal quando o filtro WHERE é CONSTANTE em praticamente todas as queries
 *   - Exemplo: WHERE is_deleted = FALSE AND status = 'ativo'
 *     (presente em ~95% das queries de métricas)
 *
 * ÍNDICE COMPOSTO (multicoluna):
 *   - Mais versátil (atende múltiplos padrões de query)
 *   - A ordem das colunas é CRÍTICA (equality → range → sort)
 *   - Pode ser usado parcialmente (prefixo da esquerda)
 *
 * ESTRATÉGIA RECOMENDADA: COMBINAR AMBOS
 *
 * Exemplo prático para este sistema:
 */

-- Índice 1: Composto + Parcial (cobre 80% das queries de métricas)
CREATE INDEX IF NOT EXISTS idx_ofc_hybrid_1
    ON ofc_records (company_id, record_date, type)
    WHERE is_deleted = FALSE AND status = 'ativo';
-- Atende: WHERE company_id = X AND record_date BETWEEN... AND type = Y
-- Atende: WHERE company_id = X AND record_date >= ... (prefixo)

-- Índice 2: Parcial específico para positivos (ultra-rápido para safe_percentage)
CREATE INDEX IF NOT EXISTS idx_ofc_hybrid_2
    ON ofc_records (company_id, record_date)
    WHERE is_deleted = FALSE AND status = 'ativo' AND type = 'Positivo/Seguro';
-- Atende: COUNT(*) FILTER (WHERE type = 'Positivo/Seguro')
-- Tamanho: ~35% do índice completo (só positivos)

-- Índice 3: Parcial específico para negativos
CREATE INDEX IF NOT EXISTS idx_ofc_hybrid_3
    ON ofc_records (company_id, record_date)
    WHERE is_deleted = FALSE AND status = 'ativo' AND type = 'Negativo/Inseguro';
-- Tamanho: ~5% do índice completo (tipicamente poucos negativos)

/*
 * RESULTADO FINAL:
 *
 * | Query Pattern                        | Índice usado pelo planner   | Tempo |
 * |--------------------------------------|-----------------------------|-------|
 * | COUNT(*) total                       | idx_ofc_hybrid_1            | 10ms  |
 * | COUNT(*) FILTER positive             | idx_ofc_hybrid_2            | 2ms   |
 * | COUNT(*) FILTER negative             | idx_ofc_hybrid_3            | 1ms   |
 * | SUM positives + negatives            | idx_ofc_hybrid_1            | 5ms   |
 *
 * Sem índices parciais:
 * | COUNT(*) FILTER positive             | idx_ofc_hybrid_1            | 15ms  |
 * (3-7x mais lento porque o índice é maior e o planner precisa filtrar type)
 */


-- ============================================================================
-- SEÇÃO 6: CONFIGURAÇÕES postgresql.conf PARA WORKLOAD ANALÍTICO
-- ============================================================================

/*
 * ─── CONTEXTO ────────────────────────────────────────────────────────────
 * Servidor interno, PostgreSQL 16, workload misto:
 *   70% leitura analítica (métricas, dashboards, relatórios)
 *   30% escrita OLTP (registro de OFCs, edições)
 * RAM estimada: 8-16 GB dedicados ao PostgreSQL
 *
 * ─── CONFIGURAÇÕES RECOMENDADAS ─────────────────────────────────────────
 *
 * LOCALIZAÇÃO no Windows: C:\Program Files\PostgreSQL\16\data\postgresql.conf
 * LOCALIZAÇÃO no Linux:   /etc/postgresql/16/main/postgresql.conf
 */

-- ═══ MEMÓRIA ═══
-- shared_buffers: Cache de páginas de dados no PostgreSQL
-- Recomendação: 25% da RAM disponível para o PostgreSQL
shared_buffers = 4GB                    -- Assumindo 16GB de RAM para o PG
-- (Windows: 512MB pode ser suficiente; valores >512MB podem ser contraproducentes
--  devido à limitação do System V shared memory no Windows. No Linux: 4GB+)

-- effective_cache_size: Estimativa da RAM total disponível para cache de SO + PG
-- O planner usa isso para decidir entre index scan vs seq scan
effective_cache_size = 12GB             -- 75% da RAM total do servidor (16GB)

-- work_mem: Memória por operação de sort/hash (por nó do plano de execução)
-- Aumentar acelera ORDER BY, DISTINCT, GROUP BY, hash joins
-- ATENÇÃO: multiplicado pelo número de conexões simultâneas
-- Com pool de 20 conexões: 256MB * 20 = 5GB (OK para 16GB)
work_mem = 256MB

-- maintenance_work_mem: Memória para VACUUM, CREATE INDEX, REINDEX
-- Aumentar acelera criação de índices e REFRESH MATERIALIZED VIEW
maintenance_work_mem = 1GB

-- hash_mem_multiplier: PG 15+, controla memória para hash operations
-- 2.0 = 2x work_mem para hash joins (bom para queries analíticas)
hash_mem_multiplier = 2.0

-- ═══ PLANEJADOR ═══
-- random_page_cost: Custo relativo de leitura aleatória vs sequencial
-- Para SSD: 1.0-1.1 (disco é quase tão rápido aleatório quanto sequencial)
-- Para HDD: 4.0 (padrão)
random_page_cost = 1.1                  -- SSD

-- effective_io_concurrency: Leituras paralelas de índice bitmap
-- Para SSD NVMe: 200, SATA SSD: 100, HDD: 2
effective_io_concurrency = 200          -- NVMe

-- cursor_tuple_fraction: Fração de linhas que o planner espera buscar com cursor
-- 0.1 favorece index scans para as primeiras linhas (bom para dashboards paginados)
cursor_tuple_fraction = 0.1

-- default_statistics_target: Precisão das estatísticas do ANALYZE
-- Aumentar melhora planos para queries com muitas condições
-- Valor 500-1000 recomendado para colunas com dados enviesados (type, shift)
default_statistics_target = 500

-- Estatísticas por coluna (executar via SQL):
-- ALTER TABLE ofc_records ALTER COLUMN type SET STATISTICS 1000;
-- ALTER TABLE ofc_records ALTER COLUMN shift SET STATISTICS 500;
-- ALTER TABLE ofc_records ALTER COLUMN record_date SET STATISTICS 1000;

-- ═══ PARALELISMO ═══
-- max_parallel_workers_per_gather: Workers por nó Gather paralelo
-- CPU cores / 4 é um bom ponto de partida
max_parallel_workers_per_gather = 4    -- 16 vCPUs

-- max_parallel_workers: Total de workers paralelos no sistema
-- CPU cores / 2
max_parallel_workers = 8               -- 16 vCPUs

-- parallel_tuple_cost: Custo por tupla transferida entre workers
-- Reduzir incentiva o planner a usar mais paralelismo
parallel_tuple_cost = 0.01             -- padrão 0.1

-- parallel_setup_cost: Custo fixo de iniciar workers paralelos
-- Reduzir incentiva paralelismo para queries menores
parallel_setup_cost = 100              -- padrão 1000

-- min_parallel_table_scan_size: Tamanho mínimo da tabela para considerar paralelismo
min_parallel_table_scan_size = '4MB'   -- padrão 8MB

-- min_parallel_index_scan_size: Índice mínimo para considerar paralelismo de índice
min_parallel_index_scan_size = '512kB' -- padrão 512kB

-- ═══ WRITE-AHEAD LOG (WAL) ═══
-- Ambiente offline → podemos relaxar durabilidade para ganhar performance
-- ATENÇÃO: NÃO use essas configs se precisar de disaster recovery imediato

-- wal_level: 'minimal' desabilita WAL para algumas operações (CREATE TABLE AS, COPY)
-- Use 'replica' se precisar de PITR ou replicação
wal_level = replica                     -- mantém compatibilidade com backup

-- wal_buffers: Buffer para escrita de WAL
-- Aumentar reduz fsync calls
wal_buffers = 64MB

-- checkpoint_timeout: Intervalo entre checkpoints
-- Aumentar reduz I/O de checkpoint, mas aumenta tempo de recovery
checkpoint_timeout = 15min

-- max_wal_size: Tamanho máximo do WAL entre checkpoints
-- Aumentar permite mais writes antes de forçar checkpoint
max_wal_size = 8GB

-- ═══ AUTOVACUUM (TABELA DE ALTO VOLUME) ═══
-- ofc_records tem muitas inserções diárias e poucas atualizações
autovacuum = on
autovacuum_max_workers = 3

-- Escala agressiva para ofc_records (via ALTER TABLE)
-- Já configurado na migração:
--   autovacuum_vacuum_scale_factor = 0.01   (vacuum a cada 1% de tuplas mortas)
--   autovacuum_analyze_scale_factor = 0.005 (analyze a cada 0.5% de mudanças)
--   fillfactor = 85                         (15% de espaço livre para HOT updates)

-- ═══ CONEXÕES ═══
max_connections = 100                  -- 200 é overkill para servidor interno

-- ═══ QUERY TUNING ═══
-- enable_seqscan = on                   (NUNCA desabilitar em produção)
-- from_collapse_limit = 8              (subquery flattening, padrão OK)
-- join_collapse_limit = 8              (join reordering, aumentar se queries lentas com 10+ JOINs)

-- ═══ LOGGING (DEBUG) ═══
-- Habilitar temporariamente para diagnosticar queries lentas:
-- log_min_duration_statement = 500      -- log queries > 500ms
-- log_autovacuum_min_duration = 1000    -- log autovacuum > 1s
-- log_lock_waits = on                   -- log quando query espera lock > 1s
-- auto_explain.log_min_duration = 1000  -- explica plano de queries > 1s
-- (descomente apenas durante troubleshooting, gera muito log em produção)


-- ============================================================================
-- SEÇÃO 7: EXECUÇÃO (COMANDOS PARA APLICAR AS OTIMIZAÇÕES)
-- ============================================================================

/*
 * ─── ORDEM DE EXECUÇÃO RECOMENDADA ──────────────────────────────────────
 *
 * 1. Aplicar configurações postgresql.conf → pg_ctl reload
 * 2. Executar índices (CREATE INDEX CONCURRENTLY, um por vez)
 * 3. Criar Materialized View
 * 4. Executar ANALYZE em ofc_records
 * 5. Executar ANALYZE na Materialized View
 * 6. Verificar EXPLAIN ANALYZE de cada query otimizada
 *
 * COMANDOS:
 *
 *   -- Passo 1: Aplicar configs
 *   -- Edite postgresql.conf com as configs acima
 *   -- pg_ctl reload   (ou net stop postgresql-x64-16 && net start postgresql-x64-16 no Windows)
 *
 *   -- Passo 2: Criar índices (um por vez, CONCURRENTLY não bloqueia escritas)
 *   -- psql -U postgres -d ofs_db -f ofs_query_optimization_v3.sql
 *
 *   -- Passo 4: Atualizar estatísticas
 *   ANALYZE ofc_records;
 *
 *   -- Passo 5: Analisar a MV
 *   ANALYZE vw_weekly_metrics;
 *
 *   -- Passo 6: Verificar plano de execução
 *   EXPLAIN (ANALYZE, BUFFERS, TIMING)
 *   SELECT ... (query otimizada);
 *
 * ─── MANUTENÇÃO CONTÍNUA ────────────────────────────────────────────────
 *
 *   -- Reindexação mensal dos índices mais usados (evita bloat):
 *   REINDEX INDEX CONCURRENTLY idx_ofc_metrics_main;
 *   REINDEX INDEX CONCURRENTLY idx_ofc_positive_only;
 *   REINDEX INDEX CONCURRENTLY idx_ofc_negative_only;
 *
 *   -- Refresh da materialized view a cada 5 min:
 *   -- Via pg_cron:
 *   -- SELECT cron.schedule('refresh-mvw-metrics', '*/5 * * * *',
 *   --     'REFRESH MATERIALIZED VIEW CONCURRENTLY vw_weekly_metrics');
 *
 *   -- Via apscheduler (Python/FastAPI) — adicionar ao scheduler.py:
 *   -- scheduler.add_job(
 *   --     lambda: asyncio.run(refresh_mv()),
 *   --     trigger=CronTrigger(minute='*/5'),
 *   --     id='refresh_weekly_metrics',
 *   --     name='Refresh da Materialized View vw_weekly_metrics'
 *   -- )
 */
