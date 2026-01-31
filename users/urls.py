from django.urls import path
from . import views

urlpatterns = [
    path('profile/', views.UserProfileView, name='user-profile'),
    path('subscription-plans/', views.SubscriptionPlansView, name='subscription-plans'),
    path('purchase-subscription/', views.PurchaseSubscriptionView, name='purchase-subscription'),
]

