# ESPECIFICAÇÃO DE SEGURANÇA E AUDITORIA — MÓDULO OFS/OFS

**Sistema:** Feedback Comportamental OFS/OFS
**Versão:** MVP 1.0
**Data:** 13/05/2026

---

## 1. MATRIZ DE PERMISSÕES — MÓDULO OFS

| Ação                    | Observador | Supervisor | Gestor | Admin |
|--------------------------|:----------:|:----------:|:------:|:-----:|
| Criar OFS                | ✅ | ✅ | ✅ | ✅ |
| Ver OFS                  | 🔹 (seus) | 🔹 (empresa) | ✅ | ✅ |
| Editar OFS               | ⏱ 24h (seus) | ⏱ 48h (empresa) | ✅ | ✅ |
| Cancelar OFS             | ❌ | ❌ | ✅ | ✅ |
| Restaurar OFS            | ❌ | ❌ | ❌ | ✅ |
| Exportar PDF (individual)| 🔹 (seus) | 🔹 (empresa) | ✅ | ✅ |
| Exportar PDF (semanal)   | ❌ | ❌ | ✅ | ✅ |
| Exportar CSV             | 🔹 (seus) | 🔹 (empresa) | ✅ | ✅ |
| Ver Métricas            | ❌ | 🔹 (empresa) | ✅ | ✅ |
| Ver Auditoria            | ❌ | ❌ | ❌ | ✅ |

**Legenda:**
- ✅ Permitido sem restrição
- ❌ Proibido
- 🔹 Permitido com restrição de escopo (próprios registros ou mesma empresa)
- ⏱ Permitido com janela de tempo

---

## 2. REGRAS DE JANELA DE EDIÇÃO

### 2.1 Política

| Perfil      | Escopo                     | Janela         |
|-------------|----------------------------|----------------|
| Observador  | Apenas registros próprios | 24 horas       |
| Supervisor  | Registros da empresa       | 48 horas       |
| Gestor      | Qualquer registro          | Sem limite     |
| Admin       | Qualquer registro          | Sem limite     |

### 2.2 Regras adicionais

- Registros com `status = 'cancelled'` nunca podem ser editados (exceto Admin via restauração)
- A janela conta a partir de `created_at`
- A verificação é server-side e imutável (não confia no frontend)

### 2.3 Código — `can_edit_ofc()`

```python
# core/permissions.py
from datetime import datetime, timezone, timedelta
from uuid import UUID

EDIT_WINDOWS: dict[str, timedelta | None] = {
    "observador": timedelta(hours=24),
    "supervisor": timedelta(hours=48),
    "gestor":     None,   # sem limite
    "admin":      None,   # sem limite
}

def can_edit_ofc(user: "User", OFS: "OfcRecord") -> tuple[bool, str | None]:
    """
    Verifica se o usuário pode editar o registro OFS.
    Retorna (permitido, motivo_recusa).

    Regras:
      1. Registro cancelado → somente Admin pode restaurar, ninguém edita
      2. Observador → apenas próprios registros + janela 24h
      3. Supervisor → apenas registros da empresa + janela 48h
      4. Gestor/Admin → sempre (exceto cancelado)
    """
    window = EDIT_WINDOWS.get(user.role)

    # Admin/Gestor sem limite? Tudo liberado, exceto cancelado
    if window is None:
        if OFS.status == "cancelled":
            return False, "Registro cancelado não pode ser editado. Use a função de restauração."
        return True, None

    # Verifica escopo
    if user.role == "observador" and OFS.observer_id != user.id:
        return False, "Observador só pode editar seus próprios registros."

    if user.role == "supervisor" and OFS.company_id != user.company_id:
        return False, "Supervisor só pode editar registros da sua empresa."

    # Verifica status
    if OFS.status == "cancelled":
        return False, "Registro cancelado não pode ser editado."

    # Verifica janela de tempo
    elapsed = datetime.now(timezone.utc) - OFS.created_at
    if elapsed > window:
        hours = window.total_seconds() / 3600
        return False, f"Janela de edição expirada ({int(hours)}h). Contate um Gestor ou Admin."

    return True, None
```

---

## 3. REGRAS DE CANCELAMENTO

### 3.1 Política

| Regra                          | Detalhe                                              |
|--------------------------------|------------------------------------------------------|
| Quem pode cancelar             | Apenas Gestor e Admin                                |
| Motivo obrigatório             | Mínimo 10 caracteres                                 |
| Tipo de exclusão               | Soft delete (`status = 'cancelled'`)                  |
| Exclusão física                | **Nunca permitida** (bloqueada por trigger)          |
| O que acontece                 | `status = 'cancelled'`, `cancel_reason = motivo`, `cancelled_by = user.id`, `cancelled_at = NOW()` |
| OFS cancelada visível?         | Não aparece em métricas, nem em listagens padrão    |
| Auditoria                      | Evento `OFC_CANCEL`, severidade `WARN`               |

### 3.2 Código — Cancelamento

```python
# api/OFS.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone
from pydantic import BaseModel, field_validator

class CancelOFCRequest(BaseModel):
    reason: str

    @field_validator("reason")
    @classmethod
    def reason_min_length(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 10:
            raise ValueError("Motivo do cancelamento deve ter no mínimo 10 caracteres.")
        return v


@router.patch("/api/OFS-records/{ofc_id}/cancel")
async def cancel_ofc(
    ofc_id: UUID,
    body: CancelOFCRequest,
    user: User = Depends(require_role("gestor", "admin")),
    db: AsyncSession = Depends(get_db),
):
    OFS = await db.get(OfcRecord, ofc_id)
    if not OFS:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Registro não encontrado")
    if OFS.status == "cancelled":
        raise HTTPException(status.HTTP_409_CONFLICT, "Registro já está cancelado")

    OFS.status = "cancelled"
    OFS.cancel_reason = body.reason.strip()
    OFS.cancelled_by = user.id
    OFS.cancelled_at = datetime.now(timezone.utc)
    OFS.updated_at = datetime.now(timezone.utc)

    await db.commit()

    # Auditoria assíncrona (background)
    await audit_log(
        db, user_id=user.id, username=user.full_name,
        action="OFC_CANCEL", resource="ofc_records",
        resource_id=str(ofc_id),
        details={"cancel_reason": body.reason},
        severity="WARN",
    )

    return {"message": "OFS cancelada com sucesso", "ofc_id": str(ofc_id)}
```

---

## 4. REGRAS DE RESTAURAÇÃO

### 4.1 Política

| Regra                    | Detalhe                                           |
|--------------------------|---------------------------------------------------|
| Quem pode restaurar      | **Apenas Admin**                                  |
| O que faz                | Reverte `status = 'open'`, limpa `cancel_reason`, `cancelled_by`, `cancelled_at` |
| Pré-condição             | Registro deve estar `status = 'cancelled'`         |
| Auditoria                | Evento `OFC_RESTORE`, severidade **CRITICAL**     |

### 4.2 Código — Restauração

```python
@router.patch("/api/OFS-records/{ofc_id}/restore")
async def restore_ofc(
    ofc_id: UUID,
    user: User = Depends(require_role("admin")),
    db: AsyncSession = Depends(get_db),
):
    OFS = await db.get(OfcRecord, ofc_id)
    if not OFS:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Registro não encontrado")
    if OFS.status != "cancelled":
        raise HTTPException(status.HTTP_409_CONFLICT, "Apenas registros cancelados podem ser restaurados")

    motivo_anterior = OFS.cancel_reason
    OFS.status = "open"
    OFS.cancel_reason = None
    OFS.cancelled_by = None
    OFS.cancelled_at = None
    OFS.updated_at = datetime.now(timezone.utc)

    await db.commit()

    await audit_log(
        db, user_id=user.id, username=user.full_name,
        action="OFC_RESTORE", resource="ofc_records",
        resource_id=str(ofc_id),
        details={
            "cancel_reason_anterior": motivo_anterior,
            "restored_by": user.full_name,
        },
        severity="CRITICAL",
    )

    return {"message": "OFS restaurada com sucesso", "ofc_id": str(ofc_id)}
```

---

## 5. ESTRUTURA DE AUDITORIA

### 5.1 Tabela `ofc_edit_log` — Histórico campo a campo

```sql
-- Migração: ajustar tabela existente para ser imutável (sem FK CASCADE)
ALTER TABLE ofc_edit_log
    DROP CONSTRAINT IF EXISTS ofc_edit_log_ofc_record_id_fkey,
    ALTER COLUMN ofc_record_id DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS ofc_sequential_number INT,
    ADD COLUMN IF NOT EXISTS edited_by_name VARCHAR(300);

COMMENT ON TABLE ofc_edit_log IS 'Histórico de alterações campo a campo nos registros OFS (imutável)';
COMMENT ON COLUMN ofc_edit_log.field_name IS 'Nome do campo alterado (ex: behavior_description)';
COMMENT ON COLUMN ofc_edit_log.old_value IS 'Valor anterior (NULL = campo estava vazio)';
COMMENT ON COLUMN ofc_edit_log.new_value IS 'Novo valor (NULL = campo foi limpo)';
COMMENT ON COLUMN ofc_edit_log.edited_by IS 'UUID do usuário que editou';
COMMENT ON COLUMN ofc_edit_log.edited_by_name IS 'Nome do usuário no momento da edição (snapshot)';

-- REVOKE UPDATE/DELETE no ofc_edit_log (imutável para a aplicação)
REVOKE UPDATE, DELETE ON ofc_edit_log FROM ofs_app;
```

### 5.2 Tabela `audit_logs` — Log de eventos do sistema

```sql
CREATE TABLE IF NOT EXISTS audit_logs (
    id              BIGSERIAL       PRIMARY KEY,
    timestamp       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    user_id         UUID            REFERENCES users(id) ON DELETE SET NULL,
    username        VARCHAR(300),
    action          VARCHAR(50)     NOT NULL,
    entity          VARCHAR(100)    NOT NULL,
    entity_id       VARCHAR(255),
    details         JSONB           NOT NULL DEFAULT '{}',
    ip_address      VARCHAR(45),
    user_agent      TEXT,
    severity        VARCHAR(20)     NOT NULL DEFAULT 'INFO'
                                    CHECK (severity IN ('INFO','WARN','CRITICAL')),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS 'Log de auditoria de todas as ações críticas do sistema (imutável)';
COMMENT ON COLUMN audit_logs.action IS 'Código da ação: OFC_CREATE, OFC_UPDATE, OFC_CANCEL, OFC_RESTORE, OFC_EXPORT_PDF, OFC_EXPORT_CSV, etc.';
COMMENT ON COLUMN audit_logs.entity IS 'Entidade afetada: ofc_records, users, companies, etc.';
COMMENT ON COLUMN audit_logs.severity IS 'INFO = rotina | WARN = modificação/cancelamento | CRITICAL = restauração/backup';

-- Índices
CREATE INDEX IF NOT EXISTS idx_audit_ts          ON audit_logs (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_user        ON audit_logs (user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_action       ON audit_logs (action, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity       ON audit_logs (entity, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_severity     ON audit_logs (severity, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_details      ON audit_logs USING GIN (details);

-- Imutável para a aplicação
REVOKE UPDATE, DELETE ON audit_logs FROM ofs_app;
```

### 5.3 Eventos auditados

| Código            | Severity  | Gatilho                              |
|--------------------|:---------:|--------------------------------------|
| `OFC_CREATE`       | INFO      | Novo registro OFS                    |
| `OFC_UPDATE`       | WARN      | Edição de registro OFS               |
| `OFC_CANCEL`       | WARN      | Cancelamento (soft delete)           |
| `OFC_RESTORE`      | CRITICAL  | Restauração de OFS cancelada         |
| `OFC_EXPORT_PDF`   | INFO      | Geração de PDF individual/semanal    |
| `OFC_EXPORT_CSV`   | INFO      | Exportação CSV da consulta           |
| `LOGIN_SUCCESS`    | INFO      | Login bem-sucedido                   |
| `LOGIN_FAILED`     | WARN      | Tentativa de login com falha         |
| `PERMISSION_DENIED`| WARN      | Acesso negado (403)                  |

---

## 6. CÓDIGO PYTHON — AUDITORIA

### 6.1 Função central de escrita de auditoria

```python
# core/audit.py
from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def write_audit_log(
    db: AsyncSession,
    *,
    user_id: UUID | None,
    username: str | None,
    action: str,
    entity: str,
    entity_id: str | None = None,
    details: dict[str, Any] | None = None,
    ip_address: str | None = None,
    user_agent: str | None = None,
    severity: str = "INFO",
) -> None:
    """Insere registro na tabela audit_logs. Não bloqueia a resposta principal."""
    await db.execute(
        text("""
            INSERT INTO audit_logs
                (timestamp, user_id, username, action, entity, entity_id, details,
                 ip_address, user_agent, severity, created_at)
            VALUES
                (:ts, :uid, :uname, :action, :entity, :eid, :details::jsonb,
                 :ip, :ua, :severity, :ts)
        """),
        {
            "ts": datetime.now(timezone.utc),
            "uid": user_id,
            "uname": username,
            "action": action,
            "entity": entity,
            "eid": entity_id,
            "details": json.dumps(details or {}),
            "ip": ip_address,
            "ua": user_agent,
            "severity": severity,
        },
    )
    await db.commit()
```

### 6.2 Decorator `@audit_ofc_action`

```python
# core/decorators.py
from functools import wraps
from typing import Callable, Any
from uuid import UUID

from fastapi import Request

from core.audit import write_audit_log


def audit_ofc_action(action: str, severity: str = "INFO"):
    """Decorator para endpoints que manipulam OFS.

    Uso:
        @router.put("/{ofc_id}")
        @audit_ofc_action("OFC_UPDATE", severity="WARN")
        async def update_ofc(ofc_id: UUID, ...):
            ...

    O decorator extrai automaticamente:
        - user_id e username do dependency current_user
        - ofc_id do path parameter
        - ip e user_agent do request
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args: Any, **kwargs: Any) -> Any:
            result = await func(*args, **kwargs)

            # Extrai user e request dos kwargs (injetados por Depends)
            current_user = None
            request = None
            ofc_id = kwargs.get("ofc_id", None)

            for v in kwargs.values():
                if hasattr(v, "role") and hasattr(v, "id"):
                    current_user = v
                if isinstance(v, Request):
                    request = v

            if current_user is not None:
                # Obtém db da closure (assume que o endpoint tem db: AsyncSession = Depends)
                db = kwargs.get("db")
                if db:
                    await write_audit_log(
                        db,
                        user_id=current_user.id if hasattr(current_user, "id") else None,
                        username=getattr(current_user, "full_name", None),
                        action=action,
                        entity="ofc_records",
                        entity_id=str(ofc_id) if ofc_id else None,
                        ip_address=request.client.host if request and request.client else None,
                        user_agent=request.headers.get("user-agent") if request else None,
                        severity=severity,
                    )

            return result
        return wrapper
    return decorator
```

### 6.3 Middleware de auditoria (403/401 automático)

```python
# middleware/audit_middleware.py
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response
from starlette.background import BackgroundTask

from core.audit import write_audit_log


class AuditMiddleware(BaseHTTPMiddleware):
    """Captura automaticamente 401 e 403 para log de PERMISSION_DENIED."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        response = await call_next(request)

        if response.status_code in (401, 403):
            async def _log():
                from core.database import async_session_factory
                async with async_session_factory() as db:
                    await write_audit_log(
                        db,
                        user_id=None,
                        username=None,
                        action="PERMISSION_DENIED" if response.status_code == 403 else "LOGIN_FAILED",
                        entity="auth",
                        entity_id=None,
                        details={
                            "path": str(request.url.path),
                            "method": request.method,
                            "status_code": response.status_code,
                        },
                        ip_address=request.client.host if request.client else None,
                        user_agent=request.headers.get("user-agent"),
                        severity="WARN",
                    )
            response.background = BackgroundTask(_log)

        return response
```

### 6.4 Função de registro de edição campo a campo

```python
# core/edit_tracker.py
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


FIELDS_TO_TRACK = [
    "observed_name",
    "observation_date",
    "shift",
    "classification",
    "severity",
    "behavior_description",
    "context",
    "location",
    "activity_context",
    "competency_id",
    "department_id",
    "cycle_id",
]


def diff_ofc_fields(before: dict[str, Any], after: dict[str, Any]) -> list[dict[str, Any]]:
    """Compara valores antes/depois e retorna lista de alterações."""
    changes = []
    for field in FIELDS_TO_TRACK:
        old_val = before.get(field)
        new_val = after.get(field)

        # Normaliza para comparação
        old_str = str(old_val) if old_val is not None else None
        new_str = str(new_val) if new_val is not None else None

        if old_str != new_str:
            changes.append({
                "field_name": field,
                "old_value": old_str,
                "new_value": new_str,
            })
    return changes


async def log_ofc_edits(
    db: AsyncSession,
    ofc_id: UUID,
    sequential_number: int,
    edited_by: UUID,
    edited_by_name: str,
    changes: list[dict[str, Any]],
) -> None:
    """Insere registros em ofc_edit_log para cada campo alterado."""
    if not changes:
        return

    now = datetime.now(timezone.utc)
    for ch in changes:
        await db.execute(
            text("""
                INSERT INTO ofc_edit_log
                    (ofc_record_id, ofc_sequential_number, edited_by, edited_by_name,
                     field_name, old_value, new_value, edited_at)
                VALUES
                    (:ofc_id, :seq, :editor, :editor_name,
                     :field, :old, :new, :ts)
            """),
            {
                "ofc_id": ofc_id,
                "seq": sequential_number,
                "editor": edited_by,
                "editor_name": edited_by_name,
                "field": ch["field_name"],
                "old": ch["old_value"],
                "new": ch["new_value"],
                "ts": now,
            },
        )


async def update_ofc_with_tracking(
    db: AsyncSession,
    OFS: "OfcRecord",
    update_data: dict[str, Any],
    edited_by: UUID,
    edited_by_name: str,
) -> list[dict[str, Any]]:
    """
    Atualiza um OFS com rastreamento campo a campo.
    Retorna a lista de alterações realizadas.

    Usar dentro do endpoint PUT /api/OFS-records/{id}:
        changes = await update_ofc_with_tracking(db, OFS, body.model_dump(exclude_unset=True), user.id, user.full_name)
        await db.commit()
        await audit_log(db, ..., action="OFC_UPDATE", details={"changes": changes})
    """
    before = {f: getattr(OFS, f, None) for f in FIELDS_TO_TRACK}
    after = {**before, **{k: v for k, v in update_data.items() if k in FIELDS_TO_TRACK}}

    changes = diff_ofc_fields(before, after)

    if not changes:
        return []

    # Aplica as alterações no objeto
    for field in FIELDS_TO_TRACK:
        if field in update_data:
            setattr(OFS, field, update_data[field])

    OFS.updated_at = datetime.now(timezone.utc)

    # Log das edições (mesma transação)
    await log_ofc_edits(
        db,
        ofc_id=OFS.id,
        sequential_number=OFS.sequential_number,
        edited_by=edited_by,
        edited_by_name=edited_by_name,
        changes=changes,
    )

    return changes
```

---

## 7. OPTIMISTIC LOCKING

### 7.1 Estratégia

Comparar `updated_at` enviado pelo cliente com o valor no banco antes de salvar.
Se diferente → outro usuário editou → retornar **409 Conflict**.

### 7.2 Código

```python
# core/optimistic_lock.py
from datetime import datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession


async def check_optimistic_lock(
    db: AsyncSession,
    ofc_id: UUID,
    client_updated_at: datetime,
) -> "OfcRecord":
    """
    Busca o OFS e verifica conflito de concorrência via updated_at.
    Se o updated_at do banco for diferente do enviado pelo cliente → 409.

    Uso no endpoint:
        OFS = await check_optimistic_lock(db, ofc_id, body.updated_at)
    """
    result = await db.execute(
        select(OfcRecord).where(OfcRecord.id == ofc_id)
    )
    OFS = result.scalar_one_or_none()

    if not OFS:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Registro não encontrado")

    # Compara com precisão de microsegundos (PostgreSQL TIMESTAMPTZ)
    if OFS.updated_at != client_updated_at:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            detail={
                "error": "concurrency_conflict",
                "message": "Registro foi modificado por outro usuário. Recarregue e tente novamente.",
                "server_updated_at": OFS.updated_at.isoformat(),
                "client_updated_at": client_updated_at.isoformat(),
            },
        )

    return OFS


# Schema Pydantic que exige updated_at no request de edição
# class UpdateOfcRequest(BaseModel):
#     updated_at: datetime   # ← campo obrigatório para optimistic lock
#     behavior_description: str | None = None
#     ...
```

### 7.3 Endpoint completo com optimistic locking

```python
@router.put("/api/OFS-records/{ofc_id}")
@audit_ofc_action("OFC_UPDATE", severity="WARN")
async def update_ofc(
    ofc_id: UUID,
    body: UpdateOfcRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # 1. Verifica permissão + janela
    allowed, reason = can_edit_ofc(user, await db.get(OfcRecord, ofc_id))
    if not allowed:
        raise HTTPException(status.HTTP_403_FORBIDDEN, reason)

    # 2. Optimistic lock (409 se conflito)
    OFS = await check_optimistic_lock(db, ofc_id, body.updated_at)

    # 3. Aplica edições com rastreamento campo a campo
    changes = await update_ofc_with_tracking(
        db, OFS,
        update_data=body.model_dump(exclude={"updated_at"}, exclude_unset=True),
        edited_by=user.id,
        edited_by_name=user.full_name,
    )

    await db.commit()

    return {
        "message": "Registro atualizado com sucesso",
        "ofc_id": str(ofc_id),
        "fields_changed": len(changes),
        "updated_at": OFS.updated_at.isoformat(),
    }
```

---

## 8. PREVENÇÃO DE EXCLUSÃO FÍSICA

### 8.1 Trigger PostgreSQL

```sql
-- ============================================================================
-- TRIGGER: IMPEDE DELETE físico em ofc_records
-- A única forma de "remover" um registro é via soft delete (status = 'cancelled')
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_prevent_ofc_physical_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'EXCLUSAO_FISICA_BLOQUEADA: OFS #% não pode ser excluída fisicamente. '
                    'Use o fluxo de cancelamento (soft delete) via API.',
                    OLD.sequential_number;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_ofc_delete ON ofc_records;
CREATE TRIGGER trg_prevent_ofc_delete
    BEFORE DELETE ON ofc_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_ofc_physical_delete();

-- ============================================================================
-- TRIGGER: IMPEDE DELETE físico em ofc_edit_log (imutável)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_prevent_editlog_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'EXCLUSAO_FISICA_BLOQUEADA: Histórico de edição é imutável. '
                    'Registro de auditoria não pode ser removido.';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_editlog_delete ON ofc_edit_log;
CREATE TRIGGER trg_prevent_editlog_delete
    BEFORE DELETE ON ofc_edit_log
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_editlog_delete();

-- ============================================================================
-- TRIGGER: IMPEDE DELETE/UDPATE em audit_logs (imutável)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_prevent_audit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'AUDIT_LOG_IMUTAVEL: A tabela audit_logs é imutável. '
                    'Registros de auditoria não podem ser alterados ou removidos.';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_audit_update ON audit_logs;
CREATE TRIGGER trg_prevent_audit_update
    BEFORE UPDATE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_audit_mutation();

DROP TRIGGER IF EXISTS trg_prevent_audit_delete ON audit_logs;
CREATE TRIGGER trg_prevent_audit_delete
    BEFORE DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION fn_prevent_audit_mutation();
```

### 8.2 Teste de validação

```sql
-- Deve FALHAR com erro:
--   "EXCLUSAO_FISICA_BLOQUEADA: OFS #XX não pode ser excluída fisicamente."
DELETE FROM ofc_records WHERE id = '<algum-uuid>';

-- Deve FALHAR com erro:
--   "EXCLUSAO_FISICA_BLOQUEADA: Histórico de edição é imutável."
DELETE FROM ofc_edit_log WHERE ofc_record_id = '<algum-uuid>';

-- Deve FALHAR com erro:
--   "AUDIT_LOG_IMUTAVEL: A tabela audit_logs é imutável."
DELETE FROM audit_logs WHERE id = 1;
UPDATE audit_logs SET details = '{}' WHERE id = 1;

-- Única forma de "remover" um OFS:
UPDATE ofc_records SET status = 'cancelled', cancel_reason = '...', cancelled_by = '...', cancelled_at = NOW() WHERE id = '...';
```

---

## 9. RESUMO DE ARQUIVOS GERADOS

| Arquivo | Conteúdo |
|---------|----------|
| `ESPECIFICACAO_SEGURANCA_AUDITORIA_OFC.md` | Este documento |
| `migration_v3_audit_security.sql` | Migration SQL (triggers, tabelas, índices) |
| `core/permissions.py` | `can_edit_ofc()`, `EDIT_WINDOWS` |
| `core/audit.py` | `write_audit_log()` |
| `core/decorators.py` | `@audit_ofc_action` |
| `core/edit_tracker.py` | `diff_ofc_fields()`, `log_ofc_edits()`, `update_ofc_with_tracking()` |
| `core/optimistic_lock.py` | `check_optimistic_lock()` |
| `middleware/audit_middleware.py` | `AuditMiddleware` (captura 401/403) |

---

**Documento gerado em 13/05/2026.**
