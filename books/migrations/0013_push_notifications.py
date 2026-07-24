# Generated manually for PushNotification + DevicePushToken

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('books', '0012_aboutpage_purchase_guide'),
    ]

    operations = [
        migrations.CreateModel(
            name='PushNotification',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=200, verbose_name='Сарлавҳа')),
                ('body', models.TextField(verbose_name='Матн')),
                ('is_sent', models.BooleanField(default=False, verbose_name='Фиристода шуд')),
                ('sent_at', models.DateTimeField(blank=True, null=True, verbose_name='Вақти фиристодан')),
                ('created_at', models.DateTimeField(auto_now_add=True, verbose_name='Эҷод шуд')),
                ('fcm_success', models.PositiveIntegerField(default=0, verbose_name='FCM муваффақ')),
                ('fcm_failure', models.PositiveIntegerField(default=0, verbose_name='FCM номуваффақ')),
            ],
            options={
                'verbose_name': 'Огоҳӣ (Push)',
                'verbose_name_plural': 'Огоҳиҳо (Push)',
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='DevicePushToken',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('token', models.CharField(max_length=512, unique=True, verbose_name='FCM Token')),
                ('platform', models.CharField(choices=[('android', 'Android'), ('ios', 'iOS'), ('other', 'Дигар')], default='android', max_length=16, verbose_name='Платформа')),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='push_tokens', to=settings.AUTH_USER_MODEL, verbose_name='Корбар')),
            ],
            options={
                'verbose_name': 'Токени push',
                'verbose_name_plural': 'Токенҳои push',
            },
        ),
    ]
