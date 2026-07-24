from django.shortcuts import get_object_or_404
from django.http import FileResponse, Http404
from django.db.models import Q
from rest_framework import viewsets
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.authentication import TokenAuthentication
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.contrib.auth import get_user_model
from django.conf import settings
from django.utils import timezone
from django.db import transaction as db_transaction
from decimal import Decimal
from datetime import datetime, timedelta, timezone as dt_timezone
import uuid

from .apple_iap import decode_apple_jws_payload
from .legal_docs import resolve_legal_document_path
from .models import (
    AboutPage,
    AppleStoreTransaction,
    Book,
    Chapter,
    LegalDocument,
    PurchasedChapter,
    Purchase,
    SubscriptionPlan,
    Subscription,
    Transaction,
)
from .serializers import (
    AboutPageSerializer,
    BookSerializer,
    LegalDocumentSerializer,
    TransactionSerializer,
)
from .payments.exceptions import SmartPayError
from .payments.geo import is_smartpay_region_allowed
from .access import user_has_chapter_access
from .payments.services.balance import is_charged_status
from .payments.services.smartpay_service import SmartPayService
from .payments.webhook_auth import verify_smartpay_webhook
from .payment_utils import (
    apply_smartpay_success,
    build_smartpay_transaction_description,
    find_transaction_for_smartpay,
    smartpay_status_lookup_id,
)
from .services import generate_payment_xml

User = get_user_model()


def _has_chapter_access(user, chapter):
    return user_has_chapter_access(user, chapter)

class BookViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Ин View танҳо барои хондан аст (ReadOnly).
    Рӯйхати китобҳо ва бобҳоро нишон медиҳад.
    """
    queryset = Book.objects.all()
    serializer_class = BookSerializer

    def get_serializer_context(self):
        """Илова кардани маълумоти корбар ба context"""
        context = super().get_serializer_context()
        if self.request.user.is_authenticated:
            context['user'] = self.request.user
        return context


@method_decorator(csrf_exempt, name='dispatch')
class PurchaseChapterView(APIView):
    """API барои харидани боб"""
    permission_classes = [IsAuthenticated]

    def post(self, request, chapter_id):
        try:
            chapter = Chapter.objects.get(id=chapter_id)
        except Chapter.DoesNotExist:
            return Response({'error': 'Боб ёфт нашуд'}, status=404)

        # Агар боб ройгон бошад
        if chapter.is_free:
            return Response({'error': 'Ин боб ройгон аст'}, status=400)

        # Санҷиш, оё аллакай харида шудааст
        if PurchasedChapter.objects.filter(user=request.user, chapter=chapter).exists():
            return Response({'error': 'Шумо ин бобро аллакай харидаед'}, status=400)

        # Санҷиши баланс
        chapter_price = Decimal(str(chapter.book.price))  # Нархи китоб = нархи боб
        if request.user.balance < chapter_price:
            return Response({
                'error': 'Баланси шумо кофӣ нест',
                'required': str(chapter_price),
                'current_balance': str(request.user.balance)
            }, status=400)

        # Харидани боб
        request.user.balance -= chapter_price
        request.user.save()

        # Сабти харид
        purchase = PurchasedChapter.objects.create(
            user=request.user,
            chapter=chapter,
            price_paid=chapter_price
        )

        return Response({
            'message': 'Боб бомуваффақият харида шуд',
            'purchase_id': purchase.id,
            'new_balance': str(request.user.balance)
        })


@method_decorator(csrf_exempt, name='dispatch')
class CheckChapterAccessView(APIView):
    """API барои санҷидани дастрасии боб"""
    permission_classes = [IsAuthenticated]

    def get(self, request, chapter_id):
        try:
            chapter = Chapter.objects.get(id=chapter_id)
        except Chapter.DoesNotExist:
            return Response({'error': 'Боб ёфт нашуд'}, status=404)

        has_access = _has_chapter_access(request.user, chapter)

        return Response({
            'has_access': has_access,
            'is_free': chapter.is_free,
            'price': str(chapter.book.price)
        })


@method_decorator(csrf_exempt, name='dispatch')
class PurchaseSubscriptionView(APIView):
    """API барои харидани обуна (бо интихоби нақша)"""
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plan_id = request.data.get('plan_id')
        if not plan_id:
            return Response({'error': 'ID-и нақшаро (plan_id) ворид кунед'}, status=400)

        plan = get_object_or_404(SubscriptionPlan, id=plan_id, is_active=True)
        user = request.user

        if user.balance < plan.price:
            return Response({
                'error': 'Маблағ кифоя нест',
                'required': str(plan.price),
                'current_balance': str(user.balance)
            }, status=400)

        current_subscription = Subscription.objects.filter(
            user=user,
            plan=plan,
            expires_at__gt=timezone.now(),
        ).order_by('-expires_at').first()

        if current_subscription:
            new_expires_at = current_subscription.expires_at + timezone.timedelta(days=plan.days)
        else:
            new_expires_at = timezone.now() + timezone.timedelta(days=plan.days)

        try:
            with db_transaction.atomic():
                user.balance -= plan.price
                user.save()

                Subscription.objects.create(
                    user=user,
                    plan=plan,
                    expires_at=new_expires_at,
                )

                Transaction.objects.create(
                    user=user,
                    amount=plan.price,
                    status='SUCCESS',
                    transaction_id=f"SUB-{uuid.uuid4().hex[:8].upper()}",
                    description=f"Обуна: {plan.book.title} ({plan.name})"
                )

            return Response({
                'message': 'Обуна бо муваффақият фаъол шуд!',
                'new_balance': str(user.balance),
                'expires_at': new_expires_at.strftime('%Y-%m-%d %H:%M:%S')
            })
        except Exception as e:
            return Response({'error': f'Хатогӣ ҳангоми харид: {str(e)}'}, status=500)


@method_decorator(csrf_exempt, name='dispatch')
class BuyBookView(APIView):
    """API барои харидани китоб"""
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        book_id = request.data.get('book_id')
        
        if not book_id:
            return Response({'error': 'ID-и китобро ворид кунед'}, status=400)
        
        try:
            book = Book.objects.get(id=book_id)
        except Book.DoesNotExist:
            return Response({'error': 'Китоб ёфт нашуд'}, status=404)

        # Санҷиш, оё аллакай харида шудааст
        if Purchase.objects.filter(user=request.user, book=book).exists():
            return Response({'error': 'Шумо ин китобро аллакай харидаед'}, status=400)

        # Санҷиши баланс
        book_price = Decimal(str(book.price))
        if request.user.balance < book_price:
            return Response({
                'error': 'Маблағ кифоя нест',
                'required': str(book_price),
                'current_balance': str(request.user.balance)
            }, status=400)

        # Харидани китоб
        request.user.balance -= book_price
        request.user.save()

        # Сабти харид
        purchase = Purchase.objects.create(
            user=request.user,
            book=book
        )

        return Response({
            'message': 'Китоб бомуваффақият харида шуд',
            'purchase_id': purchase.id,
            'new_balance': str(request.user.balance)
        })


@method_decorator(csrf_exempt, name='dispatch')
class InitPaymentView(APIView):
    """
    API endpoint to initialize payment via Dushanbe City Payment Gateway
    Accepts: amount (required)
    Returns: payment_url and xml_data for Flutter WebView submission
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        amount = request.data.get('amount')
        book_id = request.data.get('book_id')  # Optional: for book purchase
        
        if not amount:
            return Response({'error': 'Маблағро ворид кунед'}, status=400)
        
        try:
            amount_decimal = Decimal(str(amount))
            if amount_decimal <= 0:
                return Response({'error': 'Маблағ бояд мусбат бошад'}, status=400)
        except (ValueError, TypeError):
            return Response({'error': 'Маблағи нодуруст'}, status=400)
        
        # Generate unique order ID
        order_id = str(uuid.uuid4())
        
        # Get user phone
        phone = request.user.phone if hasattr(request.user, 'phone') else ''
        
        # Create description
        if book_id:
            try:
                book = Book.objects.get(id=book_id)
                description = f'Хариди китоб: {book.title}'
            except Book.DoesNotExist:
                description = f'Пур кардани баланси барномаи ҳуқуқи ронанда: {amount} сомонӣ'
        else:
            description = f'Пур кардани баланси барномаи ҳуқуқи ронанда: {amount} сомонӣ'
        
        # Generate payment XML
        try:
            xml_data = generate_payment_xml(
                order_id=order_id,
                amount=amount,
                description=description,
                phone=phone
            )
        except Exception as e:
            import traceback
            return Response({
                'error': 'Хатогӣ ҳангоми тайёр кардани пардохт',
                'details': str(e),
                'traceback': traceback.format_exc()
            }, status=500)
        
        # Generate HTML form
        try:
            html_form = _generate_html_form(xml_data)
        except Exception as e:
            import traceback
            return Response({
                'error': 'Хатогӣ ҳангоми тайёр кардани HTML форма',
                'details': str(e),
                'traceback': traceback.format_exc()
            }, status=500)
        
        # Return payment URL and XML data
        return Response({
            'payment_url': settings.DC_PAYMENT_URL,
            'xml_data': xml_data,
            'order_id': order_id,
            'amount': str(amount),
            'description': description,
            # HTML form for WebView (Flutter will use this)
            'html_form': html_form
        })


@method_decorator(csrf_exempt, name='dispatch')
class SmartPayInitView(APIView):
    """
    Legacy: POST /api/payment/smartpay/init/
    Барои Flutter-и кӯҳна — ҳамон create-invoice (deeplink_url агар bank_id бошад).
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not is_smartpay_region_allowed(request, request.user):
            return Response(
                {'error': 'SmartPay танҳо дар Тоҷикистон дастрас аст.', 'code': 'region_not_allowed'},
                status=403,
            )

        amount = request.data.get('amount')
        description = request.data.get('description')
        bank_id = request.data.get('bank_id')

        if not amount:
            return Response({'error': 'Маблағро ворид кунед'}, status=400)

        try:
            service = SmartPayService()
            amount_decimal = service.validate_amount(amount)
        except SmartPayError as exc:
            return Response({'error': exc.message, 'code': exc.code}, status=exc.status_code)
        except (ValueError, TypeError):
            return Response({'error': 'Маблағи нодуруст'}, status=400)

        phone = request.user.phone if hasattr(request.user, 'phone') else ''
        if not description:
            description = f'Пур кардани баланси барномаи ҳуқуқи ронанда: {amount_decimal} сомонӣ'

        order_id = str(uuid.uuid4())
        try:
            result = service.create_invoice(
                amount=amount_decimal,
                order_id=order_id,
                bank_id=bank_id,
                description=description,
                customer_phone=phone,
            )
        except SmartPayError as exc:
            return Response({'error': exc.message, 'code': exc.code}, status=exc.status_code)
        except Exception as e:
            return Response({'error': f'Хатогӣ ҳангоми SmartPay: {e}'}, status=500)

        smartpay_id = result.get('smartpay_id') or ''
        invoice_uuid = result.get('invoice_uuid') or ''
        txn_description = build_smartpay_transaction_description(
            description,
            smartpay_id=smartpay_id,
            invoice_id=invoice_uuid,
        )

        Transaction.objects.update_or_create(
            transaction_id=order_id,
            defaults={
                'user': request.user,
                'amount': amount_decimal,
                'status': 'PENDING',
                'description': txn_description,
                'invoice_uuid': invoice_uuid,
                'payment_provider': 'smartpay',
            },
        )

        deeplink_url = result.get('deeplink_url')
        payment_link = result.get('payment_link')
        redirect_url = deeplink_url or payment_link

        payload = {
            'order_id': order_id,
            'invoice_uuid': invoice_uuid,
            'smartpay_id': smartpay_id,
            'payment_link': payment_link,
            'deeplink_url': deeplink_url,
            'use_deeplink': bool(deeplink_url),
        }

        if redirect_url and not deeplink_url:
            payload['html_form'] = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="0;url={redirect_url}">
  <title>SmartPay</title>
</head>
<body>
  <p>Интизор шавед... <a href="{redirect_url}">Пардохт</a></p>
</body>
</html>"""

        return Response(payload)


def _generate_html_form(xml_data):
    """
    Generate HTML form that will POST XML data to payment gateway
    This will be used in Flutter WebView
    """
    try:
        payment_url = getattr(settings, 'DC_PAYMENT_URL', 'https://acquire.dushanbecity.tj/createOrder.jsp')
    except:
        payment_url = 'https://acquire.dushanbecity.tj/createOrder.jsp'
    
    # Escape XML for HTML attribute - replace quotes and special chars
    # First escape & to avoid double escaping
    escaped_xml = xml_data.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&#39;')
    
    html = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Пардохт</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: #f5f5f5;
        }}
        .container {{
            text-align: center;
            padding: 20px;
        }}
        .spinner {{
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }}
        @keyframes spin {{
            0% {{ transform: rotate(0deg); }}
            100% {{ transform: rotate(360deg); }}
        }}
    </style>
</head>
<body onload="document.forms['paymentForm'].submit();">
    <div class="container">
        <div class="spinner"></div>
        <p>Интизор шавед, ба саҳифаи пардохт гузаронида мешавем...</p>
    </div>
    <form id="paymentForm" name="paymentForm" method="POST" action="{payment_url}">
        <input type="hidden" name="xml" value="{escaped_xml}">
        <noscript>
            <div style="text-align: center; padding: 20px;">
                <p>JavaScript фаъол нест. Лутфан тугмаи зеринро пахш кунед:</p>
                <button type="submit" style="padding: 10px 20px; font-size: 16px; background: #3498db; color: white; border: none; border-radius: 5px; cursor: pointer;">
                    Пардохт кардан
                </button>
            </div>
        </noscript>
    </form>
</body>
</html>'''
    return html


@method_decorator(csrf_exempt, name='dispatch')
class PaymentSuccessView(APIView):
    """
    Callback endpoint for successful payment
    DC will redirect here after successful payment
    """
    permission_classes = []  # No authentication required for callback
    
    def post(self, request):
        # DC will send payment result data here
        # You should verify the payment and update user balance
        return Response({
            'status': 'success',
            'message': 'Пардохт бомуваффақият анҷом шуд'
        })
    
    def get(self, request):
        # Some gateways use GET for redirects
        return Response({
            'status': 'success',
            'message': 'Пардохт бомуваффақият анҷом шуд'
        })


@method_decorator(csrf_exempt, name='dispatch')
class PaymentCancelView(APIView):
    """
    Callback endpoint for cancelled payment
    """
    permission_classes = []
    
    def post(self, request):
        return Response({
            'status': 'cancelled',
            'message': 'Пардохт бекор карда шуд'
        })
    
    def get(self, request):
        return Response({
            'status': 'cancelled',
            'message': 'Пардохт бекор карда шуд'
        })


@method_decorator(csrf_exempt, name='dispatch')
class PaymentDeclineView(APIView):
    """
    Callback endpoint for declined payment
    """
    permission_classes = []
    
    def post(self, request):
        return Response({
            'status': 'declined',
            'message': 'Пардохт рад карда шуд'
        })
    
    def get(self, request):
        return Response({
            'status': 'declined',
            'message': 'Пардохт рад карда шуд'
        })


@method_decorator(csrf_exempt, name='dispatch')
class SmartPayWebhookView(APIView):
    """
    Legacy webhook: POST /api/payment/smartpay/webhook/
  Ҳолати Charged ё success — баланс фаврӣ пур мешавад.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        if not verify_smartpay_webhook(request):
            return Response({'error': 'Unauthorized'}, status=401)

        data = request.data if isinstance(request.data, dict) else {}
        status = data.get('status') or data.get('Status')
        order_id = data.get('order_id') or data.get('orderId')
        smartpay_id = data.get('smartpay_id') or data.get('smartpayId')
        invoice_id = (
            data.get('invoice_id')
            or data.get('invoiceId')
            or data.get('invoice_uuid')
            or data.get('invoiceUuid')
        )

        if is_charged_status(status):
            txn = find_transaction_for_smartpay(
                order_id=order_id,
                smartpay_id=smartpay_id,
                invoice_id=invoice_id,
            )
            if txn:
                apply_smartpay_success(txn, status_hint=status)

        return Response({'status': 'accepted'})


@method_decorator(csrf_exempt, name='dispatch')
class SmartPayStatusView(APIView):
    """
    Legacy: GET /api/payment/smartpay/status/?order_id=...
    Барои Flutter — ҳолати пардохт ва пуркунии баланс.
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        order_id = request.query_params.get('order_id')
        if not order_id:
            return Response({'error': 'order_id лозим аст'}, status=400)

        txn = find_transaction_for_smartpay(order_id=order_id, user=request.user)
        if not txn:
            return Response({'error': 'Транзаксия ёфт нашуд'}, status=404)

        if txn.status == 'SUCCESS':
            request.user.refresh_from_db()
            return Response({
                'order_id': txn.transaction_id,
                'status': 'SUCCESS',
                'local_status': txn.status,
                'credited': False,
                'new_balance': str(request.user.balance),
            })

        lookup_id = smartpay_status_lookup_id(txn, fallback_order_id=order_id)
        try:
            data = SmartPayService().get_order_status(lookup_id)
        except SmartPayError as exc:
            return Response({'error': exc.message, 'code': exc.code}, status=exc.status_code)

        remote_status = data.get('status')
        credited = False
        new_balance = None
        if is_charged_status(remote_status):
            if apply_smartpay_success(txn, status_hint=remote_status):
                credited = True
            request.user.refresh_from_db()
            new_balance = str(request.user.balance)

        payload = {
            'order_id': txn.transaction_id,
            'status': remote_status or txn.status,
            'local_status': txn.status,
            'amount': data.get('amount'),
            'paid_amount': data.get('paid_amount'),
            'paid_at': data.get('paid_at'),
            'credited': credited,
        }
        if new_balance is not None:
            payload['new_balance'] = new_balance
        return Response(payload)


class PaymentHistoryView(APIView):
    """
    Return payment history for current user.
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Transaction.objects.filter(user=request.user).order_by('-created_at')
        serializer = TransactionSerializer(qs, many=True)
        return Response(serializer.data)


@method_decorator(csrf_exempt, name='dispatch')
class AppleIAPConfirmView(APIView):
    """POST /api/iap/apple/confirm/ — тасдиқи StoreKit 2 JWS."""
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plan_id = request.data.get('plan_id')
        jws = (
            request.data.get('signed_transaction_info')
            or request.data.get('signedTransactionInfo')
        )
        if not plan_id or not jws:
            return Response(
                {'error': 'plan_id ва signed_transaction_info лозим аст'},
                status=400,
            )

        plan = get_object_or_404(SubscriptionPlan, id=plan_id, is_active=True)
        if not (plan.apple_product_id or '').strip():
            return Response(
                {'error': 'Барои ин нақша apple_product_id танзим нашудааст'},
                status=400,
            )

        try:
            payload = decode_apple_jws_payload(jws)
        except (ValueError, TypeError) as exc:
            return Response({'error': f'JWS нодуруст: {exc}'}, status=400)

        expected_bundle = (getattr(settings, 'APPLE_BUNDLE_ID', '') or '').strip()
        bundle_id = payload.get('bundleId') or payload.get('bundle_id') or ''
        if expected_bundle and bundle_id and bundle_id != expected_bundle:
            return Response({'error': 'bundleId номувафиқ аст'}, status=400)

        product_id = payload.get('productId') or payload.get('product_id') or ''
        if product_id and product_id != plan.apple_product_id:
            return Response({'error': 'productId номувафиқ аст'}, status=400)

        transaction_id = (
            payload.get('transactionId')
            or payload.get('transaction_id')
            or ''
        )
        if not transaction_id:
            return Response({'error': 'transactionId дар JWS нест'}, status=400)

        if AppleStoreTransaction.objects.filter(transaction_id=transaction_id).exists():
            return Response({
                'message': 'Транзаксия аллакай сабт шудааст',
                'duplicate': True,
            })

        expires_at = None
        expires_ms = payload.get('expiresDate') or payload.get('expires_date')
        if expires_ms is not None:
            try:
                expires_at = datetime.fromtimestamp(
                    int(expires_ms) / 1000,
                    tz=dt_timezone.utc,
                )
            except (TypeError, ValueError):
                expires_at = None

        user = request.user
        try:
            with db_transaction.atomic():
                AppleStoreTransaction.objects.create(
                    user=user,
                    plan=plan,
                    transaction_id=transaction_id,
                    original_transaction_id=(
                        payload.get('originalTransactionId')
                        or payload.get('original_transaction_id')
                        or ''
                    ),
                    product_id=product_id or plan.apple_product_id,
                    raw_payload=payload,
                )

                current = Subscription.objects.filter(
                    user=user,
                    plan=plan,
                    expires_at__gt=timezone.now(),
                ).order_by('-expires_at').first()

                if expires_at:
                    new_expires = expires_at
                elif current:
                    new_expires = current.expires_at + timedelta(days=plan.days)
                else:
                    new_expires = timezone.now() + timedelta(days=plan.days)

                Subscription.objects.create(
                    user=user,
                    plan=plan,
                    expires_at=new_expires,
                )

                Transaction.objects.create(
                    user=user,
                    amount=plan.price,
                    status='SUCCESS',
                    transaction_id=f'APL-{uuid.uuid4().hex[:12].upper()}',
                    description=f'Apple IAP: {plan.name}',
                )
        except Exception as exc:
            return Response({'error': str(exc)}, status=500)

        return Response({
            'message': 'Обуна фаъол шуд',
            'expires_at': new_expires.isoformat(),
        })


class AboutPageView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        page = AboutPage.objects.first()
        if not page:
            return Response({
                'title': 'Дар бораи мо',
                'content': '',
                'phone': '',
                'email': '',
                'telegram_url': '',
                'whatsapp_url': '',
            })
        return Response(AboutPageSerializer(page).data)


class LegalDocumentsListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        documents = LegalDocument.objects.filter(is_active=True).order_by('order', 'id')
        serializer = LegalDocumentSerializer(
            documents,
            many=True,
            context={'request': request},
        )
        return Response(serializer.data)


class LegalDocumentPdfView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, pk):
        document = get_object_or_404(LegalDocument, pk=pk, is_active=True)
        if document.pdf_file and document.pdf_file.name:
            disk_path = resolve_legal_document_path(document.pdf_file.name)
            if disk_path:
                return FileResponse(
                    open(disk_path, 'rb'),
                    content_type='application/pdf',
                    filename=document.pdf_file.name.split('/')[-1],
                )
        if document.pdf_url:
            return Response({'pdf_url': document.pdf_url})
        raise Http404('PDF нест')