# Sync production SQLite schema with current models (legacy DB had migrations 0002–0012 without files)

import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name='subscriptionplan',
            name='is_active',
            field=models.BooleanField(default=True, verbose_name='Фаъол'),
        ),
        migrations.AddField(
            model_name='subscriptionplan',
            name='apple_product_id',
            field=models.CharField(
                blank=True,
                default='',
                help_text='Дар App Store Connect → In‑App Purchases Product ID (бо plan мепайвандад)',
                max_length=128,
                verbose_name='Apple IAP Product ID',
            ),
        ),
        migrations.AddField(
            model_name='subscriptionplan',
            name='created_at',
            field=models.DateTimeField(
                auto_now_add=True,
                default=django.utils.timezone.now,
            ),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='subscriptionplan',
            name='updated_at',
            field=models.DateTimeField(auto_now=True),
        ),
        migrations.AlterField(
            model_name='subscriptionplan',
            name='name',
            field=models.CharField(max_length=255, verbose_name='Номи нақша'),
        ),
        migrations.CreateModel(
            name='Subscription',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('purchased_at', models.DateTimeField(auto_now_add=True, verbose_name='Вақти харид')),
                ('expires_at', models.DateTimeField(verbose_name='Муҳлати анҷом')),
                ('plan', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='subscriptions', to='books.subscriptionplan', verbose_name='Нақша')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='subscriptions', to=settings.AUTH_USER_MODEL, verbose_name='Корбар')),
            ],
            options={
                'verbose_name': 'Обуна',
                'verbose_name_plural': 'Обунаҳо',
                'ordering': ['-purchased_at'],
            },
        ),
        migrations.CreateModel(
            name='AppleStoreTransaction',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('transaction_id', models.CharField(db_index=True, max_length=128, unique=True, verbose_name='Transaction ID')),
                ('original_transaction_id', models.CharField(blank=True, default='', max_length=128, verbose_name='Original transaction ID')),
                ('product_id', models.CharField(blank=True, default='', max_length=128, verbose_name='Product ID')),
                ('raw_payload', models.JSONField(blank=True, null=True, verbose_name='JWS payload (decoded)')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('plan', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='apple_transactions', to='books.subscriptionplan', verbose_name='Нақша')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='apple_transactions', to=settings.AUTH_USER_MODEL, verbose_name='Корбар')),
            ],
            options={
                'verbose_name': 'Apple IAP транзаксия',
                'verbose_name_plural': 'Apple IAP транзаксияҳо',
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='LegalDocument',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('order', models.PositiveIntegerField(default=1, verbose_name='№ дар рӯйхат')),
                ('title', models.CharField(max_length=500, verbose_name='Сарлавҳа')),
                ('pdf_file', models.FileField(blank=True, null=True, upload_to='legal_documents/', verbose_name='Файли PDF')),
                ('pdf_url', models.URLField(blank=True, help_text='Агар файл бор накунед, истифода баред: https://.../file.pdf', verbose_name='Ссылкаи PDF (URL)')),
                ('is_active', models.BooleanField(default=True, verbose_name='Фаъол')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Санади меъёрию ҳуқуқӣ',
                'verbose_name_plural': 'Санадҳои меъёрию ҳуқуқӣ (Қоидаҳои ҳаракат дар роҳ)',
                'ordering': ['order', 'id'],
            },
        ),
        migrations.CreateModel(
            name='AboutPage',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(default='Дар бораи мо', max_length=200, verbose_name='Сарлавҳа')),
                ('content', models.TextField(blank=True, verbose_name='Матн')),
                ('phone', models.CharField(blank=True, max_length=50, verbose_name='Телефон')),
                ('email', models.EmailField(blank=True, max_length=254, verbose_name='Email')),
                ('telegram_url', models.URLField(blank=True, verbose_name='Telegram')),
                ('whatsapp_url', models.URLField(blank=True, verbose_name='WhatsApp')),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Дар бораи мо',
                'verbose_name_plural': 'Дар бораи мо',
            },
        ),
    ]
