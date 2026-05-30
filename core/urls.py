import os

from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.http import FileResponse, Http404

from books.legal_docs import resolve_legal_document_path
from users.views import (
    telegram_login_page,
    telegram_oauth_start,
    telegram_oauth_callback,
)


def serve_legal_document(request, path):
    """PDF аз LEGAL_DOCUMENTS_ROOT ё MEDIA/legal_documents/."""
    filename = os.path.basename(path.replace('\\', '/'))
    disk_path = resolve_legal_document_path(f'legal_documents/{filename}')
    if not disk_path:
        raise Http404('PDF нест')
    return FileResponse(
        open(disk_path, 'rb'),
        content_type='application/pdf',
        filename=filename,
    )


urlpatterns = [
    path('telegram-login/', telegram_login_page, name='telegram-login'),
    path('telegram-login/oauth/start/', telegram_oauth_start, name='telegram-oauth-start'),
    path('telegram-login/oauth/callback/', telegram_oauth_callback, name='telegram-oauth-callback'),
    path('admin/', admin.site.urls),
    path('ckeditor/', include('ckeditor_uploader.urls')),
    path('api/', include('books.urls')),
    path('api/auth/', include('users.urls')),
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# PDF-ҳо: https://books.1week.tj/legal_documents/file.pdf
urlpatterns += [
    re_path(
        r'^legal_documents/(?P<path>.*)$',
        serve_legal_document,
    ),
]
