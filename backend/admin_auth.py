from fastapi import APIRouter, Request, HTTPException
from datetime import datetime
import hashlib
import supabase_py

router = APIRouter(prefix="/admin")

# Exemple de stockage des admins (à remplacer par une table Supabase)
ADMINS = {
    "admin": hashlib.sha256(b"MotDePasseComplexe123!").hexdigest(),
}


@router.post("/login")
def admin_login(request: Request):
    data = request.json()
    username = data.get("username")
    password = data.get("password")
    ip = request.client.host
    hashed = hashlib.sha256(password.encode()).hexdigest()
    if username in ADMINS and ADMINS[username] == hashed:
        # Journaliser l'accès dans Supabase
        supabase_py.insert("admin_access_logs", {
            "username": username,
            "access_time": datetime.now().isoformat(),
            "ip": ip
        })
        # TODO: Générer un token de session sécurisé
        return {"status": "ok", "token": "SESSION_TOKEN"}
    else:
        raise HTTPException(status_code=401, detail="Accès refusé")

@router.get("/logs")
def get_admin_logs():
    return supabase_py.select_all("admin_access_logs")
