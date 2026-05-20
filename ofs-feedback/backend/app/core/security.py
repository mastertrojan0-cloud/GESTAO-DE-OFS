import re
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from passlib.context import CryptContext
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import get_db
from app.models.user import User
from app.models import OfcRecord

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")
pwd_context = CryptContext(schemes=["bcrypt"], bcrypt__rounds=12, deprecated="auto")

ROLE_HIERARCHY = {
    "admin": 4,
    "gestor": 3,
    "supervisor": 2,
    "observador": 1,
}

EDIT_WINDOWS = {
    "observador": timedelta(hours=24),
    "supervisor": timedelta(hours=48),
    "gestor": None,
    "admin": None,
}


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def validate_password_strength(password: str) -> tuple[bool, Optional[str]]:
    if len(password) < 8:
        return False, "Senha deve ter no minimo 8 caracteres."
    if not re.search(r"[A-Z]", password):
        return False, "Senha deve conter ao menos 1 letra maiuscula."
    if not re.search(r"[a-z]", password):
        return False, "Senha deve conter ao menos 1 letra minuscula."
    if not re.search(r"\d", password):
        return False, "Senha deve conter ao menos 1 numero."
    return True, None


def create_access_token(user_id: str, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "role": role,
        "type": "access",
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "type": "refresh",
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token invalido ou expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        if payload.get("type") != "access":
            raise credentials_exception
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expirado.")
    except JWTError:
        raise credentials_exception

    user = await db.get(User, UUID(user_id))
    if user is None or not user.is_active:
        raise credentials_exception

    return user


def require_role(*roles: str):
    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Seu perfil nao tem permissao para esta acao.",
            )
        return current_user

    return role_checker


async def verify_ofc_access(
    ofc_id: UUID,
    current_user: User,
    db: AsyncSession,
) -> OfcRecord:
    OFS = await db.get(OfcRecord, ofc_id)
    if OFS is None or OFS.is_deleted:
        raise HTTPException(status_code=404, detail="OFS nao encontrada.")

    if current_user.role == "observador" and OFS.criado_por != current_user.id:
        raise HTTPException(status_code=403, detail="Sem acesso a este registro.")
    if current_user.role == "supervisor" and OFS.empresa_observada_id != current_user.company_id:
        raise HTTPException(status_code=403, detail="Sem acesso a registros de outra empresa.")

    return OFS


def get_data_scope(current_user: User) -> dict:
    if current_user.role == "observador":
        return {"criado_por": current_user.id, "is_deleted": False}
    elif current_user.role == "supervisor":
        return {"empresa_observada_id": current_user.company_id, "is_deleted": False}
    elif current_user.role == "gestor":
        return {"is_deleted": False}
    else:
        return {}


def get_admin_scope(current_user: User, resource_company_id_col: str = "company_id") -> dict:
    if current_user.role in ("admin",):
        return {}
    elif current_user.role == "gestor":
        return {resource_company_id_col: current_user.company_id}
    else:
        raise HTTPException(status_code=403, detail="Acesso negado.")


def can_edit_ofc(OFS: OfcRecord, user: User) -> bool:
    if OFS.is_deleted:
        return False
    if user.role in ("gestor", "admin"):
        return True
    if user.role == "supervisor" and OFS.empresa_observada_id == user.company_id:
        window = EDIT_WINDOWS["supervisor"]
        return datetime.now(timezone.utc) <= OFS.criado_em + window
    if user.role == "observador" and OFS.criado_por == user.id:
        window = EDIT_WINDOWS["observador"]
        return datetime.now(timezone.utc) <= OFS.criado_em + window
    return False


def can_cancel_ofc(user: User) -> bool:
    return user.role in ("gestor", "admin")


def decode_token(token: str, verify_exp: bool = True) -> dict:
    """Decodifica e valida token JWT. Lanca HTTPException se invalido."""
    try:
        options = {} if verify_exp else {"verify_exp": False}
        return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM], options=options)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado.")
    except JWTError:
        raise HTTPException(status_code=401, detail="Token invalido.")


PERMISSIONS = {
    "observador": ["OFS:create", "OFS:read_own", "OFS:edit_own_24h", "OFS:pdf_own"],
    "supervisor": ["OFS:create", "OFS:read_company", "OFS:edit_company_48h", "OFS:pdf_company",
                   "metrics:read_company", "reports:read_company"],
    "gestor": ["OFS:create", "OFS:read_all", "OFS:edit_all", "OFS:cancel", "OFS:pdf_all",
               "metrics:read_all", "reports:generate", "users:manage_company", "targets:manage"],
    "admin": ["*"],
}


def has_permission(user: User, permission: str) -> bool:
    perms = PERMISSIONS.get(user.role, [])
    if "*" in perms:
        return True
    return permission in perms


def has_any_permission(user: User, *permissions: str) -> bool:
    return any(has_permission(user, p) for p in permissions)


def require_permission(*permissions: str):
    async def checker(current_user: User = Depends(get_current_user)) -> User:
        if not has_any_permission(current_user, *permissions):
            raise HTTPException(status_code=403, detail="Permissao insuficiente.")
        return current_user
    return checker


async def change_password(user: User, current_password: str, new_password: str, db: AsyncSession) -> None:
    if not verify_password(current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Senha atual incorreta.")
    is_valid, msg = validate_password_strength(new_password)
    if not is_valid:
        raise HTTPException(status_code=422, detail=msg)
    user.password_hash = hash_password(new_password)
    db.add(user)


def check_lockout(user: User) -> None:
    if user.locked_until and user.locked_until > datetime.now(timezone.utc):
        bloqueio = user.locked_until.strftime("%d/%m/%Y %H:%M")
        raise HTTPException(status_code=423, detail=f"Usuario bloqueado ate {bloqueio}.")


def register_failed_attempt(user: User) -> None:
    user.login_attempts += 1
    if user.login_attempts >= settings.MAX_FAILED_ATTEMPTS:
        user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=settings.LOCKOUT_MINUTES)
        user.login_attempts = 0


def reset_lockout(user: User) -> None:
    user.login_attempts = 0
    user.locked_until = None


def can_restore_ofc(user: User) -> bool:
    return user.role == "admin"


def check_edit_window(OFS: OfcRecord, current_user: User) -> None:
    window = EDIT_WINDOWS.get(current_user.role)
    if window is None:
        return
    deadline = OFS.criado_em + window
    if datetime.now(timezone.utc) > deadline:
        horas = int(window.total_seconds() / 3600)
        raise HTTPException(
            status_code=403,
            detail=f"Janela de edicao expirada ({horas}h apos criacao).",
        )
