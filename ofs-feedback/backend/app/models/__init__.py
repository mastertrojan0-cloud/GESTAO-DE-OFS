from app.models.company import Company
from app.models.user import User
from app.models.contract import Contract
from app.models.target import Target
from app.models.ofs_record import OfsRecord, OfsEditLog
from app.models.ofs_seq_control import OfsSeqControl
from app.models.audit_log import AuditLog
from app.models.password_history import PasswordHistory
from app.models.revoked_token import RevokedToken
from app.models.report import Report
from app.models.system_param import SystemParam

# Backward-compatibility aliases
OfcRecord = OfsRecord
OfcEditLog = OfsEditLog
OFSSeqControl = OfsSeqControl

__all__ = [
    "Company",
    "User",
    "Contract",
    "Target",
    "OfsRecord",
    "OfsEditLog",
    "OfsSeqControl",
    "AuditLog",
    "PasswordHistory",
    "RevokedToken",
    "Report",
    "SystemParam",
    # Legacy aliases
    "OfcRecord",
    "OfcEditLog",
    "OFSSeqControl",
]
