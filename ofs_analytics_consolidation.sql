-- ============================================================================
-- SISTEMA OFS/OFS — ANALYTICS: VIEWS, FUNÇÕES E QUERIES DE CONSOLIDAÇÃO
-- PostgreSQL 16 | Módulo: Métricas Semanais
-- Data: 13/05/2026
--
-- ESQUEMA BASE ASSUMIDO:
--   ofc_records (id, company_id, contract_id, record_date, type, status_registro,
--                is_deleted, generated_by, observed_name, shift, ...)
--   targets    (id, company_id, contract_id, week_start, active_people,
--                weekly_target, is_active)
--   companies  (id, name, is_active)
--   users      (id, company_id, full_name, is_active)
-- ============================================================================

-- ============================================================================
-- 1. VIEW: vw_valid_ofcs
--    Filtra registros válidos para métricas (não deletados, não cancelados)
--    com JOIN em companies e users para nomes
-- ============================================================================
CREATE OR REPLACE VIEW vw_valid_ofcs AS
SELECT
    o.id,
    o.company_id,
    c.name                                 AS company_name,
    o.contract_id,
    o.record_date,
    EXTRACT(YEAR FROM o.record_date)::INT  AS ano,
    EXTRACT(WEEK FROM o.record_date)::INT  AS semana,
    EXTRACT(MONTH FROM o.record_date)::INT AS mes,
    o.type,
    o.status_registro,
    o.generated_by                         AS user_id,
    u.full_name                            AS user_name,
    o.observed_name,
    o.shift,
    o.is_deleted,
    o.record_date BETWEEN
        DATE_TRUNC('week', CURRENT_DATE)::DATE
        AND (DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '6 days')::DATE
                                           AS is_current_week
FROM ofc_records o
INNER JOIN companies c ON c.id = o.company_id
                       AND c.is_active = TRUE
INNER JOIN users u ON u.id = o.generated_by
WHERE o.is_deleted = FALSE
  AND o.status_registro != 'Cancelado';

COMMENT ON VIEW vw_valid_ofcs IS
'Registros OFS válidos para métricas: não deletados, não cancelados, com nomes de empresa e usuário';


-- ============================================================================
-- 2. MATERIALIZED VIEW: vw_weekly_metrics
--    Agregado semanal por empresa com indicadores core
--    Colunas: company_id, company_name, ano, semana,
--             total_realizadas, positivas, negativas, usuarios_ativos,
--             media_ofc_usuario, data_inicio, data_fim
-- ============================================================================
DROP MATERIALIZED VIEW IF EXISTS vw_weekly_metrics;

CREATE MATERIALIZED VIEW vw_weekly_metrics AS
WITH weekly_agg AS (
    SELECT
        v.company_id,
        v.company_name,
        v.ano,
        v.semana,
        MIN(v.record_date)                                   AS data_inicio,
        MAX(v.record_date)                                   AS data_fim,
        COUNT(*)                                             AS total_realizadas,
        COUNT(*) FILTER (WHERE v.type = 'Positivo/Seguro')   AS positivas,
        COUNT(*) FILTER (WHERE v.type = 'Negativo/Inseguro') AS negativas,
        COUNT(DISTINCT v.user_id)                            AS usuarios_ativos
    FROM vw_valid_ofcs v
    GROUP BY v.company_id, v.company_name, v.ano, v.semana
)
SELECT
    wa.company_id,
    wa.company_name,
    wa.ano,
    wa.semana,
    wa.total_realizadas,
    wa.positivas,
    wa.negativas,
    wa.usuarios_ativos,
    ROUND(
        wa.total_realizadas::NUMERIC
        / NULLIF(wa.usuarios_ativos, 0), 1
    )                                                       AS media_ofc_usuario,
    wa.data_inicio,
    wa.data_fim,
    NOW()                                                   AS refreshed_at
FROM weekly_agg wa
ORDER BY wa.company_name, wa.ano DESC, wa.semana DESC;

-- Índice único na materialized view (requisito para REFRESH CONCURRENTLY)
CREATE UNIQUE INDEX idx_mvw_weekly_metrics_pk
    ON vw_weekly_metrics (company_id, ano, semana);

-- Índice de apoio para consultas por período
CREATE INDEX idx_mvw_weekly_metrics_inicio
    ON vw_weekly_metrics (data_inicio DESC);

CREATE INDEX idx_mvw_weekly_metrics_company
    ON vw_weekly_metrics (company_id, data_inicio DESC);

COMMENT ON MATERIALIZED VIEW vw_weekly_metrics IS
'Métricas semanais agregadas por empresa. Refresh via função fn_refresh_weekly_metrics().';

-- Comando de refresh:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY vw_weekly_metrics;
-- Função auxiliar para refresh agendado:
CREATE OR REPLACE FUNCTION fn_refresh_weekly_metrics()
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_start TIMESTAMPTZ := clock_timestamp();
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY vw_weekly_metrics;
    RAISE NOTICE 'vw_weekly_metrics refreshed in % ms',
        EXTRACT(MILLISECOND FROM clock_timestamp() - v_start)::INT;
END;
$$;


-- ============================================================================
-- 3. FUNÇÃO: calculate_weekly_metrics(week_start DATE, p_company_id INT)
--    Retorna 10 indicadores + status para uma empresa em uma semana
--    Usa CTE para meta e realizado, NULLIF para divisão por zero
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_weekly_metrics(
    p_week_start DATE,
    p_company_id INT
)
RETURNS TABLE (
    -- Meta
    pessoas_ativas        BIGINT,
    ofc_programadas       BIGINT,
    -- Realizado
    ofc_realizadas        BIGINT,
    positivas             BIGINT,
    negativas             BIGINT,
    -- Calculados
    aderencia_percentual  NUMERIC(5,1),
    percentual_seguro     NUMERIC(5,1),
    percentual_desvio     NUMERIC(5,1),
    usuarios_ativos       BIGINT,
    media_ofc_usuario     NUMERIC(10,1),
    -- Status
    status                VARCHAR(20),
    -- Período
    data_inicio           DATE,
    data_fim              DATE
)
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    WITH meta AS (
        SELECT
            COALESCE(SUM(t.active_people), 0)                       AS active_people,
            COALESCE(SUM(t.weekly_target * t.active_people), 0)     AS ofc_programadas
        FROM targets t
        WHERE t.company_id = p_company_id
          AND t.week_start = p_week_start
          AND t.is_active = TRUE
    ),
    realizado AS (
        SELECT
            COUNT(*)                                                        AS total_realizadas,
            COUNT(*) FILTER (WHERE v.type = 'Positivo/Seguro')              AS positivas,
            COUNT(*) FILTER (WHERE v.type = 'Negativo/Inseguro')            AS negativas,
            COUNT(DISTINCT v.user_id)                                       AS usuarios_ativos
        FROM vw_valid_ofcs v
        WHERE v.company_id = p_company_id
          AND v.record_date BETWEEN p_week_start
                                 AND (p_week_start + INTERVAL '6 days')::DATE
    )
    SELECT
        -- Meta (1-2)
        m.active_people::BIGINT,
        m.ofc_programadas::BIGINT,
        -- Realizado (3-5)
        COALESCE(r.total_realizadas, 0)::BIGINT,
        COALESCE(r.positivas, 0)::BIGINT,
        COALESCE(r.negativas, 0)::BIGINT,
        -- Calculados (6-10)
        ROUND(
            COALESCE(r.total_realizadas, 0)::NUMERIC
            / NULLIF(m.ofc_programadas, 0) * 100, 1
        )::NUMERIC(5,1),
        ROUND(
            COALESCE(r.positivas, 0)::NUMERIC
            / NULLIF(COALESCE(r.total_realizadas, 0), 0) * 100, 1
        )::NUMERIC(5,1),
        ROUND(
            COALESCE(r.negativas, 0)::NUMERIC
            / NULLIF(COALESCE(r.total_realizadas, 0), 0) * 100, 1
        )::NUMERIC(5,1),
        COALESCE(r.usuarios_ativos, 0)::BIGINT,
        ROUND(
            COALESCE(r.total_realizadas, 0)::NUMERIC
            / NULLIF(COALESCE(r.usuarios_ativos, 0), 0), 1
        )::NUMERIC(10,1),
        -- Status
        CASE
            WHEN m.ofc_programadas IS NULL OR m.ofc_programadas = 0 THEN 'SEM_META'
            WHEN COALESCE(r.total_realizadas, 0)::NUMERIC
                 / NULLIF(m.ofc_programadas, 0) * 100 >= 100 THEN 'OK'
            WHEN COALESCE(r.total_realizadas, 0)::NUMERIC
                 / NULLIF(m.ofc_programadas, 0) * 100 >= 80  THEN 'ATENCAO'
            ELSE 'ALERTA'
        END::VARCHAR(20),
        -- Período
        p_week_start,
        (p_week_start + INTERVAL '6 days')::DATE
    FROM (SELECT 1) AS dummy
    LEFT JOIN meta m ON TRUE
    LEFT JOIN realizado r ON TRUE;
$$;

COMMENT ON FUNCTION calculate_weekly_metrics(DATE, INT) IS
'Calcula 10 indicadores + status para uma empresa em uma semana.
 Parâmetros: week_start (segunda-feira), company_id.
 Retorno: TABLE com meta, realizado, calculados e status (OK/ATENCAO/ALERTA/SEM_META).';


-- ============================================================================
-- 4. FUNÇÃO: get_weekly_evolution(p_company_id INT, p_weeks INT DEFAULT 8)
--    Retorna aderência por semana (semanas consecutivas, sem gaps)
--    Usa generate_series para preencher semanas sem dados
-- ============================================================================
CREATE OR REPLACE FUNCTION get_weekly_evolution(
    p_company_id INT,
    p_weeks      INT DEFAULT 8
)
RETURNS TABLE (
    semana_ano           TEXT,
    ano                  INT,
    semana               INT,
    data_inicio          DATE,
    data_fim             DATE,
    ofc_realizadas       BIGINT,
    positivas            BIGINT,
    negativas            BIGINT,
    ofc_programadas      BIGINT,
    aderencia_percentual NUMERIC(5,1),
    pos_comparacao       BIGINT,
    usuarios_ativos      BIGINT,
    media_ofc_usuario    NUMERIC(10,1),
    status               VARCHAR(20)
)
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    WITH week_series AS (
        -- Gera todas as semanas do período, incluindo as sem dados
        SELECT
            gen.week_start::DATE,
            (gen.week_start + INTERVAL '6 days')::DATE AS week_end,
            EXTRACT(YEAR FROM gen.week_start)::INT     AS yr,
            EXTRACT(WEEK FROM gen.week_start)::INT     AS wk
        FROM generate_series(
            (DATE_TRUNC('week', CURRENT_DATE) - (p_weeks - 1) * INTERVAL '7 days')::DATE,
            DATE_TRUNC('week', CURRENT_DATE)::DATE,
            '7 days'::INTERVAL
        ) AS gen(week_start)
    ),
    weekly_ofc AS (
        SELECT
            v.ano,
            v.semana,
            MIN(v.record_date)                                   AS data_inicio,
            COUNT(*)                                             AS ofc_realizadas,
            COUNT(*) FILTER (WHERE v.type = 'Positivo/Seguro')   AS positivas,
            COUNT(*) FILTER (WHERE v.type = 'Negativo/Inseguro') AS negativas,
            COUNT(DISTINCT v.user_id)                            AS usuarios_ativos
        FROM vw_valid_ofcs v
        WHERE v.company_id = p_company_id
          AND v.record_date >= (DATE_TRUNC('week', CURRENT_DATE)
                                - (p_weeks - 1) * INTERVAL '7 days')::DATE
          AND v.record_date <= CURRENT_DATE
        GROUP BY v.ano, v.semana
    ),
    weekly_meta AS (
        SELECT
            t.week_start,
            COALESCE(SUM(t.weekly_target * t.active_people), 0) AS ofc_programadas
        FROM targets t
        WHERE t.company_id = p_company_id
          AND t.is_active = TRUE
          AND t.week_start >= (DATE_TRUNC('week', CURRENT_DATE)
                               - (p_weeks - 1) * INTERVAL '7 days')::DATE
          AND t.week_start <= DATE_TRUNC('week', CURRENT_DATE)::DATE
        GROUP BY t.week_start
    )
    SELECT
        ws.yr::TEXT || '-S' || LPAD(ws.wk::TEXT, 2, '0'),
        ws.yr,
        ws.wk,
        ws.week_start,
        ws.week_end,
        COALESCE(wo.ofc_realizadas, 0)::BIGINT,
        COALESCE(wo.positivas, 0)::BIGINT,
        COALESCE(wo.negativas, 0)::BIGINT,
        COALESCE(wm.ofc_programadas, 0)::BIGINT,
        ROUND(
            COALESCE(wo.ofc_realizadas, 0)::NUMERIC
            / NULLIF(COALESCE(wm.ofc_programadas, 0), 0) * 100, 1
        )::NUMERIC(5,1),
        -- Comparação com semana anterior (para gráfico de tendência)
        COALESCE(
            LAG(wo.ofc_realizadas) OVER (ORDER BY ws.week_start), 0
        )::BIGINT,
        COALESCE(wo.usuarios_ativos, 0)::BIGINT,
        ROUND(
            COALESCE(wo.ofc_realizadas, 0)::NUMERIC
            / NULLIF(COALESCE(wo.usuarios_ativos, 0), 0), 1
        )::NUMERIC(10,1),
        CASE
            WHEN COALESCE(wm.ofc_programadas, 0) = 0 THEN 'SEM_META'
            WHEN COALESCE(wo.ofc_realizadas, 0)::NUMERIC
                 / NULLIF(COALESCE(wm.ofc_programadas, 0), 0) * 100 >= 100 THEN 'OK'
            WHEN COALESCE(wo.ofc_realizadas, 0)::NUMERIC
                 / NULLIF(COALESCE(wm.ofc_programadas, 0), 0) * 100 >= 80  THEN 'ATENCAO'
            ELSE 'ALERTA'
        END::VARCHAR(20)
    FROM week_series ws
    LEFT JOIN weekly_ofc wo
        ON wo.ano = ws.yr AND wo.semana = ws.wk
    LEFT JOIN weekly_meta wm
        ON wm.week_start = ws.week_start
    ORDER BY ws.week_start;
$$;

COMMENT ON FUNCTION get_weekly_evolution(INT, INT) IS
'Retorna evolução semanal de aderência para uma empresa.
 Parâmetros: company_id, semanas (default 8).
 Usa generate_series para garantir semanas consecutivas sem gaps no gráfico.';


-- ============================================================================
-- 5. VIEW: vw_company_ranking
--    Ranking de empresas por aderência na semana atual
-- ============================================================================
CREATE OR REPLACE VIEW vw_company_ranking AS
WITH week_start AS (
    SELECT DATE_TRUNC('week', CURRENT_DATE)::DATE AS ws
),
company_scores AS (
    SELECT
        c.id                                                   AS company_id,
        c.name                                                 AS company_name,
        COUNT(v.id)                                            AS total_ofcs,
        COUNT(v.id) FILTER (WHERE v.type = 'Positivo/Seguro')  AS positivas,
        COUNT(v.id) FILTER (WHERE v.type = 'Negativo/Inseguro') AS negativas,
        COUNT(DISTINCT v.user_id)                              AS usuarios_ativos,
        COALESCE(SUM(t.weekly_target * t.active_people), 0)    AS ofc_programadas,
        ROUND(
            COUNT(v.id)::NUMERIC
            / NULLIF(COALESCE(SUM(t.weekly_target * t.active_people), 0), 0) * 100, 1
        )                                                      AS aderencia_pct
    FROM companies c
    CROSS JOIN week_start ws
    LEFT JOIN vw_valid_ofcs v
        ON v.company_id = c.id
        AND v.record_date BETWEEN ws.ws
                              AND (ws.ws + INTERVAL '6 days')::DATE
    LEFT JOIN targets t
        ON t.company_id = c.id
        AND t.week_start = ws.ws
        AND t.is_active = TRUE
    WHERE c.is_active = TRUE
    GROUP BY c.id, c.name
)
SELECT
    RANK() OVER (ORDER BY cs.aderencia_pct DESC NULLS LAST) AS rank_position,
    cs.company_id,
    cs.company_name,
    cs.total_ofcs,
    cs.positivas,
    cs.negativas,
    cs.usuarios_ativos,
    cs.ofc_programadas,
    cs.aderencia_pct,
    CASE
        WHEN cs.ofc_programadas = 0 THEN 'SEM_META'
        WHEN cs.aderencia_pct >= 100 THEN 'OK'
        WHEN cs.aderencia_pct >= 80  THEN 'ATENCAO'
        WHEN cs.aderencia_pct IS NOT NULL THEN 'ALERTA'
        ELSE 'SEM_META'
    END                                                    AS status
FROM company_scores cs
ORDER BY rank_position;

COMMENT ON VIEW vw_company_ranking IS
'Ranking de empresas por aderência (%) na semana atual. Ordenado do maior para o menor.';


-- ============================================================================
-- 6. VIEW: vw_user_ranking
--    Ranking de usuários por quantidade de OFCs na semana atual
-- ============================================================================
CREATE OR REPLACE VIEW vw_user_ranking AS
WITH week_start AS (
    SELECT DATE_TRUNC('week', CURRENT_DATE)::DATE AS ws
),
user_scores AS (
    SELECT
        u.id                                                   AS user_id,
        u.full_name                                            AS user_name,
        u.company_id,
        c.name                                                 AS company_name,
        COUNT(v.id)                                            AS total_ofcs,
        COUNT(v.id) FILTER (WHERE v.type = 'Positivo/Seguro')  AS positivas,
        COUNT(v.id) FILTER (WHERE v.type = 'Negativo/Inseguro') AS negativas,
        COUNT(DISTINCT v.record_date)                          AS dias_ativos,
        ROUND(
            COUNT(v.id) FILTER (WHERE v.type = 'Positivo/Seguro')::NUMERIC
            / NULLIF(COUNT(v.id), 0) * 100, 1
        )                                                      AS taxa_positividade
    FROM users u
    INNER JOIN companies c ON c.id = u.company_id
                           AND c.is_active = TRUE
    CROSS JOIN week_start ws
    LEFT JOIN vw_valid_ofcs v
        ON v.user_id = u.id
        AND v.record_date BETWEEN ws.ws
                              AND (ws.ws + INTERVAL '6 days')::DATE
    WHERE u.is_active = TRUE
    GROUP BY u.id, u.full_name, u.company_id, c.name
    HAVING COUNT(v.id) > 0
)
SELECT
    RANK() OVER (ORDER BY us.total_ofcs DESC)             AS rank_position,
    us.user_id,
    us.user_name,
    us.company_id,
    us.company_name,
    us.total_ofcs,
    us.positivas,
    us.negativas,
    us.dias_ativos,
    us.taxa_positividade
FROM user_scores us
ORDER BY rank_position;

COMMENT ON VIEW vw_user_ranking IS
'Ranking de usuários por quantidade de OFCs registradas na semana atual.
 Inclui apenas usuários ativos que tenham pelo menos 1 OFS na semana.';


-- ============================================================================
-- 7. QUERY CONSOLIDADA: Tabela com todas as empresas na semana
--    Versão como VIEW para uso frequente no dashboard
-- ============================================================================
CREATE OR REPLACE VIEW vw_consolidated_weekly AS
WITH week_start AS (
    SELECT DATE_TRUNC('week', CURRENT_DATE)::DATE AS ws
),
company_metrics AS (
    SELECT
        c.id                                                     AS company_id,
        c.name                                                   AS company_name,
        -- Meta
        COALESCE(SUM(t.active_people), 0)::BIGINT                AS pessoas_ativas,
        COALESCE(SUM(t.weekly_target * t.active_people), 0)::BIGINT AS ofc_programadas,
        -- Realizado
        COUNT(v.id)::BIGINT                                      AS ofc_realizadas,
        COUNT(v.id) FILTER (WHERE v.type = 'Positivo/Seguro')::BIGINT  AS positivas,
        COUNT(v.id) FILTER (WHERE v.type = 'Negativo/Inseguro')::BIGINT AS negativas,
        -- Neutros (realizadas - positivas - negativas)
        (COUNT(v.id)
         - COUNT(v.id) FILTER (WHERE v.type = 'Positivo/Seguro')
         - COUNT(v.id) FILTER (WHERE v.type = 'Negativo/Inseguro'))::BIGINT AS neutras,
        -- Calculados
        ROUND(
            COUNT(v.id)::NUMERIC
            / NULLIF(COALESCE(SUM(t.weekly_target * t.active_people), 0), 0) * 100, 1
        )::NUMERIC(5,1)                                         AS aderencia_percentual,
        ROUND(
            COUNT(v.id) FILTER (WHERE v.type = 'Positivo/Seguro')::NUMERIC
            / NULLIF(COUNT(v.id), 0) * 100, 1
        )::NUMERIC(5,1)                                         AS percentual_seguro,
        ROUND(
            COUNT(v.id) FILTER (WHERE v.type = 'Negativo/Inseguro')::NUMERIC
            / NULLIF(COUNT(v.id), 0) * 100, 1
        )::NUMERIC(5,1)                                         AS percentual_desvio,
        COUNT(DISTINCT v.user_id)::BIGINT                       AS usuarios_ativos,
        ROUND(
            COUNT(v.id)::NUMERIC
            / NULLIF(COUNT(DISTINCT v.user_id), 0), 1
        )::NUMERIC(10,1)                                        AS media_ofc_usuario,
        COUNT(DISTINCT v.record_date)::BIGINT                   AS dias_com_registro,
        -- Status
        CASE
            WHEN COALESCE(SUM(t.weekly_target * t.active_people), 0) = 0
                THEN 'SEM_META'
            WHEN COUNT(v.id)::NUMERIC
                 / NULLIF(COALESCE(SUM(t.weekly_target * t.active_people), 0), 0) * 100 >= 100
                THEN 'OK'
            WHEN COUNT(v.id)::NUMERIC
                 / NULLIF(COALESCE(SUM(t.weekly_target * t.active_people), 0), 0) * 100 >= 80
                THEN 'ATENCAO'
            ELSE 'ALERTA'
        END                                                     AS status
    FROM companies c
    CROSS JOIN week_start ws
    LEFT JOIN vw_valid_ofcs v
        ON v.company_id = c.id
        AND v.record_date BETWEEN ws.ws
                              AND (ws.ws + INTERVAL '6 days')::DATE
    LEFT JOIN targets t
        ON t.company_id = c.id
        AND t.week_start = ws.ws
        AND t.is_active = TRUE
    WHERE c.is_active = TRUE
    GROUP BY c.id, c.name
),
totals AS (
    SELECT
        SUM(cm.pessoas_ativas)        AS tot_pessoas_ativas,
        SUM(cm.ofc_programadas)       AS tot_programadas,
        SUM(cm.ofc_realizadas)        AS tot_realizadas,
        SUM(cm.positivas)             AS tot_positivas,
        SUM(cm.negativas)             AS tot_negativas,
        SUM(cm.neutras)               AS tot_neutras,
        SUM(cm.usuarios_ativos)       AS tot_usuarios_ativos,
        SUM(cm.dias_com_registro)     AS tot_dias
    FROM company_metrics cm
)
SELECT
    cm.company_id,
    cm.company_name,
    cm.pessoas_ativas,
    cm.ofc_programadas,
    cm.ofc_realizadas,
    cm.positivas,
    cm.negativas,
    cm.neutras,
    cm.aderencia_percentual,
    cm.percentual_seguro,
    cm.percentual_desvio,
    cm.usuarios_ativos,
    cm.media_ofc_usuario,
    cm.dias_com_registro,
    cm.status,
    FALSE AS is_total_row
FROM company_metrics cm

UNION ALL

-- Linha de TOTAL
SELECT
    NULL::INT                                             AS company_id,
    'TOTAL'::VARCHAR                                      AS company_name,
    t.tot_pessoas_ativas::BIGINT                          AS pessoas_ativas,
    t.tot_programadas::BIGINT                             AS ofc_programadas,
    t.tot_realizadas::BIGINT                              AS ofc_realizadas,
    t.tot_positivas::BIGINT                               AS positivas,
    t.tot_negativas::BIGINT                               AS negativas,
    t.tot_neutras::BIGINT                                 AS neutras,
    ROUND(
        t.tot_realizadas::NUMERIC
        / NULLIF(t.tot_programadas, 0) * 100, 1
    )::NUMERIC(5,1)                                       AS aderencia_percentual,
    ROUND(
        t.tot_positivas::NUMERIC
        / NULLIF(t.tot_realizadas, 0) * 100, 1
    )::NUMERIC(5,1)                                       AS percentual_seguro,
    ROUND(
        t.tot_negativas::NUMERIC
        / NULLIF(t.tot_realizadas, 0) * 100, 1
    )::NUMERIC(5,1)                                       AS percentual_desvio,
    t.tot_usuarios_ativos::BIGINT                         AS usuarios_ativos,
    ROUND(
        t.tot_realizadas::NUMERIC
        / NULLIF(t.tot_usuarios_ativos, 0), 1
    )::NUMERIC(10,1)                                      AS media_ofc_usuario,
    t.tot_dias::BIGINT                                    AS dias_com_registro,
    CASE
        WHEN t.tot_programadas = 0 THEN 'SEM_META'
        WHEN t.tot_realizadas::NUMERIC
             / NULLIF(t.tot_programadas, 0) * 100 >= 100 THEN 'OK'
        WHEN t.tot_realizadas::NUMERIC
             / NULLIF(t.tot_programadas, 0) * 100 >= 80  THEN 'ATENCAO'
        ELSE 'ALERTA'
    END                                                   AS status,
    TRUE                                                  AS is_total_row
FROM totals t

ORDER BY is_total_row, status, aderencia_percentual DESC NULLS LAST;

COMMENT ON VIEW vw_consolidated_weekly IS
'Tabela consolidada de métricas da semana atual para todas as empresas ativas.
 Inclui linha de TOTAL com somatórios e médias ponderadas.
 Ordenada: empresas primeiro, depois linha TOTAL.';


-- ============================================================================
-- QUERY DIRETA: Tabela consolidada para uma semana específica
-- Uso: SELECT * FROM get_consolidated_weekly('2026-05-11');
-- ============================================================================
CREATE OR REPLACE FUNCTION get_consolidated_weekly(
    p_week_start DATE
)
RETURNS TABLE (
    company_id            INT,
    company_name          VARCHAR,
    pessoas_ativas        BIGINT,
    ofc_programadas       BIGINT,
    ofc_realizadas        BIGINT,
    positivas             BIGINT,
    negativas             BIGINT,
    neutras               BIGINT,
    aderencia_percentual  NUMERIC(5,1),
    percentual_seguro     NUMERIC(5,1),
    percentual_desvio     NUMERIC(5,1),
    usuarios_ativos       BIGINT,
    media_ofc_usuario     NUMERIC(10,1),
    dias_com_registro     BIGINT,
    status                VARCHAR(20),
    is_total_row          BOOLEAN
)
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    WITH company_metrics AS (
        SELECT
            c.id                                                     AS cid,
            c.name                                                   AS cname,
            COALESCE(SUM(t.active_people), 0)::BIGINT                AS p_ativas,
            COALESCE(SUM(t.weekly_target * t.active_people), 0)::BIGINT AS p_prog,
            COUNT(v.id)::BIGINT                                      AS p_real,
            COUNT(v.id) FILTER (WHERE v.type = 'Positivo/Seguro')::BIGINT  AS p_pos,
            COUNT(v.id) FILTER (WHERE v.type = 'Negativo/Inseguro')::BIGINT AS p_neg,
            (COUNT(v.id)
             - COUNT(v.id) FILTER (WHERE v.type = 'Positivo/Seguro')
             - COUNT(v.id) FILTER (WHERE v.type = 'Negativo/Inseguro'))::BIGINT AS p_neu,
            ROUND(
                COUNT(v.id)::NUMERIC
                / NULLIF(COALESCE(SUM(t.weekly_target * t.active_people), 0), 0) * 100, 1
            )::NUMERIC(5,1)                                         AS p_ader,
            ROUND(
                COUNT(v.id) FILTER (WHERE v.type = 'Positivo/Seguro')::NUMERIC
                / NULLIF(COUNT(v.id), 0) * 100, 1
            )::NUMERIC(5,1)                                         AS p_pseg,
            ROUND(
                COUNT(v.id) FILTER (WHERE v.type = 'Negativo/Inseguro')::NUMERIC
                / NULLIF(COUNT(v.id), 0) * 100, 1
            )::NUMERIC(5,1)                                         AS p_pdes,
            COUNT(DISTINCT v.user_id)::BIGINT                       AS p_uativ,
            ROUND(
                COUNT(v.id)::NUMERIC
                / NULLIF(COUNT(DISTINCT v.user_id), 0), 1
            )::NUMERIC(10,1)                                        AS p_media,
            COUNT(DISTINCT v.record_date)::BIGINT                   AS p_dias,
            CASE
                WHEN COALESCE(SUM(t.weekly_target * t.active_people), 0) = 0
                    THEN 'SEM_META'
                WHEN COUNT(v.id)::NUMERIC
                     / NULLIF(COALESCE(SUM(t.weekly_target * t.active_people), 0), 0) * 100 >= 100
                    THEN 'OK'
                WHEN COUNT(v.id)::NUMERIC
                     / NULLIF(COALESCE(SUM(t.weekly_target * t.active_people), 0), 0) * 100 >= 80
                    THEN 'ATENCAO'
                ELSE 'ALERTA'
            END                                                     AS p_status
        FROM companies c
        LEFT JOIN vw_valid_ofcs v
            ON v.company_id = c.id
            AND v.record_date BETWEEN p_week_start
                                  AND (p_week_start + INTERVAL '6 days')::DATE
        LEFT JOIN targets t
            ON t.company_id = c.id
            AND t.week_start = p_week_start
            AND t.is_active = TRUE
        WHERE c.is_active = TRUE
        GROUP BY c.id, c.name
    ),
    totals AS (
        SELECT
            SUM(cm.p_ativas)    AS t_ativas,
            SUM(cm.p_prog)      AS t_prog,
            SUM(cm.p_real)      AS t_real,
            SUM(cm.p_pos)       AS t_pos,
            SUM(cm.p_neg)       AS t_neg,
            SUM(cm.p_neu)       AS t_neu,
            SUM(cm.p_uativ)     AS t_uativ,
            SUM(cm.p_dias)      AS t_dias
        FROM company_metrics cm
    )
    SELECT
        cm.cid, cm.cname, cm.p_ativas, cm.p_prog, cm.p_real,
        cm.p_pos, cm.p_neg, cm.p_neu, cm.p_ader, cm.p_pseg,
        cm.p_pdes, cm.p_uativ, cm.p_media, cm.p_dias, cm.p_status,
        FALSE::BOOLEAN
    FROM company_metrics cm

    UNION ALL

    SELECT
        NULL::INT,
        'TOTAL'::VARCHAR,
        t.t_ativas, t.t_prog, t.t_real, t.t_pos, t.t_neg, t.t_neu,
        ROUND(t.t_real::NUMERIC / NULLIF(t.t_prog, 0) * 100, 1)::NUMERIC(5,1),
        ROUND(t.t_pos::NUMERIC  / NULLIF(t.t_real, 0) * 100, 1)::NUMERIC(5,1),
        ROUND(t.t_neg::NUMERIC  / NULLIF(t.t_real, 0) * 100, 1)::NUMERIC(5,1),
        t.t_uativ,
        ROUND(t.t_real::NUMERIC / NULLIF(t.t_uativ, 0), 1)::NUMERIC(10,1),
        t.t_dias,
        CASE
            WHEN t.t_prog = 0 THEN 'SEM_META'
            WHEN t.t_real::NUMERIC / NULLIF(t.t_prog, 0) * 100 >= 100 THEN 'OK'
            WHEN t.t_real::NUMERIC / NULLIF(t.t_prog, 0) * 100 >= 80  THEN 'ATENCAO'
            ELSE 'ALERTA'
        END::VARCHAR(20),
        TRUE::BOOLEAN
    FROM totals t

    ORDER BY is_total_row, status, aderencia_percentual DESC NULLS LAST;
$$;

COMMENT ON FUNCTION get_consolidated_weekly(DATE) IS
'Tabela consolidada com métricas de todas as empresas ativas para uma semana específica.
 Retorna empresas + linha TOTAL com somatórios. Parâmetro: data de início da semana (segunda).';


-- ============================================================================
-- ÍNDICES DE APOIO PARA PERFORMANCE
-- ============================================================================

-- Índice composto para a view vw_valid_ofcs (acelera filtros nas funções)
CREATE INDEX IF NOT EXISTS idx_ofc_valid_company_date
    ON ofc_records (company_id, record_date, type)
    WHERE is_deleted = FALSE AND status_registro != 'Cancelado';

-- Índice para métricas por usuário (ranking)
CREATE INDEX IF NOT EXISTS idx_ofc_valid_user_date
    ON ofc_records (generated_by, record_date)
    WHERE is_deleted = FALSE AND status_registro != 'Cancelado';

-- Índice para targets (join com empresa + semana)
CREATE INDEX IF NOT EXISTS idx_targets_company_week
    ON targets (company_id, week_start, weekly_target)
    WHERE is_active = TRUE;


-- ============================================================================
-- EXEMPLOS DE USO
-- ============================================================================

-- Exemplo 1: Métricas da semana atual para empresa ID=1
-- SELECT * FROM calculate_weekly_metrics(
--     DATE_TRUNC('week', CURRENT_DATE)::DATE, 1
-- );

-- Exemplo 2: Evolução das últimas 8 semanas para empresa ID=1
-- SELECT * FROM get_weekly_evolution(1, 8);

-- Exemplo 3: Evolução das últimas 4 semanas
-- SELECT * FROM get_weekly_evolution(1, 4);

-- Exemplo 4: Ranking de empresas na semana atual
-- SELECT * FROM vw_company_ranking;

-- Exemplo 5: Ranking de usuários na semana atual
-- SELECT * FROM vw_user_ranking;

-- Exemplo 6: Tabela consolidada da semana atual
-- SELECT * FROM vw_consolidated_weekly;

-- Exemplo 7: Tabela consolidada para uma semana específica
-- SELECT * FROM get_consolidated_weekly('2026-05-11');

-- Exemplo 8: Refresh da materialized view (agendar a cada 5 min)
-- SELECT fn_refresh_weekly_metrics();

-- Exemplo 9: Métricas de todas as semanas via materialized view
-- SELECT * FROM vw_weekly_metrics
-- WHERE data_inicio >= '2026-01-01'
-- ORDER BY data_inicio DESC, company_name;


-- ============================================================================
-- VERIFICAÇÃO RÁPIDA (descomente para testar)
-- ============================================================================

-- Verifica se as views foram criadas
-- SELECT table_name, table_type
-- FROM information_schema.tables
-- WHERE table_schema = 'public'
--   AND table_name IN (
--     'vw_valid_ofcs', 'vw_weekly_metrics', 'vw_company_ranking',
--     'vw_user_ranking', 'vw_consolidated_weekly'
--   )
-- ORDER BY table_name;

-- Verifica se as funções foram criadas
-- SELECT routine_name, routine_type
-- FROM information_schema.routines
-- WHERE routine_schema = 'public'
--   AND routine_name IN (
--     'calculate_weekly_metrics', 'get_weekly_evolution',
--     'get_consolidated_weekly', 'fn_refresh_weekly_metrics'
--   )
-- ORDER BY routine_name;


-- ============================================================================
-- FIM DO SCRIPT DE CONSOLIDAÇÃO ANALYTICS
-- ============================================================================
