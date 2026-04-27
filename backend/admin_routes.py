from __future__ import annotations

import os
from typing import Any

import requests
from fastapi import APIRouter, Depends, HTTPException

from backend.config import get_current_admin, supabase

router = APIRouter(prefix="/admin", tags=["admin"])

FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY")


@router.post("/add_payment_method")
def add_payment_method(method: dict, admin=Depends(get_current_admin)):
    del admin
    res = supabase.table("payment_methods").insert(method).execute()
    return res.data


@router.post("/block_user/{user_id}")
def block_user(user_id: str, admin=Depends(get_current_admin)):
    del admin
    user = supabase.table("profiles").select("is_vip, role").eq("id", user_id).execute()
    if user.data:
        row = user.data[0]
        if row.get("is_vip") or row.get("role") == "ADMIN":
            raise HTTPException(status_code=403, detail="Impossible de bloquer un VIP ou un ADMIN")
    updated = supabase.table("profiles").update({"role": "SUSPENDED"}).eq("id", user_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return {"status": "bloque"}


@router.post("/add_vip_client")
def add_vip_client(data: dict, admin=Depends(get_current_admin)):
    del admin
    client_id = data.get("id")
    if not client_id:
        raise HTTPException(status_code=400, detail="id du client manquant")
    updated = supabase.table("profiles").update({"is_vip": True, "role": "VIP"}).eq("id", client_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return {"status": "VIP ajoute"}


@router.get("/vip/dashboard")
def vip_dashboard(admin=Depends(get_current_admin)):
    del admin
    try:
        vip_users = (
            supabase.table("profiles")
            .select("id, email, full_name, is_vip, created_at, total_profit")
            .eq("is_vip", True)
            .order("created_at", desc=True)
            .limit(100)
            .execute()
        )
        return vip_users.data or []
    except Exception as exc:
        print(f"Erreur vip/dashboard: {exc}")
        return []


@router.post("/sync_with_master/{client_id}")
def sync_with_master(client_id: str, admin=Depends(get_current_admin)):
    del admin
    admin_profile = supabase.table("profiles").select("id").eq("role", "ADMIN").execute()
    if not admin_profile.data:
        raise HTTPException(status_code=404, detail="Admin introuvable")

    master_acc = (
        supabase.table("trading_accounts")
        .select("id")
        .eq("user_id", admin_profile.data[0]["id"])
        .eq("account_type", "MASTER")
        .execute()
    )
    if not master_acc.data:
        raise HTTPException(status_code=404, detail="Compte master introuvable")

    updated = (
        supabase.table("trading_accounts")
        .update({"master_account_id": master_acc.data[0]["id"]})
        .eq("user_id", client_id)
        .execute()
    )
    if not updated.data:
        raise HTTPException(status_code=404, detail="Compte client introuvable")
    return {"status": "Synchronise avec master"}


@router.get("/copytrading/status/{client_id}")
def get_copytrading_status(client_id: str, admin=Depends(get_current_admin)):
    del admin
    acc = supabase.table("trading_accounts").select("is_active, master_account_id").eq("user_id", client_id).execute()
    if not acc.data:
        raise HTTPException(status_code=404, detail="Compte client introuvable")
    return acc.data[0]


@router.get("/copytrading/history")
def get_copytrading_history(admin=Depends(get_current_admin)):
    del admin
    try:
        history = (
            supabase.table("copied_trades")
            .select("id, signal_id, client_account_id, volume_executed, execution_status, profit, error_message, created_at, closed_at")
            .order("created_at", desc=True)
            .limit(100)
            .execute()
        )
        items: list[dict[str, Any]] = []
        for row in history.data or []:
            status = (row.get("execution_status") or "").upper()
            created_at = row.get("created_at")
            closed_at = row.get("closed_at")
            items.append(
                {
                    "id": row.get("id"),
                    "action": status or row.get("error_message") or "COPY",
                    "status": status or "UNKNOWN",
                    "date": created_at or closed_at,
                    "created_at": created_at,
                    "closed_at": closed_at,
                    "signal_id": row.get("signal_id"),
                    "client_account_id": row.get("client_account_id"),
                    "volume_executed": row.get("volume_executed"),
                    "profit": row.get("profit"),
                    "error_message": row.get("error_message"),
                }
            )
        return items
    except Exception as exc:
        print(f"Erreur copytrading/history: {exc}")
        return []


@router.get("/users")
def list_users(admin=Depends(get_current_admin)):
    del admin
    try:
        profiles = (
            supabase.table("profiles")
            .select("id, email, full_name, role, is_vip, needs_vps, created_at")
            .order("created_at", desc=True)
            .execute()
        )
        accounts = (
            supabase.table("trading_accounts")
            .select("id, user_id, mt5_login, account_type, is_active, master_account_id, created_at")
            .order("created_at", desc=True)
            .execute()
        )

        accounts_by_user_id: dict[str, list[dict[str, Any]]] = {}
        for account in accounts.data or []:
            user_id = str(account.get("user_id") or "")
            if not user_id:
                continue
            accounts_by_user_id.setdefault(user_id, []).append(account)

        users: list[dict[str, Any]] = []
        for profile in profiles.data or []:
            user_id = str(profile.get("id") or "")
            linked_accounts = accounts_by_user_id.get(user_id, [])
            active_accounts = [account for account in linked_accounts if account.get("is_active")]
            users.append(
                {
                    **profile,
                    "trading_accounts": linked_accounts,
                    "mt5_logins": [account.get("mt5_login") for account in linked_accounts if account.get("mt5_login")],
                    "has_trading_account": bool(linked_accounts),
                    "active_trading_accounts": len(active_accounts),
                    "inactive_trading_accounts": len(linked_accounts) - len(active_accounts),
                    "primary_mt5_login": (linked_accounts[0].get("mt5_login") if linked_accounts else None),
                }
            )

        return users
    except Exception as exc:
        print(f"Erreur users: {exc}")
        return []


@router.post("/users/activate/{user_id}")
def activate_user(user_id: str, admin=Depends(get_current_admin)):
    del admin
    profile = supabase.table("profiles").select("id, is_vip").eq("id", user_id).maybe_single().execute()
    profile_row = profile.data or {}
    if not profile_row:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    next_role = "VIP" if profile_row.get("is_vip") else "CLIENT"
    updated = supabase.table("profiles").update({"role": next_role}).eq("id", user_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return {"status": "active", "role": next_role}


@router.post("/users/suspend/{user_id}")
def suspend_user(user_id: str, admin=Depends(get_current_admin)):
    del admin
    updated = supabase.table("profiles").update({"role": "SUSPENDED"}).eq("id", user_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return {"status": "suspendu"}


@router.delete("/users/{user_id}")
def delete_user(user_id: str, admin=Depends(get_current_admin)):
    del admin
    deleted = supabase.table("profiles").delete().eq("id", user_id).execute()
    if not deleted.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return {"status": "supprime"}


@router.get("/logs")
def get_logs(admin=Depends(get_current_admin)):
    del admin
    try:
        logs = (
            supabase.table("admin_access_logs")
            .select("id, username, access_time, ip")
            .order("access_time", desc=True)
            .limit(100)
            .execute()
        )
        return logs.data or []
    except Exception as exc:
        print(f"Erreur logs: {exc}")
        return []


@router.get("/support_tickets")
def get_support_tickets(admin=Depends(get_current_admin)):
    del admin
    try:
        res = supabase.table("support_tickets").select("id, subject, status, created_at, user_id").execute()
        return res.data or []
    except Exception as exc:
        print(f"Erreur support_tickets: {exc}")
        return []


@router.get("/payments")
def list_payments(admin=Depends(get_current_admin)):
    del admin
    try:
        res = supabase.table("payments").select("id, user_id, amount, status, method, proof_url, created_at, transaction_id, entity").execute()
        return res.data or []
    except Exception as exc:
        print(f"Erreur payments: {exc}")
        return []


@router.post("/payments/validate/{payment_id}")
def validate_payment(payment_id: str, admin=Depends(get_current_admin)):
    del admin
    updated = supabase.table("payments").update({"status": "VALIDATED"}).eq("id", payment_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Paiement introuvable")

    payment = supabase.table("payments").select("user_id, amount").eq("id", payment_id).maybe_single().execute()
    payment_row = payment.data or {}
    if payment_row:
        user_id = payment_row.get("user_id")
        amount = payment_row.get("amount")
        if user_id is not None and amount is not None:
            try:
                send_notification(
                    {
                        "user_id": user_id,
                        "title": "Paiement valide",
                        "message": f"Votre paiement de {amount}$ a ete valide. Merci !",
                        "priority": "HIGH",
                    }
                )
            except Exception as exc:
                print(f"Erreur notification paiement: {exc}")
    return {"status": "valide"}


@router.post("/payments/refuse/{payment_id}")
def refuse_payment(payment_id: str, motif: dict, admin=Depends(get_current_admin)):
    del admin
    updated = supabase.table("payments").update({"status": "REFUSED", "motif": motif.get("motif", "")}).eq("id", payment_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Paiement introuvable")
    return {"status": "refuse"}


@router.post("/notifications/send")
def send_notification(data: dict, admin=Depends(get_current_admin)):
    del admin
    notif = supabase.table("notifications").insert(data).execute()
    user_id = data.get("user_id")
    token_res = supabase.table("profiles").select("fcm_token").eq("id", user_id).execute()
    fcm_token = token_res.data[0]["fcm_token"] if token_res.data and token_res.data[0].get("fcm_token") else None

    if fcm_token and FCM_SERVER_KEY:
        fcm_payload = {
            "to": fcm_token,
            "notification": {
                "title": data.get("title", "Notification"),
                "body": data.get("message", ""),
            },
            "data": {
                "priority": data.get("priority", "NORMAL"),
            },
        }
        headers = {
            "Authorization": f"key={FCM_SERVER_KEY}",
            "Content-Type": "application/json",
        }
        try:
            requests.post("https://fcm.googleapis.com/fcm/send", json=fcm_payload, headers=headers, timeout=10)
        except Exception as exc:
            print(f"Erreur FCM: {exc}")
    return notif.data


@router.get("/notifications")
def list_notifications(admin=Depends(get_current_admin)):
    del admin
    try:
        res = supabase.table("notifications").select("id, user_id, title, message, priority, created_at").execute()
        return res.data or []
    except Exception as exc:
        print(f"Erreur notifications: {exc}")
        return []


@router.get("/logs/detailed")
def get_detailed_logs(admin=Depends(get_current_admin)):
    del admin
    logs = (
        supabase.table("admin_access_logs")
        .select("id, admin_id, action, timestamp, ip_address")
        .order("timestamp", desc=True)
        .limit(100)
        .execute()
    )
    return logs.data
