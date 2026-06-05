# Сервер: books/migrations/0007_ensure_subscriptionplan_chapters_table.py
# M2M: SubscriptionPlan.chapters ↔ Chapter

from django.db import migrations, connection


def create_m2m_table(apps, schema_editor):
    table = 'books_subscriptionplan_chapters'
    with connection.cursor() as cursor:
        if connection.vendor == 'sqlite':
            cursor.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=%s",
                [table],
            )
            if cursor.fetchone():
                return
            cursor.execute(
                """
                CREATE TABLE books_subscriptionplan_chapters (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    subscriptionplan_id bigint NOT NULL REFERENCES books_subscriptionplan(id)
                        DEFERRABLE INITIALLY DEFERRED,
                    chapter_id bigint NOT NULL REFERENCES books_chapter(id)
                        DEFERRABLE INITIALLY DEFERRED,
                    UNIQUE (subscriptionplan_id, chapter_id)
                )
                """
            )
            cursor.execute(
                """
                CREATE INDEX IF NOT EXISTS books_subscriptionplan_chapters_subscriptionplan_id
                ON books_subscriptionplan_chapters (subscriptionplan_id)
                """
            )
            cursor.execute(
                """
                CREATE INDEX IF NOT EXISTS books_subscriptionplan_chapters_chapter_id
                ON books_subscriptionplan_chapters (chapter_id)
                """
            )
            return

        SubscriptionPlan = apps.get_model('books', 'SubscriptionPlan')
        through = SubscriptionPlan.chapters.through
        if through._meta.db_table in connection.introspection.table_names():
            return
        schema_editor.create_model(through)


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0006_ensure_purchasedchapter_table'),
    ]

    operations = [
        migrations.RunPython(create_m2m_table, migrations.RunPython.noop),
    ]
