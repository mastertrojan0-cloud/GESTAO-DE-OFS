from datetime import date, time, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

from app.schemas.enums import TipoObservacao, Turno


class OfsCreateRequest(BaseModel):
    data_registro: date = Field(default_factory=date.today)
    hora_registro: Optional[time] = None
    contrato_id: Optional[int] = None
    empresa_observada_id: Optional[int] = None
    empresa_observada_outros: Optional[str] = Field(None, max_length=150)
    nome_observado: str = Field(..., min_length=3, max_length=200)
    atividade_observada: str = Field(..., min_length=5, max_length=300)
    local_observado: str = Field(..., min_length=3, max_length=200)
    turno: str = Field(..., min_length=1, max_length=50)
    tipo_observacao: str = Field(..., min_length=1, max_length=20)
    comportamento_observado: str = Field(..., min_length=5)
    observacao_complementar: Optional[str] = None

    @field_validator("data_registro")
    @classmethod
    def data_nao_futura(cls, v: date) -> date:
        if v > date.today():
            raise ValueError("Data de registro nao pode ser futura")
        return v

    @field_validator("tipo_observacao")
    @classmethod
    def validar_tipo(cls, v: str) -> str:
        if v not in ("Positivo/Seguro", "Negativo/Inseguro"):
            raise ValueError("Tipo de observacao invalido")
        return v

    @model_validator(mode="after")
    def validar_empresa_outros(self):
        if self.empresa_observada_id is None:
            if not self.empresa_observada_outros or not self.empresa_observada_outros.strip():
                raise ValueError(
                    'Campo "empresa_observada_outros" e obrigatorio quando nenhuma empresa '
                    'da lista e selecionada (Outros)'
                )
        return self


class OfsUpdateRequest(BaseModel):
    empresa_observada_id: Optional[int] = None
    empresa_observada_outros: Optional[str] = None
    nome_observado: Optional[str] = Field(None, min_length=3, max_length=200)
    atividade_observada: Optional[str] = Field(None, min_length=5, max_length=300)
    local_observado: Optional[str] = Field(None, min_length=3, max_length=200)
    turno: Optional[str] = None
    tipo_observacao: Optional[str] = None
    comportamento_observado: Optional[str] = Field(None, min_length=5)
    observacao_complementar: Optional[str] = None
    updated_at: datetime


class OfsCancelRequest(BaseModel):
    motivo_cancelamento: str = Field(..., min_length=10, description="Motivo do cancelamento (minimo 10 caracteres)")


class OfsEditLogEntry(BaseModel):
    field_changed: str
    old_value: Optional[str] = None
    new_value: Optional[str] = None
    edited_at: datetime

    model_config = {"from_attributes": True}


class OfsResponse(BaseModel):
    id: UUID
    codigo: str
    data_registro: date
    hora_registro: time
    semana: int
    mes: int
    ano: int
    usuario_id: UUID
    usuario_nome_snapshot: str
    usuario_login_snapshot: str
    usuario_email_snapshot: Optional[str] = None
    usuario_perfil_snapshot: str
    empresa_usuario_snapshot: Optional[str] = None
    contrato_id: Optional[int] = None
    empresa_observada_id: Optional[int] = None
    empresa_observada_outros: Optional[str] = None
    nome_observado: str
    atividade_observada: str
    local_observado: str
    turno: str
    tipo_observacao: str
    comportamento_observado: str
    observacao_complementar: Optional[str] = None
    status_registro: str
    is_deleted: bool
    edit_count: int
    criado_por: UUID
    criado_em: datetime
    editado_por: Optional[UUID] = None
    editado_em: Optional[datetime] = None
    cancelado_por: Optional[UUID] = None
    cancelado_em: Optional[datetime] = None
    motivo_cancelamento: Optional[str] = None
    updated_at: datetime

    model_config = {"from_attributes": True}


class OfsListItem(BaseModel):
    id: UUID
    codigo: str
    data_registro: date
    nome_observado: str
    empresa_observada_id: Optional[int] = None
    empresa_observada_outros: Optional[str] = None
    turno: str
    tipo_observacao: str
    status_registro: str
    usuario_nome_snapshot: str
    criado_em: datetime

    model_config = {"from_attributes": True}


class OfsDetailResponse(BaseModel):
    registro: OfsResponse
    edicoes: list[OfsEditLogEntry] = []


class OfsCancelResponse(BaseModel):
    message: str
    id: UUID
    codigo: str
    status: str
    cancelado_em: datetime
    motivo_cancelamento: Optional[str] = None


# ============================================================
# Filtros (query params para GET /ofs e GET /consulta)
# ============================================================
class OfsFiltros(BaseModel):
    data_inicio: Optional[date] = None
    data_fim: Optional[date] = None
    semana: Optional[int] = Field(None, ge=1, le=53)
    mes: Optional[int] = Field(None, ge=1, le=12)
    ano: Optional[int] = None
    empresa_observada_id: Optional[int] = None
    contrato_id: Optional[int] = None
    usuario_id: Optional[UUID] = None
    turno: Optional[str] = None
    tipo_observacao: Optional[str] = None
    status_registro: Optional[str] = None
    codigo: Optional[str] = None
    busca: Optional[str] = None
    page: int = Field(1, ge=1)
    page_size: int = Field(25, ge=1, le=100)
    order_by: str = "created_at"
    order_dir: str = "desc"

    model_config = {"from_attributes": True}


class OfsUpdateResponse(BaseModel):
    registro: OfsResponse
    edicoes_realizadas: list[OfsEditLogEntry] = []


class CancelResponse(BaseModel):
    message: str
    id: UUID
    status: str
    cancelado_em: datetime


EditLogEntry = OfsEditLogEntry


# ============================================================
# Aliases de compatibilidade (legacy)
# ============================================================
OFSCreate = OfsCreateRequest
OFSUpdate = OfsUpdateRequest
OFSFiltros = OfsFiltros
OFSResp = OfsResponse
OFSCancelRequest = OfsCancelRequest
OfsCreate = OfsCreateRequest
OfsUpdate = OfsUpdateRequest

# OFS legacy aliases
OfcCreateRequest = OfsCreateRequest
OfcUpdateRequest = OfsUpdateRequest
OfcCancelRequest = OfsCancelRequest
OfcEditLogEntry = OfsEditLogEntry
OfcResponse = OfsResponse
OfcListItem = OfsListItem
OfcDetailResponse = OfsDetailResponse
OfcCancelResponse = OfsCancelResponse
OfcFiltros = OfsFiltros
OfcUpdateResponse = OfsUpdateResponse
OFCCreate = OfsCreateRequest
OFCUpdate = OfsUpdateRequest
OFCFiltros = OfsFiltros
OFCResp = OfsResponse
OFCCancelRequest = OfsCancelRequest
OfcCreate = OfsCreateRequest
OfcUpdate = OfsUpdateRequest
