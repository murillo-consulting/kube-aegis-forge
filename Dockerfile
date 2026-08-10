# syntax=docker/dockerfile:1

# uv is copied from an immutable multi-architecture image.
FROM ghcr.io/astral-sh/uv:0.12.1@sha256:cf4eedcaa81655197f625739489effcbe71b61ceb1506f332c3facae5deceded AS uv

# Builder keeps compilers and package metadata out of the runtime image.
FROM python:3.13-slim-bookworm@sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8 AS builder

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy
WORKDIR /app

COPY --from=uv /uv /usr/local/bin/uv
COPY app/pyproject.toml app/uv.lock app/README.md ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-install-project

COPY app/src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable

# Runtime contains only Python, the virtual environment, and application code.
FROM python:3.13-slim-bookworm@sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8 AS runtime

ARG APP_VERSION=dev
ARG GIT_SHA=unknown
LABEL org.opencontainers.image.title="kube-aegis-forge" \
      org.opencontainers.image.description="Observable workload for a GitOps reference platform" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/murillo-consulting/kube-aegis-forge" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}"

ENV APP_VERSION="${APP_VERSION}" \
    GIT_SHA="${GIT_SHA}" \
    HOME=/home/app \
    PATH=/app/.venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
RUN mkdir -p /home/app /tmp && chown -R 10001:10001 /home/app /tmp /app
COPY --from=builder --chown=10001:10001 /app/.venv /app/.venv

USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health/live', timeout=2)"]

CMD ["uvicorn", "demo_api.main:app", "--host", "0.0.0.0", "--port", "8080", "--no-server-header"]

