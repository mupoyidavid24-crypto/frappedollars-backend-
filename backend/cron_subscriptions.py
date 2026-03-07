import os
import asyncio
from datetime import datetime, timedelta
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# Supabase Configuration
url: str = os.getenv("SUPABASE_URL")
key: str = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(url, key)

async def process_renewals():
    """
    Checks for expired subscriptions and handles renewals or suspensions.
    """
    print(f"[{datetime.now()}] Starting subscription renewal check...")

    # 1. Fetch all subscriptions that have ended and are still marked 'ACTIVE' or 'WEEKLY_LIMIT_REACHED'
    now_iso = datetime.utcnow().isoformat()
    expired_subs = supabase.table("subscriptions")\
        .select("*, profiles(fcm_token)")\
        .lte("end_date", now_iso)\
        .in_("status", ["ACTIVE", "WEEKLY_LIMIT_REACHED"])\
        .execute()

    for sub in expired_subs.data:
        user_id = sub['user_id']
        sub_type = sub['type']
        auto_renew = sub['auto_renew']

        if auto_renew:
            # TODO: Logic to charge the user via Payment Gateway (Stripe/Flutterwave)
            # For this POC, we simulate a successful charge and extend the date

            new_end_date = datetime.utcnow()
            if sub_type == 'COPY_TRADING_WEEKLY':
                new_end_date += timedelta(days=7)
            elif sub_type == 'VPS_MONTHLY':
                new_end_date += timedelta(days=30)

            supabase.table("subscriptions").update({
                "start_date": datetime.utcnow().isoformat(),
                "end_date": new_end_date.isoformat(),
                "status": "ACTIVE" # Reset limit if it was reached
            }).eq("id", sub['id']).execute()

            print(f"Renewed {sub_type} for user {user_id}")
            # Optional: Send FCM notification "Abonnement renouvelé !"
        else:
            # Suspend access
            supabase.table("subscriptions").update({
                "status": "EXPIRED"
            }).eq("id", sub['id']).execute()

            # Deactivate trading account link if necessary
            supabase.table("trading_accounts").update({"is_active": False}).eq("user_id", user_id).execute()

            print(f"Suspended {sub_type} for user {user_id} (Auto-renew OFF)")
            # Optional: Send FCM notification "Abonnement expiré. Veuillez renouveler."

async def reset_weekly_limits():
    """
    Every Monday at 00:00, reset status from 'WEEKLY_LIMIT_REACHED' to 'ACTIVE'
    """
    # This can be more precise based on your business rules
    now = datetime.now()
    if now.weekday() == 0 and now.hour == 0:
        print(f"[{datetime.now()}] Resetting weekly limits...")
        supabase.table("subscriptions")\
            .update({"status": "ACTIVE"})\
            .eq("status", "WEEKLY_LIMIT_REACHED")\
            .execute()

if __name__ == "__main__":
    asyncio.run(process_renewals())
    # You can schedule this script to run every hour using a CRON job on your VPS
    # Example CRON: 0 * * * * python3 /path/to/cron_subscriptions.py
