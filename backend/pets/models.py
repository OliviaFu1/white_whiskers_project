from django.db import models
from django.conf import settings

class Pet(models.Model):
    class Species(models.TextChoices):
        # constant name = database value, display label
        CAT = "cat", "Cat"
        DOG = "dog", "Dog"

    class Sex(models.TextChoices):
        MALE = "male", "Male"
        FEMALE = "female", "Female"
        UNKNOWN = "unknown", "Unknown"

    name = models.CharField(max_length=100)
    photo_url = models.URLField(blank=True)

    species = models.CharField(max_length=10, choices=Species.choices)
    breed_text = models.CharField(max_length=100, blank=True)

    sex = models.CharField(max_length=10, choices=Sex.choices, default=Sex.UNKNOWN)
    spayed_neutered = models.BooleanField(null=True, blank=True)

    age_years = models.PositiveSmallIntegerField(null=True, blank=True)
    birthdate = models.DateField(null=True, blank=True)
    date_of_death = models.DateField(null=True, blank=True) # None if still alive

    weight_kg = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def is_deceased(self) -> bool:
        return self.date_of_death is not None

    def __str__(self):
        return f"{self.name} ({self.species})"


class PetUser(models.Model):
    class Role(models.TextChoices):
        OWNER = "owner", "Owner"
        FAMILY = "family", "Family"

    pet = models.ForeignKey(Pet, on_delete=models.CASCADE)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)

    role = models.CharField(max_length=10, choices=Role.choices)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["pet", "user"], name="uniq_pet_user")
        ]

    def __str__(self):
        return f"{self.user} ↔ {self.pet} ({self.role})"