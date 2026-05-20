from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class TargetCreateRequest(BaseModel):
    company_id: int
    contract_id: Optional[int] = None
    week_start: date
    active_people: int = Field(1, ge=0)
    weekly_target: int = Field(5, ge=1)
    active_users: int = Field(1, ge=0)

    @field_validator("week_start")
    @classmethod
    def week_start_must_be_monday(cls, v: date) -> date:
        if v.weekday() != 0:
            raise ValueError("week_start deve ser uma segunda-feira")
        return v


class TargetResponse(BaseModel):
    id: int
    company_id: int
    contract_id: Optional[int] = None
    week_start: date
    active_people: int
    weekly_target: int
    active_users: int
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}

    @property
    def programmed_ofc(self) -> int:
        return self.active_people * self.weekly_target
