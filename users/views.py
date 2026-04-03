<<<<<<< HEAD
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.authtoken.models import Token as AuthToken 
from rest_framework.authentication import TokenAuthentication
from django.contrib.auth import get_user_model
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from .models import PhoneOTP
import random
from django.apps import apps
from .utils import send_osonsms
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
User = get_user_model()
from rest_framework.permissions import IsAuthenticated 
from .serializers import UserSerializer

@method_decorator(csrf_exempt, name='dispatch')
class SendCodeView(APIView):
    def post(self, request):
        print(f"=== SendCodeView POST request ===")
        print(f"Request data: {request.data}")
        print(f"Request META: {request.META.get('CONTENT_TYPE', 'N/A')}")
        
        phone = request.data.get('phone')
        print(f"Phone received: {phone}")
        
        if not phone:
            print("Error: Phone is missing")
            return Response({'error': 'Телефонро ворид кунед'}, status=400)

        phone = str(phone).replace(" ", "")

        existing_otp = PhoneOTP.objects.filter(phone=phone).first()
        if existing_otp and existing_otp.updated_at >= timezone.now() - timedelta(seconds=60):
            code = existing_otp.code
            print(f"Reusing recent code: {code}")
        else:
            code = str(random.randint(1000, 9999))
            print(f"Generated code: {code}")
            PhoneOTP.objects.update_or_create(
                phone=phone, defaults={'code': code}
            )
        
        # Ирсоли SMS
        print(f"Sending SMS to {phone} with code {code}")
        sms_result = send_osonsms(phone, code)
        print(f"SMS send result: {sms_result}")
        
        print(f"--- KODI SANOCHI: {code} ---")
        response = {'message': 'Код фиристода шуд!'}
        if getattr(settings, 'DEBUG', False):
            response['code'] = code
        return Response(response)

@method_decorator(csrf_exempt, name='dispatch')
class VerifyCodeView(APIView):
    def post(self, request):
        phone = request.data.get('phone')
        code = request.data.get('code')

        if not phone or not code:
            return Response({'error': 'Маълумотро пурра ворид кунед'}, status=400)

        phone = str(phone).replace(" ", "")
        code = str(code).strip()

        try:
            otp_obj = PhoneOTP.objects.get(phone=phone)
        except PhoneOTP.DoesNotExist:
            return Response({'error': 'Код нодуруст аст'}, status=400)

        if otp_obj.updated_at < timezone.now() - timedelta(minutes=5):
            return Response({'error': 'Код кӯҳна шудааст, дубора фиристед'}, status=400)

        if otp_obj.code != code:
            return Response({'error': 'Код нодуруст аст'}, status=400)

        # Сохтани корбар
        user, created = User.objects.get_or_create(phone=phone)

        # --- ГИРИФТАНИ ТОКЕН (РОҲИ БЕХАТАР) ---
        TokenModel = apps.get_model('authtoken', 'Token')
        token, _ = TokenModel.objects.get_or_create(user=user)
        # --------------------------------------

        otp_obj.delete()

        return Response({'token': token.key, 'user_id': user.id})
    
class UserProfileView(APIView):
    """
    Ин View барои гирифтан ва тағйир додани маълумоти корбар (Профил)
    """
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated] # Фақат агар Token дошта бошад, кор мекунад

    def get(self, request):
        # Маълумоти ҳамон корбареро мегирад, ки Token равон кардааст
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

    def patch(self, request):
        # Барои иваз кардани Ном ва Фамилия
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=400)    
=======
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta
from .serializers import UserSerializer, SubscriptionPlanSerializer
from .models import SubscriptionPlan, Subscription

User = get_user_model()


@api_view(['GET', 'PUT', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def UserProfileView(request):
    """
    GET: Получить профиль пользователя
    PUT/PATCH: Обновить профиль пользователя (first_name, last_name, birth_date)
    DELETE: Удалить аккаунт пользователя
    """
    user = request.user
    
    if request.method == 'GET':
        serializer = UserSerializer(user)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    elif request.method in ['PUT', 'PATCH']:
        # Разрешаем обновление только определенных полей
        allowed_fields = ['first_name', 'last_name', 'birth_date']
        data = {k: v for k, v in request.data.items() if k in allowed_fields}
        
        serializer = UserSerializer(user, data=data, partial=request.method == 'PATCH')
        
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    elif request.method == 'DELETE':
        # Удаление аккаунта пользователя
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
    return Response(
        {'error': 'Method not allowed'}, 
        status=status.HTTP_405_METHOD_NOT_ALLOWED
    )


@api_view(['GET'])
@permission_classes([])  # Public endpoint - no authentication required
def SubscriptionPlansView(request):
    """
    GET: Get list of active subscription plans.
    Returns all active subscription plans available for purchase.
    """
    plans = SubscriptionPlan.objects.filter(is_active=True).order_by('price')
    serializer = SubscriptionPlanSerializer(plans, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def PurchaseSubscriptionView(request):
    """
    POST: Purchase a subscription plan.
    Requires: plan_id in request body.
    Validates user balance and creates subscription with expires_at calculated from plan.days.
    """
    user = request.user
    plan_id = request.data.get('plan_id')
    
    if not plan_id:
        return Response(
            {'success': False, 'error': 'plan_id is required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        plan = SubscriptionPlan.objects.get(id=plan_id, is_active=True)
    except SubscriptionPlan.DoesNotExist:
        return Response(
            {'success': False, 'error': 'Subscription plan not found or inactive'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Validate user balance
    if user.balance < plan.price:
        return Response(
            {
                'success': False,
                'error': f'Баланси шумо кифоя нест. Баланс: {user.balance}, Нарх: {plan.price}'
            },
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Calculate expires_at based on plan.days
    # If user has an active subscription, extend from expires_at, otherwise from now
    now = timezone.now()
    existing_subscription = Subscription.objects.filter(
        user=user,
        is_active=True,
        expires_at__gt=now
    ).order_by('-expires_at').first()
    
    if existing_subscription and existing_subscription.expires_at > now:
        # Extend from existing expiration date
        expires_at = existing_subscription.expires_at + timedelta(days=plan.days)
    else:
        # Start from now
        expires_at = now + timedelta(days=plan.days)
    
    # Deduct balance
    user.balance -= plan.price
    user.save()
    
    # Create subscription
    subscription = Subscription.objects.create(
        user=user,
        plan=plan,
        expires_at=expires_at,
        is_active=True
    )
    
    # Deactivate old subscriptions (optional - if you want only one active subscription)
    Subscription.objects.filter(
        user=user,
        is_active=True
    ).exclude(id=subscription.id).update(is_active=False)
    
    return Response(
        {
            'success': True,
            'message': f'Обунаи "{plan.name}" бо муваффақият харида шуд',
            'subscription': {
                'id': subscription.id,
                'plan_name': plan.name,
                'expires_at': subscription.expires_at.isoformat(),
            },
            'balance': float(user.balance),
        },
        status=status.HTTP_201_CREATED
    )

>>>>>>> a8f22a8973d7365b3dc32dbc0ffe15ba3b9e85a5
