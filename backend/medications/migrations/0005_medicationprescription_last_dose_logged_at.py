from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("medications", "0004_medication_prescribing_vet_clinic"),
    ]

    operations = [
        migrations.AddField(
            model_name="medicationprescription",
            name="last_dose_logged_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
