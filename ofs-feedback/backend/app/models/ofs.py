"""Compatibilidade: re-exporta OfsRecord como OFS e OfsEditLog como OFSEditLog."""
from app.models.ofs_record import OfsRecord as OFS, OfsEditLog as OFSEditLog  # noqa: F401
