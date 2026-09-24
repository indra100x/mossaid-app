from fastapi import HTTPException, status

from app.core.deps import CurrentUser

# Tiers per Phase 3 spec: support, ops, finance, super_admin (+ legacy admin)
TIER_PERMISSIONS: dict[str, set[str]] = {
    "support": {"users.suspend", "users.list", "verification.review"},
    "ops": {"verification.review", "disputes.list", "disputes.resolve", "users.list", "users.suspend"},
    "finance": {"payments.list", "payments.refund", "payouts.view", "analytics.view"},
    "super_admin": {"*"},
    "admin": {"*"},  # legacy
}

# Map endpoint actions to permission strings
def require_permission(user: CurrentUser, permission: str) -> None:
    role = user.role
    # Non-admin roles (client/craftsman) have no admin permissions
    if role in ("client", "craftsman"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only")
    perms = TIER_PERMISSIONS.get(role, set())
    if "*" in perms or permission in perms:
        return
    # super_admin is also allowed via role super_admin
    if role == "super_admin":
        return
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"Tier {role} lacks permission {permission}")


def is_admin_tier(user: CurrentUser) -> bool:
    return user.role in ("support", "ops", "finance", "super_admin", "admin")
