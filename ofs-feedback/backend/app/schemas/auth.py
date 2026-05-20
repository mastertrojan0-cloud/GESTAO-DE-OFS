from pydantic import BaseModel


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: dict


class PasswordChange(BaseModel):
    current_password: str
    new_password: str
