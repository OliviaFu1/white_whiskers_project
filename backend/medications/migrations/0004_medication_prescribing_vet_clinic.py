from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("medications", "0003_medication_form_description"),
    ]

    operations = [
        migrations.AddField(
            model_name="medication",
            name="prescribing_vet_clinic",
            field=models.CharField(blank=True, max_length=200, null=True),
        ),
    ]
