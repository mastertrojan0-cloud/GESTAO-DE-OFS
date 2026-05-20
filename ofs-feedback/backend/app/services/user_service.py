from datetime import datetime, timezone, timedelta
from typing import Optional, Any
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.password_history import PasswordHistory
from app.models.audit_log import AuditLog
from app.core.security import hash_password, verify_password, validate_password_strength


async def create_user(
    db: AsyncSession,
    data: Any,
    current_user: Optional[User] = None,
) -> User:
    existing = await db.execute(
        select(User).where(User.username == data.username)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username ja esta em uso.",
        )

    valid, msg = validate_password_strength(data.password)
    if not valid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=msg)

    now = datetime.now(timezone.utc)
    user = User(
        id=uuid4(),
        username=data.username,
        password_hash=hash_password(data.password),
        full_name=data.full_name,
        email=data.email,
        role=data.role,
        company_id=data.company_id,
        is_active=True,
        login_attempts=0,
        created_at=now,
        updated_at=now,
    )
    db.add(user)

    if current_user:
        await db.execute(
            select(AuditLog).where(False)
        )
        audit = AuditLog(
            timestamp=now,
            user_id=current_user.id,
            username=current_user.username,
            action="USER_CREATE",
            resource="users",
            resource_id=str(user.id),
            details={"username": user.username, "role": user.role},
            severity="INFO",
            created_at=now,
        )
        db.add(audit)

    await db.flush()
    await db.refresh(user)
    return user


async def get_user(
    db: AsyncSession,
    user_id: UUID,
) -> User:
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado.")
    return user


async def list_users(
    db: AsyncSession,
    role: Optional[str] = None,
    company_id: Optional[int] = None,
    is_active: Optional[bool] = None,
    page: int = 1,
    limit: int = 25,
) -> dict:
    query = select(User)

    if role:
        query = query.where(User.role == role)
    if company_id:
        query = query.where(User.company_id == company_id)
    if is_active is not None:
        query = query.where(User.is_active == is_active)

    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar() or 0

    query = query.order_by(User.full_name.asc())
    offset = (page - 1) * limit
    query = query.offset(offset).limit(limit)
    results = (await db.execute(query)).scalars().all()

    total_pages = (total + limit - 1) // limit if total > 0 else 0

    return {
        "data": list(results),
        "total": total,
        "page": page,
        "limit": limit,
        "total_pages": total_pages,
    }


async def update_user(
    db: AsyncSession,
    user_id: UUID,
    data: Any,
    current_user: Optional[User] = None,
) -> User:
    user = await get_user(db, user_id)
    now = datetime.now(timezone.utc)
    changed = {}

    if data.full_name is not None:
        if user.full_name != data.full_name:
            changed["full_name"] = {"old": user.full_name, "new": data.full_name}
            user.full_name = data.full_name
    if data.email is not None:
        if user.email != data.email:
            changed["email"] = {"old": user.email, "new": data.email}
            user.email = data.email
    if data.role is not None:
        if user.role != data.role:
            changed["role"] = {"old": user.role, "new": data.role}
            user.role = data.role
    if data.company_id is not None:
        if user.company_id != data.company_id:
            changed["company_id"] = {"old": user.company_id, "new": data.company_id}
            user.company_id = data.company_id
    if data.is_active is not None:
        if user.is_active != data.is_active:
            changed["is_active"] = {"old": user.is_active, "new": data.is_active}
            user.is_active = data.is_active

    if changed and current_user:
        audit = AuditLog(
            timestamp=now,
            user_id=current_user.id,
            username=current_user.username,
            action="USER_UPDATE",
            resource="users",
            resource_id=str(user.id),
            details={"changed": changed},
            severity="WARNING" if "role" in changed else "INFO",
            created_at=now,
        )
        db.add(audit)

    user.updated_at = now
    await db.flush()
    await db.refresh(user)
    return user


async def change_password(
    db: AsyncSession,
    user: User,
    current_password: str,
    new_password: str,
) -> None:
    if not verify_password(current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Senha atual incorreta.",
        )

    valid, msg = validate_password_strength(new_password)
    if not valid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=msg)

    if verify_password(new_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nova senha deve ser diferente da atual.",
        )

    now = datetime.now(timezone.utc)
    old_hash = user.password_hash

    user.password_hash = hash_password(new_password)
    user.updated_at = now
    user.password_expires_at = now + timedelta(days=90)

    pass_hist = PasswordHistory(
        user_id=user.id,
        password_hash=old_hash,
        changed_at=now,
    )
    db.add(pass_hist)

    audit = AuditLog(
        timestamp=now,
        user_id=user.id,
        username=user.username,
        action="PASSWORD_CHANGE",
        resource="users",
        resource_id=str(user.id),
        severity="WARNING",
        created_at=now,
    )
    db.add(audit)

    await db.flush()



