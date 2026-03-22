from supabase import create_client
import os

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def ensure_master_account(login="6048965", balance=10000.0):
    res = supabase.table("trading_accounts").select("id").eq("mt5_login", login).eq("account_type", "MASTER").execute()
    if res.data:
        print("Compte maître déjà présent.")
        return
    supabase.table("trading_accounts").insert({
        "mt5_login": login,
        "account_type": "MASTER",
        "balance": balance,
        "is_active": True
    }).execute()
    print("Compte maître ajouté.")

if __name__ == "__main__":
    ensure_master_account()
