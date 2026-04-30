from django.db import migrations
import secrets
import string


def generate_pet_code(length=8):
    alphabet = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def backfill_pet_share_codes(apps, schema_editor):
    Pet = apps.get_model("pets", "Pet")

    used_codes = set(
        Pet.objects.exclude(share_code__isnull=True)
        .exclude(share_code="")
        .values_list("share_code", flat=True)
    )

    for pet in Pet.objects.filter(share_code__isnull=True):
        code = generate_pet_code()
        while code in used_codes or Pet.objects.filter(share_code=code).exists():
            code = generate_pet_code()

        pet.share_code = code
        pet.save(update_fields=["share_code"])
        used_codes.add(code)


class Migration(migrations.Migration):

    dependencies = [
        ("pets", "0007_pet_share_code"),
    ]

    operations = [
        migrations.RunPython(backfill_pet_share_codes, migrations.RunPython.noop),
    ]