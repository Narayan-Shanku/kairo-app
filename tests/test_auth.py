"""Backend token-auth middleware: off by default, gates /api/* when enabled."""

from fastapi.testclient import TestClient

from backend import app as appmod
from backend import config
from backend.storage import db


def test_no_auth_required_by_default():
    db.init_db()
    config.API_TOKEN = None
    client = TestClient(appmod.app)
    assert client.get("/api/health").status_code == 200
    assert client.get("/api/stats").status_code == 200


def test_token_gates_api_when_set():
    db.init_db()
    config.API_TOKEN = "secret-token"
    try:
        client = TestClient(appmod.app)
        # Health is always exempt (for uptime checks / load balancers).
        assert client.get("/api/health").status_code == 200
        # Protected endpoints need the bearer token.
        assert client.get("/api/stats").status_code == 401
        assert client.get(
            "/api/stats", headers={"Authorization": "Bearer secret-token"}
        ).status_code == 200
        assert client.get(
            "/api/stats", headers={"Authorization": "Bearer wrong"}
        ).status_code == 401
    finally:
        config.API_TOKEN = None
