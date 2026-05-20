from datetime import datetime, timezone, date, timedelta
from typing import Optional, Any

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.target import Target
from app.models.user import User
from app.models.audit_log import AuditLog


async def get_current_target(
    db: AsyncSession,
    company_id: int,
    contract_id: Optional[int] = None,
) -> Optional[Target]:
    week_start = date.today() - timedelta(days=date.today().weekday())

    query = select(Target).where(
        Target.company_id == company_id,
        Target.week_start <= week_start,
        Target.is_active == True,
    ).order_by(Target.week_start.desc()).limit(1)

    if contract_id:
        query = query.where(Target.contract_id == contract_id)

    result = await db.execute(query)
    return result.scalar_one_or_none()


async def get_weekly_target(
    db: AsyncSession,
    company_id: int,
    contract_id: Optional[int] = None,
    year: Optional[int] = None,
    week: Optional[int] = None,
) -> list[Target]:
    query = select(Target).where(
        Target.company_id == company_id,
        Target.is_active == True,
    ).order_by(Target.week_start.desc())

    if contract_id:
        query = query.where(Target.contract_id == contract_id)
    if year:
        from datetime import date as dt_date
        jan1 = dt_date(year, 1, 1)
        jan1_weekday = jan1.weekday()
        if jan1_weekday <= 3:
            week1_start = jan1 - timedelta(days=jan1_weekday)
        else:
            week1_start = jan1 + timedelta(days=7 - jan1_weekday)
        data_inicio = week1_start + timedelta(weeks=week - 1)
        query = query.where(Target.week_start == data_inicio)

    result = await db.execute(query)
    return list(result.scalars().all())


async def create_target(
    db: AsyncSession,
    data: Any,
    current_user: User,
) -> Target:
    now = datetime.now(timezone.utc)

    if data.week_start.weekday() != 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="week_start deve ser uma segunda-feira.",
        )

    existing = await db.execute(
        select(Target).where(
            Target.company_id == data.company_id,
            Target.contract_id == data.contract_id,
            Target.week_start == data.week_start,
        )
    )
    existing_target = existing.scalar_one_or_none()

    if existing_target:
        existing_target.active_people = data.active_people
        existing_target.weekly_target = data.weekly_target
        existing_target.active_users = data.active_users
        existing_target.is_active = True
        existing_target.updated_at = now

        audit = AuditLog(
            timestamp=now,
            user_id=current_user.id,
            username=current_user.username,
            action="TARGET_UPDATE",
            resource="targets",
            resource_id=str(existing_target.id),
            details={
                "active_people": data.active_people,
                "weekly_target": data.weekly_target,
                "active_users": data.active_users,
            },
            severity="INFO",
            created_at=now,
        )
        db.add(audit)
        await db.flush()
        await db.refresh(existing_target)
        return existing_target

    target = Target(
        company_id=data.company_id,
        contract_id=data.contract_id,
        week_start=data.week_start,
        active_people=data.active_people,
        weekly_target=data.weekly_target,
        active_users=data.active_users,
        is_active=True,
        created_at=now,
        updated_at=now,
    )
    db.add(target)

    audit = AuditLog(
        timestamp=now,
        user_id=current_user.id,
        username=current_user.username,
        action="TARGET_CREATE",
        resource="targets",
        details={
            "company_id": data.company_id,
            "contract_id": data.contract_id,
            "week_start": data.week_start.isoformat(),
            "active_people": data.active_people,
            "weekly_target": data.weekly_target,
        },
        severity="INFO",
        created_at=now,
    )
    db.add(audit)

    await db.flush()
    await db.refresh(target)
    return target


async def deactivate_target(
    db: AsyncSession,
    target_id: int,
    current_user: User,
) -> Target:
    target = await db.get(Target, target_id)
    if not target:
        raise HTTPException(status_code=404, detail="Meta nao encontrada.")

    target.is_active = False
    target.updated_at = datetime.now(timezone.utc)

    audit = AuditLog(
        timestamp=datetime.now(timezone.utc),
        user_id=current_user.id,
        username=current_user.username,
        action="TARGET_DEACTIVATE",
        resource="targets",
        resource_id=str(target.id),
        severity="WARNING",
        created_at=datetime.now(timezone.utc),
    )
    db.add(audit)

    await db.flush()
    await db.refresh(target)
    return target
