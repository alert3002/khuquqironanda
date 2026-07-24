from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    AboutPageAdminViewSet,
    AdminLoginView,
    AdminMeView,
    AppleStoreTransactionAdminViewSet,
    BookAdminViewSet,
    ChapterAdminViewSet,
    LegalDocumentAdminViewSet,
    PhoneOTPAdminViewSet,
    PurchaseAdminViewSet,
    PurchasedChapterAdminViewSet,
    SubscriptionAdminViewSet,
    SubscriptionPlanAdminViewSet,
    TransactionAdminViewSet,
    UserAdminViewSet,
)

router = DefaultRouter()
router.register('books', BookAdminViewSet, basename='admin-books')
router.register('chapters', ChapterAdminViewSet, basename='admin-chapters')
router.register('users', UserAdminViewSet, basename='admin-users')
router.register('transactions', TransactionAdminViewSet, basename='admin-transactions')
router.register('subscription-plans', SubscriptionPlanAdminViewSet, basename='admin-plans')
router.register('subscriptions', SubscriptionAdminViewSet, basename='admin-subscriptions')
router.register('purchases', PurchaseAdminViewSet, basename='admin-purchases')
router.register('purchased-chapters', PurchasedChapterAdminViewSet, basename='admin-purchased-chapters')
router.register('legal-documents', LegalDocumentAdminViewSet, basename='admin-legal')
router.register('about-pages', AboutPageAdminViewSet, basename='admin-about')
router.register('apple-transactions', AppleStoreTransactionAdminViewSet, basename='admin-apple')
router.register('phone-otp', PhoneOTPAdminViewSet, basename='admin-otp')

urlpatterns = [
    path('auth/login/', AdminLoginView.as_view(), name='admin-login'),
    path('auth/me/', AdminMeView.as_view(), name='admin-me'),
    path('', include(router.urls)),
]
