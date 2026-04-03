from __future__ import annotations

import hmac
import os
from typing import Any, Literal

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field

from backend.storage import SQLiteStorage, hash_api_key, utc_now


BASE_DIR = os.path.dirname(__file__)
load_dotenv(os.path.join(BASE_DIR, ".env"))

ADMIN_API_KEY = os.getenv("ADMIN_API_KEY") or "a23112857d84806ef3201f526ea2558a"
SQLITE_DB_PATH = os.getenv(
    "SQLITE_DB_PATH",
    os.path.join(BASE_DIR, "runtime", "pipeline.db"),
)
DISPATCH_LEASE_SECONDS = int(os.getenv("DISPATCH_LEASE_SECONDS", "30"))
DISPATCHABLE_STATUSES = ("PENDING", "RETRY")

storage = SQLiteStorage(SQLITE_DB_PATH)
app = FastAPI(title="FrappedDollars Backend", version="2.1.0")


class MasterTradePayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    client_login: str = Field(min_length=1)
    master_login: str = Field(min_length=1)
    ticket_id: str = Field(min_length=1)
    action: Literal["OPEN", "CLOSE"]
    symbol: str = Field(min_length=1)
    trade_type: Literal["BUY", "SELL"]
    volume: float = Field(gt=0)
    open_price: float | None = None
    sl: float | None = None
    tp: float | None = None


class TradeExecutedPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    client_login: str = Field(min_length=1)
    trade_id: str = Field(min_length=1)
    client_ticket_id: str | None = None


class TradeFailedPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    client_login: str = Field(min_length=1)
    trade_id: str = Field(min_length=1)
    error_message: str = Field(min_length=1)


class GenerateApiKeyPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    mt5_login: str = Field(min_length=1)
    account_role: Literal["MASTER", "CLIENT"]


def _verify_ea_api_key(mt5_login: str, provided_api_key: str | None, expected_role: str) -> dict[str, Any]:
    if not provided_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="L'en-tete x-api-key est obligatoire.",
        )

    record = storage.get_api_key_record(mt5_login)
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Aucune cle API active pour le login MT5 {mt5_login}.",
        )
    if not bool(record.get("is_active", 0)):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"La cle API du login MT5 {mt5_login} est desactivee.",
        )
    if record.get("account_role") != expected_role:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Le login MT5 {mt5_login} n'a pas le role {expected_role}.",
        )
    expected_hash = record.get("api_key_hash", "")
    if not hmac.compare_digest(expected_hash, hash_api_key(provided_api_key)):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Cle API invalide.",
        )
    return record


def _require_admin_key(x_admin_key: str | None = Header(default=None)) -> str:
    if not ADMIN_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="ADMIN_API_KEY n'est pas configuree sur le backend.",
        )
    if not x_admin_key or not hmac.compare_digest(x_admin_key, ADMIN_API_KEY):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Cle admin invalide.",
        )
    return x_admin_key


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "FrappedDollars backend OK", "pipeline": "sqlite-persisted"}


@app.get("/ping")
def ping() -> dict[str, str]:
    return {"ping": "pong"}


@app.get("/monitoring")
def monitoring_status(admin_key: str = Depends(_require_admin_key)) -> dict[str, Any]:
    del admin_key
    return {
        "dispatch_status_counts": storage.monitoring_counts(),
        "dispatchable_statuses": DISPATCHABLE_STATUSES,
    }


@app.post("/master/trade")
def master_trade(
    payload: MasterTradePayload,
    x_api_key: str | None = Header(default=None),
) -> dict[str, Any]:
    _verify_ea_api_key(payload.master_login, x_api_key, expected_role="MASTER")

    existing = storage.get_dispatch_by_dedupe(payload.client_login, payload.ticket_id, payload.action)
    if existing is not None:
        return {"item": existing, "duplicate": True}

    created = storage.create_dispatch(payload.model_dump())
    return {"item": created, "duplicate": False}


@app.get("/client/pending_trades/{mt5_login}")
def client_pending_trades(
    mt5_login: str,
    limit: int = Query(default=20, ge=1, le=100),
    x_api_key: str | None = Header(default=None),
) -> dict[str, Any]:
    _verify_ea_api_key(mt5_login, x_api_key, expected_role="CLIENT")
    storage.requeue_stale_dispatches(mt5_login, DISPATCH_LEASE_SECONDS)
    return {"version": "v1", "items": storage.claim_dispatches(mt5_login, limit)}


@app.post("/client/trade_executed")
def trade_executed(
    payload: TradeExecutedPayload,
    x_api_key: str | None = Header(default=None),
) -> dict[str, Any]:
    _verify_ea_api_key(payload.client_login, x_api_key, expected_role="CLIENT")

    row = storage.update_dispatch_status(
        trade_id=payload.trade_id,
        client_login=payload.client_login,
        required_status="DISPATCHED",
        updates={
            "status": "EXECUTED",
            "executed_at": utc_now(),
            "client_ticket_id": payload.client_ticket_id,
        },
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Le trade {payload.trade_id} pour {payload.client_login} n'est pas dans l'etat attendu DISPATCHED."
            ),
        )
    return {"item": row}


@app.post("/client/trade_failed")
def trade_failed(
    payload: TradeFailedPayload,
    x_api_key: str | None = Header(default=None),
) -> dict[str, Any]:
    _verify_ea_api_key(payload.client_login, x_api_key, expected_role="CLIENT")

    row = storage.update_dispatch_status(
        trade_id=payload.trade_id,
        client_login=payload.client_login,
        required_status="DISPATCHED",
        updates={
            "status": "FAILED",
            "last_error": payload.error_message,
        },
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                f"Le trade {payload.trade_id} pour {payload.client_login} n'est pas dans l'etat attendu DISPATCHED."
            ),
        )
    return {"item": row}


@app.post("/admin/generate_api_key")
def generate_api_key(
    payload: GenerateApiKeyPayload,
    admin_key: str = Depends(_require_admin_key),
) -> dict[str, str]:
    del admin_key
    return storage.issue_api_key(payload.mt5_login, payload.account_role)


@app.get("/admin/trade_dispatches")
def list_trade_dispatches(
    client_login: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=100, ge=1, le=500),
    admin_key: str = Depends(_require_admin_key),
) -> dict[str, list[dict[str, Any]]]:
    del admin_key
    return {
        "items": storage.list_dispatches(
            client_login=client_login,
            status_filter=status_filter,
            limit=limit,
        )
    }
