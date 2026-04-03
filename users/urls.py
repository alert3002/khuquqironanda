from django.urls import path
<<<<<<< HEAD
from .views import SendCodeView, VerifyCodeView, UserProfileView

urlpatterns = [
    path('send-code/', SendCodeView.as_view()),   # api/users/send-code/
    path('verify-code/', VerifyCodeView.as_view()), # api/users/verify-code/
    path('profile/', UserProfileView.as_view()),   # api/users/profile/
]
=======
from . import views

urlpatterns = [
    path('profile/', views.UserProfileView, name='user-profile'),
    path('subscription-plans/', views.SubscriptionPlansView, name='subscription-plans'),
    path('purchase-subscription/', views.PurchaseSubscriptionView, name='purchase-subscription'),
]

>>>>>>> a8f22a8973d7365b3dc32dbc0ffe15ba3b9e85a5
