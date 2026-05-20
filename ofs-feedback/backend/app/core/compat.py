"""
compat.py — Adaptador de compatibilidade entre os modelos User (security) e Usuario (services).
Garante que objetos User tenham os atributos esperados pelos services metrics/OFS.
"""
from types import SimpleNamespace
from app.models.user import User


def user_to_adapter(user: User) -> SimpleNamespace:
    """Converte User em objeto com os atributos que metrics_service/ofc_service esperam.

    User tem: id, username, full_name, role, company_id, email, is_active
    Service espera: id, nome, perfil, empresa_id, username, email
    """
    return SimpleNamespace(
        id=user.id,
        nome=user.full_name or user.username,
        perfil=user.role,
        empresa_id=user.company_id,
        username=user.username,
        email=user.email,
    )
