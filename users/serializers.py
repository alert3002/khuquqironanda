from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import SubscriptionPlan, Subscription

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """
    Serializer for User model.
    Includes all user fields including birth_date.
    """
    
    class Meta:
        model = User
        fields = ['id', 'phone', 'first_name', 'last_name', 'balance', 'birth_date']
        read_only_fields = ['id', 'phone', 'balance']
    
    def validate_birth_date(self, value):
        """
        Validate birth_date field.
        Ensures the date is not in the future.
        """
        from datetime import date
        if value and value > date.today():
            raise serializers.ValidationError("Birth date cannot be in the future.")
        return value


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    """
    Serializer for SubscriptionPlan model.
    """
    
    class Meta:
        model = SubscriptionPlan
        fields = ['id', 'name', 'price', 'days', 'is_active']
        read_only_fields = ['id']


class SubscriptionSerializer(serializers.ModelSerializer):
    """
    Serializer for Subscription model.
    """
    plan = SubscriptionPlanSerializer(read_only=True)
    
    class Meta:
        model = Subscription
        fields = ['id', 'plan', 'purchased_at', 'expires_at', 'is_active']
        read_only_fields = ['id', 'purchased_at', 'expires_at']

