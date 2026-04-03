# Generated manually — iOS App Store IAP

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('books', '0009_merge_20260124_1619'),
    ]

    operations = [
        migrations.AddField(
            model_name='subscriptionplan',
            name='apple_product_id',
            field=models.CharField(
                blank=True,
                default='',
                max_length=128,
                verbose_name='Apple IAP Product ID',
                help_text='Дар App Store Connect сохта мешавад (мисли com.bundle.sub.week)',
            ),
        ),
        migrations.CreateModel(
            name='AppleStoreTransaction',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('transaction_id', models.CharField(db_index=True, max_length=128, unique=True)),
                ('original_transaction_id', models.CharField(blank=True, default='', max_length=128)),
                ('product_id', models.CharField(blank=True, default='', max_length=128)),
                ('raw_payload', models.JSONField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('plan', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='apple_transactions', to='books.subscriptionplan')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='apple_transactions', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Apple IAP транзаксия',
                'verbose_name_plural': 'Apple IAP транзаксияҳо',
                'ordering': ['-created_at'],
            },
        ),
    ]
