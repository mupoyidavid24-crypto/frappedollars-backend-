from fastapi import APIRouter, Depends, HTTPException, FastAPI
import os
import requests
from supabase import create_client
from typing import List
from backend.config import supabase, get_current_admin

router = APIRouter()

# --- Ajout pour permettre le lancement avec Uvicorn ---
app = FastAPI()
app.include_router(router)
import requests
from supabase import create_client
from typing import List
from backend.config import supabase, get_current_admin
router = APIRouter()

@router.post("/add_payment_method")
def add_payment_method(method: dict, admin=Depends(get_current_admin)):
    res = supabase.table("payment_methods").insert(method).execute()
    return res.data

@router.post("/block_user/{user_id}")
def block_user(user_id: str, admin=Depends(get_current_admin)):
    user = supabase.table("profiles").select("is_vip, role").eq("id", user_id).execute()
    if user.data and (user.data[0]["is_vip"] or user.data[0]["role"] == "ADMIN"):
        raise HTTPException(status_code=403, detail="Impossible de bloquer un VIP ou un ADMIN")
    updated = supabase.table("profiles").update({"role": "SUSPENDED"}).eq("id", user_id).execute()
    return {"status": "bloqué"}
@router.post("/add_vip_client")
def add_vip_client(data: dict, admin=Depends(get_current_admin)):
    # data doit contenir l'id du client
    updated = supabase.table("profiles").update({"is_vip": True, "role": "VIP"}).eq("id", data["id"]).execute()
    return {"status": "VIP ajouté"}
# Endpoint tableau de bord VIP
@router.get("/vip/dashboard")
def vip_dashboard(admin=Depends(get_current_admin)):
    vip_users = supabase.table("profiles").select("id, email, full_name, is_vip, created_at, total_profit").eq("is_vip", True).order("created_at", desc=True).limit(100).execute()
    return vip_users.data

@router.post("/sync_with_master/{client_id}")
def sync_with_master(client_id: str, admin=Depends(get_current_admin)):
    # Synchronise le compte client avec le compte master de l'admin
    admin_profile = supabase.table("profiles").select("id").eq("role", "ADMIN").execute()
    if not admin_profile.data:
        raise HTTPException(status_code=404, detail="Admin introuvable")
    master_acc = supabase.table("trading_accounts").select("id").eq("user_id", admin_profile.data[0]["id"]).eq("account_type", "MASTER").execute()
    if not master_acc.data:
        raise HTTPException(status_code=404, detail="Compte master introuvable")
    updated = supabase.table("trading_accounts").update({"master_account_id": master_acc.data[0]["id"]}).eq("user_id", client_id).execute()
    return {"status": "Synchronisé avec master"}

# Endpoint pour statut et historique copy trading
@router.get("/copytrading/status/{client_id}")
def get_copytrading_status(client_id: str, admin=Depends(get_current_admin)):
    acc = supabase.table("trading_accounts").select("is_active, master_account_id").eq("user_id", client_id).execute()
    if not acc.data:
        raise HTTPException(status_code=404, detail="Compte client introuvable")
    return acc.data[0]

@router.get("/copytrading/history")
def get_copytrading_history(admin=Depends(get_current_admin)):
    history = supabase.table("copied_trades").select("id, signal_id, client_account_id, volume_executed, execution_status, profit, error_message, created_at, closed_at").order("created_at", desc=True).limit(100).execute()
    return history.data
from fastapi import APIRouter, HTTPException, Depends
from supabase import create_client
from typing import List
from backend.config import supabase, get_current_admin

router = APIRouter(prefix="/admin", tags=["admin"])
from fastapi import APIRouter, Depends, HTTPException
import os
router = APIRouter(prefix="/admin", tags=["admin"])

@router.post("/add_payment_method")
def add_payment_method(method: dict, admin=Depends(get_current_admin)):
    res = supabase.table("payment_methods").insert(method).execute()
    return res.data

@router.post("/block_user/{user_id}")
def block_user(user_id: str, admin=Depends(get_current_admin)):
    user = supabase.table("profiles").select("is_vip").eq("id", user_id).execute()
    if user.data and user.data[0]["is_vip"]:
        raise HTTPException(status_code=403, detail="Impossible de bloquer un VIP")
    updated = supabase.table("profiles").update({"role": "SUSPENDED"}).eq("id", user_id).execute()
    return {"status": "bloqué"}

@router.post("/add_vip_client")
def add_vip_client(data: dict, admin=Depends(get_current_admin)):
    # data doit contenir l'id du client
    updated = supabase.table("profiles").update({"is_vip": True}).eq("id", data["id"]).execute()
    return {"status": "VIP ajouté"}

@router.post("/sync_with_master/{client_id}")
def sync_with_master(client_id: str, admin=Depends(get_current_admin)):
    # Synchronise le compte client avec le compte master de l'admin
    admin_profile = supabase.table("profiles").select("id").eq("role", "ADMIN").execute()
    if not admin_profile.data:
        raise HTTPException(status_code=404, detail="Admin introuvable")
    master_acc = supabase.table("trading_accounts").select("id").eq("user_id", admin_profile.data[0]["id"]).eq("account_type", "MASTER").execute()
    if not master_acc.data:
        raise HTTPException(status_code=404, detail="Compte master introuvable")
    updated = supabase.table("trading_accounts").update({"master_account_id": master_acc.data[0]["id"]}).eq("user_id", client_id).execute()
    return {"status": "Synchronisé avec master"}

@router.get("/users")
def list_users(admin=Depends(get_current_admin)):
    res = supabase.table("profiles").select("id, email, full_name, role, is_vip, needs_vps, created_at").execute()
    return res.data
@router.get("/users")
def list_users(admin=Depends(get_current_admin)):
    res = supabase.table("profiles").select("id, email, full_name, role, is_vip, needs_vps, created_at").execute()
    return res.data

@router.post("/users/suspend/{user_id}")
def suspend_user(user_id: str, admin=Depends(get_current_admin)):
    updated = supabase.table("profiles").update({"role": "SUSPENDED"}).eq("id", user_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return {"status": "suspendu"}

@router.delete("/users/{user_id}")
def delete_user(user_id: str, admin=Depends(get_current_admin)):
    deleted = supabase.table("profiles").delete().eq("id", user_id).execute()
    if not deleted.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return {"status": "supprimé"}


@router.get("/logs")
def get_logs(admin=Depends(get_current_admin)):
    logs = supabase.table("admin_access_logs").select("id, username, access_time, ip").order("access_time", desc=True).limit(100).execute()
    return logs.data

@router.get("/support_tickets")
def get_support_tickets(admin=Depends(get_current_admin)):
    res = supabase.table("support_tickets").select("id, subject, status, created_at, user_id").execute()
    return res.data

# Paiements
@router.get("/payments")
def list_payments(admin=Depends(get_current_admin)):
    res = supabase.table("payments").select("id, user_id, amount, status, method, proof_url, created_at, transaction_id, entity").execute()
    return res.data
    try:
        res = supabase.table("payments").select("id, user_id, amount, status, method, proof_url, created_at, transaction_id, entity").execute()
        return res.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur chargement paiements: {str(e)}")

@router.post("/payments/validate/{payment_id}")
def validate_payment(payment_id: str, admin=Depends(get_current_admin)):
    updated = supabase.table("payments").update({"status": "VALIDATED"}).eq("id", payment_id).execute()
    if not updated.data:
        raise HTTPException(status_code=404, detail="Paiement introuvable")
    # Récupérer l'utilisateur et le montant du paiement
    payment = supabase.table("payments").select("user_id, amount").eq("id", payment_id).maybe_single().execute()
    if payment.data:
        user_id = payment.data.get("user_id")
        amount = payment.data.get("amount")
        # Créer et envoyer la notification
        notif_data = {
            "user_id": user_id,
            "title": "Paiement validé",
            "message": f"Votre paiement de {amount}$ a été validé. Merci !",
            "priority": "HIGH"
        }
        try:
            send_notification(notif_data, admin)
        except Exception as e:
            print(f"Erreur notification paiement: {e}")
    return {"status": "validé"}
    try:
        updated = supabase.table("payments").update({"status": "VALIDATED"}).eq("id", payment_id).execute()
        if not updated.data:
            raise HTTPException(status_code=404, detail="Paiement introuvable")
        return {"status": "validé"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur validation paiement: {str(e)}")
# Refuser un paiement
# (à ajouter)
@router.post("/payments/refuse/{payment_id}")
def refuse_payment(payment_id: str, motif: dict, admin=Depends(get_current_admin)):
    try:
        updated = supabase.table("payments").update({"status": "REFUSED", "motif": motif.get("motif", "")}).eq("id", payment_id).execute()
        if not updated.data:
            raise HTTPException(status_code=404, detail="Paiement introuvable")
        return {"status": "refusé"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur refus paiement: {str(e)}")

# Notifications
import requests

FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY")

@router.post("/notifications/send")
def send_notification(data: dict, admin=Depends(get_current_admin)):
    # Stocker la notification dans Supabase
    notif = supabase.table("notifications").insert(data).execute()
    # Récupérer le token FCM du destinataire
    user_id = data.get("user_id")
    token_res = supabase.table("profiles").select("fcm_token").eq("id", user_id).execute()
    fcm_token = token_res.data[0]["fcm_token"] if token_res.data and token_res.data[0].get("fcm_token") else None
    # Envoyer la notification push via FCM
    from fastapi import APIRouter, Depends, HTTPException
    import os
    router = APIRouter(prefix="/admin", tags=["admin"])
    if fcm_token and FCM_SERVER_KEY:
        fcm_payload = {
            "to": fcm_token,
            "notification": {
                "title": data.get("title", "Notification"),
                "body": data.get("message", "")
            },
            "data": {
                "priority": data.get("priority", "NORMAL")
            }
        }
        headers = {
            "Authorization": f"key={FCM_SERVER_KEY}",
            "Content-Type": "application/json"
        }
        try:
            requests.post("https://fcm.googleapis.com/fcm/send", json=fcm_payload, headers=headers)
        except Exception as e:
            print(f"Erreur FCM: {e}")
    return notif.data

@router.get("/notifications")
def list_notifications(admin=Depends(get_current_admin)):
    res = supabase.table("notifications").select("id, user_id, title, message, priority, created_at").execute()
    return res.data

# Logs détaillés
@router.get("/logs/detailed")
def get_detailed_logs(admin=Depends(get_current_admin)):
    logs = supabase.table("admin_access_logs").select("id, admin_id, action, timestamp, ip_address").order("timestamp", desc=True).limit(100).execute()
    return logs.data

