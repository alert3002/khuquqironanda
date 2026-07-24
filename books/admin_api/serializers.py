from django.contrib.auth import get_user_model
from rest_framework import serializers

from books.models import (
    AboutPage,
    AppleStoreTransaction,
    Book,
    Chapter,
    LegalDocument,
    Purchase,
    PurchasedChapter,
    Subscription,
    SubscriptionPlan,
    Transaction,
)
from users.models import PhoneOTP

User = get_user_model()


class BookAdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = Book
        fields = '__all__'


class ChapterAdminSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='book.title', read_only=True)

    class Meta:
        model = Chapter
        fields = '__all__'


class UserAdminSerializer(serializers.ModelSerializer):
    login_label = serializers.CharField(read_only=True)
    password = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = User
        fields = (
            'id',
            'phone',
            'telegram_id',
            'telegram_username',
            'first_name',
            'last_name',
            'balance',
            'is_active',
            'is_staff',
            'is_superuser',
            'date_joined',
            'last_login',
            'login_label',
            'password',
        )
        read_only_fields = ('date_joined', 'last_login', 'login_label')

    def create(self, validated_data):
        password = validated_data.pop('password', None)
        user = User(**validated_data)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save()
        return user

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password:
            instance.set_password(password)
        instance.save()
        return instance


class TransactionAdminSerializer(serializers.ModelSerializer):
    user_phone = serializers.CharField(source='user.phone', read_only=True)

    class Meta:
        model = Transaction
        fields = '__all__'


class SubscriptionPlanAdminSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='book.title', read_only=True)
    chapter_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=Chapter.objects.all(),
        source='chapters',
        required=False,
    )

    class Meta:
        model = SubscriptionPlan
        fields = '__all__'


class SubscriptionAdminSerializer(serializers.ModelSerializer):
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    plan_name = serializers.CharField(source='plan.name', read_only=True)

    class Meta:
        model = Subscription
        fields = '__all__'


class PurchaseAdminSerializer(serializers.ModelSerializer):
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    book_title = serializers.CharField(source='book.title', read_only=True)

    class Meta:
        model = Purchase
        fields = '__all__'
        read_only_fields = ('purchased_at',)


class PurchasedChapterAdminSerializer(serializers.ModelSerializer):
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    chapter_title = serializers.CharField(source='chapter.title', read_only=True)

    class Meta:
        model = PurchasedChapter
        fields = '__all__'
        read_only_fields = ('purchased_at',)


class LegalDocumentAdminSerializer(serializers.ModelSerializer):
    has_pdf = serializers.BooleanField(read_only=True)

    class Meta:
        model = LegalDocument
        fields = '__all__'


class AboutPageAdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = AboutPage
        fields = '__all__'


class AppleStoreTransactionAdminSerializer(serializers.ModelSerializer):
    user_phone = serializers.CharField(source='user.phone', read_only=True)

    class Meta:
        model = AppleStoreTransaction
        fields = '__all__'
        read_only_fields = ('created_at', 'raw_payload')


class PhoneOTPAdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = PhoneOTP
        fields = '__all__'
