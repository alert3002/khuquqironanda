from django.db import models
from ckeditor_uploader.fields import RichTextUploadingField
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()

class Book(models.Model):
    title = models.CharField(max_length=200, verbose_name="Номи китоб")
    description = models.TextField(verbose_name="Тавсифи мухтасар", blank=True)
    cover_image = models.ImageField(upload_to='book_covers/', verbose_name="Расми муқова")
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0, verbose_name="Нархи китоб (сомонӣ)")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title

    class Meta:
        verbose_name = "Китоб"
        verbose_name_plural = "Китобҳо"


class Chapter(models.Model):
    book = models.ForeignKey(Book, related_name='chapters', on_delete=models.CASCADE, verbose_name="Китоб")
    title = models.CharField(max_length=200, verbose_name="Сарлавҳаи боб")
    
    # ИНҶОРО ИВАЗ КАРДЕМ: TextField -> RichTextUploadingField
    content = RichTextUploadingField(verbose_name="Матни боб") 
    
    is_free = models.BooleanField(default=False, verbose_name="Ройгон аст?")
    is_premium = models.BooleanField(default=False, verbose_name="Премиум аст?")
    order = models.PositiveIntegerField(default=1, verbose_name="Тартиби ҷойгиршавӣ")

    def __str__(self):
        return f"{self.book.title} - {self.title}"

    class Meta:
        ordering = ['order']
        verbose_name = "Боб"
        verbose_name_plural = "Бобҳо"


class PurchasedChapter(models.Model):
    """Модели бобҳои харидашуда"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='purchased_chapters', verbose_name="Корбар")
    chapter = models.ForeignKey(Chapter, on_delete=models.CASCADE, related_name='purchases', verbose_name="Боб")
    purchased_at = models.DateTimeField(auto_now_add=True, verbose_name="Вақти харид")
    price_paid = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Нархи пардохташуда")

    class Meta:
        unique_together = ['user', 'chapter']  # Як корбар як бобро танҳо як маротиба харида метавонад
        verbose_name = "Боби харидашуда"
        verbose_name_plural = "Бобҳои харидашуда"
        ordering = ['-purchased_at']

    def __str__(self):
        return f"{self.user.phone} - {self.chapter.title}"


class Purchase(models.Model):
    """Модели китобҳои харидашуда"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='purchased_books', verbose_name="Корбар")
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='purchases', verbose_name="Китоб")
    purchased_at = models.DateTimeField(auto_now_add=True, verbose_name="Вақти харид")

    class Meta:
        unique_together = ['user', 'book']  # Як корбар як китобро танҳо як маротиба харида метавонад
        verbose_name = "Китоби харидашуда"
        verbose_name_plural = "Китобҳои харидашуда"
        ordering = ['-purchased_at']

    def __str__(self):
        return f"{self.user.phone} - {self.book.title}"


class SubscriptionPlan(models.Model):
    """Нақшаи обуна барои китоб бо интихоби бобҳо"""
    book = models.ForeignKey(Book, related_name='plans', on_delete=models.CASCADE, verbose_name="Китоб")
    name = models.CharField(max_length=255, verbose_name="Номи нақша")
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Нарх")
    days = models.PositiveIntegerField(verbose_name="Рӯзҳо")
    is_active = models.BooleanField(default=True, verbose_name="Фаъол")
    apple_product_id = models.CharField(
        max_length=128,
        blank=True,
        default='',
        verbose_name="Apple IAP Product ID",
        help_text="Дар App Store Connect → In‑App Purchases Product ID (бо plan мепайвандад)",
    )
    chapters = models.ManyToManyField(
        Chapter,
        related_name='subscription_plans',
        blank=True,
        verbose_name="Бобҳои дастрас",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Нақшаи обуна"
        verbose_name_plural = "Нақшаҳои обуна"
        ordering = ['price']

    def __str__(self):
        return f"{self.name} - {self.price} сомонӣ ({self.days} рӯз)"


class Subscription(models.Model):
    """Обунаи корбар ба нақша"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='subscriptions', verbose_name="Корбар")
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.CASCADE, related_name='subscriptions', verbose_name="Нақша")
    purchased_at = models.DateTimeField(auto_now_add=True, verbose_name="Вақти харид")
    expires_at = models.DateTimeField(verbose_name="Муҳлати анҷом")

    class Meta:
        verbose_name = "Обуна"
        verbose_name_plural = "Обунаҳо"
        ordering = ['-purchased_at']

    def __str__(self):
        return f"{self.user.phone} - {self.plan.name} (то {self.expires_at.date()})"

    def is_active(self):
        return self.expires_at and self.expires_at > timezone.now()


class AppleStoreTransaction(models.Model):
    """Ҷамъоварии транзаксияҳои Apple IAP (StoreKit) барои пешгирии такрор."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='apple_transactions', verbose_name="Корбар")
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.CASCADE, related_name='apple_transactions', verbose_name="Нақша")
    transaction_id = models.CharField(max_length=128, unique=True, db_index=True, verbose_name="Transaction ID")
    original_transaction_id = models.CharField(max_length=128, blank=True, default='', verbose_name="Original transaction ID")
    product_id = models.CharField(max_length=128, blank=True, default='', verbose_name="Product ID")
    raw_payload = models.JSONField(blank=True, null=True, verbose_name="JWS payload (decoded)")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Apple IAP транзаксия"
        verbose_name_plural = "Apple IAP транзаксияҳо"
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.transaction_id} — {self.user.phone}"


class Transaction(models.Model):
    """Транзаксия барои обуна ё пуркунии баланс"""
    STATUS_CHOICES = (
        ('PENDING', 'PENDING'),
        ('SUCCESS', 'SUCCESS'),
        ('FAILED', 'FAILED'),
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='transactions', verbose_name="Корбар")
    amount = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Маблағ")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING', verbose_name="Ҳолат")
    transaction_id = models.CharField(max_length=64, unique=True, verbose_name="ID-и транзаксия")
    description = models.CharField(max_length=255, blank=True, verbose_name="Тавсиф")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Сана")

    class Meta:
        verbose_name = "Транзаксия"
        verbose_name_plural = "Транзаксияҳо"
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.transaction_id} - {self.user.phone} - {self.amount}"


class LegalDocument(models.Model):
    """Санадҳои меъёрию ҳуқуқӣ — рӯйхати «Қоидаҳои ҳаракат дар роҳ»"""
    order = models.PositiveIntegerField(default=1, verbose_name="№ дар рӯйхат")
    title = models.CharField(max_length=500, verbose_name="Сарлавҳа")
    pdf_file = models.FileField(
        upload_to='legal_documents/',
        blank=True,
        null=True,
        verbose_name="Файли PDF",
    )
    pdf_url = models.URLField(
        blank=True,
        verbose_name="Ссылкаи PDF (URL)",
        help_text="Агар файл бор накунед, истифода баред: https://.../file.pdf",
    )
    is_active = models.BooleanField(default=True, verbose_name="Фаъол")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['order', 'id']
        verbose_name = "Санади меъёрию ҳуқуқӣ"
        verbose_name_plural = "Санадҳои меъёрию ҳуқуқӣ (Қоидаҳои ҳаракат дар роҳ)"

    def __str__(self):
        return f"{self.order}. {self.title[:60]}"

    @property
    def has_pdf(self):
        return bool(self.pdf_file) or bool(self.pdf_url.strip() if self.pdf_url else False)


class AboutPage(models.Model):
    """Маълумоти саҳифаи 'Дар бораи мо' ва дастурамали харид"""
    title = models.CharField(max_length=200, verbose_name="Сарлавҳа", default="Дар бораи мо")
    content = RichTextUploadingField(verbose_name="Матн", blank=True)
    purchase_guide_title = models.CharField(
        max_length=200,
        blank=True,
        default='Чӣ тавр харидан мумкин аст',
        verbose_name='Сарлавҳаи дастурамал (харид)',
    )
    purchase_guide_content = RichTextUploadingField(
        verbose_name='Дастурамал: чӣ тавр харидан',
        blank=True,
        help_text='Қадамҳо барои хариди китоб/обуна. Дар барнома зери «Тарифҳо» намоиш дода мешавад.',
    )
    phone = models.CharField(max_length=50, blank=True, verbose_name="Телефон")
    email = models.EmailField(blank=True, verbose_name="Email")
    telegram_url = models.URLField(blank=True, verbose_name="Telegram")
    whatsapp_url = models.URLField(blank=True, verbose_name="WhatsApp")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Дар бораи мо"
        verbose_name_plural = "Дар бораи мо"

    def __str__(self):
        return self.title