from dotenv import load_dotenv
from supabase import create_client
import os

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
SUPABASE_CLIENT_KEY = SUPABASE_SERVICE_ROLE_KEY or SUPABASE_KEY

if not SUPABASE_URL or not SUPABASE_CLIENT_KEY:
    raise RuntimeError("Les variables SUPABASE_URL et SUPABASE_KEY doivent être définies dans le fichier .env")

supabase = create_client(SUPABASE_URL, SUPABASE_CLIENT_KEY)


def get_current_admin():
    return {"role": "ADMIN"}


PRICES = {
    "COPY_TRADING_WEEKLY": 50.0,
    "VPS_MONTHLY": 35.0,
}

WEEKLY_PROFIT_LIMIT = 250.0
MIN_CAPITAL_REQUIRED = 30.0
