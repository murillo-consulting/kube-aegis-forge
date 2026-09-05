"""FastAPI application with bounded-cardinality Prometheus metrics."""

from __future__ import annotations

import logging
import time
from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response as StarletteResponse

from demo_api.settings import Settings

LOGGER = logging.getLogger(__name__)
HTTP_METHODS = frozenset(
    {"GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH"}
)

HTTP_REQUESTS = Counter(
    "demo_api_http_requests_total",
    "Total HTTP requests handled by the demo API.",
    ("method", "route", "status"),
)
HTTP_DURATION = Histogram(
    "demo_api_http_request_duration_seconds",
    "HTTP request duration for the demo API.",
    ("method", "route"),
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)


class BuildInfo(BaseModel):
    """Public build metadata returned by the root endpoint."""

    name: str
    version: str
    git_sha: str


class HealthStatus(BaseModel):
    """Health response shared by liveness and readiness checks."""

    status: str


class ObservabilityMiddleware(BaseHTTPMiddleware):
    """Record request metrics and apply safe response headers."""

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[StarletteResponse]],
    ) -> StarletteResponse:
        started = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            LOGGER.exception("Unhandled request failure")
            response = JSONResponse(status_code=500, content={"detail": "Internal server error"})
        route = request.scope.get("route")
        route_path = getattr(route, "path", "<unmatched>")
        status = str(response.status_code)

        method = request.method if request.method in HTTP_METHODS else "OTHER"
        HTTP_REQUESTS.labels(method, route_path, status).inc()
        HTTP_DURATION.labels(method, route_path).observe(time.perf_counter() - started)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response


def create_app(settings: Settings | None = None) -> FastAPI:
    """Create an application instance with injectable build metadata."""

    runtime_settings = settings or Settings.from_environment()
    application = FastAPI(
        title="DevSecOps Demo API",
        description="Observable workload for the GitOps reference platform.",
        version=runtime_settings.version,
        docs_url="/docs",
        redoc_url=None,
    )
    application.add_middleware(ObservabilityMiddleware)

    @application.get("/", response_model=BuildInfo)
    async def build_info() -> BuildInfo:
        return BuildInfo(
            name=runtime_settings.app_name,
            version=runtime_settings.version,
            git_sha=runtime_settings.git_sha,
        )

    @application.get("/health/live", response_model=HealthStatus)
    async def live() -> HealthStatus:
        return HealthStatus(status="ok")

    @application.get("/health/ready", response_model=HealthStatus)
    async def ready() -> HealthStatus:
        return HealthStatus(status="ready")

    @application.get("/metrics", include_in_schema=False)
    async def metrics() -> Response:
        return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

    return application


app = create_app()
