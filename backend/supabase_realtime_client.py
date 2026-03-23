from realtime import Client
import os

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://<ton-projet>.supabase.co")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "<ta-clé-anon>")

client = Client(SUPABASE_URL, SUPABASE_ANON_KEY)

# Remplace par le client_id que tu veux écouter
CLIENT_ID = os.getenv("CLIENT_ID", "test_client_id")

def on_trade_insert(payload):
    new_trade = payload["new"]
    if new_trade.get("client_id") == CLIENT_ID:
        print("[Realtime] Nouveau trade pour ce client:", new_trade)

def on_trade_update(payload):
    updated_trade = payload["new"]
    if updated_trade.get("client_id") == CLIENT_ID:
        print("[Realtime] Trade mis à jour pour ce client:", updated_trade)

# S’abonner aux nouveaux trades et updates pour ce client_id
client.table("trades").on("INSERT", on_trade_insert).subscribe()
client.table("trades").on("UPDATE", on_trade_update).subscribe()

print(f"[Realtime] Abonnement aux trades pour client_id={CLIENT_ID}")
client.run_forever()
