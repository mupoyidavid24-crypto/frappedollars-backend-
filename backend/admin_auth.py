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
    try:
        data = request.json()
        username = data.get("username")
        password = data.get("password")
        ip = request.client.host
        # Validation stricte
        if not username or not password:
            print(f"Tentative de connexion sans identifiants depuis {ip}")
            raise HTTPException(status_code=400, detail="Identifiants manquants")
        hashed = hashlib.sha256(password.encode()).hexdigest()
        if username in ADMINS and ADMINS[username] == hashed:
            # Journaliser l'accès dans Supabase
            supabase_py.insert("admin_access_logs", {
                "username": username,
                "access_time": datetime.now().isoformat(),
                "ip": ip,
                "status": "succès"
            })
            print(f"Connexion admin réussie pour {username} depuis {ip}")
            # TODO: Générer un token de session sécurisé
            return {"status": "ok", "token": "SESSION_TOKEN"}
        else:
            supabase_py.insert("admin_access_logs", {
                "username": username,
                "access_time": datetime.now().isoformat(),
                "ip": ip,
                "status": "échec"
            })
            print(f"Échec de connexion admin pour {username} depuis {ip}")
            raise HTTPException(status_code=401, detail="Identifiants invalides ou accès refusé")
    except Exception as e:
        print(f"Erreur backend lors de la connexion admin : {str(e)}")
        raise HTTPException(status_code=500, detail="Erreur serveur lors de la connexion")

@router.get("/logs")
def get_admin_logs():
    return supabase_py.select_all("admin_access_logs")
