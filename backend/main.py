@app.get("/client/pending_trades/{mt5_login}")
def client_pending_trades(mt5_login: str):
    print("CLIENT PENDING TRADES login:", mt5_login)
    return {}

from fastapi import FastAPI, Request

app = FastAPI()

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
    return {"status": "received", "data": data}
