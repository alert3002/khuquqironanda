# Сервер: books/migrations/0006_ensure_purchasedchapter_table.py

from django.db import migrations, connection


def create_purchasedchapter_table(apps, schema_editor):
    table = 'books_purchasedchapter'
    with connection.cursor() as cursor:
        if connection.vendor == 'sqlite':
            # Django SQLite uses %s placeholders, not ?
            cursor.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=%s",
                [table],
            )
            if cursor.fetchone():
                return
            cursor.execute(
                """
                CREATE TABLE books_purchasedchapter (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    purchased_at datetime NOT NULL,
                    price_paid decimal NOT NULL,
                    chapter_id bigint NOT NULL REFERENCES books_chapter(id)
                        DEFERRABLE INITIALLY DEFERRED,
                    user_id bigint NOT NULL REFERENCES users_customuser(id)
                        DEFERRABLE INITIALLY DEFERRED,
                    UNIQUE (user_id, chapter_id)
                )
                """
            )
            return
        PurchasedChapter = apps.get_model('books', 'PurchasedChapter')
        if PurchasedChapter._meta.db_table in connection.introspection.table_names():
            return
        schema_editor.create_model(PurchasedChapter)


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0005_sync_missing_models'),
    ]

    operations = [
        migrations.RunPython(create_purchasedchapter_table, migrations.RunPython.noop),
    ]
