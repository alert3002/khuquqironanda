import os

from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.http import FileResponse, Http404

from books.legal_docs import resolve_legal_document_path


def _serve_legal_pdf(filename: str) -> FileResponse:
    disk_path = resolve_legal_document_path(f'legal_documents/{filename}')
    if not disk_path:
        raise Http404('PDF нест')
    return FileResponse(
        open(disk_path, 'rb'),
        content_type='application/pdf',
        filename=filename,
    )


def serve_legal_document(request, path):
    """PDF аз LEGAL_DOCUMENTS_ROOT ё MEDIA/legal_documents/."""
    filename = os.path.basename(path.replace('\\', '/'))
    return _serve_legal_pdf(filename)


def serve_media_legal_document(request, path):
    """PDF тавассути /media/legal_documents/ (ҳамон файл дар LEGAL_DOCUMENTS_ROOT)."""
    filename = os.path.basename(path.replace('\\', '/'))
    return _serve_legal_pdf(filename)


urlpatterns = [
    path('admin/', admin.site.urls),
    path('ckeditor/', include('ckeditor_uploader.urls')),
    path('api/', include('books.urls')),
    path('api/auth/', include('users.urls')),
]

# PDF-ҳо: https://books.1week.tj/legal_documents/file.pdf
urlpatterns += [
    re_path(
        r'^legal_documents/(?P<path>.*)$',
        serve_legal_document,
    ),
]

# FileField.url → /media/legal_documents/... (файлҳо дар LEGAL_DOCUMENTS_ROOT нигоҳ дошта мешаванд)
urlpatterns += [
    re_path(
        r'^media/legal_documents/(?P<path>.*)$',
        serve_media_legal_document,
    ),
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
