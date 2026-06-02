from rest_framework import serializers
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
    LegalDocument,
)
from .legal_docs import resolve_legal_document_path
from .access import user_has_chapter_access as _user_has_chapter_access


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
        fields = [
            'title', 'content',
            'purchase_guide_title', 'purchase_guide_content',
            'phone', 'email', 'telegram_url', 'whatsapp_url', 'updated_at',
        ]


class LegalDocumentSerializer(serializers.ModelSerializer):
    pdf_url = serializers.SerializerMethodField()
    has_pdf = serializers.SerializerMethodField()

    class Meta:
        model = LegalDocument
        fields = ['id', 'order', 'title', 'pdf_url', 'has_pdf']

    def get_pdf_url(self, obj):
        request = self.context.get('request')
        if obj.pdf_file and obj.pdf_file.name:
            if resolve_legal_document_path(obj.pdf_file.name):
                # Ссылкаи админка (/media/legal_documents/...) — дар сервер кор мекунад
                rel_url = obj.pdf_file.url
                if request is not None:
                    return request.build_absolute_uri(rel_url)
                return rel_url
        external = (obj.pdf_url or '').strip()
        if external and request is not None:
            if external.startswith('http://') or external.startswith('https://'):
                return external
            return request.build_absolute_uri(external)
        return external

    def get_has_pdf(self, obj):
        if obj.pdf_file and obj.pdf_file.name:
            if resolve_legal_document_path(obj.pdf_file.name):
                return True
            try:
                return bool(obj.pdf_file.path and obj.pdf_file.storage.exists(obj.pdf_file.name))
            except (ValueError, NotImplementedError):
                return False
        return bool(obj.pdf_url and obj.pdf_url.strip())