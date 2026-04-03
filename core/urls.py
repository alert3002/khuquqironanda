from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('ckeditor/', include('ckeditor_uploader.urls')),
    path('api/', include('books.urls')),
    path('api/auth/', include('users.urls')),
]   

# Ин қисм барои он аст, ки расмҳо ҳангоми кор дар компютер кушода шаванд
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)