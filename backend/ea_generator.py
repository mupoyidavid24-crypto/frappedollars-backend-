import os
from fastapi import APIRouter, Depends, HTTPException
from supabase import create_client, Client
from dotenv import load_dotenv
from tempfile import NamedTemporaryFile
from typing import Optional

load_dotenv()

router = APIRouter()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

EA_TEMPLATE_PATH = os.path.join(os.path.dirname(__file__), '../mt5/FrappedDollarsClient.mq5')

# Utilitaire pour générer le code EA personnalisé
def generate_ea_code(login: str) -> str:
    with open(EA_TEMPLATE_PATH, 'r', encoding='utf-8') as f:
        code = f.read()
    # Remplace la ligne InpAllowedLogin
    code = code.replace('input string   InpAllowedLogin = "87654321";', f'input string   InpAllowedLogin = "{login}";')
    return code

@router.get("/client/download_ea")
def download_ea(mt5_login: str, user_id: Optional[str] = None):
    # Vérifie que l'utilisateur existe et a le droit
    acc = supabase.table("trading_accounts").select("user_id").eq("mt5_login", mt5_login).execute()
    if not acc.data:
        raise HTTPException(status_code=404, detail="Compte MT5 introuvable")
    if user_id and acc.data[0]['user_id'] != user_id:
        raise HTTPException(status_code=403, detail="Accès refusé")

    # Génère le code EA personnalisé
    ea_code = generate_ea_code(mt5_login)
    # Sauvegarde temporaire
    with NamedTemporaryFile(delete=False, suffix='.mq5', mode='w', encoding='utf-8') as tmp:
        tmp.write(ea_code)
        tmp_path = tmp.name
    # Upload sur Supabase Storage
    bucket = "ea_files"
    file_name = f"FrappedDollarsClient_{mt5_login}.mq5"
    with open(tmp_path, "rb") as f:
        res = supabase.storage.from_(bucket).upload(file_name, f)
    # Génère un lien signé (valable 10 min)
    signed_url = supabase.storage.from_(bucket).create_signed_url(file_name, 600)
    # Nettoyage
    os.remove(tmp_path)
    return {"download_url": signed_url['signedURL']}

# À ajouter dans main.py :
# from ea_generator import router as ea_router
# app.include_router(ea_router)
