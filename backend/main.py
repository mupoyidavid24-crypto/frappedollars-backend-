

from fastapi import FastAPI, Request
from typing import Dict, List

# Stockage en mémoire : {login: [trades]}
pending_trades: Dict[str, List[dict]] = {}

app = FastAPI()

@app.get("/client/pending_trades/{mt5_login}")
def client_pending_trades(mt5_login: str):
    print("CLIENT PENDING TRADES login:", mt5_login)
    trades = pending_trades.get(mt5_login, [])
    # Pour tests, on laisse les trades dans la liste (pas de suppression)
    return {"pending_trades": trades}

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
    if client_login not in pending_trades:
        pending_trades[client_login] = []
    pending_trades[client_login].append(data)
    print(f"Trade ajouté à {client_login} :", data)
    return {"status": "received", "data": data}
