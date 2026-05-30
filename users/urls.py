from django.urls import path

from .views import SendCodeView, VerifyCodeView, TelegramLoginView, UserProfileView

urlpatterns = [
    path('send-code/', SendCodeView.as_view()),
    path('verify-code/', VerifyCodeView.as_view()),
    path('telegram/', TelegramLoginView.as_view()),
    path('profile/', UserProfileView.as_view()),
]
