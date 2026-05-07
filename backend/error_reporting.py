from __future__ import annotations

from traceback import format_exception
from typing import Any

from backend.config import supabase


def _clean_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def record_error_log(
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
    payload = {
        "source": _clean_text(source) or "backend",
        "component": _clean_text(component) or "unknown",
        "severity": _clean_text(severity) or "ERROR",
        "message": _clean_text(message) or "Erreur inconnue",
        "details": details or {},
        "user_id": _clean_text(user_id),
        "mt5_login": _clean_text(mt5_login),
        "trade_id": _clean_text(trade_id),
    }

    try:
        supabase.table("errors_logs").insert(payload).execute()
    except Exception as exc:
        print(f"[ERROR_LOGGING] impossible d'ecrire dans errors_logs: {exc}")


def report_exception(
    component: str,
    exc: Exception,
    *,
    source: str = "backend",
    severity: str = "ERROR",
    details: dict[str, Any] | None = None,
    user_id: str | None = None,
    mt5_login: str | None = None,
    trade_id: str | None = None,
) -> None:
    payload_details = dict(details or {})
    payload_details.setdefault("exception_type", exc.__class__.__name__)
    payload_details.setdefault(
        "traceback",
        "".join(format_exception(type(exc), exc, exc.__traceback__)),
    )
    record_error_log(
        source=source,
        component=component,
        severity=severity,
        message=str(exc),
        details=payload_details,
        user_id=user_id,
        mt5_login=mt5_login,
        trade_id=trade_id,
    )
