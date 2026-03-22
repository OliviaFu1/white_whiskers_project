from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("pets", "0002_pet_age_years_pet_spayed_neutered"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="pet",
            name="photo_url",
        ),
        migrations.AddField(
            model_name="pet",
            name="photo",
            field=models.ImageField(blank=True, null=True, upload_to="pet_photos/"),
        ),
    ]
