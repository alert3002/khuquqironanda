from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0003_alter_aboutpage_content'),
    ]

    operations = [
        migrations.AddField(
            model_name='transaction',
            name='invoice_uuid',
            field=models.CharField(
                blank=True,
                default='',
                max_length=64,
                verbose_name='SmartPay invoice UUID',
            ),
        ),
        migrations.AddField(
            model_name='transaction',
            name='payment_provider',
            field=models.CharField(
                blank=True,
                default='',
                max_length=32,
                verbose_name='Провайдери пардохт',
            ),
        ),
    ]
