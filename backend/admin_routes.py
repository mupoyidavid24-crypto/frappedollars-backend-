from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any

import requests
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from backend.config import (
    get_app_settings_payload,
    get_business_rules_payload,
    get_current_admin,
    supabase,
    upsert_app_settings_payload,
    upsert_business_rules_payload,
)
from backend.error_reporting import report_exception

router = APIRouter(prefix="/admin", tags=["admin"])

FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY")


class KycStatusUpdatePayload(BaseModel):
    status: str = Field(min_length=1)
    reason: str | None = None
    reviewer_note: str | None = None


class PaymentDecisionPayload(BaseModel):
    motif: str | None = None


class BusinessRulesUpdatePayload(BaseModel):
    currency: str | None = None
    copy_trading_weekly_price: float | None = None
    vps_monthly_price: float | None = None


class AppSettingsUpdatePayload(BaseModel):
    app_name: str | None = None
    tagline: str | None = None
    logo_url: str | None = None
    primary_color_hex: str | None = None
    background_color_hex: str | None = None
    support_email: str | None = None
    support_phone: str | None = None


class PaymentMethodPayload(BaseModel):
    provider: str
    label: str
    account_name: str | None = None
    account_number: str | None = None
    is_active: bool = True
    metadata: dict[str, Any] | None = None


class UserVipPayload(BaseModel):
    is_vip: bool


class UserNeedsVpsPayload(BaseModel):
    needs_vps: bool


class VpsAssignmentPayload(BaseModel):
    status: str
    provider: str | None = None
    host_label: str | None = None
    notes: str | None = None


@router.get("/business-rules")
def read_business_rules(admin=Depends(get_current_admin)):
    del admin
    return get_business_rules_payload()


@router.put("/business-rules")
def update_business_rules(payload: BusinessRulesUpdatePayload, admin=Depends(get_current_admin)):
    admin_id = str(admin.get("id") or "")
    return upsert_business_rules_payload(payload.model_dump(exclude_none=True), updated_by=admin_id or None)


@router.get("/app-settings")
def read_app_settings(admin=Depends(get_current_admin)):
    del admin
    return get_app_settings_payload()


@router.put("/app-settings")
def update_app_settings(payload: AppSettingsUpdatePayload, admin=Depends(get_current_admin)):
    admin_id = str(admin.get("id") or "")
    return upsert_app_settings_payload(payload.model_dump(exclude_none=True), updated_by=admin_id or None)


@router.get("/payment-methods")
def list_payment_methods(admin=Depends(get_current_admin)):
    del admin
    try:
        res = (
            supabase.table("payment_methods")
            .select("id, provider, label, account_name, account_number, is_active, metadata, created_at, updated_at")
            .order("created_at", desc=True)
            .execute()
        )
        return res.data or []
    except Exception as exc:
        print(f"Erreur payment_methods: {exc}")
        report_exception("admin_routes.payment_methods", exc, source="backend", details={"route": "/admin/payment-methods"})
        return []


@router.post("/payment-methods")
def create_payment_method(payload: PaymentMethodPayload, admin=Depends(get_current_admin)):
    del admin
    result = supabase.table("payment_methods").insert(payload.model_dump()).execute()
    return result.data


@router.patch("/payment-methods/{method_id}")
def update_payment_method(method_id: str, payload: PaymentMethodPayload, admin=Depends(get_current_admin)):
    del admin
    result = supabase.table("payment_methods").update(payload.model_dump()).eq("id", method_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Methode de paiement introuvable")
    return result.data


@router.delete("/payment-methods/{method_id}")
def delete_payment_method(method_id: str, admin=Depends(get_current_admin)):
    del admin
    result = supabase.table("payment_methods").delete().eq("id", method_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Methode de paiement introuvable")
    return {"status": "deleted"}


def _count_rejected_kyc_documents(user_id: str) -> int:
    rejected = (
        supabase.table("kyc_documents")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .eq("status", "REJECTED")
        .execute()
    )
    return int(rejected.count or 0)


def _alert_admin_repeated_rejections(user_id: str, reviewer_id: str, rejected_count: int) -> None:
    profile_res = (
        supabase.table("profiles")
        .select("email, full_name")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )
    profile = profile_res.data or {}
    title = "Alerte KYC: rejets répétés"
    message = (
        f"L'utilisateur {profile.get('full_name') or profile.get('email') or user_id} a {rejected_count} dossiers KYC rejetés. "
        "Vérifier la conformité avant nouvelle soumission."
    )
    _send_user_notification(reviewer_id, title, message, "URGENT")


def _build_kyc_reason(status_value: str, reason: str | None, reviewer_note: str | None) -> str:
    cleaned_reason = (reason or reviewer_note or "").strip()
    if cleaned_reason:
        return cleaned_reason
    if status_value == "APPROVED":
        return "Dossier approuvé après vérification"
    if status_value == "PENDING":
        return "Dossier remis en attente pour révision"
    raise HTTPException(status_code=400, detail="Un motif KYC est obligatoire pour un rejet")


def _activate_manual_subscription(user_id: str, payment_type: str, payment_id: str) -> None:
    now = datetime.now(timezone.utc)
    duration = timedelta(days=30 if payment_type == "VPS_MONTHLY" else 7)
    supabase.table("subscriptions").insert(
        {
            "user_id": user_id,
            "type": payment_type,
            "status": "ACTIVE",
            "start_date": now.isoformat(),
            "end_date": (now + duration).isoformat(),
            "transaction_ref": f"MANUAL-{payment_id}",
            "auto_renew": True,
        }
    ).execute()


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
        report_exception("admin_routes.vip_dashboard", exc, source="backend", details={"route": "/admin/vip/dashboard"})
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
        report_exception("admin_routes.copytrading_history", exc, source="backend", details={"route": "/admin/copytrading/history"})
        return []


@router.get("/users")
def list_users(admin=Depends(get_current_admin)):
    del admin
    try:
        profiles = (
            supabase.table("profiles")
            .select("id, email, full_name, phone_number, date_of_birth, kyc_status, kyc_blocked, role, is_vip, needs_vps, created_at")
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
        report_exception("admin_routes.users", exc, source="backend", details={"route": "/admin/users"})
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
        report_exception("admin_routes.logs", exc, source="backend", details={"route": "/admin/logs"})
        return []

@router.get("/kyc/documents")
def list_kyc_documents(admin=Depends(get_current_admin)):
    del admin
    try:
        documents = (
            supabase.table("kyc_documents")
            .select("id, user_id, document_type, document_number, address_line, country, city, file_url, status, reason, reviewer_id, reviewer_note, submitted_at, reviewed_at")
            .order("submitted_at", desc=True)
            .execute()
        )
        profiles = (
            supabase.table("profiles")
            .select("id, email, full_name, phone_number, date_of_birth, kyc_status, kyc_blocked")
            .execute()
        )
        profiles_by_id = {str(row.get("id") or ""): row for row in (profiles.data or [])}

        response: list[dict[str, Any]] = []
        for row in documents.data or []:
            user_id = str(row.get("user_id") or "")
            profile = profiles_by_id.get(user_id, {})
            response.append(
                {
                    **row,
                    "profile": profile,
                    "age": _calculate_age(profile.get("date_of_birth") or row.get("submitted_at")),
                }
            )
        return response
    except Exception as exc:
        print(f"Erreur kyc/documents: {exc}")
        report_exception("admin_routes.kyc_documents", exc, source="backend", details={"route": "/admin/kyc/documents"})
        return []


@router.post("/kyc/documents/{document_id}/status")
def update_kyc_document_status(
    document_id: str,
    payload: KycStatusUpdatePayload,
    admin=Depends(get_current_admin),
):
    reviewer_id = admin.get("id")
    status_value = payload.status.strip().upper()
    if status_value not in {"APPROVED", "REJECTED", "PENDING"}:
        raise HTTPException(status_code=400, detail="Statut KYC invalide")

    document_res = (
        supabase.table("kyc_documents")
        .select("id, user_id, status, file_url")
        .eq("id", document_id)
        .maybe_single()
        .execute()
    )
    document = document_res.data or {}
    if not document:
        raise HTTPException(status_code=404, detail="Document KYC introuvable")

    reason = _build_kyc_reason(status_value, payload.reason, payload.reviewer_note)

    profile_update: dict[str, Any] = {
        "kyc_status": status_value,
        "kyc_blocked": status_value != "APPROVED",
    }
    document_update: dict[str, Any] = {
        "status": status_value,
        "reason": reason,
        "reviewer_id": reviewer_id,
        "reviewer_note": reason,
        "reviewed_at": datetime.now(timezone.utc).isoformat() if status_value != "PENDING" else None,
    }

    updated_document = (
        supabase.table("kyc_documents")
        .update(document_update)
        .eq("id", document_id)
        .execute()
    )
    if not updated_document.data:
        raise HTTPException(status_code=404, detail="Document KYC introuvable")

    user_id = str(document.get("user_id") or "")
    supabase.table("profiles").update(profile_update).eq("id", user_id).execute()

    if status_value == "APPROVED":
        _send_user_notification(
            user_id,
            "KYC approuvé",
            "Votre vérification KYC a été approuvée. Le copy trading est maintenant disponible.",
            "HIGH",
        )
    elif status_value == "REJECTED":
        _send_user_notification(
            user_id,
            "KYC rejeté",
            payload.reviewer_note or "Votre vérification KYC a été rejetée. Veuillez corriger vos informations et soumettre à nouveau.",
            "HIGH",
        )
    else:
        _send_user_notification(
            user_id,
            "KYC en attente",
            reason,
            "NORMAL",
        )

    rejected_count = _count_rejected_kyc_documents(user_id)
    if rejected_count >= 2:
        _alert_admin_repeated_rejections(user_id, reviewer_id, rejected_count)

    return {"status": status_value, "document_id": document_id}

    reason = _build_kyc_reason(status_value, payload.reason, payload.reviewer_note)



@router.post("/users/{user_id}/vip")
def set_user_vip(user_id: str, payload: UserVipPayload, admin=Depends(get_current_admin)):
    del admin
    current = supabase.table("profiles").select("role").eq("id", user_id).maybe_single().execute()
    current_row = current.data or {}
    if not current_row:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    next_role = "VIP" if payload.is_vip else "CLIENT"
    if str(current_row.get("role") or "").upper() == "ADMIN":
        raise HTTPException(status_code=403, detail="Impossible de modifier le role d'un ADMIN")

    result = supabase.table("profiles").update({"is_vip": payload.is_vip, "role": next_role}).eq("id", user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return {"status": "updated", "is_vip": payload.is_vip, "role": next_role}


@router.post("/users/{user_id}/vps")
def set_user_vps(user_id: str, payload: UserNeedsVpsPayload, admin=Depends(get_current_admin)):
    del admin
    profile_res = supabase.table("profiles").select("id, needs_vps").eq("id", user_id).maybe_single().execute()
    profile = profile_res.data or {}
    if not profile:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    result = supabase.table("profiles").update({"needs_vps": payload.needs_vps}).eq("id", user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    assignment_payload = {
        "user_id": user_id,
        "status": "CONNECTED" if payload.needs_vps else "DISCONNECTED",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    supabase.table("vps_assignments").upsert(assignment_payload, on_conflict="user_id").execute()
    return {"status": "updated", "needs_vps": payload.needs_vps}


@router.get("/vps/assignments")
def list_vps_assignments(admin=Depends(get_current_admin)):
    del admin
    try:
        assignments = (
            supabase.table("vps_assignments")
            .select("id, user_id, status, provider, host_label, notes, last_heartbeat, last_restart_requested_at, created_at, updated_at")
            .order("updated_at", desc=True)
            .execute()
        )
        profiles = supabase.table("profiles").select("id, email, full_name, needs_vps, role").execute()
        profile_by_id = {str(row.get("id") or ""): row for row in (profiles.data or [])}
        response: list[dict[str, Any]] = []
        for assignment in assignments.data or []:
            user_id = str(assignment.get("user_id") or "")
            response.append({**assignment, "profile": profile_by_id.get(user_id, {})})
        return response
    except Exception as exc:
        print(f"Erreur vps_assignments: {exc}")
        report_exception("admin_routes.vps_assignments", exc, source="backend", details={"route": "/admin/vps/assignments"})
        return []


@router.post("/vps/assignments/{user_id}/action")
def manage_vps_assignment(user_id: str, payload: VpsAssignmentPayload, admin=Depends(get_current_admin)):
    del admin
    status_value = payload.status.strip().upper()
    if status_value not in {"CONNECTED", "DISCONNECTED", "RESTART_REQUESTED", "ERROR"}:
        raise HTTPException(status_code=400, detail="Statut VPS invalide")

    update_data: dict[str, Any] = {
        "user_id": user_id,
        "status": status_value,
        "provider": payload.provider,
        "host_label": payload.host_label,
        "notes": payload.notes,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    if status_value == "RESTART_REQUESTED":
        update_data["last_restart_requested_at"] = datetime.now(timezone.utc).isoformat()

    supabase.table("vps_assignments").upsert(update_data, on_conflict="user_id").execute()
    if status_value == "CONNECTED":
        supabase.table("profiles").update({"needs_vps": True}).eq("id", user_id).execute()
    elif status_value == "DISCONNECTED":
        supabase.table("profiles").update({"needs_vps": False}).eq("id", user_id).execute()

    return {"status": status_value, "user_id": user_id}


@router.get("/support_tickets")
def get_support_tickets(admin=Depends(get_current_admin)):
    del admin
    try:
        res = supabase.table("support_tickets").select("id, subject, status, created_at, user_id").execute()
        return res.data or []
    except Exception as exc:
        print(f"Erreur support_tickets: {exc}")
        report_exception("admin_routes.support_tickets", exc, source="backend", details={"route": "/admin/support_tickets"})
        return []


@router.get("/payments")
def list_payments(admin=Depends(get_current_admin)):
    del admin
    try:
        res = supabase.table("payments").select(
            "id, client, payment_type, payment_status, montant, amount, moyen, numero, payer_phone, destination_number, preuve, proof_url, statut, date, created_at, motif, review_reason, reviewer_id, reviewed_at"
        ).execute()
        return res.data or []
    except Exception as exc:
        print(f"Erreur payments: {exc}")
        report_exception("admin_routes.payments", exc, source="backend", details={"route": "/admin/payments"})
        return []


@router.post("/payments/approve/{payment_id}")
def approve_payment(payment_id: str, admin=Depends(get_current_admin)):
    reviewer_id = admin.get("id")
    payment_res = (
        supabase.table("payments")
        .select("id, client, payment_type, montant, amount")
        .eq("id", payment_id)
        .maybe_single()
        .execute()
    )
    payment_row = payment_res.data or {}
    if not payment_row:
        raise HTTPException(status_code=404, detail="Paiement introuvable")

    updated = supabase.table("payments").update(
        {
            "payment_status": "APPROVED",
            "statut": "Validé",
            "reviewer_id": reviewer_id,
            "reviewed_at": datetime.now(timezone.utc).isoformat(),
            "review_reason": None,
        }
    ).eq("id", payment_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Paiement introuvable")

    user_id = str(payment_row.get("client") or "")
    payment_type = str(payment_row.get("payment_type") or "COPY_TRADING_WEEKLY")
    amount = payment_row.get("montant") or payment_row.get("amount")
    if user_id:
        try:
            _activate_manual_subscription(user_id, payment_type, payment_id)
            _send_user_notification(
                user_id,
                "Paiement approuvé",
                f"Votre paiement Mobile Money de {amount}$ a été approuvé. L'abonnement est maintenant actif.",
                "HIGH",
            )
        except Exception as exc:
            print(f"Erreur activation abonnement paiement: {exc}")
    return {"status": "approved"}


@router.post("/payments/reject/{payment_id}")
def reject_payment(payment_id: str, payload: PaymentDecisionPayload, admin=Depends(get_current_admin)):
    reviewer_id = admin.get("id")
    reason = (payload.motif or "").strip()
    if not reason:
        raise HTTPException(status_code=400, detail="Un motif est obligatoire pour le rejet")

    payment_res = supabase.table("payments").select("client").eq("id", payment_id).maybe_single().execute()
    payment_row = payment_res.data or {}

    updated = supabase.table("payments").update(
        {
            "payment_status": "REJECTED",
            "statut": "Refusé",
            "reviewer_id": reviewer_id,
            "reviewed_at": datetime.now(timezone.utc).isoformat(),
            "review_reason": reason,
            "motif": reason,
        }
    ).eq("id", payment_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Paiement introuvable")

    user_id = str(payment_row.get("client") or "")
    if user_id:
        _send_user_notification(user_id, "Paiement rejeté", reason, "HIGH")
    return {"status": "rejected"}


@router.post("/notifications/send")
def send_notification(data: dict, admin=Depends(get_current_admin)):
    del admin
    user_id = data.get("user_id")
    if not user_id:
        raise HTTPException(status_code=400, detail="user_id manquant")
    title = data.get("title", "Notification")
    message = data.get("message", "")
    priority = data.get("priority", "NORMAL")
    _send_user_notification(str(user_id), str(title), str(message), str(priority))
    return {"status": "sent"}


@router.get("/notifications")
def list_notifications(admin=Depends(get_current_admin)):
    del admin
    try:
        res = supabase.table("notifications").select("id, user_id, title, message, priority, created_at").execute()
        return res.data or []
    except Exception as exc:
        print(f"Erreur notifications: {exc}")
        report_exception("admin_routes.notifications", exc, source="backend", details={"route": "/admin/notifications"})
        return []


def _calculate_age(date_value: Any) -> int | None:
    if not date_value:
        return None
    try:
        parsed = datetime.fromisoformat(str(date_value).replace("Z", "+00:00"))
        today = datetime.now(timezone.utc)
        age = today.year - parsed.year - ((today.month, today.day) < (parsed.month, parsed.day))
        return age
    except Exception:
        return None


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


@router.get("/errors")
def list_errors(admin=Depends(get_current_admin)):
    del admin
    try:
        res = (
            supabase.table("errors_logs")
            .select("id, source, component, severity, message, details, user_id, mt5_login, trade_id, created_at")
            .order("created_at", desc=True)
            .limit(200)
            .execute()
        )
        return res.data or []
    except Exception as exc:
        print(f"Erreur errors_logs: {exc}")
        report_exception("admin_routes.errors", exc, source="backend", details={"route": "/admin/errors"})
        return []
