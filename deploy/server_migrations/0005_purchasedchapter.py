# Барои сервер: books.payvandtrans.com
# Нусба ба: books/migrations/0005_purchasedchapter.py
# Пас: python manage.py migrate books

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0004_transaction_smartpay_fields'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='PurchasedChapter',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('purchased_at', models.DateTimeField(auto_now_add=True, verbose_name='Вақти харид')),
                ('price_paid', models.DecimalField(decimal_places=2, max_digits=10, verbose_name='Нархи пардохташуда')),
                ('chapter', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='purchases', to='books.chapter', verbose_name='Боб')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='purchased_chapters', to=settings.AUTH_USER_MODEL, verbose_name='Корбар')),
            ],
            options={
                'verbose_name': 'Боби харидашуда',
                'verbose_name_plural': 'Бобҳои харидашуда',
                'ordering': ['-purchased_at'],
                'unique_together': {('user', 'chapter')},
            },
        ),
    ]
