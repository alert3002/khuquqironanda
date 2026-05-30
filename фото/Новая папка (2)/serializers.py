from rest_framework import serializers
from django.contrib.auth import get_user_model
from books.models import SubscriptionPlan, Subscription

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        # Ин маълумотҳоро ба барнома мефиристем:
        fields = ['id', 'phone', 'first_name', 'last_name', 'balance']
        # Баланс ва Телефонро тавассути API тағйир дода нашавад (фақат хондан):
        read_only_fields = ['phone', 'balance']


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = ['id', 'name', 'price', 'days', 'is_active']


class SubscriptionSerializer(serializers.ModelSerializer):
    plan = SubscriptionPlanSerializer(read_only=True)

    class Meta:
        model = Subscription
        fields = ['id', 'plan', 'purchased_at', 'expires_at']