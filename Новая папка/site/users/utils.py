import requests
import hashlib
import uuid
from django.conf import settings

def send_osonsms(phone, code):
    """
    Ирсоли SMS тавассути OsonSMS.
    """
    url = "http://api.osonsms.com/sendsms_v1.php"
    
    # 1. Маълумот аз settings.py
    login = settings.OSONSMS_LOGIN
    sender = settings.OSONSMS_SENDER
    hash_key = settings.OSONSMS_HASH
    app_name = settings.APP_NAME
    
    # ID-и уникалӣ
    txn_id = str(uuid.uuid4())
    message = f"Код: {code} барои тасдиқи {app_name}. Онро ба ҳеҷ кас надиҳед! Ҳатто ба коргарони китобхона."

    # 2. СОХТАНИ HASH (Бо формулаи дурусти OsonSMS: бо нуқта-вергул ;)
    # Формула: txn_id;login;sender;phone;hash_key
    str_source = f"{txn_id};{login};{sender};{phone};{hash_key}"
    str_hash = hashlib.sha256(str_source.encode('utf-8')).hexdigest()

    # 3. ПАРАМЕТРҲОИ ДУРУСТ (Ҳатман ҳамин хел бошад)
    params = {
        'from': sender,          # Пештар 'sender' буд, ҳоло 'from' лозим
        'phone_number': phone,   # Пештар 'phone' буд, ҳоло 'phone_number' лозим
        'msg': message,          # Пештар 'str_message' буд, ҳоло 'msg' лозим
        'str_hash': str_hash,
        'txn_id': txn_id,
        'login': login,
    }
    
    try:
        response = requests.get(url, params=params)
        print(f"OsonSMS Javob: {response.text}")
        return True
    except Exception as e:
        print(f"Hatogi dar OsonSMS: {e}")
        return False