from django.contrib.auth import authenticate, get_user_model
from rest_framework import viewsets
from rest_framework.filters import OrderingFilter, SearchFilter
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from books.models import (
    AboutPage,
    AppleStoreTransaction,
    Book,
    Chapter,
    LegalDocument,
    Purchase,
    PurchasedChapter,
    Subscription,
    SubscriptionPlan,
    Transaction,
)
from users.models import PhoneOTP

from .pagination import AdminPagination
from .permissions import IsStaffUser
from .serializers import (
    AboutPageAdminSerializer,
    AppleStoreTransactionAdminSerializer,
    BookAdminSerializer,
    ChapterAdminSerializer,
    LegalDocumentAdminSerializer,
    PhoneOTPAdminSerializer,
    PurchaseAdminSerializer,
    PurchasedChapterAdminSerializer,
    SubscriptionAdminSerializer,
    SubscriptionPlanAdminSerializer,
    TransactionAdminSerializer,
    UserAdminSerializer,
)

User = get_user_model()


class AdminLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone = (request.data.get('phone') or request.data.get('username') or '').strip()
        password = request.data.get('password') or ''

        if not phone or not password:
            return Response(
                {'error': 'Телефон ва паролро ворид кунед'},
                status=400,
            )

        user = authenticate(request, phone=phone, password=password)
        if user is None:
            return Response({'error': 'Телефон ё парол нодуруст аст'}, status=401)

        if not user.is_staff:
            return Response(
                {'error': 'Шумо дастрасии админ надоред (is_staff)'},
                status=403,
            )

        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            'token': token.key,
            'id': user.id,
            'fullName': user.get_full_name() or user.login_label or phone,
            'phone': user.phone,
        })


class AdminMeView(APIView):
    permission_classes = [IsStaffUser]

    def get(self, request):
        u = request.user
        return Response({
            'id': u.id,
            'fullName': u.get_full_name() or getattr(u, 'login_label', '') or u.phone,
            'phone': u.phone,
            'is_staff': u.is_staff,
            'is_superuser': u.is_superuser,
        })


class AdminModelViewSet(viewsets.ModelViewSet):
    permission_classes = [IsStaffUser]
    pagination_class = AdminPagination
    filter_backends = [SearchFilter, OrderingFilter]


class BookAdminViewSet(AdminModelViewSet):
    queryset = Book.objects.all().order_by('-created_at')
    serializer_class = BookAdminSerializer
    search_fields = ('title',)
    ordering_fields = ('title', 'price', 'created_at')


class ChapterAdminViewSet(AdminModelViewSet):
    queryset = Chapter.objects.select_related('book').all()
    serializer_class = ChapterAdminSerializer
    search_fields = ('title', 'book__title')
    ordering_fields = ('order', 'title', 'book')


class UserAdminViewSet(AdminModelViewSet):
    queryset = User.objects.all().order_by('-date_joined')
    serializer_class = UserAdminSerializer
    search_fields = ('phone', 'telegram_username', 'telegram_id', 'first_name', 'last_name')
    ordering_fields = ('date_joined', 'balance', 'phone')


class TransactionAdminViewSet(AdminModelViewSet):
    queryset = Transaction.objects.select_related('user').all()
    serializer_class = TransactionAdminSerializer
    search_fields = ('transaction_id', 'user__phone')
    ordering_fields = ('created_at', 'amount', 'status')


class SubscriptionPlanAdminViewSet(AdminModelViewSet):
    queryset = SubscriptionPlan.objects.select_related('book').prefetch_related('chapters')
    serializer_class = SubscriptionPlanAdminSerializer
    search_fields = ('name', 'book__title', 'apple_product_id')
    ordering_fields = ('price', 'days', 'name')


class SubscriptionAdminViewSet(AdminModelViewSet):
    queryset = Subscription.objects.select_related('user', 'plan').all()
    serializer_class = SubscriptionAdminSerializer
    search_fields = ('user__phone', 'plan__name')
    ordering_fields = ('purchased_at', 'expires_at')


class PurchaseAdminViewSet(AdminModelViewSet):
    queryset = Purchase.objects.select_related('user', 'book').all()
    serializer_class = PurchaseAdminSerializer
    search_fields = ('user__phone', 'book__title')
    ordering_fields = ('purchased_at',)


class PurchasedChapterAdminViewSet(AdminModelViewSet):
    queryset = PurchasedChapter.objects.select_related('user', 'chapter').all()
    serializer_class = PurchasedChapterAdminSerializer
    search_fields = ('user__phone', 'chapter__title')
    ordering_fields = ('purchased_at',)


class LegalDocumentAdminViewSet(AdminModelViewSet):
    queryset = LegalDocument.objects.all()
    serializer_class = LegalDocumentAdminSerializer
    search_fields = ('title',)
    ordering_fields = ('order', 'title', 'updated_at')


class AboutPageAdminViewSet(AdminModelViewSet):
    queryset = AboutPage.objects.all()
    serializer_class = AboutPageAdminSerializer
    search_fields = ('title',)


class AppleStoreTransactionAdminViewSet(AdminModelViewSet):
    queryset = AppleStoreTransaction.objects.select_related('user', 'plan').all()
    serializer_class = AppleStoreTransactionAdminSerializer
    search_fields = ('transaction_id', 'user__phone', 'product_id')
    ordering_fields = ('created_at',)
    http_method_names = ['get', 'head', 'options']


class PhoneOTPAdminViewSet(AdminModelViewSet):
    queryset = PhoneOTP.objects.all().order_by('-updated_at')
    serializer_class = PhoneOTPAdminSerializer
    search_fields = ('phone',)
    http_method_names = ['get', 'head', 'options', 'delete']
