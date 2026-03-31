import requests

# Remplace par l'URL de ton backend Render si besoin
BACKEND_URL = "https://frappedollars-backend-1.onrender.com"

# Le client_id EXACT utilisé par l'EA client (copie depuis le journal de l'EA)
CLIENT_LOGIN = "32048608_Deriv.com Limited _Deriv-Demo_DEMO"

payload = {
    "client_login": CLIENT_LOGIN,
    "master_login": "6048965",
    "ticket_id": "5609382380",
    "action": "OPEN",
    "symbol": "EURUSD",
    "trade_type": "BUY",
    "volume": 0.01,
    "open_price": 1.16134,
    "sl": None,
    "tp": None
}

response = requests.post(f"{BACKEND_URL}/master/trade", json=payload)
print("Status:", response.status_code)
print("Response:", response.json())
