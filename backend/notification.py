import supabase_py
from fastapi import APIRouter, Request
from datetime import datetime

router = APIRouter()

# Exemple de fonction pour envoyer une notification push (Firebase ou Supabase)
def send_push_notification(user_ids, message):
    # TODO: Intégrer Firebase/Supabase push
    pass

# Exemple de fonction pour envoyer une alerte EA (via API ou socket)
def send_ea_alert(client_ids, message):
    # TODO: Intégrer API MetaTrader ou socket
    pass

# Endpoint pour démarrer le copy trading
@router.post('/start_copy_trading')
def start_copy_trading(request: Request):
    data = request.json()
    custom_message = data.get('message', 'Le copy trading est actif, vérifiez vos positions.')
    admin_id = data.get('admin_id')
    # 1. Enregistrer le statut dans Supabase
    supabase_py.update_status('copy_trading_status', 'active')
    # 2. Récupérer les clients (mobiles et EA)
    user_ids = supabase_py.get_mobile_user_ids()
    client_ids = supabase_py.get_ea_client_ids()
    # 3. Envoyer notifications
    send_push_notification(user_ids, custom_message)
    send_ea_alert(client_ids, custom_message)
    # 4. Enregistrer l’historique
    supabase_py.insert_history({
        'date': datetime.now().isoformat(),
        'admin_id': admin_id,
        'statut': 'active',
        'message': custom_message
    })
    return {'status': 'ok'}
