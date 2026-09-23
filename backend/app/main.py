from fastapi import FastAPI

from app.api.health import router as health_router
from app.modules.admin.router import router as admin_router
from app.modules.auth.router import router as auth_router
from app.modules.bookings.router import router as bookings_router
from app.modules.chat.router import router as chat_router
from app.modules.discovery.router import router as discovery_router
from app.modules.notifications.router import router as notifications_router
from app.modules.payments.router import router as payments_router
from app.modules.reviews.router import router as reviews_router
from app.modules.users.router import router as users_router

app = FastAPI(
    title="Mossaid API",
    version="0.1.0",
    description="Mossaid marketplace API — skeleton",
)

# Health (no prefix)
app.include_router(health_router, tags=["health"])

# Domain routers under /api/v1
for router in [
    auth_router,
    users_router,
    discovery_router,
    bookings_router,
    chat_router,
    payments_router,
    reviews_router,
    notifications_router,
    admin_router,
]:
    app.include_router(router, prefix="/api/v1")
