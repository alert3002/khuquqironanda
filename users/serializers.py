from rest_framework import serializers
from django.contrib.auth import get_user_model
from books.models import SubscriptionPlan, Subscription

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    login_label = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = [
            'id',
            'phone',
            'first_name',
            'last_name',
            'balance',
            'telegram_id',
            'telegram_username',
            'login_label',
        ]
        read_only_fields = [
            'phone',
            'balance',
            'telegram_id',
            'telegram_username',
            'login_label',
        ]


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = ['id', 'name', 'price', 'days', 'is_active']


class SubscriptionSerializer(serializers.ModelSerializer):
    plan = SubscriptionPlanSerializer(read_only=True)

    class Meta:
        model = Subscription
        fields = ['id', 'plan', 'purchased_at', 'expires_at']