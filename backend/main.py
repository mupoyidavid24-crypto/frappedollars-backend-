from fastapi import FastAPI, Request, Depends, HTTPException, status
from fastapi.responses import JSONResponse
from typing import Dict, List
import uuid
import time
from backend.config import supabase
import asyncio
from fastapi import BackgroundTasks
from fastapi import APIRouter
import secrets
from fastapi import Body

app = FastAPI()

monitoring_router = APIRouter()

@monitoring_router.get("/monitoring")
def monitoring_status():
    # Compte les trades par statut
    res = supabase.table("trades").select("status", count="exact").execute()
    stats = {}
    if res.data:
        for trade in res.data:
            status = trade.get("status", "UNKNOWN")
            stats[status] = stats.get(status, 0) + 1
    return {"trade_status_counts": stats}

app.include_router(monitoring_router)

async def verify_api_key(request: Request):
    # Accepte Authorization: Bearer ... ou x-api-key
    api_key = None
    auth = request.headers.get("authorization")
    if auth and auth.startswith("Bearer "):
        api_key = auth.split(" ", 1)[1]
    else:
        api_key = request.headers.get("x-api-key")
    if not api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing API key")
    # Recherche du client_id associé à cette clé dans Supabase
    res = supabase.table("api_keys").select("client_id").eq("api_key", api_key).execute()
    if not res.data or len(res.data) == 0:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key")
    return res.data[0]["client_id"]

# Endpoint pour confirmation d'exécution d'un trade par le client
@app.post("/client/trade_executed")
async def trade_executed(request: Request, auth_client_id: str = Depends(verify_api_key)):
    data = await request.json()
    client_login = data.get("client_login")
    trade_id = data.get("trade_id")
    if not client_login or not trade_id:
        return JSONResponse({"error": "client_login et trade_id requis"}, status_code=400)
    if client_login != auth_client_id:
        raise HTTPException(status_code=403, detail="Forbidden")
    trades = pending_trades.get(client_login, [])
    # Suppression du trade exécuté
    new_trades = [t for t in trades if str(t.get("id")) != str(trade_id) and str(t.get("ticket_id")) != str(trade_id)]
    pending_trades[client_login] = new_trades
    return {"status": "ok", "removed": trade_id}

# Simule une file d'attente pour les trades à relancer (en mémoire)
retry_queue = []

async def retry_failed_trades():
    while True:
        # Récupère les trades en status 'RETRY' ou 'FAILED' dans Supabase
        res = supabase.table("trades").select("id, client_id, status, retry_count").in_("status", ["RETRY", "FAILED"]).execute()
        trades = res.data if res.data else []
        for trade in trades:
            retry_count = trade.get("retry_count", 0)
            if retry_count >= RETRY_MAX_ATTEMPTS:
                # Archive le trade si trop d'échecs
                supabase.table("trades").update({"status": "ARCHIVED"}).eq("id", trade["id"]).execute()
                print(f"[ARCHIVED] Trade {trade['id']} pour client {trade['client_id']} (tentative {retry_count})")
                continue
            # Relance le trade (ici, on repasse en PENDING pour qu'il soit redistribué)
            supabase.table("trades").update({"status": "PENDING", "retry_count": retry_count + 1}).eq("id", trade["id"]).execute()
            print(f"[RETRY] Relance du trade {trade['id']} pour client {trade['client_id']} (tentative {retry_count+1})")
        await asyncio.sleep(RETRY_INTERVAL_SECONDS)

@app.on_event("startup")
async def start_retry_task():
    loop = asyncio.get_event_loop()
    loop.create_task(retry_failed_trades())

from fastapi import FastAPI, Request
from typing import Dict, List
import uuid
import time
from backend.config import supabase

# Stockage en mémoire : {login: [trades]}
pending_trades: Dict[str, List[dict]] = {}

@app.get("/client/pending_trades/{mt5_login}")
def client_pending_trades(mt5_login: str, auth_client_id: str = Depends(verify_api_key)):
    if mt5_login != auth_client_id:
        raise HTTPException(status_code=403, detail="Forbidden")
    trades = pending_trades.get(mt5_login, [])
    # Adapter chaque trade au format attendu par l'EA client
    formatted = []
    for t in trades:
        formatted.append({
            "id": t.get("id", t.get("ticket_id", str(uuid.uuid4()))),
            "execution_status": t.get("execution_status", "PENDING"),
            "symbol": t.get("symbol"),
            "trade_type": t.get("trade_type"),
            "volume_executed": t.get("volume"),
            "sl": t.get("sl"),
            "tp": t.get("tp"),
            "client_ticket_id": t.get("client_ticket_id", ""),
            "timestamp": t.get("timestamp", int(time.time())),
        })
    return {"pending_trades": formatted}

@app.get("/")
def root():
    return {"message": "API OK"}

@app.get("/ping")
def ping():
    return {"ping": "pong"}

@app.post("/master/trade")
async def master_trade(request: Request):
    data = await request.json()
    print("TRADE RECU:", data)
    # On attend un champ 'client_login' dans le JSON pour router le trade
    client_login = data.get("client_login")
    if not client_login:
        # Pour test, fallback sur un login de démo
        client_login = "87654321"
    # Générer un id unique et enrichir le trade
    trade_id = str(uuid.uuid4())
    enriched = dict(data)
    enriched["id"] = trade_id
    enriched["execution_status"] = "PENDING"
    enriched["volume_executed"] = data.get("volume")
    enriched["timestamp"] = int(time.time())
    if client_login not in pending_trades:
        pending_trades[client_login] = []
    pending_trades[client_login].append(enriched)
    print(f"Trade ajouté à {client_login} :", enriched)
    return {"status": "received", "data": enriched}

@app.post("/admin/generate_api_key")
def generate_api_key(client_id: str = Body(..., embed=True)):
    # Génère une clé aléatoire sécurisée
    api_key = secrets.token_urlsafe(32)
    # Insère ou met à jour la clé dans Supabase
    res = supabase.table("api_keys").upsert({"client_id": client_id, "api_key": api_key}).execute()
    return {"client_id": client_id, "api_key": api_key, "status": "created", "supabase": res.data}

@app.get("/admin/dashboard")
def admin_dashboard():
    # Récupère tous les trades
    res = supabase.table("trades").select("id, client_id, status, timestamp").execute()
    trades = res.data if res.data else []
    # Agrège par client
    dashboard = {}
    for t in trades:
        cid = t.get("client_id", "unknown")
        status = t.get("status", "UNKNOWN")
        ts = t.get("timestamp")
        if cid not in dashboard:
            dashboard[cid] = {"status_counts": {}, "last_trades": []}
        dashboard[cid]["status_counts"][status] = dashboard[cid]["status_counts"].get(status, 0) + 1
        dashboard[cid]["last_trades"].append({"id": t["id"], "status": status, "timestamp": ts})
    # Trie les dernières activités par date décroissante
    for cid in dashboard:
        dashboard[cid]["last_trades"] = sorted(dashboard[cid]["last_trades"], key=lambda x: x["timestamp"] or 0, reverse=True)[:10]
    return {"clients": dashboard}
