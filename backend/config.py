from __future__ import annotations

import os
from typing import Any

import requests
from dotenv import load_dotenv
from fastapi import Header, HTTPException, status
from supabase import create_client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_KEY")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")

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
    response = requests.get(
        f"{SUPABASE_URL.rstrip('/')}/auth/v1/user",
        headers={
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        },
        timeout=15,
    )
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
    profile_row = profile.data or {}
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

PRICES = {
    "COPY_TRADING_WEEKLY": 50.0,
    "VPS_MONTHLY": 35.0,
}

WEEKLY_PROFIT_LIMIT = 250.0
MIN_CAPITAL_REQUIRED = 30.0
