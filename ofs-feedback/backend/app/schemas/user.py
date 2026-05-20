from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator
import re


class UserCreateRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=100, pattern=r"^[a-z0-9._]+$")
    password: str = Field(..., min_length=8, max_length=128)
    full_name: str = Field(..., min_length=3, max_length=200)
    email: Optional[str] = Field(None, max_length=200, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    role: str = Field(..., pattern=r"^(observador|supervisor|gestor|admin)$")
    company_id: Optional[int] = None

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Senha deve conter pelo menos 1 letra maiuscula")
        if not re.search(r"[a-z]", v):
            raise ValueError("Senha deve conter pelo menos 1 letra minuscula")
        if not re.search(r"\d", v):
            raise ValueError("Senha deve conter pelo menos 1 numero")
        return v


class UserUpdateRequest(BaseModel):
    full_name: Optional[str] = Field(None, min_length=3, max_length=200)
    email: Optional[str] = Field(None, max_length=200)
    role: Optional[str] = Field(None, pattern=r"^(observador|supervisor|gestor|admin)$")
    company_id: Optional[int] = None
    is_active: Optional[bool] = None


class UserResponse(BaseModel):
    id: UUID
    username: str
    full_name: str
    email: Optional[str] = None
    role: str
    company_id: Optional[int] = None
    is_active: bool
    last_login: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def new_password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Senha deve conter pelo menos 1 letra maiuscula")
        if not re.search(r"[a-z]", v):
            raise ValueError("Senha deve conter pelo menos 1 letra minuscula")
        if not re.search(r"\d", v):
            raise ValueError("Senha deve conter pelo menos 1 numero")
        return v


class UserListItem(BaseModel):
    id: UUID
    username: str
    full_name: str
    role: str
    company_id: Optional[int] = None
    is_active: bool
    last_login: Optional[datetime] = None

    model_config = {"from_attributes": True}
