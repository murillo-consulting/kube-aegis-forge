"""Behavioral tests for every public API endpoint."""

from fastapi import FastAPI
from fastapi.testclient import TestClient

from demo_api.main import create_app
from demo_api.settings import Settings


def test_build_info_is_explicit_and_non_sensitive() -> None:
    app = create_app(Settings(app_name="demo", version="1.2.3", git_sha="abc123"))

    response = TestClient(app).get("/")

    assert response.status_code == 200
    assert response.json() == {"name": "demo", "version": "1.2.3", "git_sha": "abc123"}
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["x-content-type-options"] == "nosniff"


def test_health_endpoints() -> None:
    client = TestClient(create_app())

    assert client.get("/health/live").json() == {"status": "ok"}
    assert client.get("/health/ready").json() == {"status": "ready"}


def test_metrics_expose_bounded_http_series() -> None:
    client = TestClient(create_app())
    client.get("/health/live")

    response = client.get("/metrics")

    assert response.status_code == 200
    assert "demo_api_http_requests_total" in response.text
    assert 'route="/health/live"' in response.text
    assert "demo_api_http_request_duration_seconds" in response.text


def test_unknown_route_uses_a_stable_metric_label() -> None:
    client = TestClient(create_app())
    assert client.get("/does-not-exist").status_code == 404

    metrics = client.get("/metrics").text
    assert 'route="<unmatched>"' in metrics


def test_unhandled_exception_has_generic_response() -> None:
    app: FastAPI = create_app()

    @app.get("/test-failure")
    async def fail() -> None:
        raise RuntimeError("sensitive internal detail")

    response = TestClient(app, raise_server_exceptions=False).get("/test-failure")

    assert response.status_code == 500
    assert response.json() == {"detail": "Internal server error"}
    assert "sensitive" not in response.text
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["x-content-type-options"] == "nosniff"
    metrics = TestClient(app).get("/metrics").text
    assert 'method="GET",route="/test-failure",status="500"' in metrics


def test_arbitrary_methods_do_not_create_unbounded_metric_labels() -> None:
    client = TestClient(create_app())
    for method in ("CUSTOMONE", "CUSTOMTWO", "CUSTOMTHREE"):
        assert client.request(method, "/").status_code == 405
    metrics = client.get("/metrics").text
    assert 'method="OTHER"' in metrics
    for method in ("CUSTOMONE", "CUSTOMTWO", "CUSTOMTHREE"):
        assert method not in metrics
