from django.contrib import admin
from django.contrib import messages
from django.contrib.auth import get_user_model
from django.shortcuts import render, redirect
from django.http import HttpResponseRedirect

from .legal_docs import sync_legal_document_file
from .models import (
    Book,
    Chapter,
    Purchase,
    PurchasedChapter,
    SubscriptionPlan,
    Subscription,
    AppleStoreTransaction,
    Transaction,
    AboutPage,
    LegalDocument,
)

User = get_user_model()

# Ин класс барои он аст, ки бобҳоро дар даруни саҳифаи Китоб нишон диҳад
class ChapterInline(admin.TabularInline):
    model = Chapter
    extra = 1  # Як сатри холи барои иловакуни нишон медиҳад
    fields = ('title', 'order', 'is_free', 'content') # Майдонҳое ки бояд пур кунед

@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    list_display = ('title', 'price', 'created_at') # Дар рӯйхат чиро нишон диҳад
    search_fields = ('title',) # Имкони ҷустуҷӯ
    inlines = [ChapterInline] # Пайваст кардани бобҳо ба саҳифаи китоб
    actions = ['activate_book_for_users'] # Action-ҳои иловагӣ
    
    def activate_book_for_users(self, request, queryset):
        """
        Активатсияи китобҳо барои корбарон (бе пул)
        """
        if 'apply' in request.POST:
            # Интихоб кардани корбарон
            user_ids = request.POST.getlist('users')
            if not user_ids:
                self.message_user(request, "Лутфан ҳадди ақал як корбарро интихоб кунед!", messages.ERROR)
                return
            
            users = User.objects.filter(id__in=user_ids)
            books = queryset
            
            # Активатсияи китобҳо
            activated_count = 0
            for book in books:
                for user in users:
                    # Санҷиш: Оё аллакай харида шудааст?
                    purchase, created = Purchase.objects.get_or_create(
                        user=user,
                        book=book
                    )
                    if created:
                        activated_count += 1
            
            self.message_user(
                request,
                f"✅ {activated_count} китоб барои {users.count()} корбар активатсия шуд.",
                messages.SUCCESS
            )
            return HttpResponseRedirect(request.get_full_path())
        
        # Намоиши рӯйхати корбарон
        users = User.objects.all().order_by('phone')
        context = {
            'books': queryset,
            'users': users,
            'opts': self.model._meta,
            'action_checkbox_name': admin.helpers.ACTION_CHECKBOX_NAME,
        }
        return render(request, 'admin/activate_book_for_users.html', context)
    
    activate_book_for_users.short_description = "Активатсияи китоб барои корбарон (бе пул)"

@admin.register(Chapter)
class ChapterAdmin(admin.ModelAdmin):
    list_display = ('book', 'title', 'order', 'is_free', 'is_premium')
    list_filter = ('book', 'is_free', 'is_premium') # Филтр аз руи китоб ва пулакӣ/бепул
    ordering = ('book', 'order')

@admin.register(Purchase)
class PurchaseAdmin(admin.ModelAdmin):
    list_display = ('user', 'book', 'purchased_at')
    list_filter = ('book', 'purchased_at')
    search_fields = ('user__phone', 'book__title')
    readonly_fields = ('purchased_at',)

@admin.register(PurchasedChapter)
class PurchasedChapterAdmin(admin.ModelAdmin):
    list_display = ('user', 'chapter', 'purchased_at', 'price_paid')
    list_filter = ('chapter__book', 'purchased_at')
    search_fields = ('user__phone', 'chapter__title')
    readonly_fields = ('purchased_at',)


@admin.register(SubscriptionPlan)
class SubscriptionPlanAdmin(admin.ModelAdmin):
    list_display = ('name', 'book', 'price', 'days', 'is_active', 'apple_product_id')
    list_filter = ('book', 'is_active')
    search_fields = ('name', 'book__title', 'apple_product_id')
    filter_horizontal = ('chapters',)


@admin.register(AppleStoreTransaction)
class AppleStoreTransactionAdmin(admin.ModelAdmin):
    list_display = ('transaction_id', 'user', 'plan', 'product_id', 'created_at')
    search_fields = ('transaction_id', 'original_transaction_id', 'user__phone', 'product_id')
    readonly_fields = ('created_at', 'raw_payload')
    list_filter = ('plan__book',)


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ('user', 'plan', 'purchased_at', 'expires_at')
    list_filter = ('plan__book',)
    search_fields = ('user__phone', 'plan__name')
    readonly_fields = ('purchased_at',)


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ('transaction_id', 'user', 'amount', 'status', 'created_at')
    list_filter = ('status',)
    search_fields = ('transaction_id', 'user__phone')
    readonly_fields = ('created_at',)


@admin.register(AboutPage)
class AboutPageAdmin(admin.ModelAdmin):
    list_display = ('title', 'updated_at')
    search_fields = ('title',)
    fieldsets = (
        ('Дар бораи мо', {
            'fields': ('title', 'content', 'phone', 'email', 'telegram_url', 'whatsapp_url'),
        }),
        ('Дастурамал: харид ва обуна (барнома)', {
            'fields': ('purchase_guide_title', 'purchase_guide_content'),
            'description': 'Нархҳо аз «Нақшаҳои обуна» (SubscriptionPlan) гирифта мешаванд.',
        }),
    )


@admin.register(LegalDocument)
class LegalDocumentAdmin(admin.ModelAdmin):
    list_display = ('order', 'title_short', 'has_pdf_display', 'is_active', 'updated_at')
    list_display_links = ('title_short',)
    list_editable = ('order', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('title',)
    ordering = ('order', 'id')
    fields = ('order', 'title', 'pdf_file', 'pdf_url', 'is_active')

    def title_short(self, obj):
        return obj.title[:80] + ('…' if len(obj.title) > 80 else '')

    title_short.short_description = 'Сарлавҳа'

    def has_pdf_display(self, obj):
        return '✓' if obj.has_pdf else '—'

    has_pdf_display.short_description = 'PDF'

    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)
        if obj.pdf_file and obj.pdf_file.name:
            try:
                src = obj.pdf_file.path
            except (ValueError, NotImplementedError):
                src = None
            synced = sync_legal_document_file(obj.pdf_file.name, source_path=src)
            if synced:
                self.message_user(
                    request,
                    f'PDF нусха шуд: {synced}',
                    level=messages.SUCCESS,
                )
            else:
                self.message_user(
                    request,
                    'PDF дар сервер ёфт нашуд — лутфан файлро аз нав бор кунед.',
                    level=messages.WARNING,
                )