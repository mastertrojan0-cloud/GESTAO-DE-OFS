from app.services.ofs_service import (
    create_ofs,
    get_ofs,
    list_ofs_records,
    update_ofs,
    cancel_ofs,
    restore_ofs,
    get_ofs_edit_history,
    # Backward compatibility aliases
    create_ofs_record,
    get_ofs_record,
    update_ofs_record,
    cancel_ofs_record,
    restore_ofs_record,
)
from app.services.metrics_service import (
    calculate_weekly_metrics,
    get_evolution,
    get_ranking,
    invalidate_metrics_cache,
)
from app.services.user_service import (
    create_user,
    get_user,
    list_users,
    update_user,
    change_password,
)
from app.services.target_service import (
    get_current_target,
    get_weekly_target,
    create_target,
    deactivate_target,
)

# Backward compatibility aliases
create_ofc = create_ofs
get_ofc = get_ofs
list_ofcs = list_ofs_records
update_ofc = update_ofs
cancel_ofc = cancel_ofs
restore_ofc = restore_ofs
get_ofc_edit_history = get_ofs_edit_history

__all__ = [
    "create_ofs",
    "get_ofs",
    "list_ofs_records",
    "update_ofs",
    "cancel_ofs",
    "restore_ofs",
    "get_ofs_edit_history",
    "calculate_weekly_metrics",
    "get_evolution",
    "get_ranking",
    "invalidate_metrics_cache",
    "create_user",
    "get_user",
    "list_users",
    "update_user",
    "change_password",
    "get_current_target",
    "get_weekly_target",
    "create_target",
    "deactivate_target",
    # Backward compatibility
    "create_ofc",
    "get_ofc",
    "list_ofcs",
    "update_ofc",
    "cancel_ofc",
    "restore_ofc",
    "get_ofc_edit_history",
]
