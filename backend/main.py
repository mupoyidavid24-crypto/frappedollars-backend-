from __future__ import annotations

import json
import hmac
import os
import time
import traceback
from datetime import datetime, timedelta, timezone
from typing import Any, Literal
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field
import requests

from backend.admin_routes import router as admin_router
from backend.ea_generator import router as ea_router
from backend.config import supabase, get_current_admin, _supabase_user_from_jwt
from backend.error_reporting import record_error_log, report_exception
from backend.storage import SQLiteStorage, hash_api_key, utc_now


BASE_DIR = os.path.dirname(__file__)
load_dotenv(os.path.join(BASE_DIR, ".env"))

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_KEY")
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


class ManualPaymentRequestPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    user_id: str = Field(min_length=1)
    payment_type: Literal["COPY_TRADING_WEEKLY", "VPS_MONTHLY"]
    amount: float = Field(gt=0)
    payer_phone: str = Field(min_length=1)
    destination_number: str = Field(min_length=1)
    proof_url: str = Field(min_length=1)


class DashboardConnectPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    user_id: str = Field(min_length=1)
    mt5_login: str = Field(min_length=1)
    mt5_server: str = Field(min_length=1)
    account_type: Literal["MASTER", "CLIENT"] = "CLIENT"
    is_active: bool = True


class ErrorLogPayload(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    source: str = Field(min_length=1)
    component: str = Field(min_length=1)
    severity: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = "ERROR"
    message: str = Field(min_length=1)
    details: dict[str, Any] = Field(default_factory=dict)
    user_id: str | None = None
    mt5_login: str | None = None
    trade_id: str | None = None
    account_role: Literal["MASTER", "CLIENT"] | None = None


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


def _parse_iso_datetime(value: Any) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed
    except Exception:
        return None


def _count_rows(rows: list[dict[str, Any]], field: str, expected: Any) -> int:
    return sum(1 for row in rows if row.get(field) == expected)


def _sum_numeric_rows(rows: list[dict[str, Any]], field: str) -> float:
    total = 0.0
    for row in rows:
        try:
            total += float(row.get(field) or 0)
        except Exception:
            continue
    return total


def _persist_error_log(
    *,
    source: str,
    component: str,
    severity: str,
    message: str,
    details: dict[str, Any] | None = None,
    user_id: str | None = None,
    mt5_login: str | None = None,
    trade_id: str | None = None,
) -> None:
    record_error_log(
        source=source,
        component=component,
        severity=severity,
        message=message,
        details=details,
        user_id=user_id,
        mt5_login=mt5_login,
        trade_id=trade_id,
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    report_exception(
        component=f"{request.method} {request.url.path}",
        exc=exc,
        source="backend",
        details={
            "method": request.method,
            "path": request.url.path,
        },
    )
    return JSONResponse(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, content={"detail": "Erreur interne du serveur."})


@app.get("/admin/dashboard/summary")
def admin_dashboard_summary(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    get_current_admin(authorization=authorization)
    access_token = _extract_bearer_token(authorization)

    profiles = _supabase_rest_get(
        "profiles",
        access_token,
        select="id, email, full_name, role, is_vip, needs_vps, created_at",
        order="created_at.desc.nullslast",
        limit=200,
    )
    accounts = _supabase_rest_get(
        "trading_accounts",
        access_token,
        select="id, user_id, mt5_login, mt5_server, account_type, balance, equity, is_active, last_sync",
        order="last_sync.desc.nullslast",
        limit=300,
    )
    payments = _supabase_rest_get(
        "payments",
        access_token,
        select="id, client, payment_type, payment_status, amount, montant, moyen, numero, payer_phone, destination_number, proof_url, preuve, statut, date, created_at, motif, review_reason",
        order="created_at.desc.nullslast",
        limit=200,
    )
    notifications = _supabase_rest_get(
        "notifications",
        access_token,
        select="id, user_id, title, message, priority, created_at",
        order="created_at.desc.nullslast",
        limit=100,
    )
    signals = _supabase_rest_get(
        "signals",
        access_token,
        select="id, master_account_id, ticket_id_mt5, symbol, trade_type, volume, status, created_at, closed_at",
        order="created_at.desc.nullslast",
        limit=200,
    )
    copied_trades = _supabase_rest_get(
        "copied_trades",
        access_token,
        select="id, signal_id, client_account_id, client_ticket_id, volume_executed, execution_status, profit, error_message, created_at, closed_at",
        order="created_at.desc.nullslast",
        limit=200,
    )
    support_tickets = _supabase_rest_get(
        "support_tickets",
        access_token,
        select="id, user_id, status, created_at",
        order="created_at.desc.nullslast",
        limit=100,
    )

    accounts_by_user: dict[str, list[dict[str, Any]]] = {}
    for account in accounts:
        user_id = str(account.get("user_id") or "")
        if not user_id:
            continue
        accounts_by_user.setdefault(user_id, []).append(account)

    user_cards: list[dict[str, Any]] = []
    for profile in profiles[:8]:
        user_id = str(profile.get("id") or "")
        linked_accounts = accounts_by_user.get(user_id, [])
        active_accounts = [account for account in linked_accounts if account.get("is_active")]
        user_cards.append(
            {
                "id": user_id,
                "email": profile.get("email"),
                "full_name": profile.get("full_name"),
                "role": profile.get("role"),
                "is_vip": bool(profile.get("is_vip")),
                "mt5_logins": [account.get("mt5_login") for account in linked_accounts if account.get("mt5_login")],
                "active_trading_accounts": len(active_accounts),
                "inactive_trading_accounts": len(linked_accounts) - len(active_accounts),
                "last_sync": linked_accounts[0].get("last_sync") if linked_accounts else None,
            }
        )

    dispatch_counts = storage.monitoring_counts()
    executed_dispatches = storage.list_dispatches(status_filter="EXECUTED", limit=200)
    latency_samples_ms: list[float] = []
    for dispatch in executed_dispatches:
        dispatched_at = _parse_iso_datetime(dispatch.get("dispatched_at"))
        executed_at = _parse_iso_datetime(dispatch.get("executed_at"))
        if dispatched_at is None or executed_at is None:
            continue
        latency_ms = (executed_at - dispatched_at).total_seconds() * 1000
        if latency_ms >= 0:
            latency_samples_ms.append(latency_ms)

    total_dispatches = sum(int(count) for count in dispatch_counts.values())
    total_status_dispatches = (
        dispatch_counts.get("PENDING", 0)
        + dispatch_counts.get("DISPATCHED", 0)
        + dispatch_counts.get("EXECUTED", 0)
        + dispatch_counts.get("FAILED", 0)
        + dispatch_counts.get("RETRY", 0)
        + dispatch_counts.get("CANCELLED", 0)
    )
    average_latency_ms = round(sum(latency_samples_ms) / len(latency_samples_ms), 0) if latency_samples_ms else None

    return {
        "users": {
            "total": len(profiles),
            "active": sum(1 for profile in profiles if str(profile.get("role") or "").upper() != "SUSPENDED"),
            "suspended": sum(1 for profile in profiles if str(profile.get("role") or "").upper() == "SUSPENDED"),
            "vip": sum(1 for profile in profiles if bool(profile.get("is_vip"))),
            "with_mt5": sum(1 for account in accounts if bool(account.get("mt5_login"))),
        },
        "accounts": {
            "total": len(accounts),
            "active": sum(1 for account in accounts if bool(account.get("is_active"))),
            "inactive": sum(1 for account in accounts if not bool(account.get("is_active"))),
            "master": sum(1 for account in accounts if str(account.get("account_type") or "").upper() == "MASTER"),
            "client": sum(1 for account in accounts if str(account.get("account_type") or "").upper() == "CLIENT"),
        },
        "payments": {
            "total": len(payments),
            "pending": _count_rows(payments, "payment_status", "PENDING_VALIDATION") + _count_rows(payments, "statut", "En attente"),
            "validated": _count_rows(payments, "payment_status", "APPROVED") + _count_rows(payments, "statut", "Validé"),
            "refused": _count_rows(payments, "payment_status", "REJECTED") + _count_rows(payments, "statut", "Refusé"),
            "amount_total": round(_sum_numeric_rows(payments, "amount"), 2),
        },
        "copytrading": {
            "signals_total": len(signals),
            "copied_total": len(copied_trades),
            "executed": _count_rows(copied_trades, "execution_status", "EXECUTED"),
            "failed": _count_rows(copied_trades, "execution_status", "FAILED"),
            "pending": _count_rows(copied_trades, "execution_status", "PENDING"),
            "retry": _count_rows(copied_trades, "execution_status", "RETRY"),
            "average_latency_ms": average_latency_ms,
            "dispatch_pipeline": dispatch_counts,
            "dispatch_pipeline_total": total_dispatches,
            "dispatch_pipeline_total_statuses": total_status_dispatches,
        },
        "activity": {
            "notifications": len(notifications),
            "support_tickets": len(support_tickets),
            "open_tickets": _count_rows(support_tickets, "status", "OPEN") + _count_rows(support_tickets, "status", "PENDING"),
            "signals": len(signals),
        },
        "recent_users": user_cards,
        "recent_copytrades": copied_trades[:8],
        "recent_payments": payments[:8],
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
    del x_admin_key
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="La cle admin partagee est desactivee. Utilisez un compte Supabase avec le role ADMIN.",
    )


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


@app.post("/payments/manual_request")
def manual_payment_request(payload: ManualPaymentRequestPayload, authorization: str | None = Header(default=None)) -> dict[str, Any]:
    auth_user = _supabase_user_from_jwt(_extract_bearer_token(authorization) or "")
    if str(auth_user.get("id") or "") != payload.user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Demande de paiement refusee.")

    profile_response = supabase.table("profiles").select("id").eq("id", payload.user_id).maybe_single().execute()
    if not profile_response.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable.")

    inserted = supabase.table("payments").insert(
        {
            "client": payload.user_id,
            "amount": payload.amount,
            "montant": payload.amount,
            "moyen": "Mobile Money",
            "numero": payload.payer_phone,
            "payer_phone": payload.payer_phone,
            "destination_number": payload.destination_number,
            "proof_url": payload.proof_url,
            "preuve": payload.proof_url,
            "payment_type": payload.payment_type,
            "payment_status": "PENDING_VALIDATION",
            "statut": "En attente",
            "date": datetime.now(timezone.utc).isoformat(),
        }
    ).execute()

    return {"status": "PENDING_VALIDATION", "payment": inserted.data[0] if inserted.data else None}


@app.get("/dashboard/state/{user_id}")
def dashboard_state(user_id: str, authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if authorization:
        auth_user = _supabase_user_from_jwt(_extract_bearer_token(authorization) or "")
        if str(auth_user.get("id") or "") != user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acces au tableau de bord refuse.")
    try:
        return _get_dashboard_payload(user_id, _extract_bearer_token(authorization))
    except Exception as exc:
        print(f"[DASHBOARD_STATE] unexpected error for user_id={user_id}: {exc}")
        _persist_error_log(
            source="backend",
            component="dashboard_state",
            severity="ERROR",
            message=str(exc),
            details={"user_id": user_id, "path": "/dashboard/state"},
            user_id=user_id,
        )
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




@app.post("/errors/log")
def report_error(payload: ErrorLogPayload, x_api_key: str | None = Header(default=None), authorization: str | None = Header(default=None)) -> dict[str, Any]:
    authorized = False
    if authorization:
        try:
            get_current_admin(authorization=authorization)
            authorized = True
        except HTTPException:
            authorized = False
    elif payload.mt5_login and payload.account_role and x_api_key:
        _verify_ea_api_key(payload.mt5_login, x_api_key, expected_role=payload.account_role)
        authorized = True

    if not authorized:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Autorisation invalide.")

    _persist_error_log(
        source=payload.source,
        component=payload.component,
        severity=payload.severity,
        message=payload.message,
        details=payload.details,
        user_id=payload.user_id,
        mt5_login=payload.mt5_login,
        trade_id=payload.trade_id,
    )
    return {"status": "ok"}


@app.post("/dashboard/connect_mt5")
def dashboard_connect_mt5(payload: DashboardConnectPayload, authorization: str | None = Header(default=None)) -> dict[str, Any]:
    access_token = _extract_bearer_token(authorization)
    auth_user = _supabase_user_from_jwt(access_token or "")
    if str(auth_user.get("id") or "") != payload.user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Connexion MT5 refusee.")
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
    auth_user = _supabase_user_from_jwt(access_token or "")
    if str(auth_user.get("id") or "") != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Deconnexion MT5 refusee.")
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
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Connexion admin legacy desactivee. Utilisez la connexion Supabase avec un compte role ADMIN.",
    )


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
    admin=Depends(get_current_admin),
) -> dict[str, str]:
    del admin
    result = storage.issue_api_key(payload.mt5_login, payload.account_role)
    print(f"[API_KEY] issued mt5_login={payload.mt5_login} role={payload.account_role}")
    return result


@app.get("/admin/trade_dispatches")
def list_trade_dispatches(
    client_login: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=100, ge=1, le=500),
    admin=Depends(get_current_admin),
) -> dict[str, list[dict[str, Any]]]:
    del admin
    return {
        "items": storage.list_dispatches(
            client_login=client_login,
            status_filter=status_filter,
            limit=limit,
        )
    }
