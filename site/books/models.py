from django.db import models
from ckeditor_uploader.fields import RichTextUploadingField
from django.contrib.auth import get_user_model

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