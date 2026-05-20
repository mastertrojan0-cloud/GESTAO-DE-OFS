"""
api/auth.py — Endpoints de Autenticacao: login, refresh, logout, change-password.
Sistema OFS/OFS — Security Dynamics.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Body, Request
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select, update, and_
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone, timedelta
from uuid import UUID

from app.db.session import get_db
from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
    validate_password_strength,
    hash_password,
    verify_password,
    change_password as change_password_fn,
    check_lockout,
    register_failed_attempt,
    reset_lockout,
)
from app.core.audit import audit
from app.models.usuario import Usuario
from app.models.auth_models import LoginAttempt, RefreshToken
from app.schemas.auth import PasswordChange, TokenResponse

router = APIRouter(prefix="/api/auth", tags=["Autenticacao"])


def _safe_decode_refresh_token(token: str) -> dict:
    from jose import jwt, JWTError, ExpiredSignatureError

    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Token invalido.")
        return payload
    except ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Refresh token expirado.")
    except JWTError:
        raise HTTPException(status_code=401, detail="Token invalido.")


def _user_response(user: Usuario) -> dict:
    return {
        "id": str(user.id),
        "username": user.username,
        "full_name": user.full_name,
        "email": user.email,
        "role": user.role,
        "company_id": user.company_id,
        "is_active": user.is_active,
    }



@router.post("/login", response_model=TokenResponse)
@audit(action="LOGIN_SUCCESS", resource="AUTH", severity="INFO")
async def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Usuario).where(Usuario.username == form_data.username)
    )
    user = result.scalar_one_or_none()

    if not user:
        await _record_attempt(db, form_data.username, False, "user_not_found")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais invalidas.",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuario desativado. Contate o administrador.",
        )

    check_lockout(user)

    if not verify_password(form_data.password, user.password_hash):
        register_failed_attempt(user)
        await _record_attempt(db, form_data.username, False, "invalid_password")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais invalidas.",
        )

    if user.password_expires_at:
        if datetime.now(timezone.utc) > user.password_expires_at:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Senha expirada. Contate o administrador para redefinir.",
            )

    reset_lockout(user)
    await _record_attempt(db, form_data.username, True, None)

    access_token = create_access_token(str(user.id), user.role)
    refresh_token_str = create_refresh_token(str(user.id))

    refresh_token_hash = hash_password(refresh_token_str)
    db.add(RefreshToken(
        user_id=user.id,
        token_hash=refresh_token_hash,
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    ))
    await db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token_str,
        token_type="bearer",
        user=_user_response(user),
    )


@router.post("/refresh", response_model=TokenResponse)
@audit(action="TOKEN_REFRESH", resource="AUTH", severity="INFO")
async def refresh(
    request: Request,
    refresh_token: str = Body(..., embed=True),
    db: AsyncSession = Depends(get_db),
):
    payload = _safe_decode_refresh_token(refresh_token)
    user_id = payload.get("sub")

    result = await db.execute(
        select(RefreshToken).where(
            and_(RefreshToken.user_id == UUID(user_id), RefreshToken.revoked == False)
        )
    )
    candidate_tokens = result.scalars().all()
    stored_token = next(
        (t for t in candidate_tokens if verify_password(refresh_token, t.token_hash)),
        None,
    )
    if not stored_token:
        raise HTTPException(status_code=401, detail="Refresh token revogado ou invalido.")

    user = await db.get(Usuario, UUID(user_id))
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Usuario invalido ou desativado.")

    new_access = create_access_token(str(user.id), user.role)
    new_refresh = create_refresh_token(str(user.id))

    stored_token.revoked = True
    stored_token.revoked_at = datetime.now(timezone.utc)
    db.add(RefreshToken(
        user_id=user.id,
        token_hash=hash_password(new_refresh),
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    ))
    await db.commit()

    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        token_type="bearer",
        user=_user_response(user),
    )


@router.post("/logout")
@audit(action="LOGOUT", resource="AUTH", severity="INFO")
async def logout(
    request: Request,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        update(RefreshToken)
        .where(and_(RefreshToken.user_id == current_user.id, RefreshToken.revoked == False))
        .values(revoked=True, revoked_at=datetime.now(timezone.utc))
    )
    await db.commit()
    return {"message": "Logout realizado com sucesso."}


@router.post("/change-password")
@audit(action="PASSWORD_CHANGE", resource="AUTH", severity="WARN")
async def change_password_endpoint(
    request: Request,
    payload: PasswordChange,
    current_user: Usuario = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await change_password_fn(current_user, payload.current_password, payload.new_password, db)
    await db.commit()
    return {"message": "Senha alterada com sucesso."}


@router.get("/me")
async def me(
    current_user: Usuario = Depends(get_current_user),
):
    return _user_response(current_user)


async def _record_attempt(
    db: AsyncSession,
    username: str,
    success: bool,
    failure_reason: str | None,
):
    db.add(LoginAttempt(
        username=username,
        success=success,
        failure_reason=failure_reason,
        created_at=datetime.now(timezone.utc),
    ))
