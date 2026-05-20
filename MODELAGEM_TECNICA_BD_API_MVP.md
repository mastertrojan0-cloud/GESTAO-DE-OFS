# MODELAGEM TÉCNICA — Banco de Dados e APIs do MVP

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Data:** 13/05/2026  

---

## Sumário

1. [Diagrama Lógico das Tabelas](#1-diagrama-lógico-das-tabelas)
2. [SQL DDL Completo](#2-sql-ddl-completo)
3. [Relacionamentos](#3-relacionamentos)
4. [Índices Recomendados](#4-índices-recomendados)
5. [Regras de Validação](#5-regras-de-validação)
6. [Endpoints Detalhados](#6-endpoints-detalhados)
7. [Payloads de Exemplo — OFS/OFS](#7-payloads-de-exemplo--ofcofs)
8. [Payloads de Exemplo — Métricas](#8-payloads-de-exemplo--métricas)
9. [Regras de Permissão por Endpoint](#9-regras-de-permissão-por-endpoint)
10. [Recomendações de Segurança](#10-recomendações-de-segurança)
11. [Estratégia de Auditoria](#11-estratégia-de-auditoria)
12. [Estratégia para Migração Futura para Nuvem](#12-estratégia-para-migração-futura-para-nuvem)

---

## 1. Diagrama Lógico das Tabelas

```
┌──────────────────────┐
│      empresas        │
├──────────────────────┤
│ id (PK, SERIAL)      │──┐
│ nome (VARCHAR 150)   │  │
│ status (BOOLEAN)     │  │
│ criado_em            │  │
│ atualizado_em        │  │
└─────────┬────────────┘  │
          │               │
          │               │     ┌──────────────────────┐
          │               │     │      contratos       │
          │               │     ├──────────────────────┤
          │               │     │ id (PK, SERIAL)      │──┐
          │               │     │ nome (VARCHAR 200)   │  │
          │               │     │ descricao (TEXT)     │  │
          │               │     │ status (BOOLEAN)     │  │
          │               │     │ criado_em            │  │
          │               │     │ atualizado_em        │  │
          │               │     └──────────┬───────────┘  │
          │               │                │              │
          │               │                │    ┌─────────┘
          │               │                │    │
          │               │     ┌──────────▼────▼──────────┐
          │               │     │         locais           │
          │               │     ├──────────────────────────┤
          │               │     │ id (PK, SERIAL)          │
          │               │     │ nome (VARCHAR 200)       │
          │               │     │ contrato_id (FK)         │──▶ contratos.id
          │               │     │ status (BOOLEAN)         │
          │               │     │ criado_em                │
          │               │     │ atualizado_em            │
          │               │     └──────────────────────────┘
          │               │
          │               │     ┌──────────────────────────┐
          │               │     │     metas_semanais       │
          │               │     ├──────────────────────────┤
          │               │     │ id (PK, SERIAL)          │
          │               │     │ contrato_id (FK)         │──▶ contratos.id
          │               │     │ ano (INT)                │
          │               │     │ semana (INT, 1-53)       │
          │               │     │ pessoas_ativas (INT)     │
          │               │     │ meta_ofc_por_pessoa (INT)│
          │               │     │ meta_ofc_programada (INT)│
          │               │     │ usuarios_ativos (INT)    │
          │               │     │ criado_em                │
          │               │     │ atualizado_em            │
          │               │     └──────────────────────────┘
          │               │
          │               │     ┌──────────────────────────────────────────────┐
          │               │     │              ofc_registros                   │
          │               │     ├──────────────────────────────────────────────┤
          │               │     │ id (PK, UUID)                                │
          │               │     │ codigo (SERIAL, sequencial visível)           │
          │               │     │ data_registro (DATE)                         │
          │               │     │ hora_registro (TIME)                         │
          │               │     │ semana (INT, 1-53)                           │
          │               │     │ mes (INT, 1-12)                              │
          │               │     │ ano (INT)                                    │
          │               │     │                                              │
          │               │     │ usuario_id (FK) ─────────────────────────────┼──▶ usuarios.id
          │               │     │ usuario_nome_snapshot (VARCHAR)               │
          │               │     │ usuario_email_snapshot (VARCHAR)              │
          │               │     │ usuario_perfil_snapshot (VARCHAR)             │
          │               │     │ empresa_usuario_snapshot (VARCHAR)            │
          │               │     │                                              │
          │               │     │ contrato_id (FK) ────────────────────────────┼──▶ contratos.id
          │               │     │                                              │
          │               │     │ empresa_observada_id (FK) ───────────────────┼──▶ empresas.id
          │               │     │ empresa_observada_outros (VARCHAR)            │
          │               │     │                                              │
          │               │     │ nome_observado (VARCHAR)                      │
          │               │     │ atividade_observada (VARCHAR)                 │
          │               │     │                                              │
          │               │     │ local_id (FK) ───────────────────────────────┼──▶ locais.id
          │               │     │ local_texto (VARCHAR)                         │
          │               │     │                                              │
          │               │     │ turno (VARCHAR)                               │
          │               │     │ tipo_observacao (VARCHAR, Positivo|Negativo)  │
          │               │     │ comportamento_observado (TEXT)                │
          │               │     │ observacao_complementar (TEXT)                │
          │               │     │                                              │
          │               │     │ status_registro (VARCHAR)                     │
          │               │     │                                              │
          │               │     │ criado_por (FK) ─────────────────────────────┼──▶ usuarios.id
          │               │     │ criado_em (TIMESTAMPTZ)                       │
          │               │     │ editado_por (FK) ────────────────────────────┼──▶ usuarios.id
          │               │     │ editado_em (TIMESTAMPTZ)                      │
          │               │     │ cancelado_por (FK) ──────────────────────────┼──▶ usuarios.id
          │               │     │ cancelado_em (TIMESTAMPTZ)                    │
          │               │     │ motivo_cancelamento (TEXT)                    │
          │               └────────────────────────────────────────────────────┘
          │
          │          ┌────────────────────────────────────────────────────────┐
          │          │                       usuarios                         │
          │          ├────────────────────────────────────────────────────────┤
          │          │ id (PK, UUID)                                          │
          │          │ nome (VARCHAR 200)                                     │
          │          │ login (VARCHAR 100, UNIQUE)                            │
          │          │ email (VARCHAR 200)                                    │
          │          │ senha_hash (VARCHAR 255)                               │
          ├──────────│ empresa_id (FK) ───────────────────────────────────────┘
          │          │ contrato_id (FK) ───────────────▶ contratos.id
          │          │ perfil (VARCHAR 20)
          │          │ status (BOOLEAN)
          │          │ tentativas_login (INT)
          │          │ bloqueado_ate (TIMESTAMPTZ)
          │          │ ultimo_login (TIMESTAMPTZ)
          │          │ criado_em (TIMESTAMPTZ)
          │          │ atualizado_em (TIMESTAMPTZ)
          │          └────────────────────────────────────────────────────────┘
          │
          │          ┌────────────────────────────────────────────────────────┐
          │          │                      auditoria                          │
          │          ├────────────────────────────────────────────────────────┤
          │          │ id (PK, BIGSERIAL)                                     │
          ├──────────│ usuario_id (FK) ───────────────────────────────────────┘
          │          │ acao (VARCHAR 50)
          │          │ entidade (VARCHAR 100)
          │          │ entidade_id (VARCHAR 255)
          │          │ dados_anteriores (JSONB)
          │          │ dados_novos (JSONB)
          │          │ ip_origem (VARCHAR 45)
          │          │ criado_em (TIMESTAMPTZ)
          │          └────────────────────────────────────────────────────────┘
          │
          │          ┌────────────────────────────────────────────────────────┐
          │          │                 relatorios_gerados                      │
          │          ├────────────────────────────────────────────────────────┤
          │          │ id (PK, UUID)                                          │
          │          │ tipo (VARCHAR 50) — 'individual','semanal','mensal'    │
          │          │ parametros (JSONB)                                     │
          ├──────────│ usuario_id (FK) ───────────────────────────────────────┘
          │          │ arquivo_path (VARCHAR 500)
          │          │ arquivo_tamanho (BIGINT)
          │          │ criado_em (TIMESTAMPTZ)
          │          └────────────────────────────────────────────────────────┘
          │
          │          ┌────────────────────────────────────────────────────────┐
          │          │                 ofc_edicoes                             │
          │          ├────────────────────────────────────────────────────────┤
          │          │ id (PK, BIGSERIAL)                                     │
          │          │ ofc_registro_id (FK) ──────▶ ofc_registros.id          │
          ├──────────│ editado_por (FK) ──────────────────────────────────────┘
          │          │ campo_alterado (VARCHAR)
          │          │ valor_anterior (TEXT)
          │          │ valor_novo (TEXT)
          │          │ criado_em (TIMESTAMPTZ)
          │          └────────────────────────────────────────────────────────┘
          │
          │          ┌────────────────────────────────────────────────────────┐
          │          │                 backups                                │
          │          ├────────────────────────────────────────────────────────┤
          │          │ id (PK, SERIAL)                                        │
          │          │ nome_arquivo (VARCHAR)                                 │
          │          │ caminho_arquivo (VARCHAR)                              │
          │          │ tamanho_bytes (BIGINT)                                 │
          │          │ tipo (VARCHAR, 'auto'|'manual')                        │
          │          │ status (VARCHAR, 'sucesso'|'falha')                    │
          │          │ erro_mensagem (TEXT)                                   │
          │          │ criado_em (TIMESTAMPTZ)                                │
          │          └────────────────────────────────────────────────────────┘
```

---

## 2. SQL DDL Completo

```sql
-- ============================================================
-- SCRIPT DE CRIAÇÃO DO BANCO DE DADOS
-- Sistema: OFS/OFS Feedback Comportamental — Security Dynamics
-- SGBD: PostgreSQL 16
-- Versão: MVP 1.0
-- ============================================================

-- Extensões
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID nativo
CREATE EXTENSION IF NOT EXISTS "pgcrypto";        -- gen_random_uuid()

-- ============================================================
-- TABELA 1: empresas
-- ============================================================
CREATE TABLE empresas (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(150) NOT NULL UNIQUE,
    status      BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE empresas IS 'Empresas observadas nos registros OFS/OFS';
COMMENT ON COLUMN empresas.id IS 'Identificador único (auto-incremento)';
COMMENT ON COLUMN empresas.nome IS 'Nome da empresa (único)';
COMMENT ON COLUMN empresas.status IS 'TRUE = ativa, FALSE = desativada';

-- ============================================================
-- TABELA 2: contratos
-- ============================================================
CREATE TABLE contratos (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(200) NOT NULL,
    descricao   TEXT,
    status      BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE contratos IS 'Contratos operacionais vinculados a áreas de atuação';

-- ============================================================
-- TABELA 3: locais
-- ============================================================
CREATE TABLE locais (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(200) NOT NULL,
    contrato_id INT NOT NULL REFERENCES contratos(id),
    status      BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE locais IS 'Locais ou áreas dentro dos contratos';

-- ============================================================
-- TABELA 4: usuarios
-- ============================================================
CREATE TABLE usuarios (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome            VARCHAR(200) NOT NULL,
    login           VARCHAR(100) NOT NULL UNIQUE,
    email           VARCHAR(200),
    senha_hash      VARCHAR(255) NOT NULL,
    empresa_id      INT REFERENCES empresas(id),
    contrato_id     INT REFERENCES contratos(id),
    perfil          VARCHAR(20) NOT NULL CHECK (perfil IN (
                        'Observador', 'Supervisor', 'Gestor', 'Admin'
                    )),
    status          BOOLEAN NOT NULL DEFAULT TRUE,
    tentativas_login INT NOT NULL DEFAULT 0,
    bloqueado_ate   TIMESTAMPTZ,
    ultimo_login    TIMESTAMPTZ,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE usuarios IS 'Usuários do sistema com login e perfil';
COMMENT ON COLUMN usuarios.perfil IS 'Observador | Supervisor | Gestor | Admin';
COMMENT ON COLUMN usuarios.empresa_id IS 'Empresa padrão do usuário (para filtro de escopo)';
COMMENT ON COLUMN usuarios.contrato_id IS 'Contrato padrão do usuário (para filtro de escopo)';

-- ============================================================
-- TABELA 5: metas_semanais
-- ============================================================
CREATE TABLE metas_semanais (
    id                  SERIAL PRIMARY KEY,
    contrato_id         INT NOT NULL REFERENCES contratos(id),
    ano                 INT NOT NULL,
    semana              INT NOT NULL CHECK (semana BETWEEN 1 AND 53),
    pessoas_ativas       INT NOT NULL DEFAULT 1 CHECK (pessoas_ativas >= 0),
    meta_ofc_por_pessoa  INT NOT NULL DEFAULT 5 CHECK (meta_ofc_por_pessoa >= 1),
    meta_ofc_programada  INT NOT NULL DEFAULT 0,
    usuarios_ativos      INT NOT NULL DEFAULT 1 CHECK (usuarios_ativos >= 0),
    criado_em            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (contrato_id, ano, semana)
);

COMMENT ON TABLE metas_semanais IS 'Metas semanais de OFS por contrato';
COMMENT ON COLUMN metas_semanais.semana IS 'Número da semana no ano (ISO 8601: 1 a 53)';
COMMENT ON COLUMN metas_semanais.meta_ofc_programada IS 'Calculado: pessoas_ativas × meta_ofc_por_pessoa';

-- ============================================================
-- TABELA 6: ofc_registros (TABELA PRINCIPAL)
-- ============================================================
CREATE TABLE ofc_registros (
    -- Identificação
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo                      SERIAL,

    -- Datas automáticas
    data_registro               DATE NOT NULL DEFAULT CURRENT_DATE,
    hora_registro               TIME NOT NULL DEFAULT CURRENT_TIME,
    semana                      INT NOT NULL CHECK (semana BETWEEN 1 AND 53),
    mes                         INT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    ano                         INT NOT NULL,

    -- Usuário gerador (snapshot para rastreabilidade)
    usuario_id                  UUID NOT NULL REFERENCES usuarios(id),
    usuario_nome_snapshot       VARCHAR(200) NOT NULL,
    usuario_email_snapshot      VARCHAR(200),
    usuario_perfil_snapshot     VARCHAR(20) NOT NULL,
    empresa_usuario_snapshot    VARCHAR(150),

    -- Contrato
    contrato_id                 INT REFERENCES contratos(id),

    -- Empresa observada
    empresa_observada_id        INT REFERENCES empresas(id),
    empresa_observada_outros    VARCHAR(150),

    -- Dados do observado
    nome_observado              VARCHAR(200) NOT NULL,
    atividade_observada         VARCHAR(300) NOT NULL,

    -- Local
    local_id                    INT REFERENCES locais(id),
    local_texto                 VARCHAR(200),

    -- Classificação
    turno                       VARCHAR(50) NOT NULL,
    tipo_observacao             VARCHAR(20) NOT NULL CHECK (tipo_observacao IN (
                                    'Positivo', 'Negativo'
                                )),

    -- Comportamento
    comportamento_observado     TEXT NOT NULL,
    observacao_complementar     TEXT,

    -- Status e rastreabilidade
    status_registro             VARCHAR(20) NOT NULL DEFAULT 'Gerado'
                                    CHECK (status_registro IN (
                                        'Gerado', 'Editado', 'Cancelado'
                                    )),

    criado_por                  UUID NOT NULL REFERENCES usuarios(id),
    criado_em                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    editado_por                 UUID REFERENCES usuarios(id),
    editado_em                  TIMESTAMPTZ,
    cancelado_por               UUID REFERENCES usuarios(id),
    cancelado_em                TIMESTAMPTZ,
    motivo_cancelamento         TEXT
);

COMMENT ON TABLE ofc_registros IS 'Registros de Observação de Feedback Comportamental';
COMMENT ON COLUMN ofc_registros.codigo IS 'Número sequencial visível (SERIAL)';
COMMENT ON COLUMN ofc_registros.semana IS 'Preenchido automaticamente via EXTRACT(WEEK FROM data_registro)';
COMMENT ON COLUMN ofc_registros.tipo_observacao IS 'Positivo = comportamento seguro, Negativo = comportamento inseguro';

-- ============================================================
-- TABELA 7: ofc_edicoes
-- ============================================================
CREATE TABLE ofc_edicoes (
    id              BIGSERIAL PRIMARY KEY,
    ofc_registro_id UUID NOT NULL REFERENCES ofc_registros(id) ON DELETE CASCADE,
    editado_por     UUID NOT NULL REFERENCES usuarios(id),
    campo_alterado  VARCHAR(100) NOT NULL,
    valor_anterior  TEXT,
    valor_novo      TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE ofc_edicoes IS 'Histórico de edições dos registros OFS/OFS';

-- ============================================================
-- TABELA 8: auditoria
-- ============================================================
CREATE TABLE auditoria (
    id              BIGSERIAL PRIMARY KEY,
    usuario_id      UUID REFERENCES usuarios(id),
    acao            VARCHAR(50) NOT NULL,
    entidade        VARCHAR(100) NOT NULL,
    entidade_id     VARCHAR(255),
    dados_anteriores JSONB,
    dados_novos      JSONB,
    ip_origem       VARCHAR(45),
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE auditoria IS 'Log de auditoria de todas as ações do sistema';
COMMENT ON COLUMN auditoria.acao IS 'LOGIN | LOGOUT | CRIAR_OFC | EDITAR_OFC | CANCELAR_OFC | GERAR_PDF | EXPORTAR_RELATORIO | ALTERAR_META | ALTERAR_USUARIO | RESTAURAR | CRIAR_USUARIO | etc.';

-- ============================================================
-- TABELA 9: relatorios_gerados
-- ============================================================
CREATE TABLE relatorios_gerados (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo            VARCHAR(50) NOT NULL CHECK (tipo IN ('individual', 'semanal', 'mensal')),
    parametros      JSONB NOT NULL,
    usuario_id      UUID NOT NULL REFERENCES usuarios(id),
    arquivo_path    VARCHAR(500),
    arquivo_tamanho BIGINT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE relatorios_gerados IS 'Histórico de PDFs e relatórios gerados';

-- ============================================================
-- TABELA 10: backups
-- ============================================================
CREATE TABLE backups (
    id              SERIAL PRIMARY KEY,
    nome_arquivo    VARCHAR(300) NOT NULL,
    caminho_arquivo VARCHAR(500) NOT NULL,
    tamanho_bytes   BIGINT,
    tipo            VARCHAR(20) NOT NULL DEFAULT 'auto' CHECK (tipo IN ('auto', 'manual')),
    status          VARCHAR(20) NOT NULL DEFAULT 'sucesso' CHECK (status IN ('sucesso', 'falha')),
    erro_mensagem   TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE backups IS 'Histórico de backups do banco de dados';

-- ============================================================
-- TABELA 11: tokens_revogados (JWT blacklist)
-- ============================================================
CREATE TABLE tokens_revogados (
    id          SERIAL PRIMARY KEY,
    jti         VARCHAR(255) NOT NULL UNIQUE,
    usuario_id  UUID NOT NULL REFERENCES usuarios(id),
    expira_em   TIMESTAMPTZ NOT NULL,
    revogado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE tokens_revogados IS 'Blacklist de refresh tokens JWT revogados';

-- ============================================================
-- TRIGGER: atualizar updated_at automaticamente
-- ============================================================
CREATE OR REPLACE FUNCTION atualizar_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_empresas_atualizar
    BEFORE UPDATE ON empresas
    FOR EACH ROW EXECUTE FUNCTION atualizar_timestamp();

CREATE TRIGGER trg_contratos_atualizar
    BEFORE UPDATE ON contratos
    FOR EACH ROW EXECUTE FUNCTION atualizar_timestamp();

CREATE TRIGGER trg_locais_atualizar
    BEFORE UPDATE ON locais
    FOR EACH ROW EXECUTE FUNCTION atualizar_timestamp();

CREATE TRIGGER trg_usuarios_atualizar
    BEFORE UPDATE ON usuarios
    FOR EACH ROW EXECUTE FUNCTION atualizar_timestamp();

CREATE TRIGGER trg_metas_atualizar
    BEFORE UPDATE ON metas_semanais
    FOR EACH ROW EXECUTE FUNCTION atualizar_timestamp();

-- ============================================================
-- TRIGGER: preencher meta_ofc_programada automaticamente
-- ============================================================
CREATE OR REPLACE FUNCTION calcular_meta_programada()
RETURNS TRIGGER AS $$
BEGIN
    NEW.meta_ofc_programada := NEW.pessoas_ativas * NEW.meta_ofc_por_pessoa;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_meta_programada
    BEFORE INSERT OR UPDATE OF pessoas_ativas, meta_ofc_por_pessoa ON metas_semanais
    FOR EACH ROW EXECUTE FUNCTION calcular_meta_programada();

-- ============================================================
-- TRIGGER: preencher semana, mes, ano automaticamente no OFS
-- ============================================================
CREATE OR REPLACE FUNCTION preencher_datas_ofc()
RETURNS TRIGGER AS $$
BEGIN
    NEW.semana := EXTRACT(WEEK FROM NEW.data_registro)::INT;
    NEW.mes    := EXTRACT(MONTH FROM NEW.data_registro)::INT;
    NEW.ano    := EXTRACT(YEAR FROM NEW.data_registro)::INT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ofc_datas
    BEFORE INSERT ON ofc_registros
    FOR EACH ROW EXECUTE FUNCTION preencher_datas_ofc();
```

---

## 3. Relacionamentos

### 3.1 Diagrama de Chaves Estrangeiras

```
usuarios.empresa_id          ──▶ empresas.id        (1:N, opcional)
usuarios.contrato_id         ──▶ contratos.id       (1:N, opcional)

locais.contrato_id           ──▶ contratos.id       (1:N, obrigatório)

metas_semanais.contrato_id   ──▶ contratos.id       (1:N, obrigatório)

ofc_registros.usuario_id     ──▶ usuarios.id        (1:N, obrigatório)
ofc_registros.contrato_id    ──▶ contratos.id       (1:N, opcional)
ofc_registros.empresa_observada_id ──▶ empresas.id  (1:N, opcional)
ofc_registros.local_id       ──▶ locais.id          (1:N, opcional)
ofc_registros.criado_por     ──▶ usuarios.id        (1:N, obrigatório)
ofc_registros.editado_por    ──▶ usuarios.id        (1:N, opcional)
ofc_registros.cancelado_por  ──▶ usuarios.id        (1:N, opcional)

ofc_edicoes.ofc_registro_id  ──▶ ofc_registros.id   (1:N, obrigatório, CASCADE)
ofc_edicoes.editado_por      ──▶ usuarios.id        (1:N, obrigatório)

auditoria.usuario_id         ──▶ usuarios.id        (1:N, opcional)

relatorios_gerados.usuario_id──▶ usuarios.id        (1:N, obrigatório)

tokens_revogados.usuario_id  ──▶ usuarios.id        (1:N, obrigatório)
```

### 3.2 Cardinalidades

| Relação | Tipo | Descrição |
|---------|------|-----------|
| empresa → usuarios | 1:N | Uma empresa tem muitos usuários |
| contrato → usuarios | 1:N | Um contrato tem muitos usuários |
| contrato → locais | 1:N | Um contrato tem muitos locais |
| contrato → metas_semanais | 1:N | Um contrato tem muitas metas (histórico) |
| usuario → ofc_registros (gerador) | 1:N | Um usuário gera muitos OFCs |
| empresa → ofc_registros (observada) | 1:N | Uma empresa é observada em muitos OFCs |
| contrato → ofc_registros | 1:N | Um contrato tem muitos OFCs |
| local → ofc_registros | 1:N | Um local tem muitos OFCs |
| ofc_registro → ofc_edicoes | 1:N | Um OFS pode ser editado várias vezes |

---

## 4. Índices Recomendados

```sql
-- ============================================================
-- ÍNDICES DE PERFORMANCE
-- ============================================================

-- ofc_registros — consultas por período (MAIS IMPORTANTE)
CREATE INDEX idx_ofc_data ON ofc_registros(data_registro DESC);
CREATE INDEX idx_ofc_semana ON ofc_registros(ano, semana);
CREATE INDEX idx_ofc_mes ON ofc_registros(ano, mes);
CREATE INDEX idx_ofc_data_empresa ON ofc_registros(data_registro, empresa_observada_id);

-- ofc_registros — filtros da consulta avançada
CREATE INDEX idx_ofc_empresa ON ofc_registros(empresa_observada_id);
CREATE INDEX idx_ofc_contrato ON ofc_registros(contrato_id);
CREATE INDEX idx_ofc_local ON ofc_registros(local_id);
CREATE INDEX idx_ofc_turno ON ofc_registros(turno);
CREATE INDEX idx_ofc_tipo ON ofc_registros(tipo_observacao);
CREATE INDEX idx_ofc_status ON ofc_registros(status_registro);
CREATE INDEX idx_ofc_usuario ON ofc_registros(usuario_id);

-- ofc_registros — métricas (índice composto mais usado)
CREATE INDEX idx_ofc_metricas ON ofc_registros(
    contrato_id, data_registro, tipo_observacao, status_registro
);

-- ofc_registros — full-text search para busca textual
CREATE INDEX idx_ofc_busca_textual ON ofc_registros USING GIN(
    to_tsvector('portuguese',
        COALESCE(nome_observado, '') || ' ' ||
        COALESCE(comportamento_observado, '') || ' ' ||
        COALESCE(observacao_complementar, '') || ' ' ||
        COALESCE(atividade_observada, '') || ' ' ||
        COALESCE(local_texto, '')
    )
);

-- ofc_registros — busca por código (nº OFS)
CREATE INDEX idx_ofc_codigo ON ofc_registros(codigo);

-- usuarios — login e perfil
CREATE INDEX idx_usuarios_login ON usuarios(login);
CREATE INDEX idx_usuarios_perfil ON usuarios(perfil);
CREATE INDEX idx_usuarios_empresa ON usuarios(empresa_id);
CREATE INDEX idx_usuarios_contrato ON usuarios(contrato_id);

-- locais — por contrato
CREATE INDEX idx_locais_contrato ON locais(contrato_id);

-- metas_semanais — busca vigente
CREATE INDEX idx_metas_contrato_semana ON metas_semanais(contrato_id, ano DESC, semana DESC);

-- ofc_edicoes — histórico de um OFS
CREATE INDEX idx_edicoes_ofc ON ofc_edicoes(ofc_registro_id, criado_em DESC);

-- auditoria — consultas por usuário e data
CREATE INDEX idx_auditoria_ts ON auditoria(criado_em DESC);
CREATE INDEX idx_auditoria_usuario ON auditoria(usuario_id, criado_em DESC);
CREATE INDEX idx_auditoria_acao ON auditoria(acao);
CREATE INDEX idx_auditoria_entidade ON auditoria(entidade, entidade_id);

-- tokens — limpeza de expirados
CREATE INDEX idx_tokens_expira ON tokens_revogados(expira_em) WHERE expira_em < NOW();
```

---

## 5. Regras de Validação

### 5.1 Validações no Frontend (antes do submit)

| Campo | Regra |
|-------|-------|
| `login` | Mínimo 3 caracteres, sem espaços, lowercase |
| `senha` | Mínimo 8 caracteres, 1 maiúscula, 1 minúscula, 1 número |
| `nome` | Mínimo 3 caracteres, apenas letras e espaços |
| `email` | Formato email válido (regex) |
| `empresa_observada_id` | Obrigatório. Se NULL e `empresa_observada_outros` vazio → erro |
| `empresa_observada_outros` | Obrigatório SE `empresa_observada_id` corresponde a "Outros" |
| `nome_observado` | Mínimo 3 caracteres, obrigatório |
| `atividade_observada` | Mínimo 5 caracteres, obrigatório |
| `turno` | Obrigatório, deve estar na lista |
| `tipo_observacao` | Obrigatório, apenas "Positivo" ou "Negativo" |
| `comportamento_observado` | Mínimo 5 caracteres, obrigatório |
| `data_registro` | Não pode ser data futura |
| `pessoas_ativas` | >= 0, obrigatório |
| `meta_ofc_por_pessoa` | >= 1, obrigatório |

### 5.2 Validações no Backend (Pydantic / ZOD)

```python
# Exemplo Pydantic v2 (FastAPI)

from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Optional
from datetime import date, time, datetime

class OfcCreateRequest(BaseModel):
    data_registro: date = Field(default_factory=date.today)
    hora_registro: time = Field(default_factory=lambda: datetime.now().time())
    contrato_id: Optional[int] = None
    empresa_observada_id: Optional[int] = None
    empresa_observada_outros: Optional[str] = Field(None, max_length=150)
    nome_observado: str = Field(..., min_length=3, max_length=200)
    atividade_observada: str = Field(..., min_length=5, max_length=300)
    local_id: Optional[int] = None
    local_texto: Optional[str] = Field(None, max_length=200)
    turno: str = Field(..., min_length=1, max_length=50)
    tipo_observacao: str = Field(..., pattern=r'^(Positivo|Negativo)$')
    comportamento_observado: str = Field(..., min_length=5)
    observacao_complementar: Optional[str] = None

    @field_validator('data_registro')
    @classmethod
    def nao_pode_ser_futura(cls, v: date) -> date:
        if v > date.today():
            raise ValueError('Data de registro não pode ser futura')
        return v

    @model_validator(mode='after')
    def validar_empresa_outros(self):
        if self.empresa_observada_id is None:
            if not self.empresa_observada_outros or not self.empresa_observada_outros.strip():
                raise ValueError(
                    'Campo "empresa_observada_outros" é obrigatório quando '
                    'nenhuma empresa da lista é selecionada (Outros)'
                )
        return self

class MetaSemanalCreateRequest(BaseModel):
    contrato_id: int
    ano: int = Field(..., ge=2024, le=2100)
    semana: int = Field(..., ge=1, le=53)
    pessoas_ativas: int = Field(..., ge=0)
    meta_ofc_por_pessoa: int = Field(..., ge=1)
    usuarios_ativos: int = Field(..., ge=0)

class UsuarioCreateRequest(BaseModel):
    nome: str = Field(..., min_length=3, max_length=200)
    login: str = Field(..., min_length=3, max_length=100, pattern=r'^[a-z0-9._]+$')
    email: Optional[str] = Field(None, pattern=r'^[^@]+@[^@]+\.[^@]+$')
    senha: str = Field(..., min_length=8)
    empresa_id: Optional[int] = None
    contrato_id: Optional[int] = None
    perfil: str = Field(..., pattern=r'^(Observador|Supervisor|Gestor|Admin)$')
```

### 5.3 Validações de Negócio (Service Layer)

```python
# Regras que exigem contexto do banco

async def validar_edicao_ofc(OFS, usuario, db):
    """Valida se o usuário pode editar este OFS"""
    
    # Admin e Gestor: sempre podem
    if usuario.perfil in ('Admin', 'Gestor'):
        return True
    
    # Supervisor: apenas se for do mesmo contrato
    if usuario.perfil == 'Supervisor':
        if OFS.contrato_id != usuario.contrato_id:
            raise ForbiddenException('Você só pode editar registros do seu contrato')
        diferenca = datetime.now(timezone.utc) - OFS.criado_em
        if diferenca > timedelta(hours=48):
            raise BusinessRuleException('Prazo de 48h para edição expirado')
        return True
    
    # Observador: apenas seus registros, até 24h
    if usuario.perfil == 'Observador':
        if OFS.usuario_id != usuario.id:
            raise ForbiddenException('Você só pode editar seus próprios registros')
        diferenca = datetime.now(timezone.utc) - OFS.criado_em
        if diferenca > timedelta(hours=24):
            raise BusinessRuleException('Prazo de 24h para edição expirado')
        return True
    
    return False

async def validar_cancelamento_ofc(usuario):
    """Apenas Admin e Gestor podem cancelar"""
    if usuario.perfil not in ('Admin', 'Gestor'):
        raise ForbiddenException('Apenas Admin e Gestor podem cancelar registros')
    return True

def validar_status_metrica(aderencia: float) -> str:
    """Determina o status com base na aderência"""
    if aderencia >= 100:
        return 'OK'
    elif aderencia >= 80:
        return 'ATENÇÃO'
    else:
        return 'ALERTA'
```

---

## 6. Endpoints Detalhados

### 6.1 Autenticação — `/api/auth`

| Método | Path | Auth | Descrição |
|--------|------|:---:|-----------|
| `POST` | `/api/auth/login` | 🔓 | Login com credenciais |
| `POST` | `/api/auth/logout` | 🔐 | Revogar refresh token |
| `GET` | `/api/auth/me` | 🔐 | Dados do usuário logado |

---

### 6.2 Usuários — `/api/usuarios`

| Método | Path | Permissão | Query Params |
|--------|------|:---:|-------------|
| `GET` | `/api/usuarios` | Admin, Gestor | `?perfil=&empresa_id=&status=&page=&limit=` |
| `GET` | `/api/usuarios/:id` | Admin, Gestor | — |
| `POST` | `/api/usuarios` | Admin | Body: `UsuarioCreateRequest` |
| `PUT` | `/api/usuarios/:id` | Admin | Body: `UsuarioUpdateRequest` |
| `PATCH` | `/api/usuarios/:id/status` | Admin | Body: `{ "status": true\|false }` |

---

### 6.3 Empresas — `/api/empresas`

| Método | Path | Permissão | Descrição |
|--------|------|:---:|-----------|
| `GET` | `/api/empresas` | 🔐 | Lista todas ativas (dropdown). Admin vê inativas também |
| `POST` | `/api/empresas` | Admin | Criar nova empresa |
| `PUT` | `/api/empresas/:id` | Admin | Editar nome |
| `PATCH` | `/api/empresas/:id/status` | Admin | Ativar/desativar |

---

### 6.4 Contratos — `/api/contratos`

| Método | Path | Permissão | Descrição |
|--------|------|:---:|-----------|
| `GET` | `/api/contratos` | 🔐 | Lista contratos ativos |
| `POST` | `/api/contratos` | Admin | Criar contrato |
| `PUT` | `/api/contratos/:id` | Admin | Editar contrato |
| `PATCH` | `/api/contratos/:id/status` | Admin | Ativar/desativar |

---

### 6.5 Locais — `/api/locais`

| Método | Path | Permissão | Query Params |
|--------|------|:---:|-------------|
| `GET` | `/api/locais` | 🔐 | `?contrato_id=&status=` |
| `POST` | `/api/locais` | Admin | Body: `{ nome, contrato_id }` |
| `PUT` | `/api/locais/:id` | Admin | Body: `{ nome }` |
| `PATCH` | `/api/locais/:id/status` | Admin | Ativar/desativar |

---

### 6.6 Metas — `/api/metas-semanais`

| Método | Path | Permissão | Descrição |
|--------|------|:---:|-----------|
| `GET` | `/api/metas-semanais` | 🔐 | `?contrato_id=&ano=&semana=` |
| `POST` | `/api/metas-semanais` | Admin, Gestor | Criar/atualizar meta (UPSERT por unique) |
| `PUT` | `/api/metas-semanais/:id` | Admin, Gestor | Editar meta existente |
| `GET` | `/api/metas-semanais/vigente` | 🔐 | Meta da semana atual `?contrato_id=` |

---

### 6.7 OFS/OFS — `/api/OFS` (PRINCIPAL)

| Método | Path | Permissão | Descrição |
|--------|------|:---:|-----------|
| `POST` | `/api/OFS` | Observador+ | Criar novo registro OFS/OFS |
| `GET` | `/api/OFS` | 🔐 + escopo | Listar com filtros e paginação |
| `GET` | `/api/OFS/:id` | 🔐 + escopo | Detalhe completo + edições |
| `PUT` | `/api/OFS/:id` | 🔐 + regras | Editar registro |
| `PATCH` | `/api/OFS/:id/cancelar` | Admin, Gestor | Cancelar `{ motivo_cancelamento }` |
| `GET` | `/api/OFS/:id/pdf` | 🔐 + escopo | Gerar PDF individual |

**Parâmetros de listagem (GET /api/OFS):**

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `codigo` | int | Nº do OFS |
| `data_inicio` | date | Data inicial do período |
| `data_fim` | date | Data final do período |
| `semana` | int | Nº da semana (1-53) |
| `mes` | int | Mês (1-12) |
| `ano` | int | Ano |
| `usuario_id` | UUID | Usuário gerador |
| `empresa_observada_id` | int | Empresa observada |
| `contrato_id` | int | Contrato |
| `local_id` | int | Local |
| `turno` | string | Turno |
| `tipo_observacao` | string | Positivo / Negativo |
| `status_registro` | string | Gerado / Editado / Cancelado |
| `busca` | string | Busca textual (full-text search) |
| `page` | int | Página (default 1) |
| `limit` | int | Itens por página (default 25) |
| `order_by` | string | Campo de ordenação |
| `order_dir` | string | asc / desc |

---

### 6.8 Métricas — `/api/metricas`

| Método | Path | Permissão | Descrição |
|--------|------|:---:|-----------|
| `GET` | `/api/metricas/semana` | Supervisor+ | Métricas da semana `?ano=&semana=&contrato_id=` |
| `GET` | `/api/metricas/mes` | Supervisor+ | Métricas do mês `?ano=&mes=&contrato_id=` |
| `GET` | `/api/metricas/ranking-empresas` | Gestor+ | Ranking por empresa `?ano=&semana=` |
| `GET` | `/api/metricas/ranking-usuarios` | Supervisor+ | Ranking por usuário `?ano=&semana=&contrato_id=` |
| `GET` | `/api/metricas/evolucao` | Gestor+ | Evolução semanal `?semanas=8&contrato_id=` |

---

### 6.9 Relatórios — `/api/relatorios`

| Método | Path | Permissão | Descrição |
|--------|------|:---:|-----------|
| `GET` | `/api/relatorios/semana/pdf` | Gestor+ | Download PDF semanal `?ano=&semana=&contrato_id=` |
| `GET` | `/api/relatorios/mes/pdf` | Gestor+ | Download PDF mensal `?ano=&mes=&contrato_id=` |
| `GET` | `/api/relatorios/semana/excel` | Gestor+ | Exportar Excel `?ano=&semana=&contrato_id=` (Fase 2) |

---

### 6.10 Auditoria — `/api/auditoria`

| Método | Path | Permissão | Descrição |
|--------|------|:---:|-----------|
| `GET` | `/api/auditoria` | Admin | Listar logs `?usuario_id=&acao=&entidade=&data_inicio=&data_fim=&page=&limit=` |

---

## 7. Payloads de Exemplo — OFS/OFS

### 7.1 Criar OFS/OFS

**Request:**
```
POST /api/OFS
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

```json
{
  "data_registro": "2026-05-13",
  "hora_registro": "14:30:00",
  "contrato_id": 1,
  "empresa_observada_id": 1,
  "empresa_observada_outros": null,
  "nome_observado": "João Silva Santos",
  "atividade_observada": "Operação de empilhadeira no armazém B",
  "local_id": 3,
  "local_texto": null,
  "turno": "Diurno",
  "tipo_observacao": "Positivo",
  "comportamento_observado": "Uso correto de todos os EPIs obrigatórios: capacete, luva, bota e colete. Verificou área antes de iniciar operação.",
  "observacao_complementar": "Operador demonstrou atenção redobrada aos procedimentos de segurança"
}
```

**Response 201:**
```json
{
  "sucesso": true,
  "dados": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "codigo": 1523,
    "data_registro": "2026-05-13",
    "hora_registro": "14:30:00",
    "semana": 20,
    "mes": 5,
    "ano": 2026,
    "usuario_id": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "usuario_nome_snapshot": "Carlos Henrique Oliveira",
    "usuario_email_snapshot": "carlos.oliveira@securitydynamics.com.br",
    "usuario_perfil_snapshot": "Supervisor",
    "empresa_usuario_snapshot": "Security Dynamics",
    "contrato_id": 1,
    "empresa_observada_id": 1,
    "empresa_observada_outros": null,
    "nome_observado": "João Silva Santos",
    "atividade_observada": "Operação de empilhadeira no armazém B",
    "local_id": 3,
    "local_texto": null,
    "turno": "Diurno",
    "tipo_observacao": "Positivo",
    "comportamento_observado": "Uso correto de todos os EPIs obrigatórios...",
    "observacao_complementar": "Operador demonstrou atenção redobrada...",
    "status_registro": "Gerado",
    "criado_por": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "criado_em": "2026-05-13T14:30:05-03:00",
    "editado_por": null,
    "editado_em": null,
    "cancelado_por": null,
    "cancelado_em": null,
    "motivo_cancelamento": null
  }
}
```

### 7.2 Criar OFS com Empresa "Outros"

**Request:**
```json
{
  "data_registro": "2026-05-13",
  "hora_registro": "09:15:00",
  "contrato_id": 2,
  "empresa_observada_id": null,
  "empresa_observada_outros": "Transportadora Rápida Ltda",
  "nome_observado": "Maria Aparecida",
  "atividade_observada": "Carregamento de contêineres",
  "local_id": 7,
  "turno": "Noturno",
  "tipo_observacao": "Negativo",
  "comportamento_observado": "Ausência de cinto de segurança durante operação em altura",
  "observacao_complementar": "Foi orientada imediatamente e retomou com o EPI"
}
```

**Response 422 (se faltar empresa_observada_outros):**
```json
{
  "sucesso": false,
  "erro": {
    "codigo": "VALIDACAO",
    "mensagem": "Campo 'empresa_observada_outros' é obrigatório quando nenhuma empresa da lista é selecionada",
    "detalhes": [
      {
        "campo": "empresa_observada_outros",
        "erro": "Campo obrigatório para 'Outros'"
      }
    ]
  }
}
```

### 7.3 Editar OFS/OFS

**Request:**
```
PUT /api/OFS/a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

```json
{
  "comportamento_observado": "Uso correto de todos os EPIs obrigatórios: capacete, luva, bota, colete e protetor auricular. Verificou área antes de iniciar operação.",
  "observacao_complementar": "Operador demonstrou atenção redobrada. Incluiu verificação de protetor auricular."
}
```

**Response 200:**
```json
{
  "sucesso": true,
  "dados": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "codigo": 1523,
    "status_registro": "Editado",
    "editado_por": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
    "editado_em": "2026-05-13T16:45:00-03:00",
    "edicoes": [
      {
        "campo_alterado": "comportamento_observado",
        "valor_anterior": "Uso correto de todos os EPIs obrigatórios...",
        "valor_novo": "Uso correto de todos os EPIs obrigatórios: capacete, luva, bota, colete e protetor auricular...",
        "editado_por": "Carlos Henrique Oliveira",
        "editado_em": "2026-05-13T16:45:00-03:00"
      },
      {
        "campo_alterado": "observacao_complementar",
        "valor_anterior": "Operador demonstrou atenção redobrada...",
        "valor_novo": "Operador demonstrou atenção redobrada. Incluiu verificação de protetor auricular.",
        "editado_por": "Carlos Henrique Oliveira",
        "editado_em": "2026-05-13T16:45:00-03:00"
      }
    ]
  }
}
```

### 7.4 Cancelar OFS/OFS

**Request:**
```
PATCH /api/OFS/a1b2c3d4-e5f6-7890-abcd-ef1234567890/cancelar
```

```json
{
  "motivo_cancelamento": "Registro duplicado — OFS já havia sido criado pelo usuário Pedro Costa"
}
```

**Response 200:**
```json
{
  "sucesso": true,
  "dados": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "codigo": 1523,
    "status_registro": "Cancelado",
    "cancelado_por": "g9h8i7j6-k5l4-3210-mnop-qrstuv987654",
    "cancelado_em": "2026-05-13T17:00:00-03:00",
    "motivo_cancelamento": "Registro duplicado — OFS já havia sido criado pelo usuário Pedro Costa"
  }
}
```

### 7.5 Consultar OFS (com filtros)

**Request:**
```
GET /api/OFS?data_inicio=2026-05-01&data_fim=2026-05-31&empresa_observada_id=1&tipo_observacao=Positivo&page=1&limit=25
```

**Response 200:**
```json
{
  "sucesso": true,
  "dados": [
    {
      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "codigo": 1523,
      "data_registro": "2026-05-13",
      "hora_registro": "14:30:00",
      "nome_observado": "João Silva Santos",
      "empresa_observada_id": 1,
      "empresa_nome": "Security Dynamics",
      "turno": "Diurno",
      "tipo_observacao": "Positivo",
      "status_registro": "Gerado",
      "usuario_nome_snapshot": "Carlos Henrique Oliveira",
      "criado_em": "2026-05-13T14:30:05-03:00"
    }
  ],
  "paginacao": {
    "pagina": 1,
    "limite": 25,
    "total_itens": 47,
    "total_paginas": 2
  }
}
```

---

## 8. Payloads de Exemplo — Métricas

### 8.1 Métricas da Semana

**Request:**
```
GET /api/metricas/semana?ano=2026&semana=20&contrato_id=1
```

**Response 200:**
```json
{
  "sucesso": true,
  "dados": {
    "periodo": {
      "ano": 2026,
      "semana": 20,
      "data_inicio": "2026-05-11",
      "data_fim": "2026-05-17"
    },
    "contrato": {
      "id": 1,
      "nome": "Operação Security Dynamics"
    },
    "meta": {
      "id": 1,
      "pessoas_ativas": 150,
      "meta_ofc_por_pessoa": 5,
      "meta_ofc_programada": 750,
      "usuarios_ativos_esperados": 10
    },
    "indicadores": {
      "pessoas_ativas": 150,
      "ofc_programadas": 750,
      "ofc_realizadas": 645,
      "aderencia_percentual": 86.0,
      "positivas": 520,
      "negativas": 125,
      "percentual_seguro": 80.6,
      "percentual_desvio": 19.4,
      "usuarios_ativos": 9,
      "media_ofc_por_usuario": 71.7
    },
    "status": "ATENÇÃO",
    "status_cor": "amarelo",
    "status_descricao": "Aderência entre 80% e 99% — atenção necessária",
    "distribuicao_por_turno": {
      "Diurno": 280,
      "Noturno": 210,
      "Misto": 155
    },
    "distribuicao_por_empresa": [
      { "empresa_id": 1, "empresa_nome": "Security Dynamics", "total": 645 }
    ]
  }
}
```

### 8.2 Evolução Semanal

**Request:**
```
GET /api/metricas/evolucao?semanas=8&contrato_id=1
```

**Response 200:**
```json
{
  "sucesso": true,
  "dados": {
    "contrato_id": 1,
    "evolucao": [
      {
        "ano": 2026, "semana": 13,
        "programadas": 750, "realizadas": 720,
        "aderencia_percentual": 96.0, "status": "ATENÇÃO"
      },
      {
        "ano": 2026, "semana": 14,
        "programadas": 750, "realizadas": 755,
        "aderencia_percentual": 100.7, "status": "OK"
      },
      {
        "ano": 2026, "semana": 15,
        "programadas": 800, "realizadas": 810,
        "aderencia_percentual": 101.3, "status": "OK"
      },
      {
        "ano": 2026, "semana": 16,
        "programadas": 800, "realizadas": 700,
        "aderencia_percentual": 87.5, "status": "ATENÇÃO"
      },
      {
        "ano": 2026, "semana": 17,
        "programadas": 800, "realizadas": 680,
        "aderencia_percentual": 85.0, "status": "ATENÇÃO"
      },
      {
        "ano": 2026, "semana": 18,
        "programadas": 750, "realizadas": 690,
        "aderencia_percentual": 92.0, "status": "ATENÇÃO"
      },
      {
        "ano": 2026, "semana": 19,
        "programadas": 750, "realizadas": 710,
        "aderencia_percentual": 94.7, "status": "ATENÇÃO"
      },
      {
        "ano": 2026, "semana": 20,
        "programadas": 750, "realizadas": 645,
        "aderencia_percentual": 86.0, "status": "ATENÇÃO"
      }
    ],
    "tendencia": {
      "direcao": "queda",
      "variacao_percentual": -8.7,
      "periodo_comparacao": "últimas 4 semanas vs 4 semanas anteriores"
    }
  }
}
```

### 8.3 Ranking de Empresas

**Request:**
```
GET /api/metricas/ranking-empresas?ano=2026&semana=20
```

**Response 200:**
```json
{
  "sucesso": true,
  "dados": {
    "ranking": [
      { "posicao": 1, "empresa": "Security Dynamics", "aderencia_percentual": 98.0, "status": "ATENÇÃO" },
      { "posicao": 2, "empresa": "G4S", "aderencia_percentual": 95.5, "status": "ATENÇÃO" },
      { "posicao": 3, "empresa": "ERA", "aderencia_percentual": 102.0, "status": "OK" },
      { "posicao": 4, "empresa": "Polo Norte", "aderencia_percentual": 78.5, "status": "ALERTA" },
      { "posicao": 5, "empresa": "Sodexo", "aderencia_percentual": 88.0, "status": "ATENÇÃO" }
    ]
  }
}
```

---

## 9. Regras de Permissão por Endpoint

### 9.1 Matriz Completa

| Endpoint | Observador | Supervisor | Gestor | Admin |
|----------|:---:|:---:|:---:|:---:|
| `POST /auth/login` | ✅ | ✅ | ✅ | ✅ |
| `POST /auth/logout` | ✅ | ✅ | ✅ | ✅ |
| `GET /auth/me` | ✅ | ✅ | ✅ | ✅ |
| | | | | |
| `GET /usuarios` | ❌ | ❌ | 🔸 | ✅ |
| `GET /usuarios/:id` | ❌ | ❌ | 🔸 | ✅ |
| `POST /usuarios` | ❌ | ❌ | ❌ | ✅ |
| `PUT /usuarios/:id` | ❌ | ❌ | ❌ | ✅ |
| `PATCH /usuarios/:id/status` | ❌ | ❌ | ❌ | ✅ |
| | | | | |
| `GET /empresas` | ✅ | ✅ | ✅ | ✅ |
| `POST /empresas` | ❌ | ❌ | ❌ | ✅ |
| `PUT /empresas/:id` | ❌ | ❌ | ❌ | ✅ |
| `PATCH /empresas/:id/status` | ❌ | ❌ | ❌ | ✅ |
| | | | | |
| `GET /contratos` | ✅ | ✅ | ✅ | ✅ |
| `POST /contratos` | ❌ | ❌ | ❌ | ✅ |
| `PUT /contratos/:id` | ❌ | ❌ | ❌ | ✅ |
| `PATCH /contratos/:id/status` | ❌ | ❌ | ❌ | ✅ |
| | | | | |
| `GET /locais` | ✅ | ✅ | ✅ | ✅ |
| `POST /locais` | ❌ | ❌ | ❌ | ✅ |
| `PUT /locais/:id` | ❌ | ❌ | ❌ | ✅ |
| | | | | |
| `GET /metas-semanais` | ❌ | ✅ | ✅ | ✅ |
| `POST /metas-semanais` | ❌ | ❌ | ✅ | ✅ |
| `PUT /metas-semanais/:id` | ❌ | ❌ | ✅ | ✅ |
| `GET /metas-semanais/vigente` | ❌ | ✅ | ✅ | ✅ |
| | | | | |
| `POST /OFS` | ✅ | ✅ | ✅ | ✅ |
| `GET /OFS` (filtros) | 🔹 | 🔸 | ✅ | ✅ |
| `GET /OFS/:id` | 🔹 | 🔸 | ✅ | ✅ |
| `PUT /OFS/:id` | 🔹⏱ | 🔸⏱ | ✅ | ✅ |
| `PATCH /OFS/:id/cancelar` | ❌ | ❌ | ✅ | ✅ |
| `GET /OFS/:id/pdf` | 🔹 | 🔸 | ✅ | ✅ |
| | | | | |
| `GET /metricas/semana` | ❌ | 🔸 | ✅ | ✅ |
| `GET /metricas/mes` | ❌ | 🔸 | ✅ | ✅ |
| `GET /metricas/ranking-empresas` | ❌ | ❌ | ✅ | ✅ |
| `GET /metricas/ranking-usuarios` | ❌ | 🔸 | ✅ | ✅ |
| `GET /metricas/evolucao` | ❌ | ❌ | ✅ | ✅ |
| | | | | |
| `GET /relatorios/semana/pdf` | ❌ | ❌ | ✅ | ✅ |
| `GET /relatorios/mes/pdf` | ❌ | ❌ | ✅ | ✅ |
| | | | | |
| `GET /auditoria` | ❌ | ❌ | ❌ | ✅ |

### 9.2 Legenda

| Símbolo | Significado |
|:---:|---|
| ✅ | Acesso total |
| 🔹 | Apenas registros próprios (Observador vê só o que criou) |
| 🔸 | Apenas registros do contrato/empresa (Supervisor escopo por contrato, Gestor escopo por empresa) |
| 🔹⏱ | Apenas seus registros + janela de 24h |
| 🔸⏱ | Apenas contrato + janela de 48h |
| ❌ | Sem acesso |

### 9.3 Implementação do Data Scoping

```python
# permissions.py — dependências FastAPI

async def aplicar_escopo_ofc(query, usuario: Usuario):
    """
    Aplica filtro de visibilidade na query de OFS conforme perfil.
    """
    if usuario.perfil == 'Admin':
        return query  # Vê tudo
    
    if usuario.perfil == 'Gestor':
        # Vê tudo, sem restrição de escopo
        return query
    
    if usuario.perfil == 'Supervisor':
        # Vê apenas registros do contrato
        if usuario.contrato_id:
            return query.where(ofc_registros.c.contrato_id == usuario.contrato_id)
        # Se não tem contrato vinculado, vê da empresa
        if usuario.empresa_id:
            return query.where(ofc_registros.c.empresa_usuario_snapshot == 
                select(empresas.c.nome).where(empresas.c.id == usuario.empresa_id).scalar_subquery())
        return query.where(ofc_registros.c.usuario_id == usuario.id)
    
    if usuario.perfil == 'Observador':
        # Vê apenas seus registros
        return query.where(ofc_registros.c.usuario_id == usuario.id)
    
    return query.where(False)  # Fallback: nada
```

---

## 10. Recomendações de Segurança

### 10.1 Senhas e Autenticação

| Configuração | Valor |
|-------------|-------|
| Algoritmo hash | bcrypt (cost factor 12) |
| Access Token | JWT HS256, 15 minutos |
| Refresh Token | JWT HS256, 7 dias |
| JWT Secret | Mínimo 256 bits (32 caracteres), via env var |
| Bloqueio por tentativas | 5 falhas → 30 minutos |
| Histórico de senhas | Não permitir reuso das últimas 5 |
| Logout | Revoga refresh token (blacklist na tabela `tokens_revogados`) |

### 10.2 Proteções

| Vulnerabilidade | Proteção |
|----------------|----------|
| SQL Injection | ORM (SQLAlchemy) com bind parameters. Nunca concatenar strings SQL. |
| XSS | React auto-escaping + `Content-Security-Policy: default-src 'self'` |
| CSRF | API REST usa header `Authorization: Bearer`. Sem cookies para auth. |
| IDOR | Data scoping aplicado em todas as queries. Usuário nunca acessa dados de outro. |
| Rate Limiting | 100 req/min por IP (slowapi middleware) |
| Security Headers | `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `X-XSS-Protection: 1; mode=block` |
| Secrets em código | NUNCA. Tudo via variáveis de ambiente. |

### 10.3 Checklist de Segurança no Código

```python
# ✅ CORRETO — bind parameters
query = select(ofc_registros).where(ofc_registros.c.codigo == codigo)

# ❌ ERRADO — concatenação SQL
query = f"SELECT * FROM ofc_registros WHERE codigo = {codigo}"

# ✅ CORRETO — hash de senha
senha_hash = bcrypt.hash(senha, rounds=12)

# ❌ ERRADO — senha em plain text ou MD5
senha_hash = hashlib.md5(senha.encode()).hexdigest()

# ✅ CORRETO — JWT secret do ambiente
SECRET_KEY = os.environ["JWT_SECRET"]

# ❌ ERRADO — secret hardcoded
SECRET_KEY = "minha-chave-secreta-123"
```

### 10.4 Hardening do Docker

```yaml
# docker-compose.yml (trechos de segurança)
services:
  backend:
    read_only: true             # Sistema de arquivos somente leitura
    security_opt:
      - no-new-privileges:true  # Impede escalação de privilégios
    cap_drop:
      - ALL                     # Remove todas as capabilities
    cap_add:
      - NET_BIND_SERVICE        # Apenas necessária para bind da porta
    
  db:
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}  # Via env var, nunca hardcoded
    volumes:
      - pgdata:/var/lib/postgresql/data
```

---

## 11. Estratégia de Auditoria

### 11.1 Eventos Registrados

| Ação | Entidade | Severidade | Dados em `dados_novos` (JSONB) |
|------|----------|:---:|---|
| `LOGIN` | `usuarios` | INFO | `{ "sucesso": true, "nome": "..." }` |
| `LOGIN_FALHA` | `usuarios` | WARNING | `{ "sucesso": false, "login": "...", "tentativa": 3 }` |
| `LOGOUT` | `usuarios` | INFO | `{ "nome": "..." }` |
| `CRIAR_OFC` | `ofc_registros` | INFO | `{ "codigo": 1523, "tipo": "Positivo", "empresa": "..." }` |
| `EDITAR_OFC` | `ofc_registros` | WARNING | `{ "codigo": 1523, "campos": ["comportamento"], "alterado_por": "..." }` |
| `CANCELAR_OFC` | `ofc_registros` | WARNING | `{ "codigo": 1523, "motivo": "..." }` |
| `RESTAURAR_OFC` | `ofc_registros` | CRITICAL | `{ "codigo": 1523, "restaurado_por": "..." }` |
| `GERAR_PDF` | `relatorios_gerados` | INFO | `{ "tipo": "individual", "ofc_codigo": 1523 }` |
| `GERAR_PDF_SEMANA` | `relatorios_gerados` | INFO | `{ "tipo": "semanal", "semana": 20, "contrato": 1 }` |
| `EXPORTAR_RELATORIO` | `relatorios_gerados` | INFO | `{ "formato": "pdf", "tipo": "semanal" }` |
| `ALTERAR_META` | `metas_semanais` | WARNING | `{ "meta_id": 1, "antes": {...}, "depois": {...} }` |
| `CRIAR_USUARIO` | `usuarios` | WARNING | `{ "login": "novo.user", "perfil": "Observador", "criado_por": "admin" }` |
| `ALTERAR_USUARIO` | `usuarios` | WARNING | `{ "usuario_id": "...", "alterado_por": "admin", "campos": ["perfil"] }` |
| `DESATIVAR_USUARIO` | `usuarios` | WARNING | `{ "usuario_id": "...", "desativado_por": "admin" }` |
| `BACKUP_MANUAL` | `backups` | INFO | `{ "arquivo": "backup_20260513_150000.dump" }` |
| `RESTAURAR_BACKUP` | `backups` | CRITICAL | `{ "backup_id": 1, "restaurado_por": "admin" }` |
| `ACESSO_NEGADO` | `sistema` | WARNING | `{ "recurso": "/admin", "perfil": "Observador" }` |

### 11.2 Implementação (Decorator/Middleware no FastAPI)

```python
# audit_service.py

async def registrar_auditoria(
    db: AsyncSession,
    usuario_id: UUID | None,
    acao: str,
    entidade: str,
    entidade_id: str | None = None,
    dados_anteriores: dict | None = None,
    dados_novos: dict | None = None,
    ip_origem: str | None = None
):
    log = Auditoria(
        usuario_id=usuario_id,
        acao=acao,
        entidade=entidade,
        entidade_id=entidade_id,
        dados_anteriores=dados_anteriores,
        dados_novos=dados_novos,
        ip_origem=ip_origem,
    )
    db.add(log)
    # NÃO aguarda commit — a transação principal fará o commit
    # Isso evita que o log fique órfão se a operação falhar

# Uso no endpoint:
@router.post("/api/OFS")
async def criar_ofc(
    data: OfcCreateRequest,
    db: AsyncSession = Depends(get_db),
    usuario: Usuario = Depends(get_current_user),
    request: Request = None
):
    OFS = await criar_registro_ofc(db, data, usuario)
    
    await registrar_auditoria(
        db, usuario.id,
        acao="CRIAR_OFC",
        entidade="ofc_registros",
        entidade_id=str(OFS.id),
        dados_novos={
            "codigo": OFS.codigo,
            "tipo": OFS.tipo_observacao,
            "empresa": OFS.empresa_observada_outros or OFS.empresa_observada_id,
        },
        ip_origem=request.client.host if request else None
    )
    
    await db.commit()
    return {"sucesso": True, "dados": OFS}
```

### 11.3 Retenção e Consulta

- Logs mantidos indefinidamente no banco (MVCC do PostgreSQL)
- Purga opcional: Admin pode configurar retenção (ex: 2 anos)
- Índice em `criado_em DESC` garante queries rápidas para períodos recentes
- Consulta paginada com filtros: `GET /api/auditoria?usuario_id=&acao=&entidade=&data_inicio=&data_fim=`
- Exportação CSV (Fase 2)

---

## 12. Estratégia para Migração Futura para Nuvem

### 12.1 Princípios Aplicados Hoje

| Princípio | Como implementamos |
|-----------|-------------------|
| **Stateless** | Backend não armazena estado local. Tudo no PostgreSQL. JWT stateless (sem sessão). |
| **Config por env vars** | Toda configuração via `os.environ`. Nada hardcoded. |
| **Port binding** | Backend expõe porta 8000. Nginx faz proxy. Cloud: Load Balancer → Container. |
| **Concorrência** | Uvicorn com workers. Escala vertical (mais CPUs) ou horizontal (mais containers). |
| **Descartável** | Containers podem ser destruídos e recriados sem perda de dados (banco externo). |
| **Paridade dev/prod** | Mesmo Docker Compose, mesmo Dockerfile, mesmo banco PostgreSQL. |
| **Logs stdout** | Todos os logs vão para stdout/stderr. Cloud: CloudWatch, Azure Monitor, etc. |
| **Backing services** | PostgreSQL tratado como recurso externo (URL). Fácil trocar por RDS. |

### 12.2 Mapeamento Intranet → Cloud

| Componente | Intranet (MVP) | Nuvem (Futuro) |
|-----------|----------------|----------------|
| **Frontend** | Nginx servindo estáticos | CloudFront / CDN + S3 / Blob Storage |
| **Backend** | Container Docker | ECS Fargate / ACI / Cloud Run / Kubernetes |
| **Banco** | PostgreSQL container | AWS RDS / Azure PostgreSQL / Cloud SQL |
| **PDFs** | Volume Docker `./reports/` | S3 / Azure Blob / GCS |
| **Backups** | Volume Docker `./backups/` | S3 + Lifecycle Policy / Blob Storage |
| **Secrets** | `.env` file | AWS Secrets Manager / Azure Key Vault / Secret Manager |
| **SSL** | Autoassinado ou CA interna | ACM / Azure Certificate / GCP Managed Cert |
| **DNS** | IP interno | Route 53 / Azure DNS / Cloud DNS |
| **Logs** | stdout → Docker logs | CloudWatch / Azure Monitor / Cloud Logging |
| **Métricas** | Internas (APScheduler) | CloudWatch / Azure Monitor / Cloud Monitoring |
| **CI/CD** | Manual + scripts | GitHub Actions / Azure DevOps / Cloud Build |

### 12.3 Variáveis de Ambiente (`.env.example`)

```bash
# ========================================
# CONFIGURAÇÃO DO SISTEMA OFS/OFS
# Security Dynamics — MVP
# ========================================

# Ambiente
AMBIENTE=producao          # producao | homologacao | desenvolvimento
DEBUG=false

# Banco de Dados
DB_HOST=db
DB_PORT=5432
DB_NAME=ofs_db
DB_USER=ofs_user
DB_PASSWORD=senha-forte-aqui
DB_POOL_SIZE=10
DB_MAX_OVERFLOW=20

# JWT
JWT_SECRET=chave-secreta-minimo-32-caracteres-aleatorios
JWT_ALGORITHM=HS256
JWT_ACCESS_EXPIRE_MINUTES=15
JWT_REFRESH_EXPIRE_DAYS=7

# CORS (origens permitidas)
CORS_ORIGINS=http://localhost:3000,http://servidor-interno

# Upload / Relatórios
REPORTS_DIR=/app/reports
MAX_REPORT_SIZE_MB=50

# Backup
BACKUP_DIR=/backups
BACKUP_RETENTION_DAYS=30
BACKUP_SCHEDULE_HOUR=3
BACKUP_SCHEDULE_MINUTE=0

# Logging
LOG_LEVEL=INFO

# ════════════════════════════════════
# FUTURO: Cloud (descomentar ao migrar)
# ════════════════════════════════════
# DB_HOST=meu-rds.xxxxxx.us-east-1.rds.amazonaws.com
# DB_SSL=true
# REPORTS_STORAGE=s3://meu-bucket/reports/
# BACKUP_STORAGE=s3://meu-bucket/backups/
# AWS_REGION=us-east-1
# SENTRY_DSN=https://...
```

### 12.4 Docker para Cloud (ECS/Fargate)

```dockerfile
# Dockerfile atual já é cloud-ready
FROM python:3.12-slim
WORKDIR /app

# Não-root (requisito de segurança em cloud)
RUN useradd --create-home --shell /bin/bash appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chown -R appuser:appuser /app

USER appuser
EXPOSE 8000

# Health check endpoint (cloud load balancer)
HEALTHCHECK --interval=30s --timeout=3s \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 12.5 Terraform (Exemplo Futuro — AWS)

```hcl
# Infraestrutura como código — futuro
resource "aws_ecs_service" "ofs_backend" {
  name            = "ofs-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ofs_backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.backend.id]
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "ofs-backend"
    container_port   = 8000
  }
}

resource "aws_db_instance" "ofs_postgres" {
  identifier     = "ofs-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.medium"
  storage_encrypted = true
  backup_retention_period = 30
  
  username = var.db_username
  password = var.db_password  # Secrets Manager
}
```

---

## Apêndice: Seed Data Completo

```sql
-- ============================================================
-- SEED DATA — Dados iniciais para o MVP
-- ============================================================

-- Empresas (15 + 1 "Outros")
INSERT INTO empresas (nome) VALUES
    ('Security Dynamics'),
    ('Polo Norte'),
    ('G4S'),
    ('ERA'),
    ('Innovatec'),
    ('Conin'),
    ('FM'),
    ('Sodexo'),
    ('Engecom'),
    ('P&G'),
    ('Yusen'),
    ('Mainpower'),
    ('Aduana'),
    ('Prosegur'),
    ('Outros');

-- Contrato padrão
INSERT INTO contratos (nome, descricao) VALUES
    ('Operação Security Dynamics', 'Contrato principal de operações da Security Dynamics');

-- Locais padrão
INSERT INTO locais (nome, contrato_id) VALUES
    ('Armazém A', 1),
    ('Armazém B', 1),
    ('Portaria Principal', 1),
    ('Pátio de Manobras', 1),
    ('Área Administrativa', 1);

-- Admin (senha: Admin@123 — bcrypt cost 12)
INSERT INTO usuarios (nome, login, email, senha_hash, empresa_id, contrato_id, perfil) VALUES
    ('Administrador do Sistema', 'admin', 'admin@securitydynamics.com.br',
     '$2b$12$LJ3m4ys3Lk0TSwHCpNqrIO8mXDZpJqKMGmF0MGZyPFBvfHaaVUwOe',
     1, 1, 'Admin');

-- Meta inicial (semana atual)
INSERT INTO metas_semanais (contrato_id, ano, semana, pessoas_ativas, meta_ofc_por_pessoa, usuarios_ativos)
VALUES (1, 2026, 20, 150, 5, 10);
-- NOTA: meta_ofc_programada será calculada automaticamente pelo trigger = 150 × 5 = 750
```

---

**Documento gerado em 13/05/2026.**
