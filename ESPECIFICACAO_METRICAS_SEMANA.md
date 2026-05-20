# ESPECIFICAÇÃO DO MÓDULO — MÉTRICAS DA SEMANA

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Data:** 13/05/2026  

---

## Sumário

1. [Indicadores e Fórmulas](#1-indicadores-e-fórmulas)
2. [Regras de Status](#2-regras-de-status)
3. [Estrutura da Tela](#3-estrutura-da-tela)
4. [Gráficos](#4-gráficos)
5. [Tabela Consolidada](#5-tabela-consolidada)
6. [SQL e Consultas Otimizadas](#6-sql-e-consultas-otimizadas)
7. [Endpoints e Payloads](#7-endpoints-e-payloads)
8. [Regras de Permissão](#8-regras-de-permissão)
9. [Estratégia de Performance](#9-estratégia-de-performance)
10. [Estratégia de PDF](#10-estratégia-de-pdf)
11. [Estratégia de Excel](#11-estratégia-de-excel)
12. [Estratégia de Auditoria](#12-estratégia-de-auditoria)
13. [Critérios de Aceite](#13-critérios-de-aceite)

---

## 1. Indicadores e Fórmulas

### 1.1 Os 10 Indicadores

| # | Indicador | Descrição | Unidade | Fórmula |
|---|-----------|-----------|:---:|---------|
| 1 | **Pessoas Ativas** | Total de pessoas ativas na meta | número | `targets.active_people` |
| 2 | **OFS Programadas** | Meta total de OFCs na semana | número | `active_people × weekly_target` |
| 3 | **OFS Realizadas** | OFCs efetivamente registradas | número | `COUNT(ofc_records)` no período |
| 4 | **Aderência %** | Percentual da meta atingida | % | `(Realizadas ÷ Programadas) × 100` |
| 5 | **Positivas** | OFCs com comportamento seguro | número | `COUNT WHERE type = 'Positivo/Seguro'` |
| 6 | **Negativas** | OFCs com comportamento inseguro | número | `COUNT WHERE type = 'Negativo/Inseguro'` |
| 7 | **% Seguro** | Percentual de comportamentos seguros | % | `(Positivas ÷ Realizadas) × 100` |
| 8 | **% Desvio** | Percentual de comportamentos inseguros | % | `(Negativas ÷ Realizadas) × 100` |
| 9 | **Usuários Ativos** | Usuários que geraram ao menos 1 OFS | número | `COUNT(DISTINCT generated_by)` |
| 10 | **Média OFS/Usuário** | Média de registros por usuário ativo | número | `Realizadas ÷ Usuários Ativos` |

### 1.2 Tratamento de Bordas

| Situação | Comportamento |
|----------|---------------|
| `Programadas = 0` | Aderência = 0 |
| `Realizadas = 0` | % Seguro = 0, % Desvio = 0, Média/Usuário = 0 |
| `Usuários Ativos = 0` | Média/Usuário = 0 |
| Semana sem registros | Todos indicadores = 0, Status = ALERTA |
| Sem meta cadastrada | Fallback: `programadas = realizadas`, `pessoas_ativas = usuarios_ativos` |
| OFCs canceladas | **NÃO** entram no cálculo (status != 'cancelado' AND is_deleted = FALSE) |

### 1.3 Query SQL Consolidada

```sql
WITH meta AS (
    SELECT 
        COALESCE(active_people, 0) AS active_people,
        COALESCE(weekly_target, 0) AS weekly_target,
        COALESCE(active_people * weekly_target, 0) AS ofc_programadas,
        COALESCE(active_users, 0) AS usuarios_ativos_esperados
    FROM targets
    WHERE company_id = :company_id
      AND contract_id = :contract_id
      AND week_start <= :week_start
    ORDER BY week_start DESC
    LIMIT 1
),
realizado AS (
    SELECT
        COUNT(*) FILTER (WHERE type = 'Positivo/Seguro') AS positivas,
        COUNT(*) FILTER (WHERE type = 'Negativo/Inseguro') AS negativas,
        COUNT(*) AS total_realizadas,
        COUNT(DISTINCT generated_by) AS usuarios_ativos
    FROM ofc_records
    WHERE company_id = :company_id
      AND contract_id = :contract_id
      AND record_date BETWEEN :week_start AND :week_end
      AND is_deleted = FALSE
      AND status != 'cancelado'
)
SELECT
    -- Meta
    COALESCE(m.active_people, r.usuarios_ativos, 0) AS pessoas_ativas,
    COALESCE(m.ofc_programadas, r.total_realizadas, 0) AS ofc_programadas,
    -- Realizado
    COALESCE(r.total_realizadas, 0) AS ofc_realizadas,
    COALESCE(r.positivas, 0) AS positivas,
    COALESCE(r.negativas, 0) AS negativas,
    -- Calculados
    ROUND((r.total_realizadas::NUMERIC / NULLIF(m.ofc_programadas, 0)) * 100, 1) AS aderencia_percentual,
    ROUND((r.positivas::NUMERIC / NULLIF(r.total_realizadas, 0)) * 100, 1) AS percentual_seguro,
    ROUND((r.negativas::NUMERIC / NULLIF(r.total_realizadas, 0)) * 100, 1) AS percentual_desvio,
    COALESCE(r.usuarios_ativos, 0) AS usuarios_ativos,
    ROUND((r.total_realizadas::NUMERIC / NULLIF(r.usuarios_ativos, 0)), 1) AS media_ofc_usuario,
    -- Status
    CASE 
        WHEN m.ofc_programadas IS NULL THEN 'SEM_META'
        WHEN (r.total_realizadas::NUMERIC / NULLIF(m.ofc_programadas, 0)) * 100 >= 100 THEN 'OK'
        WHEN (r.total_realizadas::NUMERIC / NULLIF(m.ofc_programadas, 0)) * 100 >= 80 THEN 'ATENCAO'
        ELSE 'ALERTA'
    END AS status
FROM (SELECT 1) AS dummy
LEFT JOIN meta m ON TRUE
LEFT JOIN realizado r ON TRUE
```

---

## 2. Regras de Status

| Status | Condição | Cor | Ícone | Interpretação |
|--------|----------|:---:|:---:|---------------|
| **OK** | Aderência ≥ 100% | 🟢 `#22C55E` | `CheckCircle` | Meta atingida ou superada. Operação dentro do esperado. |
| **ATENÇÃO** | 80% ≤ Aderência < 100% | 🟡 `#EAB308` | `AlertTriangle` | Abaixo da meta, mas dentro da faixa aceitável. Requer acompanhamento. |
| **ALERTA** | Aderência < 80% | 🔴 `#EF4444` | `AlertCircle` | Muito abaixo da meta. Ação corretiva necessária. |
| **SEM_META** | Meta não cadastrada | ⚪ `#9CA3AF` | `HelpCircle` | Nenhuma meta encontrada para esta semana. Cadastrar em Admin > Metas. |

---

## 3. Estrutura da Tela

### 3.1 Wireframe — MÉTRICAS DA SEMANA

```
┌──────────────────────────────────────────────────────────────────────┐
│ ┌──────────┐ ┌──────────────────────────────────────────────────────┐│
│ │ ☰ MENU  │ │ MÉTRICAS DA SEMANA                                   ││
│ └──────────┘ └──────────────────────────────────────────────────────┘│
│                                                                       │
│  ═══════════ FILTROS ═══════════                                     │
│  ◀ Sem. Ant.   📅 12/05 — 18/05/2025 (Semana 20/2026)   Próx. ▶    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐               │
│  │Contrato▾ │ │Empresa ▾ │ │ Turno  ▾ │ │Usuário ▾ │               │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘               │
│                                                                       │
│  ═══════════ CARDS PRINCIPAIS ═══════════                             │
│                                                                       │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────────┐  │
│  │   ADERÊNCIA      │ │    % SEGURO      │ │   STATUS             │  │
│  │                  │ │                  │ │                      │  │
│  │     92.0%        │ │     84.8%        │ │   🟢 OK             │  │
│  │   ██████████░░   │ │   █████████░░░   │ │                      │  │
│  │    Meta: 100%    │ │    Meta: >90%    │ │  Aderência ≥ 100%    │  │
│  └──────────────────┘ └──────────────────┘ └──────────────────────┘  │
│                                                                       │
│  ═══════════ CARDS SECUNDÁRIOS ═══════════                            │
│                                                                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                │
│  │Pessoas   │ │OFS Prog. │ │OFS Real. │ │Positivas │                │
│  │ Ativas   │ │          │ │          │ │          │                │
│  │   85     │ │   250    │ │   230    │ │   195    │                │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘                │
│                                                                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                │
│  │Negativas │ │Usuários  │ │Média/Usu.│ │% Desvio  │                │
│  │   35     │ │ Ativos   │ │   19.2   │ │  15.2%   │                │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘                │
│                                                                       │
│  ═══════════ GRÁFICOS ═══════════                                     │
│                                                                       │
│  ┌─────────────────────────┐ ┌─────────────────────────┐             │
│  │ Programado x Realizado  │ │ Positivo x Negativo     │             │
│  │     [BARRAS]            │ │     [DONUT]             │             │
│  └─────────────────────────┘ └─────────────────────────┘             │
│                                                                       │
│  ┌─────────────────────────┐ ┌─────────────────────────┐             │
│  │ OFS por Empresa         │ │ Evolução Semanal        │             │
│  │  [BARRAS HORIZONTAIS]   │ │  [LINHA]                │             │
│  └─────────────────────────┘ └─────────────────────────┘             │
│                                                                       │
│  ═══════════ TABELA CONSOLIDADA ═══════════                           │
│                                                                       │
│  ┌──────────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬────┐  │
│  │Empresa   │Pes.At│Prog. │Real. │Posit.│Negat.│Ader.%│% Seg.│Sta │  │
│  ├──────────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼────┤  │
│  │Sec.Dynam.│  85  │ 250  │ 230  │ 195  │  35  │ 92.0%│ 84.8%│ 🟢 │  │
│  │G4S       │  40  │ 120  │ 110  │  95  │  15  │ 91.7%│ 86.4%│ 🟡 │  │
│  │ERA       │  30  │  90  │  95  │  85  │  10  │105.6%│ 89.5%│ 🟢 │  │
│  ├──────────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼────┤  │
│  │ TOTAL    │ 155  │ 460  │ 435  │ 375  │  60  │ 94.6%│ 86.2%│ 🟡 │  │
│  └──────────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┴────┘  │
│                                                                       │
│  ┌──────────┐ ┌──────────┐                                          │
│  │📄 PDF    │ │📊 Excel  │                                          │
│  └──────────┘ └──────────┘                                          │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.2 Estados da Tela

| Estado | Componente | Comportamento |
|--------|-----------|---------------|
| **Loading** | `MetricasSkeleton` | 3 cards grandes + 7 pequenos + 4 gráficos + tabela em pulse gray |
| **Erro** | Ícone `AlertTriangle` + mensagem | Botão "Tentar novamente" recarrega tudo |
| **Sem meta** | `MetaBanner` amarelo | Link para `/admin/metas` cadastrar meta |
| **Sem dados** | `EmptyState` | Mensagem + botão "Registrar OFS" → `/OFS/novo` |
| **Dados** | Layout completo | Filtros → cards → gráficos → tabela → exportação |

### 3.3 Responsividade

```
Desktop (≥1024px):
  Cards principais: 3 colunas
  Cards secundários: 7 colunas
  Gráficos: 2 colunas

Tablet (768-1023px):
  Cards principais: 2 colunas
  Cards secundários: 4 colunas
  Gráficos: 1 coluna

Mobile (<768px):
  Cards principais: 1 coluna
  Cards secundários: 2 colunas
  Gráficos: 1 coluna
  Tabela: scroll horizontal
```

### 3.4 Interações

- Navegação de semana: setas `<` `>` + date picker
- Filtros com debounce 300ms atualizam dados automaticamente
- Cards clicáveis: hover eleva, clique drill-down para `/OFS?filtro=...`
- Exportação: toast loading → download → toast success

---

## 4. Gráficos

### 4.1 Catálogo

| # | Gráfico | Tipo Recharts | Tipo matplotlib (PDF) |
|---|---------|:---:|:---:|
| 1 | Programado x Realizado | `<BarChart>` lado a lado | Barras lado a lado |
| 2 | Positivo x Negativo | `<PieChart>` donut | Rosca (donut) |
| 3 | OFS por Empresa | `<BarChart>` horizontal | Barras horizontais |
| 4 | Evolução Semanal | `<LineChart>` | Linha com duplo eixo Y |

### 4.2 Configuração matplotlib para PDF

```python
plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.size': 10,
    'axes.titlesize': 12,
    'axes.titleweight': 'bold',
    'axes.grid': True,
    'grid.alpha': 0.3,
    'grid.color': '#CCCCCC',
    'savefig.dpi': 150,
    'savefig.bbox': 'tight',
    'figure.facecolor': '#FFFFFF',
    'axes.facecolor': '#FFFFFF',
})
```

| Gráfico | Figsize | DPI | Cores |
|---------|:---:|:---:|-------|
| Programado x Realizado | 7×3.5" | 150 | Programado `#CC0000`, Realizado `#3B82F6` |
| Positivo x Negativo | 5×3.5" | 150 | Seguro `#22C55E`, Desvio `#EF4444` |
| OFS por Empresa | 7×3.5" | 150 | Paleta cíclica 8 cores |
| Evolução Semanal | 8×4" | 150 | Realizadas `#CC0000`, Meta 100% tracejado verde, Alerta 80% tracejado amarelo |

### 4.3 Dados para Gráficos (Frontend — Recharts)

```typescript
// Programado x Realizado
[
  { label: "Programado", programado: 250, realizado: 0 },
  { label: "Realizado", programado: 0, realizado: 230 }
]

// Positivo x Negativo
[
  { name: "Positivo/Seguro", value: 195, color: "#22C55E" },
  { name: "Negativo/Inseguro", value: 35, color: "#EF4444" }
]

// OFS por Empresa
[
  { empresa: "Security Dynamics", total: 230, positivas: 195, negativas: 35 },
  { empresa: "G4S", total: 110, positivas: 95, negativas: 15 }
]

// Evolução Semanal (últimas 8 semanas)
[
  { semana: "S13", aderencia: 96.0, realizadas: 720, programadas: 750 },
  { semana: "S14", aderencia: 100.7, realizadas: 755, programadas: 750 }
]
```

---

## 5. Tabela Consolidada

### 5.1 Colunas

| # | Coluna | Fonte | Formato |
|---|--------|-------|--------|
| 1 | Empresa / Contrato | `companies.name` ou `contracts.name` | Texto |
| 2 | Pessoas Ativas | `targets.active_people` | Número |
| 3 | OFS Programadas | `active_people × weekly_target` | Número |
| 4 | OFS Realizadas | `COUNT(ofc_records)` | Número |
| 5 | Positivas | `COUNT WHERE type = 'Positivo/Seguro'` | Número (verde) |
| 6 | Negativas | `COUNT WHERE type = 'Negativo/Inseguro'` | Número (vermelho) |
| 7 | Aderência % | `(Realizadas ÷ Programadas) × 100` | % (1 decimal) |
| 8 | % Seguro | `(Positivas ÷ Realizadas) × 100` | % (1 decimal) |
| 9 | % Desvio | `(Negativas ÷ Realizadas) × 100` | % (1 decimal) |
| 10 | Usuários Ativos | `COUNT(DISTINCT generated_by)` | Número |
| 11 | Média/Usuário | `Realizadas ÷ Usuários Ativos` | Número (1 decimal) |
| 12 | Status | Calculado | Badge colorido |

### 5.2 Cores por Faixa na Tabela

| Coluna | Verde (OK) | Amarelo (ATENÇÃO) | Vermelho (ALERTA) |
|--------|:---:|:---:|:---:|
| Aderência % | ≥ 100% | 80-99% | < 80% |
| % Seguro | ≥ 90% | 75-89% | < 75% |
| % Desvio | ≤ 5% | 6-15% | > 15% |

### 5.3 Linha de TOTAL

Última linha da tabela com borda dupla, fundo cinza claro, soma de todas as colunas numéricas e médias ponderadas para percentuais.

---

## 6. SQL e Consultas Otimizadas

### 6.1 Índices Essenciais

```sql
-- Índice estrela (cobre ~80% das queries de métricas)
CREATE INDEX idx_ofc_metrics_main ON ofc_records 
    (company_id, record_date, type) 
    WHERE is_deleted = FALSE AND status != 'cancelado';

-- Métricas por contrato
CREATE INDEX idx_ofc_metrics_contract ON ofc_records 
    (contract_id, record_date, type) 
    WHERE is_deleted = FALSE AND status != 'cancelado';

-- Evolução semanal (agregação por semana)
CREATE INDEX idx_ofc_week_company ON ofc_records 
    (company_id, year_num, week_num);

-- Ranking por usuário
CREATE INDEX idx_ofc_user_metrics ON ofc_records 
    (generated_by, record_date, company_id) 
    WHERE is_deleted = FALSE AND status != 'cancelado';

-- Full-text search para top comportamentos
CREATE INDEX idx_ofc_behavior_fts ON ofc_records 
    USING GIN(to_tsvector('portuguese', COALESCE(behavior_observed,'')));
```

### 6.2 View Materializada (Opcional — Fase 2)

```sql
CREATE MATERIALIZED VIEW vw_weekly_metrics AS
SELECT
    company_id,
    contract_id,
    week_num,
    year_num,
    MIN(record_date) AS week_start,
    MAX(record_date) AS week_end,
    COUNT(*) AS total_realizadas,
    COUNT(*) FILTER (WHERE type = 'Positivo/Seguro') AS positivas,
    COUNT(*) FILTER (WHERE type = 'Negativo/Inseguro') AS negativas,
    COUNT(DISTINCT generated_by) AS usuarios_ativos
FROM ofc_records
WHERE is_deleted = FALSE AND status != 'cancelado'
GROUP BY company_id, contract_id, year_num, week_num;

CREATE UNIQUE INDEX idx_vw_metrics_pk ON vw_weekly_metrics (company_id, contract_id, year_num, week_num);

-- Refresh a cada 5 minutos via APScheduler
REFRESH MATERIALIZED VIEW CONCURRENTLY vw_weekly_metrics;
```

### 6.3 Estratégia de Cache

| Dado | TTL | Invalidação |
|------|:---:|------------|
| Métricas da semana | 5 min | Criação/edição/cancelamento de OFS |
| Evolução semanal | 15 min | Nova semana ou alteração de meta |
| Rankings (empresa, usuário) | 5 min | Criação de OFS |
| Dropdowns (empresas, contratos) | 24h | CRUD de cadastros |

Implementação: `cachetools.TTLCache` em memória (sem dependência externa).

---

## 7. Endpoints e Payloads

### 7.1 Lista de Endpoints

| Método | Path | Perfil Mínimo | Descrição |
|--------|------|:---:|-----------|
| `GET` | `/api/metrics/weekly` | Supervisor | Métricas completas da semana |
| `GET` | `/api/metrics/charts/programmed-vs-realized` | Supervisor | Dados para gráfico de barras |
| `GET` | `/api/metrics/charts/positive-vs-negative` | Supervisor | Dados para gráfico donut |
| `GET` | `/api/metrics/charts/by-company` | Gestor | Ranking por empresa |
| `GET` | `/api/metrics/charts/by-user` | Supervisor | Ranking por usuário |
| `GET` | `/api/metrics/charts/by-shift` | Supervisor | Distribuição por turno |
| `GET` | `/api/metrics/charts/top-behaviors` | Supervisor | Top comportamentos |
| `GET` | `/api/metrics/charts/weekly-evolution` | Gestor | Evolução 8 semanas |
| `GET` | `/api/metrics/export/pdf` | Gestor | Download PDF semanal |
| `GET` | `/api/metrics/export/excel` | Gestor | Download Excel |

### 7.2 Payload Principal — `GET /api/metrics/weekly`

**Query Params:** `week_start`, `company_id`, `contract_id`, `shift`, `user_id`, `type`, `status`

**Response 200:**
```json
{
  "periodo": {
    "ano": 2026,
    "semana": 20,
    "data_inicio": "2026-05-11",
    "data_fim": "2026-05-17"
  },
  "meta": {
    "cadastrada": true,
    "pessoas_ativas": 85,
    "meta_ofc_por_pessoa": 3,
    "ofc_programadas": 255,
    "usuarios_ativos_esperados": 12
  },
  "indicadores": {
    "pessoas_ativas": 85,
    "ofc_programadas": 255,
    "ofc_realizadas": 230,
    "aderencia_percentual": 90.2,
    "positivas": 195,
    "negativas": 35,
    "percentual_seguro": 84.8,
    "percentual_desvio": 15.2,
    "usuarios_ativos": 12,
    "media_ofc_usuario": 19.2
  },
  "status": "OK",
  "status_cor": "#22C55E",
  "top_comportamentos_seguros": [
    { "comportamento": "Uso correto de EPI", "total": 45 }
  ],
  "top_comportamentos_desvios": [
    { "comportamento": "Falta de sinalização", "total": 12 }
  ],
  "resumo_por_turno": [
    { "turno": "Diurno", "total": 95 },
    { "turno": "Noturno", "total": 80 }
  ],
  "gerado_em": "2026-05-13T15:30:00Z",
  "gerado_por": "Carlos H. Oliveira"
}
```

---

## 8. Regras de Permissão

| Perfil | Escopo de Dados | Métricas | PDF/Excel |
|--------|-----------------|:---:|:---:|
| **Observador** | `WHERE generated_by = user.id` | ❌ (não acessa a tela) | ❌ |
| **Supervisor** | `WHERE company_id = user.company_id` | ✅ (sua empresa) | ❌ |
| **Gestor** | Sem filtro (vê todos) | ✅ (todas) | ✅ |
| **Admin** | Sem filtro (vê todos) | ✅ (todas) | ✅ |

### Implementação no Backend

```python
# metrics_service.py
def apply_data_scope(query, user):
    if user.role == "observador":
        return query.where(OfcRecord.generated_by == user.id)
    elif user.role == "supervisor":
        return query.where(OfcRecord.company_id == user.company_id)
    return query  # gestor, admin: sem filtro
```

---

## 9. Estratégia de Performance

### 9.1 Métricas Alvo

| Operação | P50 | P95 |
|----------|:---:|:---:|
| `GET /metrics/weekly` | < 80ms | < 300ms |
| `GET /metrics/charts/*` | < 40ms | < 150ms |
| `GET /metrics/export/pdf` | < 8s | < 20s |
| `GET /metrics/export/excel` | < 3s | < 8s |

### 9.2 Otimizações Aplicadas

1. **Índice estrela** cobre 80% das queries de métricas com 1 índice composto parcial
2. **CTE única** retorna todos os 10 indicadores em 1 execução
3. **FILTER clause** (3x mais rápido que `CASE WHEN` para agregações condicionais)
4. **Cache TTLCache** 5 minutos para evitar recálculo em refresh de página
5. **View materializada** (Fase 2) para dashboards de alta frequência
6. **Paginação** na tabela consolidada quando > 50 linhas
7. **Gráficos assíncronos** no PDF (ThreadPoolExecutor)

### 9.3 Configuração PostgreSQL

```ini
shared_buffers = 512MB
work_mem = 16MB
random_page_cost = 1.1          # SSD
effective_cache_size = 1536MB
max_parallel_workers_per_gather = 2
```

---

## 10. Estratégia de PDF

### 10.1 Layout (2-3 páginas A4)

```
PÁGINA 1:
  ┌─ Cabeçalho: logo SD + "MÉTRICAS DA SEMANA"
  ├─ Metadados: semana, período, contrato, empresa, emitido por, data
  ├─ Tabela de 10 indicadores com status colorido
  ├─ Gráfico: Programado x Realizado (barras)
  └─ Gráfico: Positivo x Negativo (donut)

PÁGINA 2:
  ├─ Gráfico: OFS por Empresa (barras horizontais)
  ├─ Gráfico: OFS por Turno (pizza)
  └─ Tabela Consolidada (empresas/contratos com indicadores)

PÁGINA 3 (se necessário):
  ├─ Gráfico: Evolução Semanal (linha, últimas 8 semanas)
  └─ Gráfico: Top Comportamentos (barras horizontais)

RODAPÉ (todas as páginas):
  Gerado em: DD/MM/AAAA HH:MM │ Página X/Y
  Security Dynamics — Documento gerado automaticamente
```

### 10.2 Código de Geração

```python
# services/metrics_service.py
async def export_weekly_pdf(week_start, company_id, user):
    # 1. Busca métricas
    metrics = await calculate_weekly_metrics(week_start, company_id)
    
    # 2. Gera gráficos PNG (paralelo)
    charts = await generate_charts_parallel(metrics)
    
    # 3. Renderiza template HTML
    html = render_template("weekly_metrics.html", {
        **metrics,
        **charts,  # base64 images
        "logo_base64": get_logo_b64(),
        "gerado_em": datetime.now(),
        "gerado_por": user.full_name,
    })
    
    # 4. Converte HTML → PDF
    pdf_bytes = HTML(string=html).write_pdf()
    
    # 5. Salva e audita
    filename = f"METRICAS_SEMANA_{metrics['ano']}_{metrics['semana']}_{datetime.now():%Y%m%d}.pdf"
    save_pdf(pdf_bytes, filename)
    await audit_log("GERAR_PDF_METRICAS", user, filename)
    
    return pdf_bytes, filename
```

---

## 11. Estratégia de Excel

### 11.1 Estrutura das Abas

| Aba | Conteúdo | Formatação |
|-----|----------|------------|
| **Resumo** | Título, metadados, 10 indicadores com nome/valor/status/meta | Fonte Calibri, cabeçalho vermelho `#CC0000`, status colorido |
| **Consolidado** | Tabela por empresa (12 colunas) + linha TOTAL | Autofiltro, freeze panes, colunas Positivas (verde) / Negativas (vermelho) |
| **Registros Base** | Dados brutos dos OFCs usados no cálculo | 12 colunas, autofiltro, cores por tipo |

### 11.2 Código de Geração

```python
# services/excel_service.py
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

def export_weekly_excel(metrics_data: dict) -> bytes:
    wb = Workbook()
    
    # Aba 1: Resumo
    ws_resumo = wb.active
    ws_resumo.title = "Resumo"
    _build_resumo_sheet(ws_resumo, metrics_data)
    
    # Aba 2: Consolidado
    ws_cons = wb.create_sheet("Consolidado")
    _build_consolidado_sheet(ws_cons, metrics_data)
    
    # Aba 3: Registros Base
    ws_base = wb.create_sheet("Registros Base")
    _build_registros_sheet(ws_base, metrics_data)
    
    buffer = io.BytesIO()
    wb.save(buffer)
    buffer.seek(0)
    return buffer.getvalue()
```

### 11.3 Formatação de Células

| Elemento | Fonte | Fill | Cor Texto |
|----------|-------|------|-----------|
| Título | Calibri 16pt Bold | — | `#1A1A1A` |
| Cabeçalho tabela | Calibri 10pt Bold | `#CC0000` | `#FFFFFF` |
| Status OK | Calibri 10pt Bold | `#DCFCE7` | `#22C55E` |
| Status ATENÇÃO | Calibri 10pt Bold | `#FEF9C3` | `#A16207` |
| Status ALERTA | Calibri 10pt Bold | `#FEE2E2` | `#EF4444` |
| Linha TOTAL | Calibri 10pt Bold | `#E5E5E5` | `#1A1A1A` |

---

## 12. Estratégia de Auditoria

### 12.1 Eventos Registrados

| Evento | Ação | Severidade | Dados |
|--------|------|:---:|-------|
| Visualizar métricas | `METRICS_VIEW` | INFO | `{ semana, empresa_id, filtros }` |
| Exportar PDF | `METRICS_EXPORT_PDF` | INFO | `{ tipo, ano, semana, nome_arquivo, tamanho }` |
| Exportar Excel | `METRICS_EXPORT_EXCEL` | INFO | `{ tipo, ano, semana, nome_arquivo, qtde_registros }` |
| Erro na geração | `METRICS_EXPORT_ERROR` | ERROR | `{ tipo, parametros, mensagem_erro }` |

### 12.2 Implementação

```python
@router.get("/api/metrics/export/pdf")
@audit_action("METRICS_EXPORT_PDF", "metrics", "INFO")
async def export_pdf(
    week_start: date,
    company_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    pdf_bytes, filename = await export_weekly_pdf(week_start, company_id, current_user)
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'}
    )
```

---

## 13. Critérios de Aceite

### 13.1 Cálculo

- [ ] OFS Programadas = Pessoas Ativas × Meta por Pessoa (validado com planilha)
- [ ] Aderência % = Realizadas ÷ Programadas × 100 (1 casa decimal)
- [ ] Status OK quando aderência ≥ 100% (verde)
- [ ] Status ATENÇÃO quando 80% ≤ aderência < 100% (amarelo)
- [ ] Status ALERTA quando aderência < 80% (vermelho)
- [ ] OFCs canceladas NÃO entram no cálculo
- [ ] Sem meta cadastrada → mensagem "Meta não cadastrada" + link Admin/Metas
- [ ] Sem registros na semana → indicadores = 0

### 13.2 Tela

- [ ] Filtros funcionam (semana, contrato, empresa, turno, usuário)
- [ ] Navegação entre semanas com setas
- [ ] Cards mostram valores corretos
- [ ] Status colorido visível
- [ ] 4 gráficos renderizados (Programado×Realizado, Positivo×Negativo, Empresa, Evolução)
- [ ] Tabela consolidada com todas as empresas/contratos
- [ ] Responsivo (desktop 3 col, tablet 2 col, mobile 1 col)
- [ ] Loading skeleton durante carregamento
- [ ] Estados de erro e vazio tratados

### 13.3 PDF

- [ ] A4 retrato, logo SD no cabeçalho
- [ ] 10 indicadores em tabela formatada
- [ ] 4 gráficos visíveis e proporcionais
- [ ] Tabela consolidada completa
- [ ] Rodapé: data/hora, página X/Y, "Documento gerado automaticamente"
- [ ] Download com nome correto: `METRICAS_SEMANA_2026_20_20260513.pdf`
- [ ] Geração < 15 segundos

### 13.4 Excel

- [ ] 3 abas (Resumo, Consolidado, Registros Base)
- [ ] Formatação corporativa aplicada
- [ ] Autofiltro e freeze panes
- [ ] Colunas Positivas em verde, Negativas em vermelho
- [ ] Linha de TOTAL com borda dupla
- [ ] Download com nome correto: `METRICAS_SEMANA_2026_20_20260513.xlsx`

### 13.5 Permissões

- [ ] Observador NÃO acessa a tela de métricas
- [ ] Supervisor vê apenas métricas da sua empresa
- [ ] Gestor/Admin veem todas as empresas
- [ ] Apenas Gestor/Admin exportam PDF e Excel

### 13.6 Auditoria

- [ ] Visualização registrada em audit_logs
- [ ] Exportação PDF registrada
- [ ] Exportação Excel registrada
- [ ] Erros de geração registrados

---

**Documento gerado em 13/05/2026.**
