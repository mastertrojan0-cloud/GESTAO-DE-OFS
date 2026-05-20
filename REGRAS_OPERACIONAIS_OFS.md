# REGRAS OPERACIONAIS — Módulo de Registros OFS/OFS

**Sistema:** Feedback Comportamental — Security Dynamics  
**Versão:** 3.0 (Normativa Completa)  
**Data:** 13/05/2026  
**Stack:** FastAPI + PostgreSQL 16 + React/TypeScript  
**Perfis:** Observador | Supervisor | Gestor | Admin  

---

## SUMÁRIO

1. [Regras de Criação](#1-regras-de-criação)
2. [Regras de Edição](#2-regras-de-edição)
3. [Regras de Cancelamento](#3-regras-de-cancelamento)
4. [Máquina de Estados (Status)](#4-máquina-de-estados-status)
5. [Validações Campo-a-Campo](#5-validações-campo-a-campo)
6. [Código Python — Pydantic Schema de Validação](#6-código-python--pydantic-schema-de-validação)
7. [Fluxogramas Textuais](#7-fluxogramas-textuais)

---

## 1. REGRAS DE CRIAÇÃO

### 1.1 Campos Automáticos (preenchidos pelo servidor, NÃO enviados pelo cliente)

| Campo | Origem | Formato | Descrição |
|-------|--------|---------|-----------|
| `id` | `gen_random_uuid()` | UUID v4 | Identificador único imutável |
| `codigo` | SEQUENCE PostgreSQL | `OFS-AAAA-SS-NNNN` | Código visível gerado por trigger |
| `data_registro` | `CURRENT_DATE` (servidor) | `YYYY-MM-DD` | Data do registro no fuso do servidor |
| `hora_registro` | `CURRENT_TIME` (servidor) | `HH:MM` | Hora do registro |
| `semana` | `EXTRACT(WEEK FROM data_registro)` | INT 1-53 | Calculado automaticamente via trigger |
| `mes` | `EXTRACT(MONTH FROM data_registro)` | INT 1-12 | Calculado automaticamente via trigger |
| `ano` | `EXTRACT(YEAR FROM data_registro)` | INT | Calculado automaticamente via trigger |
| `usuario_id` | JWT `sub` claim | UUID | Usuário autenticado que criou o registro |
| `usuario_nome_snapshot` | `current_user.nome` | VARCHAR 200 | Nome do usuário no momento da criação |
| `usuario_email_snapshot` | `current_user.email` | VARCHAR 200 | Email no momento da criação |
| `usuario_perfil_snapshot` | `current_user.perfil` | VARCHAR 20 | Perfil no momento da criação |
| `empresa_usuario_snapshot` | `current_user.empresa.nome` | VARCHAR 150 | Empresa do usuário no momento da criação |
| `criado_por` | `current_user.id` | UUID | Redundante com `usuario_id`, para clareza |
| `criado_em` | `NOW()` (servidor) | TIMESTAMPTZ | Timestamp exato da criação |
| `status_registro` | Constante `'Gerado'` | VARCHAR 20 | Status inicial de todo registro |

**REGRA CRÍTICA**: O frontend NUNCA envia data, hora, id, código, snapshots do usuário ou status. Todos esses campos são gerados exclusivamente pelo backend no momento da inserção. O cliente envia apenas os dados da observação em si.

### 1.2 Campos Obrigatórios (validados no backend)

| Campo | Validação | Mensagem de Erro |
|-------|-----------|------------------|
| `nome_observado` | NOT NULL, 3-200 caracteres | "Nome do observado é obrigatório (mínimo 3 caracteres)" |
| `atividade_observada` | NOT NULL, 5-300 caracteres | "Atividade observada é obrigatória (mínimo 5 caracteres)" |
| `turno` | NOT NULL, enum: `ADM`, `1`, `2`, `3` | "Turno é obrigatório. Valores: ADM, 1, 2, 3" |
| `tipo_observacao` | NOT NULL, enum: `OFS`, `OFS` | "Tipo é obrigatório. Valores: OFS, OFS" |
| `comportamento_observado` | NOT NULL, 5-2000 caracteres | "Comportamento observado é obrigatório (mínimo 5 caracteres)" |
| `empresa_observada_id` + `empresa_observada_outros` | Pelo menos um dos dois | Ver regra "Outros" abaixo |

### 1.3 Campos Opcionais

| Campo | Máximo | Observação |
|-------|--------|------------|
| `observacao_complementar` | 2000 caracteres | Campo texto livre |
| `contrato_id` | FK opcional | Vínculo a contrato |
| `local_id` | FK opcional | Vínculo a local cadastrado |
| `local_texto` | 200 caracteres | Texto livre se local não cadastrado |

### 1.4 REGRA "OUTROS" (Empresa não cadastrada)

```
┌────────────────────────────────────────────────────────────────┐
│ REGRA: Se empresa_observada_id NÃO for informado (NULL):       │
│                                                                 │
│   1. O campo empresa_observada_outros torna-se OBRIGATÓRIO     │
│   2. Deve conter no mínimo 3 caracteres                        │
│   3. Máximo 150 caracteres                                     │
│   4. Mensagem de erro:                                         │
│      "Selecione uma empresa ou informe o nome em 'Outros'"     │
│                                                                 │
│ Se empresa_observada_id FOR informado com valor diferente do   │
│ ID da empresa "Outros", o campo empresa_observada_outros será  │
│ ignorado (NULL).                                               │
└────────────────────────────────────────────────────────────────┘
```

### 1.5 Formato do Código: `OFS-AAAA-SS-NNNN`

```
OFS-2026-20-0001
│    │    │   │
│    │    │   └── NNNN: sequencial numérico com 4 dígitos (0001 a 9999)
│    │    │         reinicia a cada semana. Gerado por SEQUENCE no PostgreSQL
│    │    │         com reset programado (via função agendada).
│    │    └────── SS: número da semana ISO (01 a 53), extraído de data_registro
│    └─────────── AAAA: ano da data_registro (4 dígitos)
└──────────────── OFS: prefixo fixo do tipo de registro
```

**Geração automática via Trigger PostgreSQL:**

```sql
-- SEQUENCE global (incrementa sempre, NÃO reinicia sozinha)
CREATE SEQUENCE IF NOT EXISTS seq_ofc_codigo START 1;

-- Trigger BEFORE INSERT
CREATE OR REPLACE FUNCTION gerar_codigo_ofc()
RETURNS TRIGGER AS $$
DECLARE
    _ano INT;
    _semana INT;
    _seq INT;
BEGIN
    _ano    := EXTRACT(YEAR  FROM NEW.data_registro);
    _semana := EXTRACT(WEEK  FROM NEW.data_registro);
    _seq    := nextval('seq_ofc_codigo');
    NEW.codigo := 'OFS-' || LPAD(_ano::TEXT, 4, '0') || '-'
                       || LPAD(_semana::TEXT, 2, '0') || '-'
                       || LPAD(_seq::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ofc_codigo
    BEFORE INSERT ON ofc_registros
    FOR EACH ROW EXECUTE FUNCTION gerar_codigo_ofc();
```

**NOTA SOBRE O SEQUENCIAL:** No MVP, a sequência é global e nunca reinicia. Em fase futura, implementar reinício por semana (ex.: `OFS-2026-20-0001`, `OFS-2026-20-0002`... `OFS-2026-21-0001`).

### 1.6 Comportamento e Tipo

| Campo | Tipo Enum | Valores Permitidos | Significado |
|-------|-----------|-------------------|-------------|
| `tipo_observacao` | `TipoOFC` | `OFS` | Observação de Feedback Comportamental (comportamento seguro/positivo) |
| | | `OFS` | Observação de Feedback de Segurança (comportamento inseguro/desvio) |
| `comportamento_observado` | Texto livre | 5-2000 caracteres | Descrição detalhada do comportamento observado |

**RELAÇÃO SEMÂNTICA:**
- `OFS` (Tipo) geralmente associado a comportamento `seguro/positivo`
- `OFS` (Tipo) geralmente associado a comportamento `desvio/inseguro`
- O sistema NÃO impõe restrição rígida de combinação; o usuário escolhe ambos livremente.

---

## 2. REGRAS DE EDIÇÃO

### 2.1 Matriz de Permissão por Perfil

| Perfil | Pode editar? | Escopo | Janela de Tempo |
|--------|:---:|--------|:---------------:|
| **Observador** | ✅ | Apenas seus próprios registros | **24 horas** da criação |
| **Supervisor** | ✅ | Registros da sua empresa | **48 horas** da criação |
| **Gestor** | ✅ | Qualquer registro | **Sem limite** |
| **Admin** | ✅ | Qualquer registro | **Sem limite** |

### 2.2 Campos que NUNCA podem ser editados (IMUTÁVEIS)

| Campo | Motivo |
|-------|--------|
| `id` | Identificador primário |
| `codigo` | Código sequencial visível |
| `data_registro` | Data original do registro |
| `hora_registro` | Hora original do registro |
| `usuario_id` | Criador original do registro |
| `usuario_nome_snapshot` | Snapshot do criador |
| `usuario_email_snapshot` | Snapshot do criador |
| `usuario_perfil_snapshot` | Snapshot do criador |
| `empresa_usuario_snapshot` | Snapshot do criador |
| `criado_por` | FK do criador |
| `criado_em` | Timestamp de criação |
| `cancelado_por` | Preenchido apenas no cancelamento |
| `cancelado_em` | Preenchido apenas no cancelamento |
| `motivo_cancelamento` | Preenchido apenas no cancelamento |
| `is_deleted` | Controlado apenas por cancelamento/restauração |

### 2.3 Campos Editáveis

| Campo | Observação |
|-------|-----------|
| `nome_observado` | Não editável na versão atual do frontend; backend permite |
| `atividade_observada` | Não editável na versão atual do frontend; backend permite |
| `empresa_observada_id` | Editável, respeitando regra "Outros" |
| `empresa_observada_outros` | Editável |
| `contrato_id` | Editável |
| `local_id` | Editável |
| `local_texto` | Editável |
| `turno` | Editável |
| `tipo_observacao` | Editável |
| `comportamento_observado` | Editável (campo principal de edição) |
| `observacao_complementar` | Editável (campo secundário de edição) |

### 2.4 Otimistic Locking (Controle de Concorrência)

```
REGRA: Toda requisição PUT /api/OFS/{id} DEVE incluir o campo updated_at
exatamente como recebido na leitura (GET).

Se o updated_at do banco divergir do enviado pelo cliente:
  → HTTP 409 Conflict
  → Mensagem: "Este registro foi modificado por outro usuário.
               Recarregue os dados e tente novamente."
```

**Implementação:**
```python
if OFS.updated_at != payload.updated_at:
    raise HTTPException(status_code=409, detail="...")
```

### 2.5 Histórico de Edições (ofc_edit_log)

**Para CADA campo alterado, registrar:**

| Coluna | Conteúdo |
|--------|----------|
| `ofc_registro_id` | UUID do OFS editado |
| `campo_alterado` | Nome do campo (ex.: `comportamento_observado`) |
| `valor_anterior` | Valor antes da edição (TEXT, pode ser NULL) |
| `valor_novo` | Valor após a edição (TEXT, pode ser NULL) |
| `editado_por` | UUID do usuário que editou |
| `editado_em` | TIMESTAMPTZ da edição |

**Regras:**
1. Só registra se `valor_anterior != valor_novo` (comparação como string)
2. Múltiplos campos alterados geram múltiplas linhas (uma por campo)
3. O histórico NUNCA é apagado — é um log imutável
4. O status do OFS muda para `'Editado'` se pelo menos um campo foi alterado

### 2.6 Regra de Recusa de Edição

```
SE OFS.status_registro == 'Cancelado' OU OFS.is_deleted == TRUE:
    → HTTP 400: "Não é possível editar um registro cancelado."

SE OFS NÃO pertence ao escopo do usuário (data scope):
    → HTTP 403: "Sem acesso a este registro."

SE janela de edição expirada:
    → HTTP 403: "Janela de edição expirada (24h após criação)."
    → HTTP 403: "Janela de edição expirada (48h após criação)."
```

---

## 3. REGRAS DE CANCELAMENTO

### 3.1 Quem Pode Cancelar

| Perfil | Pode Cancelar? |
|--------|:---:|
| Observador | ❌ |
| Supervisor | ❌ |
| Gestor | ✅ (qualquer registro) |
| Admin | ✅ (qualquer registro) |

### 3.2 Soft Delete (NUNCA exclusão física)

```
┌────────────────────────────────────────────────────────────────┐
│ CANCELAMENTO = SOFT DELETE                                     │
│                                                                 │
│ O registro NUNCA é removido do banco. Ao cancelar:             │
│                                                                 │
│   is_deleted         = TRUE                                    │
│   cancelado_por      = current_user.id                         │
│   cancelado_em       = NOW()                                   │
│   motivo_cancelamento = payload.motivo (TEXT, obrigatório)     │
│   status_registro    = 'Cancelado'                             │
│                                                                 │
│ NENHUM DELETE físico é executado.                              │
└────────────────────────────────────────────────────────────────┘
```

### 3.3 Motivo Obrigatório

| Regra | Valor |
|-------|-------|
| Campo | `motivo_cancelamento` |
| Obrigatoriedade | **SIM, obrigatório** |
| Mínimo de caracteres | 10 |
| Máximo de caracteres | 500 |
| Mensagem de erro | "Motivo do cancelamento é obrigatório (mínimo 10 caracteres)" |

### 3.4 Impacto nas Métricas

```
REGRA: Registros cancelados (is_deleted = TRUE OU status_registro = 'Cancelado')
       NÃO entram em NENHUM cálculo de métricas.

WHERE is_deleted = FALSE AND status_registro != 'Cancelado'
                            ↑                    ↑
                      condição atual      condição redundante
                      (usada em índices   (garantia dupla)
                       parciais)
```

- Não contam em `OFS Realizadas`
- Não contam em `Positivas` / `Negativas`
- Não contam em `Usuários Ativos`
- Não aparecem em rankings
- Não entram em PDFs de métricas

### 3.5 Restauração (Apenas Admin)

```
┌────────────────────────────────────────────────────────────────┐
│ RESTAURAÇÃO: apenas Admin pode reverter um cancelamento.       │
│                                                                 │
│ Condições:                                                      │
│   • OFS.is_deleted == TRUE (registro está cancelado)           │
│                                                                 │
│ Após restaurar:                                                 │
│   is_deleted         = FALSE                                   │
│   restaurado_por     = current_user.id                         │
│   restaurado_em      = NOW()                                   │
│   status_registro    = 'Editado' (NÃO volta a 'Gerado')        │
│                                                                 │
│ A restauração é registrada em audit_logs como:                 │
│   action = "OFC_RESTORE", severity = "WARNING"                 │
└────────────────────────────────────────────────────────────────┘
```

**Regra adicional:** Um registro restaurado volta a contar nas métricas normalmente.

---

## 4. MÁQUINA DE ESTADOS (STATUS)

### 4.1 Estados Possíveis

| Estado | Significado | Quando ocorre |
|--------|------------|---------------|
| **Gerado** | Registro recém-criado, nunca editado nem cancelado | Status inicial ao criar |
| **Editado** | Registro que sofreu ao menos 1 edição | Após primeira edição bem-sucedida |
| **Cancelado** | Registro cancelado (soft-delete) | Após cancelamento por Gestor/Admin |

### 4.2 Transições Permitidas

```
                    ┌──────────┐
                    │  GERADO  │ ← status inicial (criação)
                    └────┬─────┘
                         │
              ┌──────────┼──────────┐
              │ EDITAR              │ CANCELAR
              ▼                     ▼
         ┌──────────┐         ┌────────────┐
         │ EDITADO  │         │ CANCELADO  │
         └────┬─────┘         └──────┬─────┘
              │                      │
              │ EDITAR novamente     │ RESTAURAR (Admin)
              ▼                      ▼
         ┌──────────┐         ┌──────────┐
         │ EDITADO  │         │ EDITADO  │  ← restaurado NÃO volta a Gerado
         └────┬─────┘         └──────────┘
              │
              │ CANCELAR
              ▼
         ┌────────────┐
         │ CANCELADO  │
         └────────────┘
```

### 4.3 Transições PROIBIDAS

| De | Para | Motivo |
|----|------|--------|
| Cancelado | Gerado | Restauração vai para Editado, nunca Gerado |
| Editado | Gerado | Uma vez editado, nunca volta ao estado original |
| Cancelado | Cancelado | Já está cancelado (HTTP 400) |
| Gerado → Cancelado por Observador/Supervisor | — | Apenas Gestor/Admin cancelam |

### 4.4 Impacto de Cada Status nas Consultas e Métricas

| Status | Visível em listagens? | Entra em métricas? | Pode ser editado? | Pode ser cancelado? |
|--------|:---:|:---:|:---:|:---:|
| **Gerado** | ✅ Sim | ✅ Sim | ✅ Sim (dentro da janela) | ✅ Sim (Gestor/Admin) |
| **Editado** | ✅ Sim | ✅ Sim | ✅ Sim (dentro da janela) | ✅ Sim (Gestor/Admin) |
| **Cancelado** | ⚠️ Apenas Admin vê por padrão | ❌ Não | ❌ Não | ❌ Não (já cancelado) |

---

## 5. VALIDAÇÕES CAMPO-A-CAMPO

### 5.1 Tabela Completa de Validações

| # | Campo | Tipo | Obrig. | Min | Max | Validação Específica | Mensagem de Erro |
|---|-------|------|:---:|:---:|:---:|----------------------|------------------|
| 1 | `nome_observado` | TEXT | ✅ | 3 | 200 | Sem HTML, sem caracteres de controle | "Nome do observado é obrigatório (mínimo 3 caracteres)" |
| 2 | `atividade_observada` | TEXT | ✅ | 5 | 300 | Sem HTML, sem caracteres de controle | "Atividade observada é obrigatória (mínimo 5 caracteres)" |
| 3 | `local_texto` | TEXT | ❌ | — | 200 | Sem HTML | — |
| 4 | `turno` | ENUM | ✅ | — | — | Valores: `ADM`, `1`, `2`, `3` | "Turno inválido. Valores: ADM, 1, 2, 3" |
| 5 | `tipo_observacao` | ENUM | ✅ | — | — | Valores: `OFS`, `OFS` | "Tipo inválido. Valores: OFS, OFS" |
| 6 | `comportamento_observado` | TEXT | ✅ | 5 | 2000 | Sem HTML | "Comportamento observado é obrigatório (mínimo 5 caracteres)" |
| 7 | `observacao_complementar` | TEXT | ❌ | — | 2000 | Sem HTML | — |
| 8 | `empresa_observada_id` | FK | ⚠️ | — | — | Deve ser ID válido em `empresas` OU NULL (se Outros) | "Empresa selecionada não encontrada" |
| 9 | `empresa_observada_outros` | TEXT | ⚠️ | 3 | 150 | Obrigatório SE `empresa_observada_id` for NULL | "Informe o nome da empresa em 'Outros'" |
| 10 | `contrato_id` | FK | ❌ | — | — | Deve ser ID válido em `contratos` | "Contrato selecionado não encontrado" |
| 11 | `local_id` | FK | ❌ | — | — | Deve ser ID válido em `locais` | "Local selecionado não encontrado" |
| 12 | `motivo_cancelamento` | TEXT | ✅ (no cancel.) | 10 | 500 | Obrigatório apenas no cancelamento | "Motivo do cancelamento é obrigatório (mínimo 10 caracteres)" |
| 13 | `updated_at` | TIMESTAMPTZ | ✅ (na edição) | — | — | Deve bater com o valor atual no banco (optimistic lock) | "Registro modificado por outro usuário" |

### 5.2 Sanitização de Strings (Aplicada a TODOS os campos TEXT)

```python
# 1. Remove caracteres de controle (ASCII 0-8, 11, 12, 14-31)
_sanitize_re = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")

# 2. Remove tags HTML
_html_re = re.compile(r"<[^>]*>")

def sanitize(value: str) -> str:
    value = value.strip()
    value = _sanitize_re.sub("", value)
    return value

def no_html(value: str) -> str:
    if _html_re.search(value):
        raise ValueError("Tags HTML não são permitidas.")
    return value
```

### 5.3 Validação Cruzada: Regra "Outros"

```python
@model_validator(mode='after')
def validar_regra_outros(self):
    if self.empresa_observada_id is None:
        if not self.empresa_observada_outros or len(self.empresa_observada_outros.strip()) < 3:
            raise ValueError(
                "Selecione uma empresa ou informe o nome em 'Outros' (mínimo 3 caracteres)"
            )
    return self
```

---

## 6. CÓDIGO PYTHON — PYDANTIC SCHEMA DE VALIDAÇÃO

```python
"""
schemas/ofc_record.py — Pydantic v2 schemas para registros OFS/OFS
Sistema: Security Dynamics — OFS/OFS
Versão: 3.0
"""
import re
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator


# ============================================================
# Constantes de validação
# ============================================================

TURNO_VALUES = frozenset({"ADM", "1", "2", "3"})
TIPO_OBSERVACAO_VALUES = frozenset({"OFS", "OFS"})
STATUS_VALUES = frozenset({"Gerado", "Editado", "Cancelado"})

_SANITIZE_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")
_HTML_RE = re.compile(r"<[^>]*>")


def _sanitize(value: str) -> str:
    """Remove espaços extras e caracteres de controle."""
    value = value.strip()
    value = _SANITIZE_RE.sub("", value)
    return value


def _no_html(value: str) -> str:
    """Rejeita strings que contenham tags HTML."""
    if _HTML_RE.search(value):
        raise ValueError("Tags HTML não são permitidas.")
    return value


# ============================================================
# Schema: Criação de OFS
# ============================================================

class OfcCreateRequest(BaseModel):
    """
    Schema para criação de novo registro OFS/OFS.
    Campos automáticos (id, código, data, hora, snapshots, status)
    NÃO são enviados pelo cliente — são gerados pelo backend.
    """

    # Empresa observada (regra "Outros")
    empresa_observada_id: Optional[UUID] = Field(
        None,
        description="ID da empresa observada. NULL = 'Outros' (campo texto obrigatório)"
    )
    empresa_observada_outros: Optional[str] = Field(
        None,
        min_length=3,
        max_length=150,
        description="Nome da empresa quando não está na lista. Obrigatório se empresa_observada_id for NULL."
    )

    # Dados do observado
    nome_observado: str = Field(
        ...,
        min_length=3,
        max_length=200,
        description="Nome completo da pessoa observada"
    )
    atividade_observada: str = Field(
        ...,
        min_length=5,
        max_length=300,
        description="Descrição da atividade que estava sendo realizada"
    )

    # Local
    local_id: Optional[int] = Field(
        None,
        description="ID do local cadastrado"
    )
    local_texto: Optional[str] = Field(
        None,
        max_length=200,
        description="Descrição do local (texto livre, se local_id não informado)"
    )

    # Classificação
    turno: str = Field(
        ...,
        min_length=1,
        max_length=3,
        description="Turno: ADM, 1, 2 ou 3"
    )
    tipo_observacao: str = Field(
        ...,
        min_length=3,
        max_length=3,
        description="Tipo: OFS ou OFS"
    )

    # Comportamento
    comportamento_observado: str = Field(
        ...,
        min_length=5,
        max_length=2000,
        description="Descrição detalhada do comportamento observado"
    )
    observacao_complementar: Optional[str] = Field(
        None,
        max_length=2000,
        description="Informações adicionais (opcional)"
    )

    # Contrato (opcional)
    contrato_id: Optional[int] = Field(
        None,
        description="ID do contrato associado (opcional)"
    )

    # ── Validators de sanitização ──

    @field_validator(
        "nome_observado",
        "atividade_observada",
        "comportamento_observado",
        "observacao_complementar",
        "local_texto",
        "empresa_observada_outros",
    )
    @classmethod
    def sanitize_text_fields(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        return _sanitize(v)

    @field_validator("nome_observado", "comportamento_observado")
    @classmethod
    def reject_html_in_critical_fields(cls, v: str) -> str:
        return _no_html(v)

    # ── Validators de enum ──

    @field_validator("turno")
    @classmethod
    def validate_turno(cls, v: str) -> str:
        if v not in TURNO_VALUES:
            raise ValueError(f"Turno inválido. Valores permitidos: {', '.join(sorted(TURNO_VALUES))}")
        return v

    @field_validator("tipo_observacao")
    @classmethod
    def validate_tipo_observacao(cls, v: str) -> str:
        if v not in TIPO_OBSERVACAO_VALUES:
            raise ValueError(f"Tipo inválido. Valores permitidos: {', '.join(sorted(TIPO_OBSERVACAO_VALUES))}")
        return v

    # ── Validator cruzado: regra "Outros" ──

    @model_validator(mode='after')
    def validate_empresa_outros_rule(self) -> "OfcCreateRequest":
        if self.empresa_observada_id is None:
            if not self.empresa_observada_outros or len(self.empresa_observada_outros.strip()) < 3:
                raise ValueError(
                    "Selecione uma empresa ou informe o nome em 'Outros' (mínimo 3 caracteres)"
                )
        return self


# ============================================================
# Schema: Edição de OFS
# ============================================================

class OfcUpdateRequest(BaseModel):
    """
    Schema para edição de registro OFS/OFS.
    Inclui updated_at para optimistic locking.
    """

    nome_observado: Optional[str] = Field(None, min_length=3, max_length=200)
    atividade_observada: Optional[str] = Field(None, min_length=5, max_length=300)
    empresa_observada_id: Optional[UUID] = None
    empresa_observada_outros: Optional[str] = Field(None, max_length=150)
    contrato_id: Optional[int] = None
    local_id: Optional[int] = None
    local_texto: Optional[str] = Field(None, max_length=200)
    turno: Optional[str] = Field(None, max_length=3)
    tipo_observacao: Optional[str] = Field(None, max_length=3)
    comportamento_observado: Optional[str] = Field(None, max_length=2000)
    observacao_complementar: Optional[str] = Field(None, max_length=2000)

    # Optimistic locking — obrigatório na edição
    updated_at: datetime = Field(
        ...,
        description="Timestamp da última leitura do registro (controle de concorrência)"
    )

    @field_validator("turno")
    @classmethod
    def validate_turno_optional(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in TURNO_VALUES:
            raise ValueError(f"Turno inválido. Valores permitidos: {', '.join(sorted(TURNO_VALUES))}")
        return v

    @field_validator("tipo_observacao")
    @classmethod
    def validate_tipo_optional(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in TIPO_OBSERVACAO_VALUES:
            raise ValueError(f"Tipo inválido. Valores permitidos: {', '.join(sorted(TIPO_OBSERVACAO_VALUES))}")
        return v

    @field_validator(
        "nome_observado", "atividade_observada",
        "comportamento_observado", "observacao_complementar",
        "local_texto", "empresa_observada_outros",
    )
    @classmethod
    def sanitize_text_fields(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        return _sanitize(v)


# ============================================================
# Schema: Cancelamento de OFS
# ============================================================

class OfcCancelRequest(BaseModel):
    """
    Schema para cancelamento (soft-delete) de registro OFS/OFS.
    Apenas Gestor e Admin podem cancelar.
    """

    motivo_cancelamento: str = Field(
        ...,
        min_length=10,
        max_length=500,
        description="Motivo detalhado do cancelamento (mínimo 10 caracteres)"
    )

    @field_validator("motivo_cancelamento")
    @classmethod
    def sanitize_motivo(cls, v: str) -> str:
        return _sanitize(v)


# ============================================================
# Schema: Resposta (Retorno da API)
# ============================================================

class OfcResponse(BaseModel):
    """Schema de resposta para leitura de OFS (GET)."""

    id: UUID
    codigo: str
    data_registro: str
    hora_registro: str
    semana: int
    mes: int
    ano: int

    # Snapshots do criador
    usuario_id: UUID
    usuario_nome_snapshot: str
    usuario_email_snapshot: Optional[str] = None
    usuario_perfil_snapshot: str
    empresa_usuario_snapshot: Optional[str] = None

    # Dados da observação
    empresa_observada_id: Optional[UUID] = None
    empresa_observada_outros: Optional[str] = None
    nome_observado: str
    atividade_observada: str
    local_id: Optional[int] = None
    local_texto: Optional[str] = None
    contrato_id: Optional[int] = None
    turno: str
    tipo_observacao: str
    comportamento_observado: str
    observacao_complementar: Optional[str] = None

    # Status e rastreabilidade
    status_registro: str
    is_deleted: bool
    criado_por: UUID
    criado_em: datetime
    editado_por: Optional[UUID] = None
    editado_em: Optional[datetime] = None
    cancelado_por: Optional[UUID] = None
    cancelado_em: Optional[datetime] = None
    motivo_cancelamento: Optional[str] = None
    restaurado_por: Optional[UUID] = None
    restaurado_em: Optional[datetime] = None
    updated_at: datetime

    model_config = {"from_attributes": True}


# ============================================================
# Schema: Filtros de Consulta
# ============================================================

class OfcFiltrosRequest(BaseModel):
    """Schema para filtros de listagem de OFCs."""

    codigo: Optional[str] = None
    data_inicio: Optional[str] = None
    data_fim: Optional[str] = None
    semana: Optional[int] = Field(None, ge=1, le=53)
    mes: Optional[int] = Field(None, ge=1, le=12)
    ano: Optional[int] = None
    usuario_id: Optional[UUID] = None
    empresa_observada_id: Optional[UUID] = None
    contrato_id: Optional[int] = None
    local_id: Optional[int] = None
    turno: Optional[str] = None
    tipo_observacao: Optional[str] = None
    status_registro: Optional[str] = None
    nome_observado: Optional[str] = None
    busca: Optional[str] = Field(None, description="Full-text search em português")
    page: int = Field(1, ge=1)
    limit: int = Field(25, ge=1, le=100)
    order_by: str = Field("data_registro", description="Campo para ordenação")
    order_dir: str = Field("desc", description="asc ou desc")
```

---

## 7. FLUXOGRAMAS TEXTUAIS

### 7.1 Fluxograma: Criação de OFS/OFS

```
┌─────────────────────────────────────────────────────────────────────┐
│                      FLUXO DE CRIAÇÃO                                │
│                                                                      │
│  INÍCIO                                                              │
│    │                                                                  │
│    ▼                                                                  │
│  [Usuário autenticado?] ──── NÃO ───▶ 401 Unauthorized              │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Perfil ≥ Observador?] ──── NÃO ───▶ 403 Forbidden                 │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Payload válido?] ──── NÃO ───▶ 422 Validation Error               │
│    │  ├─ nome_observado: min 3 chars?                                │
│    │  ├─ atividade_observada: min 5 chars?                           │
│    │  ├─ turno ∈ {ADM,1,2,3}?                                        │
│    │  ├─ tipo_observacao ∈ {OFS,OFS}?                                │
│    │  ├─ comportamento_observado: min 5 chars?                       │
│    │  ├─ empresa_observada_id XOR empresa_observada_outros?          │
│    │  ├─ Sem HTML injection?                                         │
│    │  └─ Sem caracteres de controle?                                 │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Gerar campos automáticos]:                                         │
│    ├─ id = gen_random_uuid()                                         │
│    ├─ data_registro = CURRENT_DATE (servidor)                        │
│    ├─ hora_registro = CURRENT_TIME (servidor)                        │
│    ├─ semana = EXTRACT(WEEK FROM data_registro)                      │
│    ├─ mes = EXTRACT(MONTH FROM data_registro)                        │
│    ├─ ano = EXTRACT(YEAR FROM data_registro)                         │
│    ├─ codigo = 'OFS-' || ano || '-' || semana || '-' || seq         │
│    ├─ usuario_id = current_user.id                                   │
│    ├─ usuario_nome_snapshot = current_user.nome                      │
│    ├─ usuario_email_snapshot = current_user.email                    │
│    ├─ usuario_perfil_snapshot = current_user.perfil                  │
│    ├─ empresa_usuario_snapshot = current_user.empresa.nome           │
│    ├─ criado_por = current_user.id                                   │
│    ├─ criado_em = NOW()                                              │
│    └─ status_registro = 'Gerado'                                     │
│    │                                                                  │
│    ▼                                                                  │
│  [INSERT INTO ofc_registros]                                         │
│    │                                                                  │
│    ▼                                                                  │
│  [Audit Log]: action="OFC_CREATE", severity="INFO"                   │
│    │                                                                  │
│    ▼                                                                  │
│  [Retornar 201 Created] com objeto completo                          │
│    │                                                                  │
│    ▼                                                                  │
│  FIM                                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.2 Fluxograma: Edição de OFS/OFS

```
┌─────────────────────────────────────────────────────────────────────┐
│                      FLUXO DE EDIÇÃO                                 │
│                                                                      │
│  INÍCIO: PUT /api/OFS/{id}                                          │
│    │                                                                  │
│    ▼                                                                  │
│  [Usuário autenticado?] ──── NÃO ───▶ 401                           │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [OFS existe?] ──── NÃO ───▶ 404 "OFS não encontrada"               │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [OFS está cancelada?] ──── SIM ───▶ 400 "Registro cancelado"       │
│    │  (is_deleted == TRUE)                                            │
│    NÃO                                                               │
│    │                                                                  │
│    ▼                                                                  │
│  [Usuário tem acesso ao escopo?]                                     │
│    ├─ Observador: OFS.usuario_id == user.id?                         │
│    ├─ Supervisor: OFS.empresa_id == user.empresa_id?                 │
│    └─ Gestor/Admin: sempre                                           │
│    │                                                                  │
│    NÃO ───▶ 403 "Sem acesso a este registro"                         │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Janela de edição válida?]                                          │
│    ├─ Observador: criado_em + 24h >= NOW?                            │
│    ├─ Supervisor: criado_em + 48h >= NOW?                            │
│    └─ Gestor/Admin: sem limite                                       │
│    │                                                                  │
│    NÃO ───▶ 403 "Janela de edição expirada (Xh)"                    │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Optimistic Lock]: payload.updated_at == OFS.updated_at?            │
│    │                                                                  │
│    NÃO ───▶ 409 "Registro modificado por outro usuário"              │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Para cada campo do payload que difere do original]:                │
│    ├─ Criar registro em ofc_edicoes                                  │
│    │   ├─ campo_alterado = nome do campo                             │
│    │   ├─ valor_anterior = valor atual no banco                      │
│    │   ├─ valor_novo = valor do payload                              │
│    │   ├─ editado_por = current_user.id                              │
│    │   └─ editado_em = NOW()                                         │
│    └─ Atualizar campo no registro OFS                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Se pelo menos 1 campo foi alterado]:                               │
│    ├─ status_registro = 'Editado'                                    │
│    ├─ editado_por = current_user.id                                  │
│    ├─ editado_em = NOW()                                             │
│    └─ updated_at = NOW()                                             │
│    │                                                                  │
│    ▼                                                                  │
│  [Audit Log]: action="OFC_UPDATE", severity="WARNING"                │
│    │                                                                  │
│    ▼                                                                  │
│  [Retornar 200 OK] com objeto completo + histórico de edições        │
│    │                                                                  │
│    ▼                                                                  │
│  FIM                                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.3 Fluxograma: Cancelamento de OFS/OFS

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FLUXO DE CANCELAMENTO                              │
│                                                                      │
│  INÍCIO: DELETE /api/OFS/{id}  (soft-delete)                        │
│    │                                                                  │
│    ▼                                                                  │
│  [Usuário autenticado?] ──── NÃO ───▶ 401                           │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Perfil ∈ {Gestor, Admin}?] ──── NÃO ───▶ 403                      │
│    │                                        "Apenas Gestor/Admin"     │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [OFS existe?] ──── NÃO ───▶ 404 "OFS não encontrada"               │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [OFS já está cancelada?] ──── SIM ───▶ 400 "OFS já cancelada"      │
│    │  (is_deleted == TRUE)                                            │
│    NÃO                                                               │
│    │                                                                  │
│    ▼                                                                  │
│  [motivo_cancelamento válido?] ──── NÃO ───▶ 422                    │
│    │  (mínimo 10 caracteres)          "Motivo obrigatório (min 10)"  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Executar SOFT DELETE]:                                             │
│    ├─ is_deleted = TRUE                                              │
│    ├─ status_registro = 'Cancelado'                                  │
│    ├─ cancelado_por = current_user.id                                │
│    ├─ cancelado_em = NOW()                                           │
│    ├─ motivo_cancelamento = payload.motivo                           │
│    └─ updated_at = NOW()                                             │
│    │                                                                  │
│    ▼                                                                  │
│  [Audit Log]: action="OFC_CANCEL", severity="WARNING"                │
│    │                                                                  │
│    ▼                                                                  │
│  [Retornar 200 OK] com mensagem de confirmação                       │
│    │                                                                  │
│    ▼                                                                  │
│  FIM                                                                  │
│                                                                      │
│  ═══════════════════════════════════════════════════════════════════ │
│                                                                      │
│  O REGISTRO NUNCA É EXCLUÍDO FISICAMENTE.                            │
│  O campo is_deleted = TRUE remove o registro das métricas            │
│  e da visualização padrão, mas ele permanece no banco.               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.4 Fluxograma: Restauração de OFS/OFS

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FLUXO DE RESTAURAÇÃO                               │
│                                                                      │
│  INÍCIO: POST /api/OFS/{id}/restore                                 │
│    │                                                                  │
│    ▼                                                                  │
│  [Usuário autenticado?] ──── NÃO ───▶ 401                           │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Perfil == Admin?] ──── NÃO ───▶ 403 "Apenas Admin"                │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [OFS existe E está cancelada?] ──── NÃO ───▶ 404                   │
│    │  (is_deleted == TRUE)              "OFS cancelada não encontrada"│
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Executar RESTAURAÇÃO]:                                             │
│    ├─ is_deleted = FALSE                                             │
│    ├─ status_registro = 'Editado'  ← NUNCA volta a 'Gerado'         │
│    ├─ restaurado_por = current_user.id                               │
│    ├─ restaurado_em = NOW()                                          │
│    └─ updated_at = NOW()                                             │
│    │                                                                  │
│    ▼                                                                  │
│  [Audit Log]: action="OFC_RESTORE", severity="WARNING"               │
│    │                                                                  │
│    ▼                                                                  │
│  [Retornar 200 OK] com mensagem de confirmação                       │
│    │                                                                  │
│    ▼                                                                  │
│  FIM                                                                  │
│                                                                      │
│  ═══════════════════════════════════════════════════════════════════ │
│                                                                      │
│  Após restauração, o registro volta a aparecer nas listagens         │
│  e a ser considerado nos cálculos de métricas.                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.5 Fluxograma: Consulta/Listagem de OFS

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FLUXO DE CONSULTA                                  │
│                                                                      │
│  INÍCIO: GET /api/OFS?filtros...&page=1&limit=25                    │
│    │                                                                  │
│    ▼                                                                  │
│  [Usuário autenticado?] ──── NÃO ───▶ 401                           │
│    │                                                                  │
│    SIM                                                                │
│    │                                                                  │
│    ▼                                                                  │
│  [Aplicar Data Scope por Perfil]:                                    │
│    ├─ Observador: WHERE usuario_gerador_id = user.id                 │
│    │              AND is_deleted = FALSE                             │
│    ├─ Supervisor:  WHERE empresa_id = user.empresa_id                │
│    │               AND is_deleted = FALSE                            │
│    ├─ Gestor:      WHERE is_deleted = FALSE                          │
│    │               (vê todas as empresas)                            │
│    └─ Admin:       sem filtro                                        │
│                    (vê inclusive cancelados se solicitado)           │
│    │                                                                  │
│    ▼                                                                  │
│  [Aplicar Filtros Opcionais]:                                        │
│    ├─ data_inicio / data_fim (range de datas)                       │
│    ├─ tipo_observacao (OFS ou OFS)                                   │
│    ├─ turno (ADM, 1, 2, 3)                                          │
│    ├─ status_registro (Gerado, Editado, Cancelado)                   │
│    ├─ empresa_observada_id                                           │
│    ├─ contrato_id                                                    │
│    ├─ usuario_id (gerador)                                           │
│    ├─ nome_observado (ILIKE %busca%)                                 │
│    └─ busca (full-text search em português)                          │
│    │                                                                  │
│    ▼                                                                  │
│  [Executar COUNT(*) para total]                                      │
│    │                                                                  │
│    ▼                                                                  │
│  [Executar SELECT com ORDER BY + OFFSET + LIMIT]                     │
│    │                                                                  │
│    ▼                                                                  │
│  [Retornar 200 OK] com:                                              │
│    {                                                                  │
│      data: [OfcResponse, ...],                                        │
│      total: 47,                                                       │
│      page: 1,                                                         │
│      limit: 25                                                        │
│    }                                                                  │
│    │                                                                  │
│    ▼                                                                  │
│  FIM                                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## APÊNDICE A — Resumo de Regras de Acesso (RBAC)

| Ação | Observador | Supervisor | Gestor | Admin |
|------|:---:|:---:|:---:|:---:|
| Criar OFS | ✅ | ✅ | ✅ | ✅ |
| Ver seus OFCs | ✅ | ✅ | ✅ | ✅ |
| Ver OFCs da empresa | ❌ | ✅ | ✅ | ✅ |
| Ver todos os OFCs | ❌ | ❌ | ✅ | ✅ |
| Editar OFS | Seu, 24h | Empresa, 48h | Sem limite | Sem limite |
| Cancelar OFS | ❌ | ❌ | ✅ | ✅ |
| Restaurar OFS | ❌ | ❌ | ❌ | ✅ |
| Ver cancelados | ❌ | ❌ | ❌ | ✅ |
| Exportar CSV | Seus | Empresa | Todos | Todos |

## APÊNDICE B — Endpoints do Módulo OFS

| Método | Path | Auth | Descrição |
|--------|------|:---:|-----------|
| `POST` | `/api/OFS` | Observador+ | Criar registro |
| `GET` | `/api/OFS` | Observador+ (escopo) | Listar com filtros |
| `GET` | `/api/OFS/{id}` | Observador+ (escopo) | Detalhe + histórico |
| `PUT` | `/api/OFS/{id}` | Observador+ (escopo + janela) | Editar |
| `DELETE` | `/api/OFS/{id}` | Gestor/Admin | Cancelar (soft-delete) |
| `POST` | `/api/OFS/{id}/restore` | Admin | Restaurar cancelado |
| `GET` | `/api/OFS/export/csv` | Observador+ (escopo) | Exportar CSV |

---

**Documento normativo gerado em 13/05/2026.**
**Versão 3.0 — Todas as regras operacionais do módulo OFS/OFS.**
