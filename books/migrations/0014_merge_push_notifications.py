# Merge migration graph leaves for push notifications

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0007_ensure_subscriptionplan_chapters_table'),
        ('books', '0013_push_notifications'),
    ]

    operations = []
