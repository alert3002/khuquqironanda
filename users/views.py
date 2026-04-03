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