# ESPECIFICAÇÃO COMPLETA DO BANCO DE DADOS — PostgreSQL MVP

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**SGBD:** PostgreSQL 16  
**Data:** 13/05/2026  

---

## Sumário

1. [Modelo Lógico](#1-modelo-lógico)
2. [DDL SQL Completo](#2-ddl-sql-completo)
3. [Índices](#3-índices)
4. [Views e Funções](#4-views-e-funções)
5. [Seeds Iniciais](#5-seeds-iniciais)
6. [Regras de Integridade](#6-regras-de-integridade)
7. [Estratégia de Snapshots](#7-estratégia-de-snapshots)
8. [Estratégia de Performance](#8-estratégia-de-performance)
9. [Estratégia de Migração](#9-estratégia-de-migração)
10. [Critérios de Aceite do Banco](#10-critérios-de-aceite-do-banco)

---

## 1. Modelo Lógico

### 1.1 Entidades (12 tabelas)

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  companies   │     │  contracts   │     │   targets    │
│              │     │              │     │              │
│ PK id        │────▶│ PK id        │────▶│ PK id        │
│ name         │     │ name         │     │ company_id   │──┐
│ is_custom    │     │ description  │     │ contract_id  │  │
│ is_active    │     │ is_active    │     │ week_start   │  │
└──────┬───────┘     └──────────────┘     │ active_people│  │
       │                                  │ weekly_target│  │
       │                                  │ active_users │  │
       │                                  └──────────────┘  │
       │                                                    │
       ▼                                                    │
┌──────────────┐                                            │
│    users     │                                            │
│              │                                            │
│ PK id (UUID) │──┐                                         │
│ username     │  │                                         │
│ password_hash│  │     ┌──────────────────────────────┐    │
│ full_name    │  │     │        ofc_records            │    │
│ role         │  │     │                              │    │
│ company_id   │──┤     │ PK id (UUID)                  │    │
│ is_active    │  │     │ codigo (OFS-AAAA-SS-NNNN)     │    │
│ login_attempts│ │     │ data_registro, hora_registro  │    │
│ locked_until │  │     │ semana, mes, ano (gerados)    │    │
└──────────────┘  │     │                              │    │
                  │     │ usuario_id (FK) ──────────────┘    │
                  │     │ usuario_nome_snapshot              │
                  │     │ usuario_login_snapshot             │
                  │     │ usuario_perfil_snapshot            │
                  │     │ empresa_usuario_snapshot           │
                  │     │                              │    │
                  │     │ contrato_id (FK) ────────────┘    │
                  │     │                              │    │
                  ├────▶│ empresa_observada_id (FK) ───┘    │
                  │     │ empresa_observada_outros           │
                  │     │                              │    │
                  │     │ nome_observado                    │
                  │     │ atividade_observada               │
                  │     │ local_observado                   │
                  │     │ turno, tipo_observacao            │
                  │     │ comportamento_observado           │
                  │     │ observacao_complementar           │
                  │     │                              │    │
                  │     │ status_registro (CHECK)           │
                  │     │ is_deleted (soft delete)          │
                  │     │ edit_count                        │
                  │     │                              │    │
                  │     │ criado_por (FK) ──────────────────┘
                  │     │ editado_por (FK) ─────────────────┘
                  │     │ cancelado_por (FK) ───────────────┘
                  │     │ motivo_cancelamento               │
                  │     └──────────────────────────────┘    │
                  │                                         │
                  │     ┌──────────────────────────────┐    │
                  │     │      ofc_edit_log             │    │
                  │     │                              │    │
                  │     │ PK id (BIGSERIAL)             │    │
                  │     │ ofc_record_id                 │    │
                  ├────▶│ edited_by (FK)                │    │
                  │     │ field_changed                 │    │
                  │     │ old_value, new_value          │    │
                  │     │ edited_at                     │    │
                  │     └──────────────────────────────┘    │
                  │                                         │
                  │     ┌──────────────────────────────┐    │
                  │     │        audit_logs             │    │
                  │     │                              │    │
                  │     │ PK id (BIGSERIAL)             │    │
                  ├────▶│ user_id (FK, SET NULL)        │    │
                  │     │ username, action, resource    │    │
                  │     │ details (JSONB)               │    │
                  │     │ ip_address, severity          │    │
                  │     │ created_at                    │    │
                  │     └──────────────────────────────┘    │
                  │                                         │
┌──────────────────┐     ┌──────────────────────────────┐   │
│ password_history │     │       revoked_tokens          │   │
│ user_id (FK)     │     │ jti (PK), user_id (FK)       │   │
│ password_hash    │     │ expires_at, revoked_at        │   │
│ changed_at       │     └──────────────────────────────┘   │
└──────────────────┘                                         │
                                                            │
┌──────────────────┐     ┌──────────────────────────────┐   │
│    reports       │     │     ofc_seq_control           │   │
│ type, parameters │     │ ano + semana (PK)             │   │
│ file_path        │     │ last_seq                      │   │
│ generated_by(FK)─┘     └──────────────────────────────┘   │
└──────────────────┘                                         │
                                                            │
┌──────────────────┐                                        │
│  system_params   │                                        │
│ chave (UNIQUE)   │                                        │
│ valor, descricao │                                        │
└──────────────────┘                                        │
```

### 1.2 Cardinalidades

| Relação | Tipo | Descrição |
|---------|------|-----------|
| companies → users | 1:N | Uma empresa tem muitos usuários |
| users → ofc_records (gerador) | 1:N | Um usuário gera muitos OFCs |
| companies → ofc_records (observada) | 1:N | Uma empresa é observada em muitos OFCs |
| contracts → ofc_records | 1:N | Um contrato tem muitos OFCs |
| users → ofc_edit_log | 1:N | Um usuário faz muitas edições |
| ofc_records → ofc_edit_log | 1:N | Um OFS tem muitas edições |
| companies → targets | 1:N | Uma empresa tem muitas metas (histórico) |
| contracts → targets | 1:N | Um contrato tem muitas metas |

---

## 2. DDL SQL Completo

```sql
-- ============================================================
-- SISTEMA OFS/OFS — Security Dynamics
-- PostgreSQL 16 — Script de Criação do Banco
-- ============================================================

-- Extensões
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. companies
-- ============================================================
CREATE TABLE companies (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    is_custom   BOOLEAN NOT NULL DEFAULT FALSE,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. users
-- ============================================================
CREATE TABLE users (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username            VARCHAR(100) NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,
    full_name           VARCHAR(200) NOT NULL,
    email               VARCHAR(200),
    role                VARCHAR(20) NOT NULL 
        CHECK (role IN ('observador','supervisor','gestor','admin')),
    company_id          INT REFERENCES companies(id) ON DELETE RESTRICT,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    login_attempts      INT NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    last_login          TIMESTAMPTZ,
    password_expires_at TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. contracts
-- ============================================================
CREATE TABLE contracts (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    description TEXT,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 4. targets
-- ============================================================
CREATE TABLE targets (
    id              SERIAL PRIMARY KEY,
    company_id      INT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    contract_id     INT REFERENCES contracts(id) ON DELETE SET NULL,
    week_start      DATE NOT NULL,
    active_people   INT NOT NULL DEFAULT 1 CHECK (active_people >= 0),
    weekly_target   INT NOT NULL DEFAULT 5 CHECK (weekly_target >= 1),
    active_users    INT NOT NULL DEFAULT 1 CHECK (active_users >= 0),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, contract_id, week_start)
);

-- ============================================================
-- 5. ofc_seq_control (controle de sequência do código)
-- ============================================================
CREATE TABLE ofc_seq_control (
    ano         INT NOT NULL,
    semana      INT NOT NULL,
    last_seq    INT NOT NULL DEFAULT 0,
    PRIMARY KEY (ano, semana)
);

-- ============================================================
-- 6. ofc_records (TABELA PRINCIPAL)
-- ============================================================
CREATE TABLE ofc_records (
    -- Identificação
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo              VARCHAR(17) NOT NULL UNIQUE,

    -- Datas
    data_registro       DATE NOT NULL DEFAULT CURRENT_DATE,
    hora_registro       TIME NOT NULL DEFAULT CURRENT_TIME,
    semana              INT NOT NULL CHECK (semana BETWEEN 1 AND 53),
    mes                 INT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    ano                 INT NOT NULL,

    -- Usuário gerador (snapshots)
    usuario_id          UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    usuario_nome_snapshot       VARCHAR(200) NOT NULL,
    usuario_login_snapshot      VARCHAR(100) NOT NULL,
    usuario_email_snapshot      VARCHAR(200),
    usuario_perfil_snapshot     VARCHAR(20) NOT NULL,
    empresa_usuario_snapshot    VARCHAR(150),

    -- Contrato
    contrato_id         INT REFERENCES contracts(id) ON DELETE SET NULL,

    -- Empresa observada
    empresa_observada_id        INT REFERENCES companies(id) ON DELETE SET NULL,
    empresa_observada_outros    VARCHAR(150),

    -- Dados do observado
    nome_observado              VARCHAR(200) NOT NULL,
    atividade_observada         VARCHAR(300) NOT NULL,
    local_observado             VARCHAR(200) NOT NULL,

    -- Classificação
    turno               VARCHAR(50) NOT NULL,
    tipo_observacao     VARCHAR(20) NOT NULL 
        CHECK (tipo_observacao IN ('Positivo/Seguro','Negativo/Inseguro')),

    -- Comportamento
    comportamento_observado     TEXT NOT NULL,
    observacao_complementar     TEXT,

    -- Status
    status_registro     VARCHAR(20) NOT NULL DEFAULT 'Gerado'
        CHECK (status_registro IN ('Gerado','Editado','Cancelado')),
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    edit_count          INT NOT NULL DEFAULT 0,

    -- Auditoria
    criado_por          UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    criado_em           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    editado_por         UUID REFERENCES users(id) ON DELETE SET NULL,
    editado_em          TIMESTAMPTZ,
    cancelado_por       UUID REFERENCES users(id) ON DELETE SET NULL,
    cancelado_em        TIMESTAMPTZ,
    motivo_cancelamento TEXT,
    deleted_at          TIMESTAMPTZ,
    deleted_by          UUID REFERENCES users(id) ON DELETE SET NULL,

    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 7. ofc_edit_log
-- ============================================================
CREATE TABLE ofc_edit_log (
    id              BIGSERIAL PRIMARY KEY,
    ofc_record_id   UUID NOT NULL,
    edited_by       UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    field_changed   VARCHAR(100) NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    edited_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 8. audit_logs
-- ============================================================
CREATE TABLE audit_logs (
    id              BIGSERIAL PRIMARY KEY,
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    username        VARCHAR(100),
    action          VARCHAR(50) NOT NULL,
    resource        VARCHAR(100) NOT NULL,
    resource_id     VARCHAR(255),
    details         JSONB DEFAULT '{}',
    ip_address      VARCHAR(45),
    severity        VARCHAR(20) NOT NULL DEFAULT 'INFO'
        CHECK (severity IN ('INFO','WARNING','CRITICAL')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 9. password_history
-- ============================================================
CREATE TABLE password_history (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    password_hash   VARCHAR(255) NOT NULL,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 10. revoked_tokens
-- ============================================================
CREATE TABLE revoked_tokens (
    jti             VARCHAR(255) PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 11. reports
-- ============================================================
CREATE TABLE reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type            VARCHAR(50) NOT NULL CHECK (type IN ('individual','semanal')),
    parameters      JSONB NOT NULL DEFAULT '{}',
    file_path       VARCHAR(500),
    file_size       BIGINT,
    generated_by    UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 12. system_params
-- ============================================================
CREATE TABLE system_params (
    id              SERIAL PRIMARY KEY,
    chave           VARCHAR(100) NOT NULL UNIQUE,
    valor           TEXT NOT NULL,
    descricao       TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Triggers

```sql
-- ============================================================
-- TRIGGER 1: Gerar código OFS-AAAA-SS-NNNN
-- ============================================================
CREATE OR REPLACE FUNCTION generate_ofc_codigo()
RETURNS TRIGGER AS $$
DECLARE
    v_ano INT;
    v_semana INT;
    v_seq INT;
BEGIN
    v_ano := EXTRACT(YEAR FROM NEW.data_registro)::INT;
    v_semana := EXTRACT(WEEK FROM NEW.data_registro)::INT;

    INSERT INTO ofc_seq_control (ano, semana, last_seq)
    VALUES (v_ano, v_semana, 1)
    ON CONFLICT (ano, semana) DO UPDATE
    SET last_seq = ofc_seq_control.last_seq + 1
    RETURNING last_seq INTO v_seq;

    NEW.codigo := 'OFS-' || LPAD(v_ano::TEXT, 4, '0') || '-' 
                         || LPAD(v_semana::TEXT, 2, '0') || '-' 
                         || LPAD(v_seq::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ofc_codigo
    BEFORE INSERT ON ofc_records
    FOR EACH ROW EXECUTE FUNCTION generate_ofc_codigo();

-- ============================================================
-- TRIGGER 2: Preencher semana/mes/ano
-- ============================================================
CREATE OR REPLACE FUNCTION fill_date_parts()
RETURNS TRIGGER AS $$
BEGIN
    NEW.semana := EXTRACT(WEEK FROM NEW.data_registro)::INT;
    NEW.mes    := EXTRACT(MONTH FROM NEW.data_registro)::INT;
    NEW.ano    := EXTRACT(YEAR FROM NEW.data_registro)::INT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ofc_date_parts
    BEFORE INSERT OR UPDATE OF data_registro ON ofc_records
    FOR EACH ROW EXECUTE FUNCTION fill_date_parts();

-- ============================================================
-- TRIGGER 3: updated_at automático
-- ============================================================
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_contracts_updated_at BEFORE UPDATE ON contracts FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_targets_updated_at BEFORE UPDATE ON targets FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_ofc_updated_at BEFORE UPDATE ON ofc_records FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_params_updated_at BEFORE UPDATE ON system_params FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================
-- TRIGGER 4: IMPEDIR DELETE físico em ofc_records
-- ============================================================
CREATE OR REPLACE FUNCTION prevent_hard_delete_ofc()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Exclusão física não permitida em ofc_records. Use cancelamento lógico (soft delete).';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ofc_no_hard_delete
    BEFORE DELETE ON ofc_records
    FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete_ofc();

-- ============================================================
-- TRIGGER 5: IMPEDIR UPDATE/DELETE em audit_logs (imutável)
-- ============================================================
CREATE OR REPLACE FUNCTION prevent_audit_tampering()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        RAISE EXCEPTION 'audit_logs é imutável. Operações UPDATE/DELETE não permitidas.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_no_tamper
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION prevent_audit_tampering();

-- ============================================================
-- TRIGGER 6: Cancelamento exige motivo
-- ============================================================
CREATE OR REPLACE FUNCTION validate_ofc_cancel()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status_registro = 'Cancelado' AND OLD.status_registro != 'Cancelado' THEN
        IF NEW.motivo_cancelamento IS NULL OR LENGTH(TRIM(NEW.motivo_cancelamento)) < 10 THEN
            RAISE EXCEPTION 'Cancelamento exige motivo com no mínimo 10 caracteres';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ofc_cancel_validate
    BEFORE UPDATE ON ofc_records
    FOR EACH ROW EXECUTE FUNCTION validate_ofc_cancel();
```

---

## 3. Índices

### 3.1 Índices por Prioridade

**P0 — Críticos (sistema não funciona sem):**

```sql
-- Métricas (índice estrela — cobre 80% das queries)
CREATE INDEX idx_ofc_metrics_main ON ofc_records 
    (company_id, data_registro, tipo_observacao) 
    WHERE is_deleted = FALSE AND status_registro != 'Cancelado';

-- Listagem por usuário (Observador)
CREATE INDEX idx_ofc_user_list ON ofc_records 
    (usuario_id, data_registro DESC) 
    WHERE is_deleted = FALSE;

-- Busca por código
CREATE UNIQUE INDEX idx_ofc_codigo ON ofc_records(codigo);

-- Login
CREATE INDEX idx_users_username ON users(username) WHERE is_active = TRUE;
```

**P1 — Importantes (consultas frequentes):**

```sql
-- Consultas por período
CREATE INDEX idx_ofc_date ON ofc_records(data_registro DESC);
CREATE INDEX idx_ofc_week ON ofc_records(ano, semana);
CREATE INDEX idx_ofc_month ON ofc_records(ano, mes);

-- Filtros individuais
CREATE INDEX idx_ofc_company ON ofc_records(empresa_observada_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_ofc_type ON ofc_records(tipo_observacao) WHERE is_deleted = FALSE;
CREATE INDEX idx_ofc_status ON ofc_records(status_registro);
CREATE INDEX idx_ofc_shift ON ofc_records(turno) WHERE is_deleted = FALSE;
CREATE INDEX idx_ofc_contract ON ofc_records(contrato_id) WHERE is_deleted = FALSE;

-- Ranking por usuário
CREATE INDEX idx_ofc_user_metrics ON ofc_records 
    (usuario_id, data_registro, company_id) 
    WHERE is_deleted = FALSE AND status_registro != 'Cancelado';

-- Histórico de edições
CREATE INDEX idx_edit_log_ofc ON ofc_edit_log(ofc_record_id, edited_at DESC);

-- Auditoria
CREATE INDEX idx_audit_ts ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_action ON audit_logs(action, created_at DESC);

-- Tokens revogados (limpeza)
CREATE INDEX idx_revoked_expires ON revoked_tokens(expires_at) WHERE expires_at < NOW();

-- Histórico de senhas
CREATE INDEX idx_pass_hist_user ON password_history(user_id, changed_at DESC);
```

**P2 — Otimizações:**

```sql
-- Full-text search (português)
CREATE INDEX idx_ofc_fts ON ofc_records USING GIN(
    to_tsvector('portuguese', 
        COALESCE(nome_observado,'') || ' ' || 
        COALESCE(comportamento_observado,'') || ' ' || 
        COALESCE(observacao_complementar,'') || ' ' ||
        COALESCE(atividade_observada,'') || ' ' ||
        COALESCE(local_observado,'')
    )
) WHERE is_deleted = FALSE;

-- Índice parcial para métricas positivas (COUNT FILTER)
CREATE INDEX idx_ofc_positive ON ofc_records 
    (company_id, data_registro) 
    WHERE is_deleted = FALSE AND tipo_observacao = 'Positivo/Seguro';

-- Índice parcial para métricas negativas
CREATE INDEX idx_ofc_negative ON ofc_records 
    (company_id, data_registro) 
    WHERE is_deleted = FALSE AND tipo_observacao = 'Negativo/Inseguro';

-- Targets: busca da meta vigente
CREATE INDEX idx_targets_current ON targets 
    (company_id, contract_id, week_start DESC) 
    WHERE is_active = TRUE;
```

---

## 4. Views e Funções

### 4.1 vw_valid_ofcs

```sql
CREATE OR REPLACE VIEW vw_valid_ofcs AS
SELECT 
    o.*,
    c.name AS empresa_observada_nome,
    u.full_name AS usuario_gerador_nome
FROM ofc_records o
LEFT JOIN companies c ON o.empresa_observada_id = c.id
LEFT JOIN users u ON o.usuario_id = u.id
WHERE o.is_deleted = FALSE 
  AND o.status_registro != 'Cancelado';
```

### 4.2 vw_weekly_metrics (Materialized)

```sql
CREATE MATERIALIZED VIEW vw_weekly_metrics AS
SELECT
    company_id,
    ano,
    semana,
    MIN(data_registro) AS data_inicio,
    MAX(data_registro) AS data_fim,
    COUNT(*) AS total_realizadas,
    COUNT(*) FILTER (WHERE tipo_observacao = 'Positivo/Seguro') AS positivas,
    COUNT(*) FILTER (WHERE tipo_observacao = 'Negativo/Inseguro') AS negativas,
    COUNT(DISTINCT usuario_id) AS usuarios_ativos,
    ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT usuario_id), 0), 1) AS media_ofc_usuario
FROM ofc_records
WHERE is_deleted = FALSE AND status_registro != 'Cancelado'
GROUP BY company_id, ano, semana;

CREATE UNIQUE INDEX idx_vwm_pk ON vw_weekly_metrics(company_id, ano, semana);

-- Refresh
CREATE OR REPLACE FUNCTION fn_refresh_weekly_metrics()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY vw_weekly_metrics;
END;
$$ LANGUAGE plpgsql;
```

### 4.3 calculate_weekly_metrics()

```sql
CREATE OR REPLACE FUNCTION calculate_weekly_metrics(
    p_week_start DATE,
    p_company_id INT
) RETURNS TABLE(
    pessoas_ativas INT,
    ofc_programadas INT,
    ofc_realizadas BIGINT,
    aderencia_percentual NUMERIC,
    positivas BIGINT,
    negativas BIGINT,
    percentual_seguro NUMERIC,
    percentual_desvio NUMERIC,
    usuarios_ativos BIGINT,
    media_ofc_usuario NUMERIC,
    status VARCHAR(20)
) AS $$
DECLARE
    v_week_end DATE := p_week_start + INTERVAL '6 days';
    v_programadas INT;
    v_active_people INT;
BEGIN
    -- Buscar meta vigente
    SELECT COALESCE(active_people, 0), COALESCE(active_people * weekly_target, 0)
    INTO v_active_people, v_programadas
    FROM targets
    WHERE company_id = p_company_id
      AND week_start <= p_week_start
      AND is_active = TRUE
    ORDER BY week_start DESC LIMIT 1;

    RETURN QUERY
    WITH realizado AS (
        SELECT
            COUNT(*)::BIGINT AS real_total,
            COUNT(*) FILTER (WHERE tipo_observacao = 'Positivo/Seguro')::BIGINT AS pos,
            COUNT(*) FILTER (WHERE tipo_observacao = 'Negativo/Inseguro')::BIGINT AS neg,
            COUNT(DISTINCT usuario_id)::BIGINT AS users_active
        FROM ofc_records
        WHERE company_id = p_company_id
          AND data_registro BETWEEN p_week_start AND v_week_end
          AND is_deleted = FALSE
          AND status_registro != 'Cancelado'
    )
    SELECT
        v_active_people,
        v_programadas,
        r.real_total,
        ROUND((r.real_total::NUMERIC / NULLIF(v_programadas, 0)) * 100, 1),
        r.pos,
        r.neg,
        ROUND((r.pos::NUMERIC / NULLIF(r.real_total, 0)) * 100, 1),
        ROUND((r.neg::NUMERIC / NULLIF(r.real_total, 0)) * 100, 1),
        r.users_active,
        ROUND((r.real_total::NUMERIC / NULLIF(r.users_active, 0)), 1),
        CASE 
            WHEN v_programadas IS NULL OR v_programadas = 0 THEN 'SEM_META'
            WHEN (r.real_total::NUMERIC / NULLIF(v_programadas, 0)) * 100 >= 100 THEN 'OK'
            WHEN (r.real_total::NUMERIC / NULLIF(v_programadas, 0)) * 100 >= 80 THEN 'ATENCAO'
            ELSE 'ALERTA'
        END
    FROM realizado r;
END;
$$ LANGUAGE plpgsql;
```

### 4.4 vw_company_ranking

```sql
CREATE OR REPLACE VIEW vw_company_ranking AS
SELECT
    c.id AS company_id,
    c.name AS company_name,
    COUNT(o.id) AS total_realizadas,
    COUNT(o.id) FILTER (WHERE o.tipo_observacao = 'Positivo/Seguro') AS positivas,
    COUNT(o.id) FILTER (WHERE o.tipo_observacao = 'Negativo/Inseguro') AS negativas,
    ROUND((COUNT(o.id) FILTER (WHERE o.tipo_observacao = 'Positivo/Seguro')::NUMERIC / 
           NULLIF(COUNT(o.id), 0)) * 100, 1) AS percentual_seguro
FROM companies c
LEFT JOIN ofc_records o ON o.empresa_observada_id = c.id
    AND o.is_deleted = FALSE
    AND o.status_registro != 'Cancelado'
    AND o.data_registro >= date_trunc('week', CURRENT_DATE)::date
    AND o.data_registro < date_trunc('week', CURRENT_DATE)::date + INTERVAL '7 days'
WHERE c.is_active = TRUE
GROUP BY c.id, c.name
ORDER BY total_realizadas DESC;
```

---

## 5. Seeds Iniciais

```sql
-- ============================================================
-- SEED DATA
-- ============================================================

-- 5.1 Empresas (15)
INSERT INTO companies (name, is_custom) VALUES
    ('Security Dynamics', FALSE),
    ('Polo Norte', FALSE),
    ('G4S', FALSE),
    ('ERA', FALSE),
    ('Innovatec', FALSE),
    ('Conin', FALSE),
    ('FM', FALSE),
    ('Sodexo', FALSE),
    ('Engecom', FALSE),
    ('P&G', FALSE),
    ('Yusen', FALSE),
    ('Mainpower', FALSE),
    ('Aduana', FALSE),
    ('Prosegur', FALSE),
    ('Outros', TRUE);

-- 5.2 Admin (senha: Admin@123)
INSERT INTO users (username, password_hash, full_name, email, role, company_id) VALUES
    ('admin', 
     '$2b$12$LJ3m4ys3Lk0TSwHCpNqrIO8mXDZpJqKMGmF0MGZyPFBvfHaaVUwOe',
     'Administrador do Sistema',
     'admin@securitydynamics.com.br',
     'admin',
     1);

-- 5.3 Contrato padrão
INSERT INTO contracts (name, description) VALUES
    ('Operação Security Dynamics', 'Contrato principal de operações da Security Dynamics');

-- 5.4 Meta inicial (semana atual)
INSERT INTO targets (company_id, contract_id, week_start, active_people, weekly_target, active_users) VALUES
    (1, 1, date_trunc('week', CURRENT_DATE)::date, 50, 5, 10);

-- 5.5 Parâmetros do sistema
INSERT INTO system_params (chave, valor, descricao) VALUES
    ('nome_sistema', 'Sistema de Feedback Comportamental OFS/OFS', 'Nome exibido no cabeçalho'),
    ('tempo_sessao_minutos', '15', 'Tempo de expiração do access token (minutos)'),
    ('meta_padrao_ofc_por_pessoa', '5', 'Meta diária padrão de OFS por pessoa');
```

---

## 6. Regras de Integridade

### 6.1 Política de Foreign Keys

| FK | ON DELETE | Justificativa |
|----|-----------|---------------|
| `ofc_records.usuario_id → users` | RESTRICT | Não permitir deletar usuário com OFCs |
| `ofc_records.criado_por → users` | RESTRICT | Idem |
| `ofc_records.empresa_observada_id → companies` | SET NULL | Empresa pode ser desativada, registro preservado |
| `ofc_records.contrato_id → contracts` | SET NULL | Contrato pode ser desativado |
| `ofc_records.editado_por → users` | SET NULL | Histórico preserva o nome no snapshot |
| `ofc_records.cancelado_por → users` | SET NULL | Histórico preserva o nome no snapshot |
| `audit_logs.user_id → users` | SET NULL | Log sobrevive à remoção do usuário |
| `password_history.user_id → users` | CASCADE | Remove histórico junto com usuário |
| `revoked_tokens.user_id → users` | CASCADE | Remove tokens junto com usuário |

### 6.2 Regras de Cancelamento Lógico

| Regra | Implementação |
|-------|---------------|
| NUNCA excluir fisicamente | Trigger `BEFORE DELETE` → RAISE EXCEPTION |
| Motivo obrigatório | Trigger valida `motivo_cancelamento` NOT NULL e LENGTH ≥ 10 |
| Status muda para Cancelado | CHECK constraint |
| is_deleted = TRUE | Coluna booleana |
| Cancelado não entra em métricas | Views e funções filtram `is_deleted = FALSE AND status != 'Cancelado'` |
| Admin pode restaurar | UPDATE `is_deleted = FALSE, status = 'Editado'` |

### 6.3 Integridade dos Snapshots

| Snapshot | Preenchido em | Imutável? |
|----------|:---:|:---:|
| `usuario_nome_snapshot` | INSERT (trigger ou backend) | ✅ Sim |
| `usuario_login_snapshot` | INSERT | ✅ Sim |
| `usuario_email_snapshot` | INSERT | ✅ Sim |
| `usuario_perfil_snapshot` | INSERT | ✅ Sim |
| `empresa_usuario_snapshot` | INSERT | ✅ Sim |

**Motivo:** Se um usuário mudar de nome, perfil ou empresa após gerar vários OFCs, os registros antigos preservam a identificação exata de quem era e qual perfil tinha no momento da criação. Essencial para auditoria.

---

## 7. Estratégia de Snapshots

### 7.1 Por que Snapshots

```
CENÁRIO REAL:
1. João (Supervisor, Security Dynamics) cria 200 OFCs em 2025
2. Em 2026, João é promovido a Gestor e transferido para G4S
3. Sem snapshots: todos os 200 OFCs apareceriam como "Gestor, G4S" — ERRADO
4. Com snapshots: cada OFS preserva "Supervisor, Security Dynamics" — CORRETO
```

### 7.2 Implementação

Os snapshots são preenchidos pelo backend no momento do INSERT, usando os dados do `current_user` extraído do JWT. NUNCA são atualizados. As colunas originais (`usuario_id`, `company_id`) mantêm as FKs para joins e integridade referencial.

---

## 8. Estratégia de Performance

### 8.1 Configurações PostgreSQL (4GB RAM)

```ini
shared_buffers = 512MB
effective_cache_size = 1536MB
work_mem = 16MB
maintenance_work_mem = 128MB
random_page_cost = 1.1          # SSD
effective_io_concurrency = 200
max_connections = 50
wal_buffers = 16MB
autovacuum_max_workers = 3
autovacuum_naptime = 60s

# Autovacuum agressivo na tabela principal
# ALTER TABLE ofc_records SET (autovacuum_vacuum_scale_factor = 0.02);
```

### 8.2 Tempos Esperados (com índices)

| Operação | P50 | P95 |
|----------|:---:|:---:|
| INSERT ofc_records | < 5ms | < 15ms |
| SELECT por código | < 1ms | < 3ms |
| Listagem paginada (25/página) | < 15ms | < 50ms |
| Métricas semanais (~10k registros) | < 30ms | < 100ms |
| FTS (busca textual) | < 50ms | < 200ms |
| Consulta com 3 filtros | < 30ms | < 100ms |

### 8.3 Manutenção

| Tarefa | Frequência | Comando |
|--------|:---:|---------|
| VACUUM ofc_records | Automático (autovacuum) | Trigger por 2% dead tuples |
| ANALYZE após carga | Após >1000 inserts | `ANALYZE ofc_records;` |
| REINDEX | Semestral | `REINDEX TABLE ofc_records;` |
| Refresh view materializada | A cada 5 min ou sob demanda | `REFRESH MATERIALIZED VIEW CONCURRENTLY vw_weekly_metrics;` |
| Limpeza revoked_tokens | Diário (04:00) | `DELETE FROM revoked_tokens WHERE expires_at < NOW();` |

---

## 9. Estratégia de Migração

### 9.1 Versionamento com Alembic

```bash
# Migration 001: schema inicial
alembic revision --autogenerate -m "initial_schema"
alembic upgrade head

# Migration 002: seeds
alembic revision --autogenerate -m "seed_data"
# (editar o arquivo gerado para conter os INSERTs)
alembic upgrade head

# Rollback
alembic downgrade -1

# Histórico
alembic history
```

### 9.2 Migração para Nuvem

```bash
# Exportar
pg_dump -h localhost -U ofs_user -d ofs_db -Fc -f backup.dump

# Importar (RDS / Cloud SQL)
pg_restore -h cloud-host -U cloud_user -d cloud_db --clean --if-exists backup.dump

# Ajustar variáveis de ambiente
# DATABASE_URL=postgresql+asyncpg://user:pass@cloud-host:5432/db
```

### 9.3 Compatibilidade Cloud

Todas as features usadas são PostgreSQL padrão:
- UUID via `gen_random_uuid()` (suportado RDS, Cloud SQL, Azure PostgreSQL)
- GIN indexes (suportado em todos)
- CHECK constraints (suportado em todos)
- Triggers PL/pgSQL (suportado em todos)

---

## 10. Critérios de Aceite do Banco

### 10.1 Criação e Estrutura

- [ ] Script SQL executado sem erros (`psql -f ddl.sql`)
- [ ] 12 tabelas criadas com todas as colunas
- [ ] 6 triggers funcionais
- [ ] 20+ índices criados
- [ ] Seeds populados (15 empresas, 1 admin, 1 contrato, 1 meta, 3 parâmetros)

### 10.2 Integridade

- [ ] DELETE físico em ofc_records bloqueado (trigger)
- [ ] UPDATE/DELETE em audit_logs bloqueado (trigger)
- [ ] Cancelamento sem motivo bloqueado (trigger)
- [ ] Código gerado no formato OFS-AAAA-SS-NNNN
- [ ] Código único por registro
- [ ] FK com ON DELETE apropriado (RESTRICT, SET NULL, CASCADE)

### 10.3 Performance

- [ ] Índice estrela cobre query de métricas (< 50ms com 10k registros)
- [ ] Busca por código usa índice único (< 1ms)
- [ ] FTS retorna resultados em < 100ms com 50k registros
- [ ] Índices parciais reduzem uso de disco em 50%

### 10.4 Rastreabilidade

- [ ] Snapshots preenchidos no INSERT
- [ ] Snapshots imutáveis (não atualizados no UPDATE)
- [ ] ofc_edit_log registra cada campo alterado
- [ ] audit_logs registra toda ação com JSONB
- [ ] Soft delete preserva histórico completo

### 10.5 Migração

- [ ] `alembic upgrade head` executa sem erros
- [ ] `alembic downgrade -1` reverte com sucesso
- [ ] `pg_dump` + `pg_restore` funcionam entre ambientes
- [ ] Views materializadas rebuild sem bloquear leituras (CONCURRENTLY)

---

**Documento gerado em 13/05/2026.**

### Arquivos SQL gerados pelos agentes:

| Arquivo | Conteúdo |
|---------|----------|
| `ddl_sistema_ofs.sql` | DDL completo (12 tabelas, triggers, índices, seeds, views) |
| `ofs_comprehensive_indexes_config.sql` | 20+ índices com EXPLAIN ANALYZE e configurações |
| `ofs_analytics_consolidation.sql` | 2 views + 1 matview + 4 funções de métricas |
| `002_seed_data.sql` | Seeds completos + 50 OFCs de teste |
| `migration_v4_integrity_comprehensive.sql` | FK policies, triggers anti-tamper, verificador integridade |
