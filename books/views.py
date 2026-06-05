from django.shortcuts import render, get_object_or_404
from django.http import FileResponse, HttpResponseRedirect
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.authentication import TokenAuthentication
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.contrib.auth import get_user_model
from django.conf import settings
from django.utils import timezone
from django.db.models import Q
from django.db import transaction as db_transaction
from decimal import Decimal
from datetime import datetime, timedelta, timezone as datetime_timezone
import json
import os
import uuid
from .models import (
    Book,
    Chapter,
    PurchasedChapter,
    Purchase,
    SubscriptionPlan,
    Subscription,
    AppleStoreTransaction,
    Transaction,
    AboutPage,
    LegalDocument,
)
from .apple_iap import decode_apple_jws_payload
from .legal_docs import resolve_legal_document_path, legal_document_filename
from .serializers import (
    BookSerializer,
    TransactionSerializer,
    AboutPageSerializer,
    LegalDocumentSerializer,
)
from .services import generate_payment_xml, create_smartpay_invoice
from .payment_utils import (
    find_transaction_for_smartpay,
    apply_smartpay_success,
    format_smartpay_id,
    extract_smartpay_id_from_description,
)
from .access import user_has_chapter_access

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

    @action(detail=False, methods=['get'], permission_classes=[AllowAny])
    def about(self, request):
        about = AboutPage.objects.order_by('-updated_at').first()
        if not about:
            return Response({
                'title': 'Дар бораи мо',
                'content': '',
                'phone': '',
                'email': '',
                'telegram_url': '',
                'whatsapp_url': '',
                'updated_at': None,
            })
        serializer = AboutPageSerializer(about)
        return Response(serializer.data)


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
        sub_description = f"Обуна: {plan.book.title} ({plan.name})"

        # Пешгирии дубли харид (дукмара пахш / retry)
        recent_dup = Transaction.objects.filter(
            user=user,
            status='SUCCESS',
            description=sub_description,
            created_at__gte=timezone.now() - timezone.timedelta(seconds=60),
        ).exists()
        if recent_dup:
            active = Subscription.objects.filter(
                user=user,
                plan=plan,
                expires_at__gt=timezone.now(),
            ).order_by('-expires_at').first()
            return Response({
                'message': 'Обуна аллакай фаъол аст',
                'new_balance': str(user.balance),
                'expires_at': active.expires_at.strftime('%Y-%m-%d %H:%M:%S') if active else None,
                'already_active': True,
            })

        try:
            with db_transaction.atomic():
                user = User.objects.select_for_update().get(pk=user.pk)
                if user.balance < plan.price:
                    return Response({
                        'error': 'Маблағ кифоя нест',
                        'required': str(plan.price),
                        'current_balance': str(user.balance),
                    }, status=400)

                current_subscription = (
                    Subscription.objects.select_for_update()
                    .filter(
                        user=user,
                        plan=plan,
                        expires_at__gt=timezone.now(),
                    )
                    .order_by('-expires_at')
                    .first()
                )

                if current_subscription:
                    current_subscription.expires_at += timezone.timedelta(days=plan.days)
                    current_subscription.save(update_fields=['expires_at'])
                    new_expires_at = current_subscription.expires_at
                else:
                    new_expires_at = timezone.now() + timezone.timedelta(days=plan.days)
                    current_subscription = Subscription.objects.create(
                        user=user,
                        plan=plan,
                        expires_at=new_expires_at,
                    )

                user.balance -= plan.price
                user.save(update_fields=['balance'])

                Transaction.objects.create(
                    user=user,
                    amount=plan.price,
                    status='SUCCESS',
                    transaction_id=f"SUB-{uuid.uuid4().hex[:8].upper()}",
                    description=sub_description,
                )

            return Response({
                'message': 'Обуна бо муваффақият фаъол шуд!',
                'new_balance': str(user.balance),
                'expires_at': new_expires_at.strftime('%Y-%m-%d %H:%M:%S'),
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
    Initialize payment via SmartPay and return redirect HTML.
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        amount = request.data.get('amount')
        description = request.data.get('description')

        if not amount:
            return Response({'error': 'Маблағро ворид кунед'}, status=400)

        try:
            amount_decimal = Decimal(str(amount))
            if amount_decimal <= 0:
                return Response({'error': 'Маблағ бояд мусбат бошад'}, status=400)
        except (ValueError, TypeError):
            return Response({'error': 'Маблағи нодуруст'}, status=400)

        phone = request.user.phone if hasattr(request.user, 'phone') else ''
        if not description:
            description = f'Пур кардани баланси барномаи ҳуқуқи ронанда: {amount_decimal} сомонӣ'

        order_id = f"SP-{uuid.uuid4().hex[:12].upper()}"
        raw_return_url = getattr(settings, 'SMARTPAY_RETURN_URL', '')
        if raw_return_url and '{order_id}' in raw_return_url:
            return_url = raw_return_url.replace('{order_id}', order_id)
        elif raw_return_url:
            joiner = '&' if '?' in raw_return_url else '?'
            return_url = f"{raw_return_url}{joiner}order_id={order_id}"
        else:
            return_url = ''

        bank_id = request.data.get('bank_id') or request.data.get('deeplink_bank_id')
        deeplink_bank_id = None
        if bank_id is not None and str(bank_id).strip() != '':
            try:
                deeplink_bank_id = int(bank_id)
            except (TypeError, ValueError):
                return Response({'error': 'ID-и бонки нодуруст'}, status=400)

        try:
            result = create_smartpay_invoice(
                amount=amount_decimal,
                description=description,
                customer_phone=phone,
                return_url=return_url,
                order_id=order_id,
                deeplink_bank_id=deeplink_bank_id,
            )
        except Exception as e:
            return Response({'error': f'Хатогӣ ҳангоми SmartPay: {e}'}, status=500)

        # Save pending transaction (merchant order_id + SmartPay dashboard id for webhook)
        extra_parts = []
        if result.get('invoice_id'):
            extra_parts.append(f"invoice_id:{result['invoice_id']}")
        if result.get('smartpay_id'):
            extra_parts.append(f"smartpay_id:{result['smartpay_id']}")
        extra_note = f" [{' '.join(extra_parts)}]" if extra_parts else ''
        Transaction.objects.create(
            user=request.user,
            amount=amount_decimal,
            status='PENDING',
            transaction_id=result.get('order_id') or order_id,
            description=f"{description}{extra_note}",
        )

        payment_link = result['payment_link']
        deeplink_url = result.get('deeplink_url')
        html_form = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="0;url={payment_link}">
  <title>SmartPay</title>
</head>
<body>
  <p>Интизор шавед... <a href="{payment_link}">Пардохт</a></p>
</body>
</html>"""

        response_data = {
            'payment_link': payment_link,
            'order_id': result['order_id'],
            'smartpay_id': result.get('smartpay_id'),
            'success': True,
        }
        if deeplink_url:
            response_data['deeplink_url'] = deeplink_url
        else:
            response_data['html_form'] = html_form
        return Response(response_data)


class SmartPayStatusView(APIView):
    """Poll payment status by order_id (updated via SmartPay webhook)."""
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        order_id = request.query_params.get('order_id')
        smartpay_id = request.query_params.get('smartpay_id')
        if not order_id and not smartpay_id:
            return Response({'error': 'order_id ё smartpay_id зарур аст'}, status=400)

        txn = find_transaction_for_smartpay(
            order_id=order_id,
            smartpay_id=smartpay_id,
        )
        if txn and txn.user_id != request.user.id:
            txn = None
        if not txn:
            txn = Transaction.objects.filter(
                user=request.user,
                transaction_id=order_id,
            ).first()
        if not txn:
            txn = Transaction.objects.filter(
                user=request.user,
                transaction_id__icontains=str(order_id).strip(),
            ).first()

        if not txn:
            return Response({'status': 'unknown', 'order_id': order_id})

        return Response({
            'status': txn.status,
            'order_id': txn.transaction_id,
            'amount': str(txn.amount),
        })


class SmartPayRefreshPendingView(APIView):
    """
    Refresh pending top-up statuses and current balance for the app «Навсозӣ» button.
    Does not call SmartPay API — returns latest DB state after webhook processing.
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        user.refresh_from_db()

        pending_qs = Transaction.objects.filter(
            user=user,
            status='PENDING',
        ).filter(
            Q(description__icontains='Пур кардани баланс')
            | Q(description__icontains='пур кардани баланс')
        ).order_by('-created_at')

        items = []
        for txn in pending_qs:
            txn.refresh_from_db()
            sp_id = extract_smartpay_id_from_description(txn.description)
            items.append({
                'transaction_id': txn.transaction_id,
                'smartpay_id': sp_id,
                'status': txn.status,
                'amount': str(txn.amount),
            })

        success_count = Transaction.objects.filter(
            user=user,
            status='SUCCESS',
        ).filter(
            Q(description__icontains='Пур кардани баланс')
            | Q(description__icontains='пур кардани баланс')
        ).count()

        return Response({
            'balance': str(user.balance),
            'pending': items,
            'pending_count': len(items),
            'success_topups': success_count,
        })


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
    SmartPay webhook endpoint.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        token = (
            request.headers.get('api_token')
            or request.headers.get('Api-Token')
            or request.headers.get('X-Api-Token')
            or request.headers.get('x-api-token')
            or request.headers.get('x-app-token')
            or request.headers.get('X-App-Token')
            or ''
        )
        expected = getattr(settings, 'SMARTPAY_WEBHOOK_TOKEN', '')
        if expected and token != expected:
            return Response({'error': 'Unauthorized'}, status=401)

        try:
            data = request.data if isinstance(request.data, dict) else {}
        except Exception:
            data = {}

        status = str(data.get('status', '')).lower()
        payload = data.get('data') if isinstance(data.get('data'), dict) else {}
        order_id = (
            data.get('order_id')
            or data.get('orderId')
            or data.get('orderid')
            or data.get('transaction_id')
            or payload.get('order_id')
            or payload.get('orderId')
        )
        smartpay_id = (
            data.get('smartpay_id')
            or data.get('smartpayId')
            or data.get('smartpayid')
            or payload.get('smartpay_id')
            or payload.get('smartpayId')
        )
        if smartpay_id:
            smartpay_id = format_smartpay_id(smartpay_id)
        invoice_id = (
            data.get('invoice_id')
            or data.get('invoice_uuid')
            or data.get('id')
            or data.get('payment_id')
            or payload.get('invoice_id')
            or payload.get('invoice_uuid')
            or payload.get('id')
        )

        txn = find_transaction_for_smartpay(
            order_id=order_id,
            smartpay_id=smartpay_id,
            invoice_id=invoice_id,
        )
        if not txn:
            import logging
            logging.getLogger(__name__).warning(
                'SmartPay webhook: transaction not found order_id=%s smartpay_id=%s invoice_id=%s',
                order_id,
                smartpay_id,
                invoice_id,
            )
            return Response({'status': 'accepted'})

        if status in ('success', 'paid', 'completed'):
            apply_smartpay_success(txn)
        elif status in ('failed', 'declined', 'canceled', 'cancelled'):
            if txn.status != 'FAILED':
                txn.status = 'FAILED'
                txn.save(update_fields=['status'])

        return Response({'status': 'accepted'})


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
    """
    Баъди харид дар iOS (StoreKit) — тасдиқи JWS ва фаъол кардани обуна дар сервер.
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plan_id = request.data.get('plan_id')
        jws = request.data.get('signed_transaction_info') or request.data.get('signedTransactionInfo')

        if not plan_id or not jws:
            return Response(
                {'error': 'plan_id ва signed_transaction_info лозиманд'},
                status=400,
            )

        plan = get_object_or_404(SubscriptionPlan, id=plan_id, is_active=True)
        if not (plan.apple_product_id or '').strip():
            return Response(
                {'error': 'Барои ин нақша дар админ Apple Product ID монда шуда нист'},
                status=400,
            )

        try:
            payload = decode_apple_jws_payload(jws)
        except (ValueError, json.JSONDecodeError, UnicodeDecodeError, OSError) as e:
            return Response({'error': f'JWS нодуруст: {e}'}, status=400)

        bundle_id = payload.get('bundleId') or payload.get('bundle_id')
        expected_bundle = getattr(settings, 'APPLE_BUNDLE_ID', '') or ''
        if expected_bundle and bundle_id and bundle_id != expected_bundle:
            return Response({'error': 'bundleId мувофиқ нест'}, status=400)

        product_id = payload.get('productId') or payload.get('product_id')
        if product_id != plan.apple_product_id.strip():
            return Response({'error': 'productId ба ин нақша мувофиқ нест'}, status=400)

        transaction_id = str(
            payload.get('transactionId') or payload.get('transaction_id') or ''
        ).strip()
        if not transaction_id:
            return Response({'error': 'transactionId дар JWS нест'}, status=400)

        if AppleStoreTransaction.objects.filter(transaction_id=transaction_id).exists():
            return Response({
                'message': 'Ин харид аллакай сабт шуда буд',
                'duplicate': True,
            })

        expires_ms = payload.get('expiresDate') or payload.get('expires_date')
        new_expires_at = None
        if expires_ms is not None:
            try:
                new_expires_at = datetime.fromtimestamp(
                    int(expires_ms) / 1000.0,
                    tz=datetime_timezone.utc,
                )
            except (TypeError, ValueError, OSError):
                new_expires_at = None

        current_subscription = Subscription.objects.filter(
            user=request.user,
            plan=plan,
            expires_at__gt=timezone.now(),
        ).order_by('-expires_at').first()

        if new_expires_at is None:
            if current_subscription:
                new_expires_at = current_subscription.expires_at + timedelta(
                    days=plan.days
                )
            else:
                new_expires_at = timezone.now() + timedelta(days=plan.days)

        try:
            with db_transaction.atomic():
                AppleStoreTransaction.objects.create(
                    user=request.user,
                    plan=plan,
                    transaction_id=transaction_id,
                    original_transaction_id=str(
                        payload.get('originalTransactionId')
                        or payload.get('original_transaction_id')
                        or ''
                    ),
                    product_id=str(product_id or ''),
                    raw_payload=payload,
                )
                Subscription.objects.create(
                    user=request.user,
                    plan=plan,
                    expires_at=new_expires_at,
                )
                Transaction.objects.create(
                    user=request.user,
                    amount=plan.price,
                    status='SUCCESS',
                    transaction_id=f"AP{uuid.uuid4().hex[:16]}",
                    description=f"Apple IAP: {plan.book.title} — {plan.name} (tx {transaction_id[:16]}…)",
                )
        except Exception as e:
            return Response({'error': f'Хатогӣ: {e}'}, status=500)

        return Response({
            'message': 'Обуна тавассути Apple фаъол шуд',
            'expires_at': new_expires_at.strftime('%Y-%m-%d %H:%M:%S'),
        })


class AboutPageView(APIView):
    """
    Public About page content.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        about = AboutPage.objects.order_by('-updated_at').first()
        if not about:
            return Response({
                'title': 'Дар бораи мо',
                'content': '',
                'purchase_guide_title': 'Чӣ тавр харидан мумкин аст',
                'purchase_guide_content': '',
                'phone': '',
                'email': '',
                'telegram_url': '',
                'whatsapp_url': '',
                'updated_at': None,
            })
        serializer = AboutPageSerializer(about)
        return Response(serializer.data)


class LegalDocumentsListView(APIView):
    """Рӯйхати санадҳои меъёрию ҳуқуқӣ барои «Қоидаҳои ҳаракат дар роҳ»."""
    permission_classes = [AllowAny]

    def get(self, request):
        documents = LegalDocument.objects.filter(is_active=True).order_by('order', 'id')
        serializer = LegalDocumentSerializer(
            documents,
            many=True,
            context={'request': request},
        )
        return Response({
            'title': 'Рӯйхати санадҳои меъёрию ҳуқуқии дар китоб истифода шуда',
            'intro': (
                'Дар китоби мазкур санадҳои меъёрию ҳуқуқи (СМҲ) - и зерин '
                'истифода карда шудааст:'
            ),
            'documents': serializer.data,
        })


class LegalDocumentPdfView(APIView):
    """PDF-и санад — барои Web/барнома бе мушкилии CORS."""
    permission_classes = [AllowAny]

    def get(self, request, pk):
        document = get_object_or_404(LegalDocument, pk=pk, is_active=True)
        if document.pdf_file and document.pdf_file.name:
            disk_path = resolve_legal_document_path(document.pdf_file.name)
            if disk_path and os.path.isfile(disk_path):
                return FileResponse(
                    open(disk_path, 'rb'),
                    content_type='application/pdf',
                    filename=os.path.basename(disk_path),
                )
            # Fallback: storage-и Django (масалан /media/legal_documents/...)
            if document.pdf_file.storage.exists(document.pdf_file.name):
                return FileResponse(
                    document.pdf_file.open('rb'),
                    content_type='application/pdf',
                    filename=legal_document_filename(document.pdf_file.name),
                )
        if document.pdf_url:
            return HttpResponseRedirect(document.pdf_url.strip())
        return HttpResponse('PDF нест', status=404)