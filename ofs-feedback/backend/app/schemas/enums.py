from enum import Enum


class UserRole(str, Enum):
    OBSERVADOR = "observador"
    SUPERVISOR = "supervisor"
    GESTOR = "gestor"
    ADMIN = "admin"


class TipoObservacao(str, Enum):
    POSITIVO_SEGURO = "Positivo/Seguro"
    NEGATIVO_INSEGURO = "Negativo/Inseguro"


class Turno(str, Enum):
    DIURNO = "Diurno"
    NOTURNO = "Noturno"
    ADMINISTRATIVO = "Administrativo"
    TURNO_1 = "Turno 1"
    TURNO_2 = "Turno 2"
    TURNO_3 = "Turno 3"


class StatusRegistro(str, Enum):
    GERADO = "Gerado"
    EDITADO = "Editado"
    CANCELADO = "Cancelado"


class Severity(str, Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    CRITICAL = "CRITICAL"


class ReportType(str, Enum):
    INDIVIDUAL = "individual"
    SEMANAL = "semanal"
