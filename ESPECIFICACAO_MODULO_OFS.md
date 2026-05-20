# ESPECIFICAÇÃO COMPLETA — Módulo de Registros OFS/OFS

**Sistema:** Feedback Comportamental OFS/OFS  
**Empresa:** Security Dynamics  
**Versão:** MVP 1.0  
**Data:** 13/05/2026  

---

## Sumário

1. [Regras de Negócio](#1-regras-de-negócio)
2. [Fluxos Operacionais](#2-fluxos-operacionais)
3. [Estrutura do Banco de Dados](#3-estrutura-do-banco-de-dados)
4. [Endpoints e Payloads](#4-endpoints-e-payloads)
5. [Validações](#5-validações)
6. [Regras de Permissão](#6-regras-de-permissão)
7. [Auditoria e Rastreabilidade](#7-auditoria-e-rastreabilidade)
8. [Estrutura das Telas](#8-estrutura-das-telas)
9. [Índices Recomendados](#9-índices-recomendados)
10. [Critérios de Aceite](#10-critérios-de-aceite)

---

## 1. Regras de Negócio

### 1.1 Criação de OFS/OFS

**Campos Automáticos (servidor, não editáveis pelo usuário):**

| Campo | Origem | Descrição |
|-------|--------|-----------|
| `id` | `gen_random_uuid()` | UUID v4 |
| `codigo` | Trigger SQL | Formato `OFS-AAAA-SS-NNNN` |
| `data_registro` | `CURRENT_DATE` | Data do servidor |
| `hora_registro` | `CURRENT_TIME` | Hora do servidor |
| `semana` | Trigger SQL | `EXTRACT(WEEK FROM data_registro)` |
| `mes` | Trigger SQL | `EXTRACT(MONTH FROM data_registro)` |
| `ano` | Trigger SQL | `EXTRACT(YEAR FROM data_registro)` |
| `usuario_id` | JWT `sub` | UUID do usuário logado |
| `usuario_nome_snapshot` | `user.full_name` | Congelado no momento |
| `usuario_email_snapshot` | `user.email` | Congelado no momento |
| `usuario_perfil_snapshot` | `user.role` | Congelado no momento |
| `empresa_usuario_snapshot` | `user.company.name` | Congelado no momento |
| `criado_por` | `user.id` | FK → users |
| `criado_em` | `NOW()` | Timestamp |
| `status_registro` | `'Gerado'` | Status inicial |

**Campos Preenchidos pelo Usuário:**

| Campo | Obrigatório | Tipo | Validação |
|-------|:---:|------|-----------|
| `empresa_observada_id` | ✅ | FK companies | Dropdown 15 empresas |
| `empresa_observada_outros` | Condicional | VARCHAR(150) | Obrigatório se empresa_id = NULL |
| `nome_observado` | ✅ | VARCHAR(200) | Mínimo 3 caracteres |
| `atividade_observada` | ✅ | VARCHAR(300) | Mínimo 5 caracteres |
| `local_observado` | ✅ | VARCHAR(200) | Mínimo 3 caracteres |
| `turno` | ✅ | VARCHAR(50) | CHECK: Diurno/Noturno/Administrativo/Turno 1/Turno 2/Turno 3 |
| `tipo_observacao` | ✅ | VARCHAR(20) | CHECK: 'Positivo/Seguro' ou 'Negativo/Inseguro' |
| `comportamento_observado` | ✅ | TEXT | Mínimo 5 caracteres |
| `observacao_complementar` | ❌ | TEXT | Opcional |

**Regra "Outros":** Se `empresa_observada_id` for NULL (representando "Outros"), o campo `empresa_observada_outros` torna-se obrigatório.

**Formato do Código:** `OFS-AAAA-SS-NNNN`
- AAAA = ano com 4 dígitos
- SS = semana com 2 dígitos (01-53)
- NNNN = sequencial com 4 dígitos (0001-9999), reinicia a cada par ano/semana

Exemplo: `OFS-2026-20-0001`

### 1.2 Edição de OFS/OFS

**Matriz de Permissão:**

| Perfil | Pode Editar | Janela de Tempo |
|--------|:---:|-----------------|
| Observador | Apenas seus registros | Até 24h da criação |
| Supervisor | Registros da sua empresa | Até 48h da criação |
| Gestor | Qualquer registro | Sem limite |
| Admin | Qualquer registro | Sem limite |

**Campos IMUTÁVEIS (nunca podem ser editados):**
- `id`, `codigo`, `data_registro`, `hora_registro`, `semana`, `mes`, `ano`
- `usuario_id`, `usuario_nome_snapshot`, `usuario_email_snapshot`
- `usuario_perfil_snapshot`, `empresa_usuario_snapshot`
- `criado_por`, `criado_em`
- `cancelado_por`, `cancelado_em`, `motivo_cancelamento` (só definidos no cancelamento)

**Campos EDITÁVEIS:**
- `empresa_observada_id`, `empresa_observada_outros`
- `nome_observado`, `atividade_observada`, `local_observado`
- `turno`, `tipo_observacao`
- `comportamento_observado`, `observacao_complementar`

**Regras de Edição:**
- Cada campo alterado gera registro em `ofc_edit_log` (campo, old_value, new_value, edited_by, edited_at)
- `status_registro` muda para `'Editado'`
- `edit_count` incrementa
- `editado_por` e `editado_em` atualizados
- Optimistic locking: verificar `updated_at` antes de salvar → 409 Conflict se divergir

### 1.3 Cancelamento de OFS/OFS

| Regra | Valor |
|-------|-------|
| Quem pode | Apenas Gestor e Admin |
| Motivo | Obrigatório, mínimo 10 caracteres |
| Tipo | Soft delete (NUNCA exclusão física) |
| Impacto | Registro NÃO entra em métricas |

**Ao Cancelar:**
- `status_registro` = `'Cancelado'`
- `is_deleted` = `TRUE`
- `cancelado_por` = `user.id`
- `cancelado_em` = `NOW()`
- `motivo_cancelamento` = texto informado

**Restauração (apenas Admin):**
- `is_deleted` = `FALSE`
- `status_registro` = `'Editado'`
- Auditado como CRITICAL

### 1.4 Máquina de Estados

```
┌──────────┐     editar      ┌──────────┐
│  Gerado  │────────────────▶│ Editado  │
└────┬─────┘                 └────┬─────┘
     │                            │
     │ cancelar                   │ cancelar
     ▼                            ▼
┌──────────┐                 ┌──────────┐
│Cancelado │◀────────────────│Cancelado │
└──────────┘                 └──────────┘
     │
     │ restaurar (apenas Admin)
     ▼
┌──────────┐
│ Editado  │  (restaurado)
└──────────┘
```

| De | Para | Permitido? |
|----|------|:---:|
| Gerado | Editado | ✅ |
| Gerado | Cancelado | ✅ |
| Editado | Editado | ✅ (múltiplas edições) |
| Editado | Cancelado | ✅ |
| Cancelado | Editado | ✅ (restore, Admin only) |
| Cancelado | Gerado | ❌ |
| Editado | Gerado | ❌ |

---

## 2. Fluxos Operacionais

### 2.1 Fluxo de Criação

```
1. Usuário autenticado → acessa /OFS/novo
2. Frontend carrega dropdowns (empresas, turnos)
3. Usuário preenche campos:
   ├── Empresa Observada* (dropdown)
   │   └── Se "Outros" → campo texto "Nome da Empresa"*
   ├── Nome do Observado*
   ├── Atividade Observada*
   ├── Local Observado*
   ├── Turno* (dropdown)
   ├── Tipo* (Positivo/Seguro ou Negativo/Inseguro)
   ├── Comportamento Observado* (textarea)
   └── Observação Complementar (opcional)
4. Validação inline (ao perder foco do campo)
5. Botão "Salvar" habilitado apenas com todos os obrigatórios preenchidos
6. POST /api/OFS-records com JSON
7. Backend:
   ├── Valida Pydantic schema
   ├── Preenche snapshots do usuário
   ├── Trigger gera código OFS-AAAA-SS-NNNN
   ├── INSERT ofc_records
   ├── INSERT audit_logs (OFC_CREATE)
   └── Retorna 201 + dados do registro
8. Frontend:
   ├── Toast verde "Registro #OFS-2026-20-0001 criado com sucesso!"
   └── Opções: [Ver Registro] [Novo Registro] [Início]
```

### 2.2 Fluxo de Edição

```
1. Usuário vê registro → clica [Editar] (visível conforme permissão)
2. Frontend carrega formulário pré-preenchido
3. Usuário altera campos permitidos
4. PUT /api/OFS-records/{id} com campos alterados + updated_at
5. Backend:
   ├── Verifica permissão (can_edit_ofc)
   ├── Verifica janela de edição (24h/48h)
   ├── Verifica optimistic lock (updated_at)
   ├── Detecta campos alterados (diff)
   ├── UPDATE ofc_records
   ├── INSERT ofc_edit_log (cada campo alterado)
   ├── INSERT audit_logs (OFC_UPDATE)
   └── Retorna 200 + registro + edições
6. Frontend: Toast "Registro atualizado com sucesso!"
```

### 2.3 Fluxo de Cancelamento

```
1. Gestor/Admin clica [Cancelar] no detalhe do registro
2. Modal: "Tem certeza? Informe o motivo:"
3. Usuário preenche motivo (mínimo 10 caracteres)
4. PATCH /api/OFS-records/{id}/cancel com { "motivo": "..." }
5. Backend:
   ├── Verifica perfil (apenas gestor/admin)
   ├── Verifica se já não está cancelado
   ├── UPDATE: status='Cancelado', is_deleted=TRUE, cancelado_por, cancelado_em, motivo
   ├── INSERT audit_logs (OFC_CANCEL)
   └── Retorna 200
6. Frontend: Toast "Registro cancelado." → atualiza tela
```

### 2.4 Fluxo de Consulta

```
1. Usuário acessa /OFS
2. Barra de filtros disponível:
   ├── Código, Data Início, Data Fim
   ├── Empresa, Turno, Tipo, Status
   └── Usuário Gerador
3. GET /api/OFS-records?filtros...
4. Backend:
   ├── Aplica data scoping por perfil
   ├── Aplica filtros dinâmicos (AND)
   ├── Paginação (25/página)
   └── Retorna resultados + total
5. Frontend: Tabela com ações por linha
   ├── 👁 Ver (todos)
   ├── 📄 PDF (todos)
   ├── ✏ Editar (condicional: dono + janela)
   └── ⛔ Cancelar (condicional: gestor/admin)
```

---

## 3. Estrutura do Banco de Dados

### 3.1 DDL Principal

```sql
CREATE TABLE ofc_records (
    -- Identificação
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo                      VARCHAR(17) NOT NULL UNIQUE,

    -- Datas
    data_registro               DATE NOT NULL DEFAULT CURRENT_DATE,
    hora_registro               TIME NOT NULL DEFAULT CURRENT_TIME,
    semana                      INT NOT NULL CHECK (semana BETWEEN 1 AND 53),
    mes                         INT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    ano                         INT NOT NULL,

    -- Usuário gerador (snapshots para rastreabilidade)
    usuario_id                  UUID NOT NULL REFERENCES users(id),
    usuario_nome_snapshot       VARCHAR(200) NOT NULL,
    usuario_email_snapshot      VARCHAR(200),
    usuario_perfil_snapshot     VARCHAR(20) NOT NULL,
    empresa_usuario_snapshot    VARCHAR(150),

    -- Contrato
    contrato_id                 INT REFERENCES contracts(id),

    -- Empresa observada
    empresa_observada_id        INT REFERENCES companies(id),
    empresa_observada_outros    VARCHAR(150),

    -- Dados da observação
    nome_observado              VARCHAR(200) NOT NULL,
    atividade_observada         VARCHAR(300) NOT NULL,
    local_observado             VARCHAR(200) NOT NULL,

    -- Classificação
    turno                       VARCHAR(50) NOT NULL,
    tipo_observacao             VARCHAR(20) NOT NULL 
        CHECK (tipo_observacao IN ('Positivo/Seguro', 'Negativo/Inseguro')),

    -- Comportamento
    comportamento_observado     TEXT NOT NULL,
    observacao_complementar     TEXT,

    -- Status e rastreabilidade
    status_registro             VARCHAR(20) NOT NULL DEFAULT 'Gerado'
        CHECK (status_registro IN ('Gerado', 'Editado', 'Cancelado')),
    is_deleted                  BOOLEAN DEFAULT FALSE,
    edit_count                  INT DEFAULT 0,

    -- Auditoria
    criado_por                  UUID NOT NULL REFERENCES users(id),
    criado_em                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    editado_por                 UUID REFERENCES users(id),
    editado_em                  TIMESTAMPTZ,
    cancelado_por               UUID REFERENCES users(id),
    cancelado_em                TIMESTAMPTZ,
    motivo_cancelamento         TEXT,
    deleted_at                  TIMESTAMPTZ,
    deleted_by                  UUID REFERENCES users(id),

    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela de controle de sequência do código
CREATE TABLE ofc_seq_control (
    ano     INT NOT NULL,
    semana  INT NOT NULL,
    last_seq INT NOT NULL DEFAULT 0,
    PRIMARY KEY (ano, semana)
);

-- Trigger: gerar código OFS-AAAA-SS-NNNN
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

-- Trigger: preencher semana/mes/ano
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

-- Trigger: updated_at
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ofc_updated_at
    BEFORE UPDATE ON ofc_records
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Trigger: IMPEDIR DELETE físico
CREATE OR REPLACE FUNCTION prevent_hard_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Exclusão física não permitida em ofc_records. Use cancelamento lógico.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ofc_no_hard_delete
    BEFORE DELETE ON ofc_records
    FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
```

### 3.2 Tabela de Edições

```sql
CREATE TABLE ofc_edit_log (
    id              BIGSERIAL PRIMARY KEY,
    ofc_record_id   UUID NOT NULL,
    edited_by       UUID NOT NULL REFERENCES users(id),
    field_changed   VARCHAR(100) NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    edited_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_edit_log_ofc ON ofc_edit_log(ofc_record_id, edited_at DESC);
```

---

## 4. Endpoints e Payloads

### 4.1 Lista de Endpoints

| Método | Path | Permissão | Descrição |
|--------|------|:---:|-----------|
| `POST` | `/api/OFS-records` | Observador+ | Criar registro |
| `GET` | `/api/OFS-records` | Observador+escopo | Listar com filtros |
| `GET` | `/api/OFS-records/{id}` | Observador+escopo | Detalhe + edições |
| `PUT` | `/api/OFS-records/{id}` | Observador+janela | Editar |
| `PATCH` | `/api/OFS-records/{id}/cancel` | Gestor/Admin | Cancelar |
| `POST` | `/api/OFS-records/{id}/restore` | Admin | Restaurar |
| `GET` | `/api/OFS-records/{id}/pdf` | Observador+escopo | PDF individual |

### 4.2 Payload de Criação

**Request:**
```json
{
  "empresa_observada_id": 1,
  "empresa_observada_outros": null,
  "nome_observado": "Carlos Silva",
  "atividade_observada": "Controle de acesso na portaria principal",
  "local_observado": "Portaria 01",
  "contrato_id": 1,
  "turno": "Diurno",
  "tipo_observacao": "Positivo/Seguro",
  "comportamento_observado": "Uso correto de procedimento de abordagem e verificação de crachás",
  "observacao_complementar": "Colaborador realizou conferência de todos os visitantes com atenção."
}
```

**Response 201:**
```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "codigo": "OFS-2026-20-0001",
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
  "nome_observado": "Carlos Silva",
  "atividade_observada": "Controle de acesso na portaria principal",
  "local_observado": "Portaria 01",
  "turno": "Diurno",
  "tipo_observacao": "Positivo/Seguro",
  "comportamento_observado": "Uso correto de procedimento de abordagem e verificação de crachás",
  "observacao_complementar": "Colaborador realizou conferência de todos os visitantes com atenção.",
  "status_registro": "Gerado",
  "edit_count": 0,
  "criado_por": "f1e2d3c4-b5a6-9780-fedc-ba0987654321",
  "criado_em": "2026-05-13T14:30:05-03:00",
  "updated_at": "2026-05-13T14:30:05-03:00"
}
```

### 4.3 Payload de Edição

**Request:**
```json
{
  "comportamento_observado": "Uso correto de procedimento de abordagem, verificação de crachás e orientação sobre uso de EPIs",
  "observacao_complementar": "Colaborador demonstrou domínio completo dos protocolos de segurança.",
  "updated_at": "2026-05-13T14:30:05-03:00"
}
```

**Response 200:**
```json
{
  "registro": { "...campos atualizados..." },
  "edicoes_realizadas": [
    {
      "campo": "comportamento_observado",
      "valor_anterior": "Uso correto de procedimento de abordagem e verificação de crachás",
      "valor_novo": "Uso correto de procedimento de abordagem, verificação de crachás e orientação sobre uso de EPIs"
    },
    {
      "campo": "observacao_complementar",
      "valor_anterior": "Colaborador realizou conferência de todos os visitantes com atenção.",
      "valor_novo": "Colaborador demonstrou domínio completo dos protocolos de segurança."
    }
  ]
}
```

### 4.4 Payload de Cancelamento

**Request:**
```json
{
  "motivo": "Registro duplicado — OFS já havia sido lançada para este colaborador no mesmo horário"
}
```

**Response 200:**
```json
{
  "message": "Registro cancelado com sucesso.",
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "codigo": "OFS-2026-20-0001",
  "status": "Cancelado",
  "cancelado_em": "2026-05-13T17:00:00-03:00",
  "motivo_cancelamento": "Registro duplicado — OFS já havia sido lançada para este colaborador no mesmo horário"
}
```

### 4.5 Payload de Consulta

**Query Params:** `codigo`, `data_inicio`, `data_fim`, `semana`, `mes`, `ano`, `usuario_id`, `empresa_observada_id`, `contrato_id`, `turno`, `tipo_observacao`, `status_registro`, `busca` (FTS), `page`, `page_size`, `order_by`, `order_dir`

**Response 200:**
```json
{
  "data": [
    {
      "id": "uuid",
      "codigo": "OFS-2026-20-0001",
      "data_registro": "2026-05-13",
      "nome_observado": "Carlos Silva",
      "empresa_observada_id": 1,
      "turno": "Diurno",
      "tipo_observacao": "Positivo/Seguro",
      "status_registro": "Gerado",
      "usuario_nome_snapshot": "Carlos H. Oliveira",
      "criado_em": "2026-05-13T14:30:05-03:00"
    }
  ],
  "total": 47,
  "page": 1,
  "page_size": 25,
  "total_pages": 2
}
```

---

## 5. Validações

### 5.1 Regras por Campo

| Campo | Validação | Mensagem de Erro |
|-------|-----------|-----------------|
| `empresa_observada_id` | Deve existir na tabela companies | "Empresa inválida" |
| `empresa_observada_outros` | Obrigatório se empresa_observada_id = NULL | "Informe o nome da empresa observada" |
| `nome_observado` | Mínimo 3 caracteres | "Nome deve ter no mínimo 3 caracteres" |
| `atividade_observada` | Mínimo 5 caracteres | "Atividade deve ter no mínimo 5 caracteres" |
| `local_observado` | Mínimo 3 caracteres | "Local deve ter no mínimo 3 caracteres" |
| `turno` | Deve estar na lista permitida | "Turno inválido" |
| `tipo_observacao` | Apenas 'Positivo/Seguro' ou 'Negativo/Inseguro' | "Tipo deve ser Positivo/Seguro ou Negativo/Inseguro" |
| `comportamento_observado` | Mínimo 5 caracteres | "Descreva o comportamento (mínimo 5 caracteres)" |
| `data_registro` | Não pode ser data futura | "Data de registro não pode ser futura" |

### 5.2 Schema Pydantic

```python
from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Optional
from datetime import date, datetime

class OfcCreateRequest(BaseModel):
    empresa_observada_id: Optional[int] = None
    empresa_observada_outros: Optional[str] = Field(None, max_length=150)
    nome_observado: str = Field(..., min_length=3, max_length=200)
    atividade_observada: str = Field(..., min_length=5, max_length=300)
    local_observado: str = Field(..., min_length=3, max_length=200)
    contrato_id: Optional[int] = None
    turno: str = Field(..., min_length=1, max_length=50)
    tipo_observacao: str = Field(..., pattern=r'^(Positivo/Seguro|Negativo/Inseguro)$')
    comportamento_observado: str = Field(..., min_length=5)
    observacao_complementar: Optional[str] = None
    data_registro: date = Field(default_factory=date.today)

    @field_validator('data_registro')
    @classmethod
    def data_nao_futura(cls, v: date) -> date:
        if v > date.today():
            raise ValueError('Data de registro não pode ser futura')
        return v

    @model_validator(mode='after')
    def validar_outros(self):
        if self.empresa_observada_id is None:
            if not self.empresa_observada_outros or not self.empresa_observada_outros.strip():
                raise ValueError('Campo empresa_observada_outros é obrigatório quando "Outros" é selecionado')
        return self
```

---

## 6. Regras de Permissão

### 6.1 Matriz Completa

| Ação | Observador | Supervisor | Gestor | Admin |
|------|:---:|:---:|:---:|:---:|
| Criar OFS | ✅ | ✅ | ✅ | ✅ |
| Ver OFCs | 🔹 seus | 🔸 empresa | ✅ todos | ✅ todos |
| Ver Detalhe | 🔹 seu | 🔸 empresa | ✅ | ✅ |
| Editar OFS | 🔹⏱ seu, 24h | 🔸⏱ empresa, 48h | ✅ sem limite | ✅ sem limite |
| Cancelar OFS | ❌ | ❌ | ✅ | ✅ |
| Restaurar OFS | ❌ | ❌ | ❌ | ✅ |
| PDF Individual | 🔹 seu | 🔸 empresa | ✅ | ✅ |
| Exportar CSV | 🔹 seus | 🔸 empresa | ✅ | ✅ |

- 🔹 Escopo: apenas registros próprios
- 🔸 Escopo: apenas registros da empresa
- ⏱ Com janela de tempo

### 6.2 Data Scoping (Código)

```python
def apply_data_scope(query, user):
    if user.role == 'observador':
        return query.where(OfcRecord.generated_by == user.id, OfcRecord.is_deleted == False)
    elif user.role == 'supervisor':
        return query.where(OfcRecord.company_id == user.company_id, OfcRecord.is_deleted == False)
    elif user.role == 'gestor':
        return query.where(OfcRecord.is_deleted == False)
    return query  # admin: sem filtro

def can_edit_ofc(OFS: OfcRecord, user: User) -> bool:
    if user.role in ('gestor', 'admin'):
        return True
    if OFS.status_registro == 'Cancelado':
        return False
    if user.role == 'observador' and OFS.generated_by != user.id:
        return False
    if user.role == 'supervisor' and OFS.company_id != user.company_id:
        return False
    window = {'observador': timedelta(hours=24), 'supervisor': timedelta(hours=48)}.get(user.role)
    if window and (datetime.now(timezone.utc) - OFS.created_at) > window:
        return False
    return True
```

---

## 7. Auditoria e Rastreabilidade

### 7.1 Eventos Auditados

| Evento | Ação | Severidade | Dados |
|--------|------|:---:|-------|
| Criar OFS | `OFC_CREATE` | INFO | ofc_id, codigo, tipo, empresa |
| Editar OFS | `OFC_UPDATE` | WARNING | ofc_id, campos_alterados (JSONB) |
| Cancelar OFS | `OFC_CANCEL` | WARNING | ofc_id, motivo |
| Restaurar OFS | `OFC_RESTORE` | CRITICAL | ofc_id, admin |
| Exportar PDF | `OFC_EXPORT_PDF` | INFO | ofc_id, codigo |
| Exportar CSV | `OFC_EXPORT_CSV` | INFO | filtros, quantidade |

### 7.2 Estrutura de Auditoria

```sql
-- Tabela de edições campo a campo
INSERT INTO ofc_edit_log (ofc_record_id, edited_by, field_changed, old_value, new_value)
VALUES (:ofc_id, :user_id, 'comportamento_observado', 'Valor antigo...', 'Valor novo...');

-- Tabela de auditoria geral
INSERT INTO audit_logs (user_id, username, action, resource, resource_id, details, severity)
VALUES (:user_id, :username, 'OFC_UPDATE', 'ofc_records', :ofc_id, 
        '{"campos_alterados": ["comportamento_observado", "observacao_complementar"], "edit_count": 2}',
        'WARNING');
```

### 7.3 Optimistic Locking

```python
async def update_ofc(ofc_id: UUID, data: OfcUpdateRequest, user: User, db: AsyncSession):
    OFS = await db.get(OfcRecord, ofc_id)
    
    # Verificar optimistic lock
    if data.updated_at and OFS.updated_at != data.updated_at:
        raise HTTPException(
            status_code=409,
            detail="Registro foi modificado por outro usuário. Recarregue e tente novamente."
        )
    
    # ... aplicar alterações e registrar ofc_edit_log ...
```

---

## 8. Estrutura das Telas

### 8.1 Tela Nova OFS/OFS

```
┌──────────────────────────────────────────────────────────────────┐
│ ← VOLTAR                           NOVA OFS/OFS                  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ INFORMAÇÕES AUTOMÁTICAS                                     │ │
│  │ Código: GERADO AO SALVAR  │ Data: 13/05/2026 │ Hora: 14:30  │ │
│  │ Gerado por: Carlos H. Oliveira (carlos.oliveira)             │ │
│  │ Perfil: Supervisor | Empresa: Security Dynamics              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  DADOS DA OBSERVAÇÃO                                              │
│                                                                   │
│  Empresa Observada *                 Nome do Observado *          │
│  ┌────────────────────────────┐     ┌──────────────────────────┐  │
│  │ Security Dynamics     ▾    │     │                          │  │
│  └────────────────────────────┘     └──────────────────────────┘  │
│                                                                   │
│  ⚠ Se "Outros" selecionado:                                      │
│  Nome da Empresa *                                                │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  Atividade Observada *              Local Observado *             │
│  ┌────────────────────────────┐     ┌──────────────────────────┐  │
│  │                            │     │                          │  │
│  └────────────────────────────┘     └──────────────────────────┘  │
│                                                                   │
│  Turno *                            Tipo da Observação *          │
│  ┌────────────────────────────┐     ○ Positivo / Seguro          │
│  │ Diurno                ▾    │     ● Negativo / Inseguro        │
│  └────────────────────────────┘                                   │
│                                                                   │
│  Comportamento Observado *                                        │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                                                            │   │
│  │                                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  Observação Complementar (opcional)                                │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │                                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌────────────┐                    ┌────────────────────┐         │
│  │ 💾 SALVAR  │                    │   ✕ CANCELAR       │         │
│  └────────────┘                    └────────────────────┘         │
│  * Campos obrigatórios                                            │
└──────────────────────────────────────────────────────────────────┘
```

### 8.2 Tela Consulta

```
┌──────────────────────────────────────────────────────────────────┐
│ CONSULTA DE REGISTROS                                            │
│                                                                   │
│  FILTROS                                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │ Código   │ │Data Iníc.│ │Data Fim  │ │Empresa ▾ │ │Turno ▾ │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                          │
│  │ Tipo   ▾ │ │Status  ▾ │ │Usuário ▾ │     [🔍 BUSCAR]          │
│  └──────────┘ └──────────┘ └──────────┘     [🗑 LIMPAR]          │
│                                                                   │
│  Resultados: 47 registros                                         │
│                                                                   │
│  ┌────────────┬──────────┬──────────┬──────┬──────┬──────┬──────┐ │
│  │ Código     │ Data     │Observado │Empr. │Turno │Tipo  │Status│ │
│  ├────────────┼──────────┼──────────┼──────┼──────┼──────┼──────┤ │
│  │OFS-26-20-01│13/05/2026│Carlos S. │SD    │Diurno│Posit.│Gerado│ │
│  │OFS-26-20-02│13/05/2026│Maria S.  │G4S   │Noturn│Negat.│Gerado│ │
│  │OFS-26-20-03│12/05/2026│Pedro L.  │ERA   │Adm.  │Posit.│Editad│ │
│  └────────────┴──────────┴──────────┴──────┴──────┴──────┴──────┘ │
│                                                                   │
│  ◀ Página 1 de 2 ▶                                25/página ▾    │
└──────────────────────────────────────────────────────────────────┘
```

### 8.3 Tela Visualização

```
┌──────────────────────────────────────────────────────────────────┐
│ ← VOLTAR              VISUALIZAR REGISTRO                        │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  OFS-2026-20-0001                    🟢 GERADO              │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────┐  ┌──────────────────────────────────┐    │
│  │ DADOS GERAIS        │  │ DADOS DA OBSERVAÇÃO              │    │
│  │ Data: 13/05/2026    │  │ Empresa: Security Dynamics       │    │
│  │ Hora: 14:30         │  │ Observado: Carlos Silva          │    │
│  │ Gerado por:         │  │ Atividade: Controle de acesso    │    │
│  │ Carlos H. Oliveira  │  │ Local: Portaria 01               │    │
│  │ Supervisor          │  │ Turno: Diurno                    │    │
│  │ Security Dynamics   │  │ Tipo: ✅ Positivo / Seguro       │    │
│  └─────────────────────┘  └──────────────────────────────────┘    │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ COMPORTAMENTO OBSERVADO                                     │   │
│  │ Uso correto de procedimento de abordagem e verificação de   │   │
│  │ crachás. Colaborador realizou conferência de todos os       │   │
│  │ visitantes com atenção.                                     │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ OBSERVAÇÃO COMPLEMENTAR                                     │   │
│  │ Colaborador demonstrou domínio completo dos protocolos.     │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ HISTÓRICO DE ALTERAÇÕES                                     │   │
│  │ Data       │ Usuário    │ Campo         │ De       │ Para   │   │
│  │ 13/05 16:4 │ Carlos O.  │ Comportamento │ Uso corr │ Uso co │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │📄 PDF    │ │✏ EDITAR  │ │⛔ CANCEL.│ │← VOLTAR  │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
└──────────────────────────────────────────────────────────────────┘
```

---

## 9. Índices Recomendados

```sql
-- Índice estrela (consultas e métricas)
CREATE INDEX idx_ofc_metrics_main ON ofc_records 
    (company_id, record_date, type) 
    WHERE is_deleted = FALSE AND status_registro != 'Cancelado';

-- Busca por código
CREATE UNIQUE INDEX idx_ofc_codigo ON ofc_records(codigo);

-- Consultas por período
CREATE INDEX idx_ofc_date ON ofc_records(data_registro DESC);
CREATE INDEX idx_ofc_week ON ofc_records(ano, semana);
CREATE INDEX idx_ofc_month ON ofc_records(ano, mes);

-- Filtros da consulta
CREATE INDEX idx_ofc_company ON ofc_records(empresa_observada_id);
CREATE INDEX idx_ofc_user ON ofc_records(usuario_id);
CREATE INDEX idx_ofc_type ON ofc_records(tipo_observacao);
CREATE INDEX idx_ofc_status ON ofc_records(status_registro);
CREATE INDEX idx_ofc_shift ON ofc_records(turno);

-- Full-text search (português)
CREATE INDEX idx_ofc_fts ON ofc_records USING GIN(
    to_tsvector('portuguese', 
        COALESCE(nome_observado,'') || ' ' || 
        COALESCE(comportamento_observado,'') || ' ' || 
        COALESCE(observacao_complementar,'') || ' ' ||
        COALESCE(atividade_observada,'') || ' ' ||
        COALESCE(local_observado,'')
    )
);

-- Histórico de edições
CREATE INDEX idx_edit_log_ofc ON ofc_edit_log(ofc_record_id, edited_at DESC);
```

---

## 10. Critérios de Aceite

### 10.1 Criação

- [ ] Formulário carrega em < 1 segundo
- [ ] Código gerado no formato `OFS-AAAA-SS-NNNN`
- [ ] Snapshots do usuário preenchidos automaticamente
- [ ] Data e hora do servidor (não do cliente)
- [ ] Dropdown de empresas contém 15 opções + "Outros"
- [ ] Selecionar "Outros" exige campo de nome
- [ ] Validação inline em todos os campos obrigatórios
- [ ] Toast verde após salvar com sucesso
- [ ] Registro aparece na lista imediatamente
- [ ] Tempo total de registro < 2 minutos

### 10.2 Edição

- [ ] Observador edita seu OFS em < 24h → sucesso
- [ ] Observador tenta editar após 24h → 409 "janela expirada"
- [ ] Supervisor edita OFS da empresa em < 48h → sucesso
- [ ] Gestor/Admin editam qualquer OFS sem limite
- [ ] Campos imutáveis bloqueados no formulário
- [ ] Histórico de edições visível no detalhe
- [ ] Optimistic locking impede conflito de edição simultânea

### 10.3 Cancelamento

- [ ] Apenas Gestor/Admin veem botão Cancelar
- [ ] Cancelamento exige motivo (mínimo 10 caracteres)
- [ ] Status muda para Cancelado
- [ ] Registro NÃO é excluído fisicamente
- [ ] Registro cancelado não aparece em métricas
- [ ] Auditoria registrada como WARNING

### 10.4 Consulta

- [ ] Todos os filtros funcionam (combinação AND)
- [ ] Busca textual retorna resultados relevantes
- [ ] Paginação funciona (25/página)
- [ ] Ações condicionais por perfil (editar, cancelar)
- [ ] Observador vê apenas seus registros
- [ ] Supervisor vê registros da empresa
- [ ] Gestor/Admin veem todos

### 10.5 Visualização

- [ ] Layout limpo, similar ao PDF
- [ ] Badge de status colorido
- [ ] Badge de tipo (Positivo verde, Negativo vermelho)
- [ ] Histórico de edições em tabela
- [ ] Botões condicionais por permissão

### 10.6 PDF Individual

- [ ] A4 retrato, logo SD no cabeçalho
- [ ] Todos os campos do registro visíveis
- [ ] Status e tipo com destaque visual
- [ ] Histórico de edições (se houver)
- [ ] Rodapé com data/hora, página, "Documento gerado automaticamente"
- [ ] Download com nome: `OFC_INDIVIDUAL_OFC-2026-20-0001_20260513.pdf`

### 10.7 Segurança e Auditoria

- [ ] NENHUM DELETE físico permitido (trigger bloqueia)
- [ ] Toda ação registrada em audit_logs
- [ ] Toda edição registrada em ofc_edit_log (campo a campo)
- [ ] Snapshots do usuário preservados mesmo se cadastro alterado
- [ ] Zero upload de arquivos (validado)

---

**Documento gerado em 13/05/2026.**
