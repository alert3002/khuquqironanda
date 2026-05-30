from django.core.management.base import BaseCommand

from books.legal_docs import sync_legal_document_file
from books.models import LegalDocument


class Command(BaseCommand):
    help = 'Нусхаи PDF-ҳои санадҳо аз MEDIA ба LEGAL_DOCUMENTS_ROOT'

    def handle(self, *args, **options):
        synced = 0
        missing = 0
        for doc in LegalDocument.objects.exclude(pdf_file='').exclude(pdf_file=None):
            if not doc.pdf_file or not doc.pdf_file.name:
                continue
            try:
                src = doc.pdf_file.path
            except (ValueError, NotImplementedError):
                src = None
            path = sync_legal_document_file(doc.pdf_file.name, source_path=src)
            if path:
                synced += 1
                self.stdout.write(self.style.SUCCESS(f'OK #{doc.id}: {path}'))
            else:
                missing += 1
                self.stdout.write(
                    self.style.WARNING(f'MISSING #{doc.id}: {doc.pdf_file.name}')
                )
        self.stdout.write(f'Нусха шуд: {synced}, ёфт нашуд: {missing}')
