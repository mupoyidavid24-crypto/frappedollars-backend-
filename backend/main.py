from __future__ import annotations

import json
import hmac
import os
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Literal
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field
import requests

from backend.admin_routes import router as admin_router
from backend.ea_generator import router as ea_router
from backend.config import supabase
from backend.storage import SQLiteStorage, hash_api_key, utc_now


BASE_DIR = os.path.dirname(__file__)
load_dotenv(os.path.join(BASE_DIR, ".env"))

ADMIN_API_KEY = os.getenv("ADMIN_API_KEY") or "a23112857d84806ef3201f526ea2558a"
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_KEY")
SQLITE_DB_PATH = os.getenv(
    "SQLITE_DB_PATH",
    os.path.join(BASE_DIR, "runtime", "pipeline.db"),
)
DISPATCH_LEASE_SECONDS = int(os.getenv("DISPATCH_LEASE_SECONDS", "300"))
DISPATCHABLE_STATUSES = ("PENDING", "RETRY")

storage = SQLiteStorage(SQLITE_DB_PATH)
app = FastAPI(title="FrappedDollars Backend", version="2.1.0")
app.include_router(ea_router)
app.include_router(admin_router)

allowed_origins = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ALLOW_ORIGINS",
        "http://localhost:3000,http://localhost:5000,http://localhost:8080,https://frappe-dollars.web.app,https://frappedollars.netlify.app",
    ).split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_origin_regex=r"https://.*\.(netlify\.app|web\.app|firebaseapp\.com)",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class MasterTradePayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

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


class AdminLoginPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    username: str = Field(min_length=1)
    password: str = Field(min_length=1)


class AdminRegisterPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    username: str = Field(min_length=1)
    password: str = Field(min_length=1)
    invite_code: str = Field(min_length=1)


class PaymentVerifyPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    user_id: str = Field(min_length=1)
    transaction_id: str = Field(min_length=1)
    payment_type: Literal["COPY_TRADING_WEEKLY", "VPS_MONTHLY"]
    amount: float = Field(gt=0)
    currency: str = Field(default="USD")


class DashboardConnectPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    user_id: str = Field(min_length=1)
    mt5_login: str = Field(min_length=1)
    mt5_server: str = Field(min_length=1)
    account_type: Literal["MASTER", "CLIENT"] = "CLIENT"
    is_active: bool = True


def _extract_bearer_token(authorization: str | None) -> str | None:
    if not authorization:
        return None
    if authorization.lower().startswith("bearer "):
        return authorization.split(" ", 1)[1].strip() or None
    return authorization.strip() or None


def _supabase_rest_headers(access_token: str | None) -> dict[str, str]:
    api_key = SUPABASE_ANON_KEY
    if not SUPABASE_URL or not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="SUPABASE_URL ou SUPABASE_KEY n'est pas configuree sur le backend.",
        )

    bearer = access_token or api_key
    return {
        "apikey": api_key,
        "Authorization": f"Bearer {bearer}",
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }


def _supabase_rest_get(
    table: str,
    access_token: str | None,
    *,
    select: str,
    filters: dict[str, str] | None = None,
    order: str | None = None,
    limit: int | None = None,
) -> list[dict[str, Any]]:
    params: dict[str, str | int] = {"select": select}
    for key, value in (filters or {}).items():
        params[key] = value
    if order:
        params["order"] = order
    if limit is not None:
        params["limit"] = limit

    response = requests.get(
        f"{SUPABASE_URL.rstrip('/')}/rest/v1/{table}",
        headers=_supabase_rest_headers(access_token),
        params=params,
        timeout=30,
    )
    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Supabase {table} query failed: {response.text}",
        )

    decoded = response.json()
    return decoded if isinstance(decoded, list) else [decoded]


def _supabase_rest_mutate(
    method: str,
    table: str,
    access_token: str | None,
    *,
    payload: dict[str, Any],
    filters: dict[str, str] | None = None,
) -> list[dict[str, Any]]:
    params: dict[str, str] = {}
    for key, value in (filters or {}).items():
        params[key] = value

    response = requests.request(
        method,
        f"{SUPABASE_URL.rstrip('/')}/rest/v1/{table}",
        headers=_supabase_rest_headers(access_token),
        params=params,
        json=payload,
        timeout=30,
    )
    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Supabase {table} mutation failed: {response.text}",
        )

    if not response.text.strip():
        return []
    decoded = response.json()
    return decoded if isinstance(decoded, list) else [decoded]


def _get_dashboard_payload(user_id: str, access_token: str | None) -> dict[str, Any]:
    profile_rows = _supabase_rest_get(
        "profiles",
        access_token,
        select="id, email, full_name, role, is_vip, needs_vps, created_at",
        filters={"id": f"eq.{user_id}"},
        limit=1,
    )
    profile = profile_rows[0] if profile_rows else {
        "id": user_id,
        "email": None,
        "full_name": None,
        "role": None,
        "is_vip": False,
        "needs_vps": False,
        "created_at": None,
    }

    try:
        account_rows = _supabase_rest_get(
            "trading_accounts",
            access_token,
            select="id, user_id, mt5_login, mt5_server, account_type, balance, equity, is_active, last_sync",
            filters={"user_id": f"eq.{user_id}", "is_active": "eq.true"},
            order="last_sync.desc.nullslast",
            limit=1,
        )
        account = account_rows[0] if account_rows else None

        subscription_rows = _supabase_rest_get(
            "subscriptions",
            access_token,
            select="id, user_id, type, status, start_date, end_date, auto_renew, transaction_ref, created_at",
            filters={"user_id": f"eq.{user_id}"},
            order="created_at.desc.nullslast",
            limit=1,
        )
        subscription = subscription_rows[0] if subscription_rows else None

        trades: list[dict[str, Any]] = []
        if account and account.get("id"):
            trades = _supabase_rest_get(
                "copied_trades",
                access_token,
                select="id, signal_id, client_account_id, client_ticket_id, volume_executed, execution_status, profit, error_message, created_at, closed_at",
                filters={"client_account_id": f"eq.{account['id']}"},
                order="created_at.desc.nullslast",
                limit=100,
            )
    except HTTPException as exc:
        print(f"[DASHBOARD_STATE] fallback for user_id={user_id}: {exc.detail}")
        account = None
        subscription = None
        trades = []

    return {
        "profile": profile,
        "account": account,
        "subscription": subscription,
        "trades": trades,
    }


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


def _flutterwave_verify_transaction(transaction_id: str) -> dict[str, Any]:
    secret_key = os.getenv("FLUTTERWAVE_SECRET_KEY")
    base_url = os.getenv("FLUTTERWAVE_BASE_URL", "https://api.flutterwave.com/v3")
    if not secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="FLUTTERWAVE_SECRET_KEY n'est pas configuree sur le backend.",
        )

    request = Request(
        f"{base_url.rstrip('/')}/transactions/{transaction_id}/verify",
        headers={"Authorization": f"Bearer {secret_key}"},
        method="GET",
    )

    try:
        with urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace") if exc.fp else str(exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Flutterwave verification failed: {body}",
        ) from exc
    except URLError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Flutterwave verification unreachable: {exc.reason}",
        ) from exc

    if payload.get("status") != "success":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transaction Flutterwave invalide ou non verifiee.",
        )

    data = payload.get("data") or {}
    if data.get("status") not in {"successful", "success"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transaction Flutterwave non reussie.",
        )
    return data


def _subscription_payment_window_open() -> bool:
    current_day = datetime.now(timezone.utc).weekday()
    return current_day in (5, 6)


def _activate_subscription_from_payment(user_id: str, payment_type: str, transaction_id: str) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    end_date = now + (timedelta(days=7) if payment_type == "COPY_TRADING_WEEKLY" else timedelta(days=30))
    result = supabase.table("subscriptions").insert(
        {
            "user_id": user_id,
            "type": payment_type,
            "status": "ACTIVE",
            "start_date": now.isoformat(),
            "end_date": end_date.isoformat(),
            "transaction_ref": transaction_id,
            "auto_renew": True,
        }
    ).execute()
    return result.data


@app.get("/dashboard/state/{user_id}")
def dashboard_state(user_id: str, authorization: str | None = Header(default=None)) -> dict[str, Any]:
    try:
        return _get_dashboard_payload(user_id, _extract_bearer_token(authorization))
    except Exception as exc:
        print(f"[DASHBOARD_STATE] unexpected error for user_id={user_id}: {exc}")
        return {
            "profile": {
                "id": user_id,
                "email": None,
                "full_name": None,
                "role": None,
                "is_vip": False,
                "needs_vps": False,
                "created_at": None,
            },
            "account": None,
            "subscription": None,
            "trades": [],
        }


@app.post("/dashboard/connect_mt5")
def dashboard_connect_mt5(payload: DashboardConnectPayload, authorization: str | None = Header(default=None)) -> dict[str, Any]:
    access_token = _extract_bearer_token(authorization)
    existing_rows = _supabase_rest_get(
        "trading_accounts",
        access_token,
        select="id",
        filters={"user_id": f"eq.{payload.user_id}", "account_type": f"eq.{payload.account_type}"},
        order="last_sync.desc.nullslast",
        limit=1,
    )

    account_data = {
        "user_id": payload.user_id,
        "mt5_login": payload.mt5_login,
        "mt5_server": payload.mt5_server,
        "account_type": payload.account_type,
        "is_active": payload.is_active,
        "last_sync": utc_now(),
    }

    if existing_rows:
        account_id = existing_rows[0]["id"]
        result = _supabase_rest_mutate(
            "PATCH",
            "trading_accounts",
            access_token,
            payload=account_data,
            filters={"id": f"eq.{account_id}"},
        )
    else:
        result = _supabase_rest_mutate("POST", "trading_accounts", access_token, payload=account_data)

    return {"status": "ok", "account": (result or [None])[0]}


@app.post("/dashboard/disconnect_mt5/{user_id}")
def dashboard_disconnect_mt5(user_id: str, authorization: str | None = Header(default=None)) -> dict[str, Any]:
    access_token = _extract_bearer_token(authorization)
    result = _supabase_rest_mutate(
        "PATCH",
        "trading_accounts",
        access_token,
        payload={"is_active": False, "last_sync": utc_now()},
        filters={"user_id": f"eq.{user_id}", "account_type": "eq.CLIENT"},
    )
    return {"status": "ok", "updated": len(result)}


@app.post("/admin/login")
def admin_login(payload: AdminLoginPayload) -> dict[str, str]:
    admin_username = os.getenv("ADMIN_USERNAME", "admin")
    admin_password = os.getenv("ADMIN_PASSWORD", "MotDePasseComplexe123!")
    if storage.verify_admin_credentials(payload.username, payload.password):
        print(f"[ADMIN_LOGIN] success username={payload.username} source=sqlite")
        return {
            "status": "ok",
            "admin_key": ADMIN_API_KEY,
            "username": payload.username,
        }
    if payload.username != admin_username or payload.password != admin_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants admin invalides.",
        )
    print(f"[ADMIN_LOGIN] success username={payload.username}")
    return {
        "status": "ok",
        "admin_key": ADMIN_API_KEY,
        "username": payload.username,
    }


@app.post("/admin/register")
def admin_register(payload: AdminRegisterPayload) -> dict[str, str]:
    invite_code = os.getenv("ADMIN_INVITE_CODE", "CreateAdmin2026")
    if payload.invite_code != invite_code:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Code d'invitation invalide.",
        )

    storage.upsert_admin_account(payload.username, payload.password)
    print(f"[ADMIN_REGISTER] success username={payload.username}")
    return {
        "status": "ok",
        "admin_key": ADMIN_API_KEY,
        "username": payload.username,
    }


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
        "active_client_count": len(storage.list_active_client_logins()),
    }


@app.post("/master/trade")
def master_trade(
    payload: MasterTradePayload,
    x_api_key: str | None = Header(default=None),
) -> dict[str, Any]:
    _verify_ea_api_key(payload.master_login, x_api_key, expected_role="MASTER")

    result = storage.create_and_fanout_master_trade_signal(payload.model_dump())
    signal = result["signal"]
    dispatches = result["dispatches"]
    if result.get("duplicate"):
        print(
            f"[MASTER_TRADE] duplicate master_login={payload.master_login} ticket_id={payload.ticket_id} action={payload.action} status={signal.get('status')}"
        )
        return {"item": signal, "duplicate": True, "dispatches_created": 0}

    print(
        f"[MASTER_TRADE] created master_login={payload.master_login} ticket_id={payload.ticket_id} action={payload.action} symbol={payload.symbol} trade_type={payload.trade_type} volume={payload.volume} signal_id={signal.get('id')} dispatches={len(dispatches)}"
    )
    return {"item": signal, "duplicate": False, "dispatches_created": len(dispatches)}


@app.get("/client/pending_trades/{mt5_login}")
def client_pending_trades(
    mt5_login: str,
    limit: int = Query(default=20, ge=1, le=100),
    wait_ms: int = Query(default=100, ge=0, le=2000),
    x_api_key: str | None = Header(default=None),
) -> dict[str, Any]:
    _verify_ea_api_key(mt5_login, x_api_key, expected_role="CLIENT")
    storage.requeue_stale_dispatches(mt5_login, DISPATCH_LEASE_SECONDS)
    deadline = time.monotonic() + (wait_ms / 1000.0)
    items = storage.claim_dispatches(mt5_login, limit)
    while not items and wait_ms > 0 and time.monotonic() < deadline:
        time.sleep(min(0.005, max(0.0, deadline - time.monotonic())))
        items = storage.claim_dispatches(mt5_login, limit)
    print(f"[CLIENT_PULL] mt5_login={mt5_login} limit={limit} wait_ms={wait_ms} items={len(items)}")
    return {"version": "v1", "items": items}


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
        row = storage.update_dispatch_status(
            trade_id=payload.trade_id,
            client_login=payload.client_login,
            required_status="RETRY",
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
    print(
        f"[CLIENT_ACK] executed client_login={payload.client_login} trade_id={payload.trade_id} client_ticket_id={payload.client_ticket_id}"
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
        row = storage.update_dispatch_status(
            trade_id=payload.trade_id,
            client_login=payload.client_login,
            required_status="RETRY",
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
    print(
        f"[CLIENT_ACK] failed client_login={payload.client_login} trade_id={payload.trade_id} error={payload.error_message}"
    )
    return {"item": row}


@app.post("/admin/generate_api_key")
def generate_api_key(
    payload: GenerateApiKeyPayload,
    admin_key: str = Depends(_require_admin_key),
) -> dict[str, str]:
    del admin_key
    result = storage.issue_api_key(payload.mt5_login, payload.account_role)
    print(f"[API_KEY] issued mt5_login={payload.mt5_login} role={payload.account_role}")
    return result


@app.post("/payments/verify")
def verify_payment(payload: PaymentVerifyPayload) -> dict[str, Any]:
    if not _subscription_payment_window_open():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Les depots d'abonnement sont autorises uniquement le samedi et le dimanche.",
        )

    profile_response = (
        supabase.table("profiles").select("id, email").eq("id", payload.user_id).maybe_single().execute()
    )
    profile = profile_response.data
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable.")

    transaction = _flutterwave_verify_transaction(payload.transaction_id)
    currency = str(transaction.get("currency") or "").upper()
    transaction_amount = float(transaction.get("amount") or transaction.get("charged_amount") or 0)
    customer = transaction.get("customer") or {}
    customer_email = str(customer.get("email") or "").lower()
    profile_email = str(profile.get("email") or "").lower()

    if payload.currency.upper() != currency:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Devise Flutterwave inattendue.",
        )
    if abs(transaction_amount - payload.amount) > 0.01:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Montant Flutterwave inattendu.",
        )
    if customer_email and profile_email and customer_email != profile_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le client Flutterwave ne correspond pas au compte utilisateur.",
        )

    subscription_rows = _activate_subscription_from_payment(
        user_id=payload.user_id,
        payment_type=payload.payment_type,
        transaction_id=payload.transaction_id,
    )

    print(
        f"[PAYMENT_VERIFY] success user_id={payload.user_id} transaction_id={payload.transaction_id} type={payload.payment_type}"
    )
    return {
        "status": "ok",
        "transaction_id": payload.transaction_id,
        "verified_transaction": transaction,
        "subscription": subscription_rows[0] if subscription_rows else None,
    }


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
