from rest_framework import serializers
from .models import Book, Chapter, PurchasedChapter, Purchase

class ChapterSerializer(serializers.ModelSerializer):
    is_purchased = serializers.SerializerMethodField()
    
    class Meta:
        model = Chapter
        fields = ['id', 'title', 'content', 'is_free', 'order', 'is_purchased']
    
    def get_is_purchased(self, obj):
        """
        Мантиқ: Боб кушода аст, агар:
        1. Боб ройгон бошад.
        2. Корбар худи бобро харида бошад.
        3. Корбар тамоми КИТОБРО харида бошад.
        """
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            # 1. Санҷиши хариди худи боб
            chapter_bought = PurchasedChapter.objects.filter(user=request.user, chapter=obj).exists()
            if chapter_bought:
                return True
            
            # 2. Санҷиши хариди китоби асосӣ (Parent Book)
            book_bought = Purchase.objects.filter(user=request.user, book=obj.book).exists()
            return book_bought
            
        return False

class BookSerializer(serializers.ModelSerializer):
    chapters = ChapterSerializer(many=True, read_only=True)
    is_purchased = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = ['id', 'title', 'description', 'cover_image', 'price', 'chapters', 'is_purchased']
    
    def get_is_purchased(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Purchase.objects.filter(user=request.user, book=obj).exists()
        return False