from django.urls import path
from .views import SendCodeView, VerifyCodeView, UserProfileView

urlpatterns = [
    path('send-code/', SendCodeView.as_view()),   # api/users/send-code/
    path('verify-code/', VerifyCodeView.as_view()), # api/users/verify-code/
    path('profile/', UserProfileView.as_view()),   # api/users/profile/
]