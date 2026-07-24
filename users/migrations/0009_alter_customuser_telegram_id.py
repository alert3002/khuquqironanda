# Telegram OIDC sub — CharField (SQLite INTEGER overflow барои sub-и калон)

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0008_alter_customuser_id_alter_phoneotp_id'),
    ]

    operations = [
        migrations.AlterField(
            model_name='customuser',
            name='telegram_id',
            field=models.CharField(
                blank=True,
                max_length=32,
                null=True,
                unique=True,
                verbose_name='Telegram ID',
            ),
        ),
    ]
