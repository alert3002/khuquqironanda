from django.db import migrations, models
import ckeditor_uploader.fields


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0011_legaldocument'),
    ]

    operations = [
        migrations.AddField(
            model_name='aboutpage',
            name='purchase_guide_title',
            field=models.CharField(
                blank=True,
                default='Чӣ тавр харидан мумкин аст',
                max_length=200,
                verbose_name='Сарлавҳаи дастурамал (харид)',
            ),
        ),
        migrations.AddField(
            model_name='aboutpage',
            name='purchase_guide_content',
            field=ckeditor_uploader.fields.RichTextUploadingField(
                blank=True,
                help_text='Қадамҳо барои хариди китоб/обуна. Дар барнома зери «Тарифҳо» намоиш дода мешавад.',
                verbose_name='Дастурамал: чӣ тавр харидан',
            ),
        ),
    ]
