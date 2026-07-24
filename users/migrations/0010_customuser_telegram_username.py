from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0009_alter_customuser_telegram_id'),
    ]

    operations = [
        migrations.AddField(
            model_name='customuser',
            name='telegram_username',
            field=models.CharField(
                blank=True,
                default='',
                max_length=64,
                verbose_name='Telegram @username',
            ),
        ),
    ]
