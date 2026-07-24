"""Хидмати React Admin дар /admin/."""

from pathlib import Path

from django.conf import settings
from django.http import FileResponse, Http404


def _admin_static_root():
    return Path(settings.BASE_DIR) / 'static' / 'admin-spa'


def serve_admin_spa(request, path=''):
    root = _admin_static_root()
    index = root / 'index.html'

    if path:
        candidate = (root / path).resolve()
        try:
            candidate.relative_to(root.resolve())
        except ValueError:
            raise Http404 from None
        if candidate.is_file():
            content_type = None
            if path.endswith('.js'):
                content_type = 'application/javascript'
            elif path.endswith('.css'):
                content_type = 'text/css'
            return FileResponse(open(candidate, 'rb'), content_type=content_type)

    if not index.is_file():
        raise Http404(
            'Админка сохта нашудааст. Аввал: cd admin-panel && npm install && npm run build',
        )
    return FileResponse(open(index, 'rb'), content_type='text/html')
