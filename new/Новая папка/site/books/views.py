from django.shortcuts import render
from rest_framework import viewsets
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.authentication import TokenAuthentication
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.contrib.auth import get_user_model
from django.conf import settings
from decimal import Decimal
import uuid
from .models import Book, Chapter, PurchasedChapter, Purchase
from .serializers import BookSerializer
from .services import generate_payment_xml

User = get_user_model()

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

        # Агар боб ройгон бошад
        if chapter.is_free:
            return Response({
                'has_access': True,
                'is_free': True
            })

        # Санҷиш, оё харида шудааст
        has_access = PurchasedChapter.objects.filter(
            user=request.user,
            chapter=chapter
        ).exists()

        return Response({
            'has_access': has_access,
            'is_free': False,
            'price': str(chapter.book.price)
        })


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