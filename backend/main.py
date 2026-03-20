# Endpoint pour confirmation d'exécution d'un trade par le client
from fastapi.responses import JSONResponse

@app.post("/client/trade_executed")
async def trade_executed(request: Request):
    data = await request.json()
    client_login = data.get("client_login")
    trade_id = data.get("trade_id")
    if not client_login or not trade_id:
        return JSONResponse({"error": "client_login et trade_id requis"}, status_code=400)
    trades = pending_trades.get(client_login, [])
    # Suppression du trade exécuté
    new_trades = [t for t in trades if str(t.get("id")) != str(trade_id) and str(t.get("ticket_id")) != str(trade_id)]
    pending_trades[client_login] = new_trades
    return {"status": "ok", "removed": trade_id}



from fastapi import FastAPI, Request
from typing import Dict, List
import uuid
import time

# Stockage en mémoire : {login: [trades]}
pending_trades: Dict[str, List[dict]] = {}

app = FastAPI()

@app.get("/client/pending_trades/{mt5_login}")
def client_pending_trades(mt5_login: str):
    print("CLIENT PENDING TRADES login:", mt5_login)
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
