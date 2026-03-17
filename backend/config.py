# Supabase client et dépendance admin
from supabase import create_client
import os
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError("Les variables SUPABASE_URL et SUPABASE_KEY doivent être définies dans le fichier .env")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def get_current_admin():
    # Dummy admin dependency for FastAPI
    return {"role": "ADMIN"}
# Supabase client et dépendance admin
from supabase import create_client
import os
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def get_current_admin():
    return {"role": "ADMIN"}

# Configuration des tarifs FrappedDollars
PRICES = {
    "COPY_TRADING_WEEKLY": 50.0, # 50$ par semaine
    "VPS_MONTHLY": 35.0          # 35$ par mois
}

# Limites Business
WEEKLY_PROFIT_LIMIT = 250.0  # Gain client par semaine
MIN_CAPITAL_REQUIRED = 30.0
