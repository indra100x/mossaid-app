import logging
import time

from fastapi import FastAPI, Request, Response

from app.api.health import router as health_router
from app.core.config import settings
from app.core.logging import setup_logging
from app.modules.admin.router import router as admin_router
from app.modules.auth.router import router as auth_router
from app.modules.bookings.router import router as bookings_router
from app.modules.chat.router import router as chat_router
from app.modules.discovery.router import router as discovery_router
from app.modules.notifications.router import router as notifications_router
from app.modules.payments.router import router as payments_router
from app.modules.reviews.router import router as reviews_router
from app.modules.users.router import router as users_router

setup_logging(settings.log_level)
logger = logging.getLogger(__name__)

# Sentry error tracking (DSN stored as secret, not in repo).
if settings.sentry_dsn:
    try:
        import sentry_sdk

        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=settings.app_env,
            traces_sample_rate=0.1,
        )
        logger.info("Sentry initialized env=%s", settings.app_env)
    except Exception as e:
        logger.warning("Sentry init failed: %s", e)
else:
    logger.info("Sentry DSN not set, error tracking disabled")

app = FastAPI(
    title="Mossaid API",
    version="0.1.0",
    description="Mossaid marketplace API",
)


@app.middleware("http")
async def prometheus_middleware(request: Request, call_next):  # type: ignore[no-untyped-def]
    start = time.perf_counter()
    response: Response | None = None
    try:
        response = await call_next(request)
        return response
    finally:
        if settings.prometheus_enabled:
            try:
                from app.core.metrics import http_request_duration_seconds, http_requests_total

                duration = time.perf_counter() - start
                route = request.scope.get("route")
                endpoint = getattr(route, "path", request.url.path) if route else request.url.path
                status_code = str(response.status_code) if response is not None else "500"
                http_requests_total.labels(
                    method=request.method, endpoint=endpoint, status=status_code
                ).inc()
                http_request_duration_seconds.labels(endpoint=endpoint).observe(duration)
            except Exception:
                pass


@app.get("/metrics", include_in_schema=False)
async def metrics() -> Response:
    from fastapi import HTTPException
    from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

    if not settings.prometheus_enabled:
        raise HTTPException(status_code=404, detail="Metrics disabled")
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


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
