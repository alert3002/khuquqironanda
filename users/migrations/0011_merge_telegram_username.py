# Merge duplicate telegram_username migration branches

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0008_customuser_telegram_username'),
        ('users', '0010_customuser_telegram_username'),
    ]

    operations = []
