from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class WeeklyMetricsResponse(BaseModel):
    ano: int
    semana: int
    data_inicio: date
    data_fim: date
    empresa_id: Optional[int] = None
    empresa_nome: Optional[str] = None

    pessoas_ativas: int
    ofc_programadas: int
    ofc_realizadas: int
    ofc_positivas: int
    ofc_negativas: int
    aderencia_percentual: float
    percentual_seguro: float
    percentual_negativo: float
    percentual_desvio: Optional[float] = None  # legacy alias for percentual_negativo
    usuarios_ativos: int
    media_ofc_usuario: float
    status: str

    gerado_em: str
    gerado_por: str


class ChartDataItem(BaseModel):
    label: str
    value: float
    extra: Optional[dict] = None


class ChartDataResponse(BaseModel):
    chart: list[ChartDataItem]
    total: Optional[int] = None


class WeeklyEvolutionItem(BaseModel):
    semana: str
    programado: int
    realizado: int
    positivas: int
    negativas: int
    aderencia: float


class WeeklyEvolutionResponse(BaseModel):
    semanas: list[WeeklyEvolutionItem]


class CompanyRankingItem(BaseModel):
    empresa_id: int
    empresa_nome: str
    total: int
    positivas: int
    negativas: int
    percentual_seguro: float


class CompanyRankingResponse(BaseModel):
    ranking: list[CompanyRankingItem]


class UserRankingItem(BaseModel):
    usuario_id: UUID
    usuario_nome: str
    empresa_nome: str
    total: int
    positivas: int
    negativas: int


class UserRankingResponse(BaseModel):
    ranking: list[UserRankingItem]


class TopBehaviorItem(BaseModel):
    comportamento: str
    tipo: str
    count: int


class TopBehaviorsResponse(BaseModel):
    seguros: list[TopBehaviorItem] = []
    negativos: list[TopBehaviorItem] = []
    desvios: list[TopBehaviorItem] = []  # legacy alias for negativos


# ============================================================
# Aliases de compatibilidade (legacy API)
# ============================================================
ProgrammedVsRealizedResponse = ChartDataResponse
PositiveVsNegativeResponse = ChartDataResponse
ByCompanyResponse = CompanyRankingResponse
ByUserResponse = UserRankingResponse
ByShiftResponse = ChartDataResponse
