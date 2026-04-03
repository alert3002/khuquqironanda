"""
Management command to process all books and create FAISS index for AI search.

Usage:
    python manage.py process_books
"""
from django.core.management.base import BaseCommand
from books.models import Chapter
from books.utils import create_faiss_index


class Command(BaseCommand):
    help = 'Process all book chapters and create FAISS index for AI search'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting to process books...'))
        
        # Get all chapters
        chapters = Chapter.objects.select_related('book').all()
        total_chapters = chapters.count()
        
        if total_chapters == 0:
            self.stdout.write(self.style.WARNING('No chapters found in database.'))
            return
        
        self.stdout.write(f'Found {total_chapters} chapters to process.')
        
        # Prepare data for indexing
        chapters_data = []
        for chapter in chapters:
            chapters_data.append((
                chapter.book.title,
                chapter.title,
                chapter.content,
                str(chapter.id)
            ))
        
        # Create FAISS index
        try:
            self.stdout.write('Creating embeddings and FAISS index...')
            num_chunks = create_faiss_index(chapters_data)
            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully created FAISS index with {num_chunks} chunks from {total_chapters} chapters.'
                )
            )
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error creating FAISS index: {str(e)}')
            )
            raise

