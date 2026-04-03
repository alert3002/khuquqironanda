from rest_framework import serializers
from django.db.models import Q
from django.utils import timezone
from .models import (
    Book,
    Chapter,
    PurchasedChapter,
    Purchase,
    SubscriptionPlan,
    Subscription,
    Transaction,
    AboutPage,
)


def _user_has_chapter_access(user, chapter):
    if chapter.is_free:
        return True
    if Purchase.objects.filter(user=user, book=chapter.book).exists():
        return True
    if PurchasedChapter.objects.filter(user=user, chapter=chapter).exists():
        return True
    if chapter.is_premium:
        return Subscription.objects.filter(
            user=user,
            expires_at__gt=timezone.now(),
            plan__is_active=True,
            plan__book=chapter.book,
        ).filter(
            Q(plan__chapters=chapter) | Q(plan__days__gte=180)
        ).exists()
    return Subscription.objects.filter(
        user=user,
        expires_at__gt=timezone.now(),
        plan__is_active=True,
        plan__book=chapter.book,
    ).exists()


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = ['id', 'name', 'price', 'days', 'is_active', 'apple_product_id']

class ChapterSerializer(serializers.ModelSerializer):
    is_purchased = serializers.SerializerMethodField()
    
    class Meta:
        model = Chapter
        fields = ['id', 'title', 'content', 'is_free', 'is_premium', 'order', 'is_purchased']
    
    def get_is_purchased(self, obj):
        """
        Мантиқ: Боб кушода аст, агар:
        1. Боб ройгон бошад.
        2. Корбар худи бобро харида бошад.
        3. Корбар тамоми КИТОБРО харида бошад.
        """
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return _user_has_chapter_access(request.user, obj)
        return False

class BookSerializer(serializers.ModelSerializer):
    chapters = ChapterSerializer(many=True, read_only=True)
    plans = SubscriptionPlanSerializer(many=True, read_only=True)
    is_purchased = serializers.SerializerMethodField()
    expires_at = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = ['id', 'title', 'description', 'cover_image', 'price', 'chapters', 'plans', 'is_purchased', 'expires_at']
    
    def get_is_purchased(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            has_purchase = Purchase.objects.filter(user=request.user, book=obj).exists()
            has_subscription = Subscription.objects.filter(
                user=request.user,
                expires_at__gt=timezone.now(),
                plan__is_active=True,
                plan__book=obj,
            ).exists()
            return has_purchase or has_subscription
        return False

    def get_expires_at(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            subscription = Subscription.objects.filter(
                user=request.user,
                expires_at__gt=timezone.now(),
                plan__is_active=True,
                plan__book=obj,
            ).order_by('-expires_at').first()
            return subscription.expires_at if subscription else None
        return None


class TransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Transaction
        fields = ['transaction_id', 'amount', 'status', 'description', 'created_at']


class AboutPageSerializer(serializers.ModelSerializer):
    class Meta:
        model = AboutPage
        fields = ['title', 'content', 'phone', 'email', 'telegram_url', 'whatsapp_url', 'updated_at']