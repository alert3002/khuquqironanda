from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0010_subscriptionplan_apple_product_id_applestoretransaction'),
    ]

    operations = [
        migrations.CreateModel(
            name='LegalDocument',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
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
    ]
