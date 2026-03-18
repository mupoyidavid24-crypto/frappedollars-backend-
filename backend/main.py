"""
Backend FrappedDollars API
-------------------------
Ce fichier initialise l'application FastAPI, configure Supabase, et inclut le module admin.
Toutes les routes principales et la logique d'intégration sont centralisées ici.
"""
import sys
print("[BOOT] Backend démarré", file=sys.stderr, flush=True)
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from supabase import create_client, Client
import os
from dotenv import load_dotenv
from typing import Optional
from datetime import datetime, timedelta
from backend.config import PRICES, WEEKLY_PROFIT_LIMIT, MIN_CAPITAL_REQUIRED
from backend.admin import router as admin_router

load_dotenv()

app = FastAPI(title="FrappedDollars API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(admin_router, prefix="/admin")

url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(url, key)

class MasterTrade(BaseModel):
    master_login: str
    ticket_id: str
    symbol: str
    trade_type: str
    volume: float
    open_price: float
    tp: Optional[float] = None
    sl: Optional[float] = None
    action: str = "OPEN"

from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

# Handler pour loguer les erreurs de validation 422
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    import sys
    print("VALIDATION ERROR:", exc.errors(), file=sys.stderr, flush=True)
    return JSONResponse(status_code=422, content={"detail": exc.errors()})

class ClientTradeUpdate(BaseModel):
    copied_trade_id: str
    ticket: str
    status: str
    profit: Optional[float] = 0.0

@app.post("/master/trade")
async def handle_master_trade(trade: MasterTrade):
        import sys
        print("[POST /master/trade] Reçu", file=sys.stderr, flush=True)
    master_acc = supabase.table("trading_accounts").select("id, balance").eq("mt5_login", trade.master_login).eq("account_type", "MASTER").execute()
    if not master_acc.data:
        raise HTTPException(status_code=404, detail="Master account not found")

    master_id = master_acc.data[0]['id']
    master_balance = float(master_acc.data[0]['balance'])

    if trade.action == "OPEN":
        signal_res = supabase.table("signals").insert({
            "master_account_id": master_id,
            "ticket_id_mt5": trade.ticket_id,
            "symbol": trade.symbol,
            "trade_type": trade.trade_type,
            "volume": trade.volume,
            "open_price": trade.open_price,
            "tp": trade.tp,
            "sl": trade.sl,
            "status": "OPEN"
        }).execute()
        signal_id = signal_res.data[0]['id']

        # 🎯 LOGIQUE D'ACTIVATION STRICTE (AVEC EXCEPTION VIP)
        clients = supabase.table("trading_accounts").select("id, balance, user_id, profiles(needs_vps, is_vip, role)").eq("account_type", "CLIENT").eq("is_active", True).gte("balance", MIN_CAPITAL_REQUIRED).execute()

        copy_tasks = []
        for client in clients.data:
            user_id = client['user_id']
            profile = client['profiles']
            needs_vps = profile['needs_vps']
            # Correction VIP : on vérifie explicitement le champ et le rôle
            is_vip = bool(profile.get('is_vip')) or profile.get('role') == 'ADMIN'

            # Les VIP ou ADMIN sont toujours exemptés
            if is_vip:
                client_capital = float(client['balance'])
                calculated_lot = round(max(0.01, trade.volume * (client_capital / master_balance)), 2)
                copy_tasks.append({
                    "signal_id": signal_id,
                    "client_account_id": client['id'],
                    "volume_executed": calculated_lot,
                    "execution_status": "PENDING"
                })
                continue

            # Si l'utilisateur n'est pas VIP, on vérifie ses abonnements
            trading_sub = supabase.table("subscriptions").select("status").eq("user_id", user_id).eq("type", "COPY_TRADING_WEEKLY").eq("status", "ACTIVE").execute()
            if not trading_sub.data:
                continue

            if needs_vps:
                vps_sub = supabase.table("subscriptions").select("status").eq("user_id", user_id).eq("type", "VPS_MONTHLY").eq("status", "ACTIVE").execute()
                if not vps_sub.data:
                    continue

            client_capital = float(client['balance'])
            calculated_lot = round(max(0.01, trade.volume * (client_capital / master_balance)), 2)
            copy_tasks.append({
                "signal_id": signal_id,
                "client_account_id": client['id'],
                "volume_executed": calculated_lot,
                "execution_status": "PENDING"
            })

        if copy_tasks:
            supabase.table("copied_trades").insert(copy_tasks).execute()

    elif trade.action == "CLOSE":
        supabase.table("signals").update({"status": "CLOSED", "closed_at": datetime.utcnow().isoformat()}).eq("ticket_id_mt5", trade.ticket_id).eq("master_account_id", master_id).execute()
        signal = supabase.table("signals").select("id").eq("ticket_id_mt5", trade.ticket_id).eq("master_account_id", master_id).execute()
        if signal.data:
            supabase.table("copied_trades").update({"execution_status": "PENDING_CLOSE"}).eq("signal_id", signal.data[0]['id']).eq("execution_status", "SUCCESS").execute()

    return {"status": "success"}

@app.get("/client/pending_trades/{mt5_login}")
async def get_pending_trades(mt5_login: str):
    client_acc = supabase.table("trading_accounts").select("id, user_id, profiles(needs_vps, is_vip, role)").eq("mt5_login", mt5_login).execute()
    if not client_acc.data: return []

    user_id = client_acc.data[0]['user_id']
    profile = client_acc.data[0]['profiles']
    needs_vps = profile['needs_vps']
    is_vip = bool(profile.get('is_vip')) or profile.get('role') == 'ADMIN'

    # 🛡️ Double sécurité : Exception pour les VIP
    if is_vip:
        pending = supabase.table("copied_trades").select("*, signals(*)").eq("client_account_id", client_acc.data[0]['id']).in_("execution_status", ["PENDING", "PENDING_CLOSE"]).execute()
        return pending.data

    trading_sub = supabase.table("subscriptions").select("status").eq("user_id", user_id).eq("type", "COPY_TRADING_WEEKLY").eq("status", "ACTIVE").execute()
    if not trading_sub.data: return []

    if needs_vps:
        vps_sub = supabase.table("subscriptions").select("status").eq("user_id", user_id).eq("type", "VPS_MONTHLY").eq("status", "ACTIVE").execute()
        if not vps_sub.data: return []

    pending = supabase.table("copied_trades").select("*, signals(*)").eq("client_account_id", client_acc.data[0]['id']).in_("execution_status", ["PENDING", "PENDING_CLOSE"]).execute()
    return pending.data

@app.post("/client/update_trade")
async def update_client_trade(update: ClientTradeUpdate):
    update_data = {"client_ticket_id": update.ticket, "execution_status": update.status}
    if update.status == "CLOSED":
        update_data["profit"] = update.profit
        update_data["closed_at"] = datetime.utcnow().isoformat()
    return supabase.table("copied_trades").update(update_data).eq("id", update.copied_trade_id).execute().data
