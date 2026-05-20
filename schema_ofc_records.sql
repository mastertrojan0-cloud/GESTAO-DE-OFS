-- ============================================================================
-- SCHEMA: Sistema OFS/OFS - Tabela de Registros
-- PostgreSQL 16 | Offline-first | Codificação: OFS-AAAA-SS-NNNN
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TABELAS DE APOIO (mínimo necessário para FKs)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS usuarios (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome        VARCHAR(200) NOT NULL,
    email       VARCHAR(200),
    perfil      VARCHAR(50),
    empresa     VARCHAR(200)
);

COMMENT ON TABLE usuarios IS 'Usuários do sistema OFS/OFS';

CREATE TABLE IF NOT EXISTS contratos (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    descricao   VARCHAR(300) NOT NULL
);

COMMENT ON TABLE contratos IS 'Contratos associados aos registros';

CREATE TABLE IF NOT EXISTS empresas (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome        VARCHAR(200) NOT NULL
);

COMMENT ON TABLE empresas IS 'Empresas observadas / fiscalizadas';

-- ----------------------------------------------------------------------------
-- TABELA DE CONTROLE SEQUENCIAL (evita gaps e race conditions)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ofc_seq_control (
    ano         INT NOT NULL,
    semana      INT NOT NULL,
    last_seq    INT NOT NULL DEFAULT 0,
    PRIMARY KEY (ano, semana)
);

COMMENT ON TABLE ofc_seq_control IS 'Controle de sequencial do código por ano/semana';
COMMENT ON COLUMN ofc_seq_control.last_seq IS 'Último número sequencial usado na semana';

-- ----------------------------------------------------------------------------
-- FUNÇÕES AUXILIARES
-- ----------------------------------------------------------------------------

-- Gera o próximo código no formato OFS-AAAA-SS-NNNN
CREATE OR REPLACE FUNCTION generate_ofc_codigo(p_data_registro DATE)
RETURNS VARCHAR(16)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ano    INT;
    v_semana INT;
    v_seq    INT;
BEGIN
    v_ano    := EXTRACT(YEAR FROM p_data_registro);
    v_semana := EXTRACT(WEEK FROM p_data_registro);

    INSERT INTO ofc_seq_control (ano, semana, last_seq)
    VALUES (v_ano, v_semana, 1)
    ON CONFLICT (ano, semana) DO UPDATE
        SET last_seq = ofc_seq_control.last_seq + 1
    RETURNING last_seq INTO v_seq;

    RETURN 'OFS-' || LPAD(v_ano::TEXT, 4, '0')
                  || '-' || LPAD(v_semana::TEXT, 2, '0')
                  || '-' || LPAD(v_seq::TEXT, 4, '0');
END;
$$;

COMMENT ON FUNCTION generate_ofc_codigo(DATE) IS 'Gera código OFS-AAAA-SS-NNNN atômico e livre de colisões';

-- ----------------------------------------------------------------------------
-- TABELA PRINCIPAL: ofc_records
-- ----------------------------------------------------------------------------

CREATE TABLE ofc_records (

    -- ========================================================================
    -- IDENTIFICAÇÃO
    -- ========================================================================
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    codigo          VARCHAR(16) NOT NULL,              -- OFS-2026-20-0001

    -- ========================================================================
    -- DATA / HORA DO REGISTRO
    -- ========================================================================
    data_registro   DATE        NOT NULL,
    hora_registro   TIME        NOT NULL DEFAULT CURRENT_TIME,

    -- Partes extraídas automaticamente de data_registro
    semana          INT         NOT NULL,               -- semana ISO do ano (1-53)
    mes             INT         NOT NULL,               -- 1-12
    ano             INT         NOT NULL,               -- ano calendário

    -- ========================================================================
    -- USUÁRIO (snapshots → preservam dados mesmo se usuário for alterado)
    -- ========================================================================
    usuario_id              UUID        NOT NULL,
    usuario_nome_snapshot   VARCHAR(200) NOT NULL,
    usuario_email_snapshot  VARCHAR(200),
    usuario_perfil_snapshot VARCHAR(50),
    empresa_usuario_snapshot VARCHAR(200),

    -- ========================================================================
    -- CONTRATO
    -- ========================================================================
    contrato_id             UUID        NOT NULL,

    -- ========================================================================
    -- EMPRESA OBSERVADA
    -- ========================================================================
    empresa_observada_id    UUID,
    empresa_observada_outros VARCHAR(300),  -- nome livre quando ID não existe

    -- ========================================================================
    -- DETALHES DA OBSERVAÇÃO
    -- ========================================================================
    nome_observado          VARCHAR(300) NOT NULL,
    atividade_observada     VARCHAR(300),
    local_observado         VARCHAR(300),

    turno                   VARCHAR(20)  NOT NULL,

    tipo_observacao         VARCHAR(20)  NOT NULL,

    comportamento_observado TEXT,                -- texto rico / descritivo
    observacao_complementar TEXT,                -- informações adicionais

    -- ========================================================================
    -- STATUS DO REGISTRO
    -- ========================================================================
    status_registro         VARCHAR(10)  NOT NULL DEFAULT 'Gerado',

    -- ========================================================================
    -- AUDITORIA DE CRIAÇÃO / EDIÇÃO
    -- ========================================================================
    criado_por              UUID        NOT NULL,
    criado_em               TIMESTAMPTZ NOT NULL DEFAULT now(),

    editado_por             UUID,
    editado_em              TIMESTAMPTZ,

    edit_count              INT         NOT NULL DEFAULT 0,

    -- ========================================================================
    -- CANCELAMENTO
    -- ========================================================================
    cancelado_por           UUID,
    cancelado_em            TIMESTAMPTZ,
    motivo_cancelamento     TEXT,

    -- ========================================================================
    -- SOFT DELETE
    -- ========================================================================
    is_deleted              BOOLEAN     NOT NULL DEFAULT FALSE,
    deleted_at              TIMESTAMPTZ,
    deleted_by              UUID,

    -- ========================================================================
    -- CONTROLE AUTOMÁTICO DE ATUALIZAÇÃO
    -- ========================================================================
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- ========================================================================
    -- CONSTRAINTS
    -- ========================================================================
    CONSTRAINT fk_ofc_records_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id),

    CONSTRAINT fk_ofc_records_contrato
        FOREIGN KEY (contrato_id) REFERENCES contratos(id),

    CONSTRAINT fk_ofc_records_empresa_observada
        FOREIGN KEY (empresa_observada_id) REFERENCES empresas(id),

    CONSTRAINT fk_ofc_records_criado_por
        FOREIGN KEY (criado_por) REFERENCES usuarios(id),

    CONSTRAINT fk_ofc_records_editado_por
        FOREIGN KEY (editado_por) REFERENCES usuarios(id),

    CONSTRAINT fk_ofc_records_cancelado_por
        FOREIGN KEY (cancelado_por) REFERENCES usuarios(id),

    CONSTRAINT fk_ofc_records_deleted_by
        FOREIGN KEY (deleted_by) REFERENCES usuarios(id),

    CONSTRAINT chk_ofc_records_codigo_format
        CHECK (codigo ~ '^OFS-\d{4}-\d{2}-\d{4}$'),

    CONSTRAINT chk_ofc_records_semana
        CHECK (semana BETWEEN 1 AND 53),

    CONSTRAINT chk_ofc_records_mes
        CHECK (mes BETWEEN 1 AND 12),

    CONSTRAINT chk_ofc_records_ano
        CHECK (ano BETWEEN 2000 AND 2100),

    CONSTRAINT chk_ofc_records_status_registro
        CHECK (status_registro IN ('Gerado', 'Editado', 'Cancelado')),

    CONSTRAINT chk_ofc_records_turno
        CHECK (turno IN ('Matutino', 'Vespertino', 'Noturno', 'Integral')),

    CONSTRAINT chk_ofc_records_tipo_observacao
        CHECK (tipo_observacao IN ('Presencial', 'Remota', 'Documental', 'Mista')),

    CONSTRAINT chk_ofc_records_cancelado_check
        CHECK (
            (status_registro = 'Cancelado' AND cancelado_por IS NOT NULL AND cancelado_em IS NOT NULL)
            OR
            (status_registro <> 'Cancelado')
        ),

    CONSTRAINT chk_ofc_records_empresa_observada
        CHECK (
            empresa_observada_id IS NOT NULL OR empresa_observada_outros IS NOT NULL
        )
);

-- ----------------------------------------------------------------------------
-- COMENTÁRIOS DAS COLUNAS
-- ----------------------------------------------------------------------------

COMMENT ON TABLE  ofc_records IS 'Registros de observação fiscal/de campo (OFS/OFS)';

COMMENT ON COLUMN ofc_records.id              IS 'Identificador único universal (UUID v4)';
COMMENT ON COLUMN ofc_records.codigo          IS 'Código no formato OFS-AAAA-SS-NNNN (gerado automaticamente)';
COMMENT ON COLUMN ofc_records.data_registro   IS 'Data do registro da observação';
COMMENT ON COLUMN ofc_records.hora_registro   IS 'Hora do registro da observação (HH:MM:SS)';
COMMENT ON COLUMN ofc_records.semana          IS 'Semana ISO do ano extraída de data_registro (1-53)';
COMMENT ON COLUMN ofc_records.mes             IS 'Mês extraído de data_registro (1-12)';
COMMENT ON COLUMN ofc_records.ano             IS 'Ano calendário extraído de data_registro';
COMMENT ON COLUMN ofc_records.usuario_id      IS 'FK → usuarios.id (usuário que registrou)';
COMMENT ON COLUMN ofc_records.usuario_nome_snapshot    IS 'Nome do usuário no momento do registro';
COMMENT ON COLUMN ofc_records.usuario_email_snapshot   IS 'Email do usuário no momento do registro';
COMMENT ON COLUMN ofc_records.usuario_perfil_snapshot  IS 'Perfil do usuário no momento do registro';
COMMENT ON COLUMN ofc_records.empresa_usuario_snapshot IS 'Empresa do usuário no momento do registro';
COMMENT ON COLUMN ofc_records.contrato_id              IS 'FK → contratos.id';
COMMENT ON COLUMN ofc_records.empresa_observada_id     IS 'FK → empresas.id (empresa fiscalizada)';
COMMENT ON COLUMN ofc_records.empresa_observada_outros IS 'Nome livre da empresa quando sem cadastro prévio';
COMMENT ON COLUMN ofc_records.nome_observado           IS 'Nome da pessoa/objeto observado';
COMMENT ON COLUMN ofc_records.atividade_observada      IS 'Atividade sendo executada no momento';
COMMENT ON COLUMN ofc_records.local_observado          IS 'Local da observação';
COMMENT ON COLUMN ofc_records.turno                    IS 'Turno: Matutino | Vespertino | Noturno | Integral';
COMMENT ON COLUMN ofc_records.tipo_observacao          IS 'Tipo: Presencial | Remota | Documental | Mista';
COMMENT ON COLUMN ofc_records.comportamento_observado  IS 'Descrição detalhada do comportamento observado';
COMMENT ON COLUMN ofc_records.observacao_complementar  IS 'Observações adicionais / notas de campo';
COMMENT ON COLUMN ofc_records.status_registro          IS 'Status: Gerado | Editado | Cancelado';
COMMENT ON COLUMN ofc_records.criado_por               IS 'FK → usuarios.id (quem criou)';
COMMENT ON COLUMN ofc_records.criado_em                IS 'Timestamp de criação (UTC)';
COMMENT ON COLUMN ofc_records.editado_por              IS 'FK → usuarios.id (quem editou pela última vez)';
COMMENT ON COLUMN ofc_records.editado_em               IS 'Timestamp da última edição explícita (UTC)';
COMMENT ON COLUMN ofc_records.edit_count               IS 'Contador de edições realizadas';
COMMENT ON COLUMN ofc_records.cancelado_por            IS 'FK → usuarios.id (quem cancelou)';
COMMENT ON COLUMN ofc_records.cancelado_em             IS 'Timestamp do cancelamento (UTC)';
COMMENT ON COLUMN ofc_records.motivo_cancelamento      IS 'Motivo/justificativa do cancelamento';
COMMENT ON COLUMN ofc_records.is_deleted               IS 'Flag de exclusão lógica (soft delete)';
COMMENT ON COLUMN ofc_records.deleted_at               IS 'Timestamp da exclusão lógica (UTC)';
COMMENT ON COLUMN ofc_records.deleted_by               IS 'FK → usuarios.id (quem excluiu logicamente)';
COMMENT ON COLUMN ofc_records.updated_at               IS 'Timestamp de última alteração na linha (automático)';

-- ============================================================================
-- ÍNDICES
-- ============================================================================

-- Código único
CREATE UNIQUE INDEX idx_ofc_records_codigo
    ON ofc_records (codigo);

-- Data do registro (maioria das consultas filtra por período)
CREATE INDEX idx_ofc_records_data_registro
    ON ofc_records (data_registro);

-- Busca por usuário
CREATE INDEX idx_ofc_records_usuario_id
    ON ofc_records (usuario_id);

-- Busca por contrato
CREATE INDEX idx_ofc_records_contrato_id
    ON ofc_records (contrato_id);

-- Busca por empresa observada
CREATE INDEX idx_ofc_records_empresa_observada_id
    ON ofc_records (empresa_observada_id);

-- Filtro por status
CREATE INDEX idx_ofc_records_status_registro
    ON ofc_records (status_registro);

-- Filtro por quem criou
CREATE INDEX idx_ofc_records_criado_por
    ON ofc_records (criado_por);

-- ---------- ÍNDICES COMPOSTOS ----------

-- Consultas frequentes: ano + semana (agrupamento semanal)
CREATE INDEX idx_ofc_records_ano_semana
    ON ofc_records (ano, semana);

-- Consultas frequentes: ano + mes (agrupamento mensal)
CREATE INDEX idx_ofc_records_ano_mes
    ON ofc_records (ano, mes);

-- Listagem de registros ativos por usuário (evita scan da PK)
CREATE INDEX idx_ofc_records_usuario_status
    ON ofc_records (usuario_id, status_registro);

-- Dashboard: total por empresa observada + status
CREATE INDEX idx_ofc_records_empresa_status
    ON ofc_records (empresa_observada_id, status_registro);

-- Busca de registros por contrato + data (range scan eficiente)
CREATE INDEX idx_ofc_records_contrato_data
    ON ofc_records (contrato_id, data_registro);

-- ---------- ÍNDICES PARCIAIS ----------

-- Registros ativos (não deletados) — otimiza 90%+ das consultas
CREATE INDEX idx_ofc_records_not_deleted
    ON ofc_records (data_registro, status_registro)
    WHERE is_deleted = FALSE;

-- Registros cancelados (auditoria / relatórios)
CREATE INDEX idx_ofc_records_cancelados
    ON ofc_records (cancelado_em)
    WHERE status_registro = 'Cancelado';

-- ---------- ÍNDICES GIN (Full-Text Search) ----------

-- Busca textual em português no comportamento observado
CREATE INDEX idx_ofc_records_comportamento_fts
    ON ofc_records
    USING GIN (to_tsvector('portuguese', coalesce(comportamento_observado, '')));

-- Busca combinada: comportamento + observação complementar
CREATE INDEX idx_ofc_records_fulltext
    ON ofc_records
    USING GIN (to_tsvector('portuguese',
        coalesce(comportamento_observado, '') || ' ' || coalesce(observacao_complementar, '')
    ));

-- Busca por nome observado (trigram similarity + ILIKE otimizado)
CREATE INDEX idx_ofc_records_nome_observado_gin
    ON ofc_records
    USING GIN (nome_observado gin_trgm_ops);

-- ---------- ÍNDICES DE APOIO ----------

-- Turno (filtro comum em relatórios)
CREATE INDEX idx_ofc_records_turno
    ON ofc_records (turno);

-- Tipo de observação
CREATE INDEX idx_ofc_records_tipo_observacao
    ON ofc_records (tipo_observacao);

-- Soft delete (purge jobs, auditoria)
CREATE INDEX idx_ofc_records_is_deleted
    ON ofc_records (is_deleted, deleted_at)
    WHERE is_deleted = TRUE;

-- Ordenação por criação (listagens recentes)
CREATE INDEX idx_ofc_records_criado_em
    ON ofc_records (criado_em DESC);

-- ----------------------------------------------------------------------------
-- TRIGGERS
-- ----------------------------------------------------------------------------

-- TRIGGER 1: Preenche semana / mes / ano automaticamente a partir de data_registro
CREATE OR REPLACE FUNCTION trg_ofc_records_fill_date_parts()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' OR NEW.data_registro IS DISTINCT FROM OLD.data_registro THEN
        NEW.ano    := EXTRACT(YEAR   FROM NEW.data_registro);
        NEW.mes    := EXTRACT(MONTH  FROM NEW.data_registro);
        NEW.semana := EXTRACT(WEEK   FROM NEW.data_registro);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ofc_records_biu_fill_date_parts
    BEFORE INSERT OR UPDATE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION trg_ofc_records_fill_date_parts();

-- TRIGGER 2: Gera código automaticamente (OFS-AAAA-SS-NNNN) na inserção
CREATE OR REPLACE FUNCTION trg_ofc_records_generate_codigo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.codigo IS NULL THEN
        NEW.codigo := generate_ofc_codigo(NEW.data_registro);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ofc_records_bi_generate_codigo
    BEFORE INSERT ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION trg_ofc_records_generate_codigo();

-- TRIGGER 3: Atualiza updated_at automaticamente em qualquer modificação
CREATE OR REPLACE FUNCTION trg_ofc_records_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ofc_records_bu_updated_at
    BEFORE UPDATE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION trg_ofc_records_set_updated_at();

-- ----------------------------------------------------------------------------
-- EXTENSÕES NECESSÁRIAS (executar uma vez como superuser)
-- ----------------------------------------------------------------------------
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;    -- para índices GIN com trigram
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- opcional, gen_random_uuid() é built-in no PG 13+

-- ============================================================================
-- EXEMPLO DE INSERT (código e date parts são gerados automaticamente)
-- ============================================================================

/*
INSERT INTO ofc_records (
    data_registro, hora_registro,
    usuario_id, usuario_nome_snapshot, usuario_email_snapshot,
    usuario_perfil_snapshot, empresa_usuario_snapshot,
    contrato_id,
    empresa_observada_id,
    nome_observado, atividade_observada, local_observado,
    turno, tipo_observacao,
    comportamento_observado,
    criado_por
) VALUES (
    '2026-05-13', '14:30:00',
    '<uuid-usuario>', 'João Silva', 'joao@exemplo.com',
    'Operador', 'Empresa XPTO',
    '<uuid-contrato>',
    '<uuid-empresa>',
    'Trabalhador A', 'Montagem de andaime', 'Setor B - Linha 3',
    'Matutino', 'Presencial',
    'Trabalhador sem cinto de segurança durante atividade em altura...',
    '<uuid-usuario>'
);
-- Retorna código como 'OFS-2026-20-0001', com semana=20, mes=5, ano=2026 preenchidos.
*/

-- ============================================================================
-- FIM DO SCHEMA
-- ============================================================================
