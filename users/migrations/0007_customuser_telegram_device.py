from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0006_alter_customuser_id_alter_phoneotp_id'),
    ]

    operations = [
        migrations.AlterField(
            model_name='customuser',
            name='phone',
            field=models.CharField(
                blank=True,
                max_length=15,
                null=True,
                unique=True,
                verbose_name='Рақами телефон',
            ),
        ),
        migrations.AddField(
            model_name='customuser',
            name='telegram_id',
            field=models.BigIntegerField(
                blank=True,
                null=True,
                unique=True,
                verbose_name='Telegram ID',
            ),
        ),
        migrations.AddField(
            model_name='customuser',
            name='device_id',
            field=models.CharField(
                blank=True,
                default='',
                max_length=255,
                verbose_name='Device ID (Flutter)',
            ),
        ),
    ]
