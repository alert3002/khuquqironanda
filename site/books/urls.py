from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    BookViewSet, 
    PurchaseChapterView, 
    CheckChapterAccessView, 
    BuyBookView,
    InitPaymentView,
    PaymentSuccessView,
    PaymentCancelView,
    PaymentDeclineView
)

# Router автоматикӣ суроғаҳоро месозад (масалан /books/)
router = DefaultRouter()
router.register(r'books', BookViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('chapters/<int:chapter_id>/purchase/', PurchaseChapterView.as_view(), name='purchase-chapter'),
    path('chapters/<int:chapter_id>/check-access/', CheckChapterAccessView.as_view(), name='check-chapter-access'),
    path('buy-book/', BuyBookView.as_view(), name='buy-book'),
    # Payment endpoints
    path('payment/init/', InitPaymentView.as_view(), name='init-payment'),
    path('payment/success/', PaymentSuccessView.as_view(), name='payment-success'),
    path('payment/cancel/', PaymentCancelView.as_view(), name='payment-cancel'),
    path('payment/decline/', PaymentDeclineView.as_view(), name='payment-decline'),
]