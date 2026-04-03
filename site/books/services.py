"""
Service functions for payment processing with Dushanbe City Payment Gateway
"""
import hashlib
import xml.etree.ElementTree as ET
from django.conf import settings


def generate_payment_xml(order_id, amount, description, phone):
    """
    Generate XML payload for Dushanbe City Payment Gateway
    
    Args:
        order_id: Unique order identifier
        amount: Payment amount (in dirams, e.g., 5000 for 50.00 TJS)
        description: Payment description
        phone: User's phone number
    
    Returns:
        str: XML string ready to be sent to payment gateway
    """
    try:
        merchant_id = settings.DC_MERCHANT_ID
        password = settings.DC_PASSWORD
        base_url = settings.DC_BASE_URL
    except AttributeError as e:
        raise ValueError(f"DC Payment settings not configured: {e}")
    
    # Calculate MD5 hash: MD5(Merchant + Password)
    sign_string = str(merchant_id) + str(password)
    sign_hash = hashlib.md5(sign_string.encode('utf-8')).hexdigest().upper()
    
    # Convert amount to dirams (multiply by 100 if needed)
    # Amount comes as string or number, convert to dirams
    try:
        if isinstance(amount, str):
            amount_float = float(amount)
        else:
            amount_float = float(amount)
        amount_dirams = int(amount_float * 100)
    except (ValueError, TypeError):
        raise ValueError(f"Invalid amount format: {amount}")
    
    # Build XML structure
    root = ET.Element('TKKPG')
    request = ET.SubElement(root, 'Request')
    
    operation = ET.SubElement(request, 'Operation')
    operation.text = 'CreateOrder'
    
    language = ET.SubElement(request, 'Language')
    language.text = 'RU'
    
    order = ET.SubElement(request, 'Order')
    
    merchant = ET.SubElement(order, 'Merchant')
    merchant.text = merchant_id
    
    amount_elem = ET.SubElement(order, 'Amount')
    amount_elem.text = str(amount_dirams)
    
    articul = ET.SubElement(order, 'Articul')
    articul.text = '124'
    
    account = ET.SubElement(order, 'Account')
    account.text = '927203002'
    
    currency = ET.SubElement(order, 'Currency')
    currency.text = '972'  # TJS currency code
    
    desc = ET.SubElement(order, 'Description')
    desc.text = description
    
    # Callback URLs
    approve_url = ET.SubElement(order, 'ApproveURL')
    approve_url.text = f'{base_url}/api/payment/success/'
    
    cancel_url = ET.SubElement(order, 'CancelURL')
    cancel_url.text = f'{base_url}/api/payment/cancel/'
    
    decline_url = ET.SubElement(order, 'DeclineURL')
    decline_url.text = f'{base_url}/api/payment/decline/'
    
    # AddParams section
    add_params = ET.SubElement(order, 'AddParams')
    
    phone_elem = ET.SubElement(add_params, 'phone')
    phone_elem.text = phone
    
    sender_name = ET.SubElement(add_params, 'SenderName')
    sender_name.text = 'Kitobi Vakil'
    
    sign_elem = ET.SubElement(add_params, 'Sign')
    sign_elem.text = sign_hash
    
    fee = ET.SubElement(order, 'Fee')
    fee.text = '0'
    
    # Convert to string
    xml_string = ET.tostring(root, encoding='utf-8', method='xml').decode('utf-8')
    
    # Add XML declaration
    xml_declaration = '<?xml version="1.0" encoding="UTF-8"?>'
    full_xml = xml_declaration + '\n' + xml_string
    
    return full_xml

