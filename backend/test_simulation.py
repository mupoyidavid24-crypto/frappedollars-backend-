import requests
import json
import time

API_URL = "http://127.0.0.1:8000"

def test_full_cycle():
    # 1. SIMULER OUVERTURE
    print("--- 🚀 Test 1 : Ouverture de position ---")
    open_data = {
        "master_login": "999999",
        "ticket_id": "12345",
        "symbol": "EURUSD",
        "trade_type": "BUY",
        "volume": 0.10,
        "open_price": 1.0850,
        "action": "OPEN"
    }
    res_open = requests.post(f"{API_URL}/master/trade", json=open_data)
    print("Réponse Ouverture:", res_open.json())

    time.sleep(2) # Attendre un peu

    # 2. SIMULER FERMETURE (AVEC PROFIT)
    print("\n--- 🏁 Test 2 : Fermeture de position ---")
    close_data = {
        "master_login": "999999",
        "ticket_id": "12345",
        "symbol": "EURUSD",
        "trade_type": "BUY",
        "volume": 0.10,
        "open_price": 1.0850,
        "action": "CLOSE"
    }
    res_close = requests.post(f"{API_URL}/master/trade", json=close_data)
    print("Réponse Fermeture:", res_close.json())

    # 3. MISE À JOUR CLIENT (Rapport de profit)
    # On simule ce que l'EA Client renverrait après avoir fermé
    print("\n--- 💰 Test 3 : Rapport de profit du client ---")
    # Note: Dans un vrai test, il faudrait récupérer l'ID réel créé en DB
    print("Vérifiez manuellement dans Supabase que le signal est 'CLOSED'")

if __name__ == "__main__":
    test_full_cycle()
