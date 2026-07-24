from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    BookViewSet,
    PurchaseChapterView,
    CheckChapterAccessView,
    BuyBookView,
    PurchaseSubscriptionView,
    InitPaymentView,
    SmartPayInitView,
    SmartPayStatusView,
    SmartPayRefreshPendingView,
    PaymentHistoryView,
    PaymentSuccessView,
    PaymentCancelView,
    PaymentDeclineView,
    SmartPayWebhookView,
    AboutPageView,
    LegalDocumentsListView,
    LegalDocumentPdfView,
    AppleIAPConfirmView,
    PushNotificationsListView,
    RegisterPushTokenView,
)
from .alif_views import (
    AlifInitView,
    AlifCallbackView,
    AlifReturnView,
    AlifStatusView,
)

# Router автоматикӣ суроғаҳоро месозад (масалан /books/)
router = DefaultRouter()
router.register(r'books', BookViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('chapters/<int:chapter_id>/purchase/', PurchaseChapterView.as_view(), name='purchase-chapter'),
    path('chapters/<int:chapter_id>/check-access/', CheckChapterAccessView.as_view(), name='check-chapter-access'),
    path('buy-book/', BuyBookView.as_view(), name='buy-book'),
    path('purchase-subscription/', PurchaseSubscriptionView.as_view(), name='purchase-subscription'),
    # Payment endpoints
    path('payment/init/', InitPaymentView.as_view(), name='init-payment'),
    path('payment/smartpay/init/', SmartPayInitView.as_view(), name='smartpay-init'),
    path('payment/smartpay/status/', SmartPayStatusView.as_view(), name='smartpay-status'),
    path(
        'payment/smartpay/refresh-pending/',
        SmartPayRefreshPendingView.as_view(),
        name='smartpay-refresh-pending',
    ),
    path('payment/smartpay/webhook/', SmartPayWebhookView.as_view(), name='smartpay-webhook'),
    # Alif Bank (Корти Милли)
    path('payment/alif/init/', AlifInitView.as_view(), name='alif-init'),
    path('payment/alif/callback/', AlifCallbackView.as_view(), name='alif-callback'),
    path('payment/alif/return/', AlifReturnView.as_view(), name='alif-return'),
    path('payment/alif/status/', AlifStatusView.as_view(), name='alif-status'),
    path('payment/history/', PaymentHistoryView.as_view(), name='payment-history'),
    path('payment/success/', PaymentSuccessView.as_view(), name='payment-success'),
    path('payment/cancel/', PaymentCancelView.as_view(), name='payment-cancel'),
    path('payment/decline/', PaymentDeclineView.as_view(), name='payment-decline'),
    path('iap/apple/confirm/', AppleIAPConfirmView.as_view(), name='apple-iap-confirm'),
    path('about/', AboutPageView.as_view(), name='about-page'),
    path('books/about/', AboutPageView.as_view(), name='books-about-page'),
    path('notifications/', PushNotificationsListView.as_view(), name='push-notifications'),
    path('push/register/', RegisterPushTokenView.as_view(), name='push-register'),
    path('legal-documents/', LegalDocumentsListView.as_view(), name='legal-documents'),
    path(
        'legal-documents/<int:pk>/pdf/',
        LegalDocumentPdfView.as_view(),
        name='legal-document-pdf',
    ),
]
