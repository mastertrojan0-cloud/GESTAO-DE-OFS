# core/edit_tracker.py
"""Rastreamento de edições campo a campo em OFS records."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, TYPE_CHECKING
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

if TYPE_CHECKING:
    from app.models import OfcRecord

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
    """Compara valores antes/depois e retorna lista de alterações detectadas."""
    changes = []
    for field in FIELDS_TO_TRACK:
        old_val = before.get(field)
        new_val = after.get(field)
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
    """Insere registros em ofc_edit_log para cada campo alterado (mesma transação)."""
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
    OFS: OfcRecord,
    update_data: dict[str, Any],
    edited_by: UUID,
    edited_by_name: str,
) -> list[dict[str, Any]]:
    """
    Atualiza um OFS com rastreamento campo a campo.

    Retorna a lista de alterações realizadas (vazia se nada mudou).
    """
    before = {f: getattr(OFS, f, None) for f in FIELDS_TO_TRACK}
    after = {**before, **{k: v for k, v in update_data.items() if k in FIELDS_TO_TRACK}}
    changes = diff_ofc_fields(before, after)

    if not changes:
        return []

    for field in FIELDS_TO_TRACK:
        if field in update_data:
            setattr(OFS, field, update_data[field])

    OFS.updated_at = datetime.now(timezone.utc)

    await log_ofc_edits(
        db,
        ofc_id=OFS.id,
        sequential_number=OFS.sequential_number,
        edited_by=edited_by,
        edited_by_name=edited_by_name,
        changes=changes,
    )

    return changes
