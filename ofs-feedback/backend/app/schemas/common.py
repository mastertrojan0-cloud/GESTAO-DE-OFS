from typing import Generic, TypeVar, Optional

from pydantic import BaseModel

T = TypeVar("T")


class PaginatedResponse(BaseModel, Generic[T]):
    data: list[T]
    total: int
    page: int
    limit: int
    total_pages: Optional[int] = None
