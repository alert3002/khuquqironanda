import os
import shutil

from django.conf import settings


def legal_document_filename(pdf_field_name: str) -> str:
    return os.path.basename(pdf_field_name.replace('\\', '/'))


def legal_document_disk_path(pdf_field_name: str) -> str:
    """Масири пурра дар диск: .../legal_documents/Document_xxx.pdf"""
    return os.path.join(
        settings.LEGAL_DOCUMENTS_ROOT,
        legal_document_filename(pdf_field_name),
    )


def legal_document_media_disk_path(pdf_field_name: str) -> str:
    """Масири файл дар MEDIA (пас аз боркунӣ дар админка)."""
    return os.path.join(
        settings.MEDIA_ROOT,
        'legal_documents',
        legal_document_filename(pdf_field_name),
    )


def resolve_legal_document_path(pdf_field_name: str) -> str | None:
    """Аввал LEGAL_DOCUMENTS_ROOT, баъд MEDIA/legal_documents/."""
    if not pdf_field_name:
        return None
    for path in (
        legal_document_disk_path(pdf_field_name),
        legal_document_media_disk_path(pdf_field_name),
    ):
        if os.path.isfile(path):
            return path
    return None


def legal_document_public_path(pdf_field_name: str) -> str:
    """URL-и оммавӣ: /legal_documents/Document_xxx.pdf"""
    return f'/legal_documents/{legal_document_filename(pdf_field_name)}'


def legal_document_media_url_path(pdf_field_name: str) -> str:
    """URL-и media: /media/legal_documents/Document_xxx.pdf"""
    return f'{settings.MEDIA_URL.rstrip("/")}/legal_documents/{legal_document_filename(pdf_field_name)}'


def sync_legal_document_file(pdf_field_name: str, source_path: str | None = None) -> str | None:
    """
    Нусхаи PDF-ро ба LEGAL_DOCUMENTS_ROOT мегузорад (барои /legal_documents/ URL).
    """
    if not pdf_field_name:
        return None
    dest = legal_document_disk_path(pdf_field_name)
    if os.path.isfile(dest):
        return dest

    src = source_path if source_path and os.path.isfile(source_path) else None
    if not src:
        media_path = legal_document_media_disk_path(pdf_field_name)
        if os.path.isfile(media_path):
            src = media_path
    if not src:
        return None

    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copy2(src, dest)
    return dest
