from django.urls import path

from .views import (
    CreateInvoiceView,
    OrderStatusView,
    SmartPayAvailabilityView,
    SmartPayBanksView,
    SmartPayWebhookView,
)

urlpatterns = [
    path(
        'smartpay/availability/',
        SmartPayAvailabilityView.as_view(),
        name='smartpay-availability',
    ),
    path('banks/', SmartPayBanksView.as_view(), name='payment-banks'),
    path(
        'create-invoice/',
        CreateInvoiceView.as_view(),
        name='create-invoice',
    ),
    path(
        'order-status/',
        OrderStatusView.as_view(),
        name='order-status',
    ),
    path(
        'smartpay/webhook/',
        SmartPayWebhookView.as_view(),
        name='smartpay-webhook-v2',
    ),
]
