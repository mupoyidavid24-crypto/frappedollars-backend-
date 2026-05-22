from __future__ import annotations

from datetime import datetime, timezone
import os
from typing import Any
import traceback

from decimal import Decimal
import requests
from dotenv import load_dotenv
from fastapi import Header, HTTPException, status
from supabase import create_client

from backend.error_reporting import report_exception

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_KEY")
SUPABASE_SERVICE_ROLE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_KEY")
)

if not SUPABASE_URL or not SUPABASE_ANON_KEY or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError(
        "Les variables SUPABASE_URL, SUPABASE_ANON_KEY et SUPABASE_SERVICE_ROLE_KEY doivent etre definies dans le fichier .env"
    )

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


def _extract_bearer_token(authorization: str | None) -> str | None:
    if not authorization:
        return None
    if authorization.lower().startswith("bearer "):
        return authorization.split(" ", 1)[1].strip() or None
    return authorization.strip() or None


def _supabase_user_from_jwt(access_token: str) -> dict[str, Any]:
    try:
        response = requests.get(
            f"{SUPABASE_URL.rstrip('/')}/auth/v1/user",
            headers={
                "apikey": SUPABASE_ANON_KEY,
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/json",
            },
            timeout=15,
        )
    except requests.RequestException as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Impossible de joindre Supabase Auth pour verifier la session.",
        ) from exc

    if response.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token Supabase invalide ou expire.",
        )
    payload = response.json()
    if not isinstance(payload, dict) or not payload.get("id"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utilisateur Supabase introuvable.",
        )
    return payload


def get_current_admin(authorization: str | None = Header(default=None)):
    try:
        access_token = _extract_bearer_token(authorization)
        if not access_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Jeton Supabase requis.",
            )

        auth_user = _supabase_user_from_jwt(access_token)
        profile = (
            supabase.table("profiles")
            .select("id, email, full_name, role, is_vip, needs_vps")
            .eq("id", auth_user["id"])
            .maybe_single()
            .execute()
        )
        profile_row = getattr(profile, "data", None) or {}
        if not profile_row:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Profil Supabase introuvable.",
            )
        if str(profile_row.get("role") or "").upper() != "ADMIN":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Acces admin refuse.",
            )
        return profile_row
    except HTTPException:
        raise
    except Exception as exc:
        print("[ADMIN_AUTH] unexpected error:")
        print(traceback.format_exc())
        report_exception(
            "config.get_current_admin",
            exc,
            source="backend",
            details={
                "has_authorization": bool(authorization),
            },
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Verification de session admin indisponible.",
        ) from exc


BUSINESS_RULE_DEFAULTS: dict[str, object] = {
    "currency": "USD",
    "copy_trading_weekly_price": 50.0,
    "vps_monthly_price": 30.0,
    "weekly_profit_limit": 120.0,
    "weekly_profit_limit_nature": "technical_limit",
    "weekly_profit_limit_description": (
        "Limite technique de protection: la copie s'arrete automatiquement lorsque le profit hebdomadaire atteint 120 USD."
    ),
    "minimum_capital_required": 30.0,
    "subscription_payment_window_weekdays": [5, 6],
}

PRICES = {
    "COPY_TRADING_WEEKLY": float(BUSINESS_RULE_DEFAULTS["copy_trading_weekly_price"]),
    "VPS_MONTHLY": float(BUSINESS_RULE_DEFAULTS["vps_monthly_price"]),
}

WEEKLY_PROFIT_LIMIT = float(BUSINESS_RULE_DEFAULTS["weekly_profit_limit"])
MIN_CAPITAL_REQUIRED = float(BUSINESS_RULE_DEFAULTS["minimum_capital_required"])

BUSINESS_RULES = dict(BUSINESS_RULE_DEFAULTS)

APP_SETTINGS_DEFAULTS: dict[str, object] = {
    "app_name": "FrappedDollars",
    "tagline": "Copy trading automatique pour comptes MT5.",
    "logo_url": None,
    "primary_color_hex": "#00C853",
    "background_color_hex": "#121212",
    "support_email": None,
    "support_phone": None,
}


def _coerce_float(value: Any, fallback: float) -> float:
    if isinstance(value, bool):
        return fallback
    if isinstance(value, (int, float, Decimal)):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return fallback


def _coerce_weekdays(value: Any) -> list[int]:
    if isinstance(value, list):
        weekdays: list[int] = []
        for item in value:
            try:
                weekday = int(item)
            except (TypeError, ValueError):
                continue
            if 1 <= weekday <= 7:
                weekdays.append(weekday)
        return weekdays or [5, 6]
    return [5, 6]


def _normalize_color_hex(value: Any, fallback: str) -> str:
    text = str(value or "").strip().lstrip("#")
    if len(text) == 6:
        return f"#{text.upper()}"
    return fallback


def _merge_business_rules(row: dict[str, Any] | None) -> dict[str, object]:
    merged = dict(BUSINESS_RULE_DEFAULTS)
    if not row:
        return merged

    merged["currency"] = str(row.get("currency") or merged["currency"])
    merged["copy_trading_weekly_price"] = _coerce_float(
        row.get("copy_trading_weekly_price"),
        float(merged["copy_trading_weekly_price"]),
    )
    merged["vps_monthly_price"] = _coerce_float(row.get("vps_monthly_price"), float(merged["vps_monthly_price"]))
    merged["weekly_profit_limit"] = _coerce_float(row.get("weekly_profit_limit"), float(merged["weekly_profit_limit"]))
    merged["weekly_profit_limit_nature"] = str(row.get("weekly_profit_limit_nature") or merged["weekly_profit_limit_nature"])
    merged["weekly_profit_limit_description"] = str(
        row.get("weekly_profit_limit_description") or merged["weekly_profit_limit_description"]
    )
    merged["minimum_capital_required"] = _coerce_float(
        row.get("minimum_capital_required"),
        float(merged["minimum_capital_required"]),
    )
    merged["subscription_payment_window_weekdays"] = _coerce_weekdays(row.get("subscription_payment_window_weekdays"))
    return merged


def _business_rules_payload_from_updates(payload: dict[str, Any]) -> dict[str, object]:
    return {
        "currency": str(payload.get("currency") or BUSINESS_RULE_DEFAULTS["currency"]),
        "copy_trading_weekly_price": _coerce_float(
            payload.get("copy_trading_weekly_price"),
            float(BUSINESS_RULE_DEFAULTS["copy_trading_weekly_price"]),
        ),
        "vps_monthly_price": _coerce_float(
            payload.get("vps_monthly_price"),
            float(BUSINESS_RULE_DEFAULTS["vps_monthly_price"]),
        ),
        "weekly_profit_limit": _coerce_float(
            payload.get("weekly_profit_limit"),
            float(BUSINESS_RULE_DEFAULTS["weekly_profit_limit"]),
        ),
        "weekly_profit_limit_nature": str(
            payload.get("weekly_profit_limit_nature") or BUSINESS_RULE_DEFAULTS["weekly_profit_limit_nature"]
        ),
        "weekly_profit_limit_description": str(
            payload.get("weekly_profit_limit_description") or BUSINESS_RULE_DEFAULTS["weekly_profit_limit_description"]
        ),
        "minimum_capital_required": _coerce_float(
            payload.get("minimum_capital_required"),
            float(BUSINESS_RULE_DEFAULTS["minimum_capital_required"]),
        ),
        "subscription_payment_window_weekdays": _coerce_weekdays(payload.get("subscription_payment_window_weekdays")),
    }


def _merge_app_settings(row: dict[str, Any] | None) -> dict[str, object]:
    merged = dict(APP_SETTINGS_DEFAULTS)
    if not row:
        return merged

    merged["app_name"] = str(row.get("app_name") or merged["app_name"])
    merged["tagline"] = str(row.get("tagline") or merged["tagline"])
    merged["logo_url"] = row.get("logo_url") or merged["logo_url"]
    merged["primary_color_hex"] = _normalize_color_hex(row.get("primary_color_hex"), str(merged["primary_color_hex"]))
    merged["background_color_hex"] = _normalize_color_hex(row.get("background_color_hex"), str(merged["background_color_hex"]))
    merged["support_email"] = row.get("support_email") or merged["support_email"]
    merged["support_phone"] = row.get("support_phone") or merged["support_phone"]
    return merged


def _app_settings_payload_from_updates(payload: dict[str, Any]) -> dict[str, object]:
    return {
        "app_name": str(payload.get("app_name") or APP_SETTINGS_DEFAULTS["app_name"]),
        "tagline": str(payload.get("tagline") or APP_SETTINGS_DEFAULTS["tagline"]),
        "logo_url": payload.get("logo_url") or None,
        "primary_color_hex": _normalize_color_hex(payload.get("primary_color_hex"), str(APP_SETTINGS_DEFAULTS["primary_color_hex"])),
        "background_color_hex": _normalize_color_hex(payload.get("background_color_hex"), str(APP_SETTINGS_DEFAULTS["background_color_hex"])),
        "support_email": payload.get("support_email") or None,
        "support_phone": payload.get("support_phone") or None,
    }


def get_business_rules_payload() -> dict[str, object]:
    try:
        response = (
            supabase.table("business_rules")
            .select(
                "id, currency, copy_trading_weekly_price, vps_monthly_price, weekly_profit_limit, weekly_profit_limit_nature, weekly_profit_limit_description, minimum_capital_required, subscription_payment_window_weekdays, updated_at",
            )
            .order("updated_at", desc=True)
            .limit(1)
            .execute()
        )
        row = (response.data or [{}])[0]
        return _merge_business_rules(row if isinstance(row, dict) else None)
    except Exception:
        return dict(BUSINESS_RULE_DEFAULTS)


def upsert_business_rules_payload(payload: dict[str, Any], updated_by: str | None = None) -> dict[str, object]:
    normalized = _business_rules_payload_from_updates(payload)
    if updated_by:
        normalized["updated_by"] = updated_by
    normalized["updated_at"] = datetime.now(timezone.utc).isoformat()

    try:
        existing = (
            supabase.table("business_rules")
            .select("id")
            .order("updated_at", desc=True)
            .limit(1)
            .execute()
        )
        existing_row = (existing.data or [{}])[0]
        existing_id = existing_row.get("id") if isinstance(existing_row, dict) else None
        if existing_id:
            result = supabase.table("business_rules").update(normalized).eq("id", existing_id).execute()
        else:
            result = supabase.table("business_rules").insert(normalized).execute()
        row = (result.data or [normalized])[0]
        return _merge_business_rules(row if isinstance(row, dict) else normalized)
    except Exception:
        return _merge_business_rules(normalized)


def get_business_rules_payload() -> dict[str, object]:
    try:
        response = (
            supabase.table("business_rules")
            .select(
                "id, currency, copy_trading_weekly_price, vps_monthly_price, weekly_profit_limit, weekly_profit_limit_nature, weekly_profit_limit_description, minimum_capital_required, subscription_payment_window_weekdays, updated_at",
            )
            .order("updated_at", desc=True)
            .limit(1)
            .execute()
        )
        row = (response.data or [{}])[0]
        return _merge_business_rules(row if isinstance(row, dict) else None)
    except Exception:
        return dict(BUSINESS_RULE_DEFAULTS)


def get_app_settings_payload() -> dict[str, object]:
    try:
        response = (
            supabase.table("app_settings")
            .select("id, app_name, tagline, logo_url, primary_color_hex, background_color_hex, support_email, support_phone, updated_at")
            .eq("id", 1)
            .maybe_single()
            .execute()
        )
        row = response.data or {}
        return _merge_app_settings(row if isinstance(row, dict) else None)
    except Exception:
        return dict(APP_SETTINGS_DEFAULTS)


def upsert_app_settings_payload(payload: dict[str, Any], updated_by: str | None = None) -> dict[str, object]:
    normalized = _app_settings_payload_from_updates(payload)
    if updated_by:
        normalized["updated_by"] = updated_by
    normalized["updated_at"] = datetime.now(timezone.utc).isoformat()

    try:
        result = supabase.table("app_settings").upsert({"id": 1, **normalized}).execute()
        row = (result.data or [normalized])[0]
        return _merge_app_settings(row if isinstance(row, dict) else normalized)
    except Exception:
        return _merge_app_settings(normalized)
