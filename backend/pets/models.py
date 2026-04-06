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
    photo = models.ImageField(upload_to='pet_photos/', blank=True, null=True)

    species = models.CharField(max_length=10, choices=Species.choices)
    breed_text = models.CharField(max_length=100, blank=True)

    sex = models.CharField(max_length=10, choices=Sex.choices, default=Sex.UNKNOWN)
    spayed_neutered = models.BooleanField(null=True, blank=True)

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


class PetInvite(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        ACCEPTED = "accepted", "Accepted"
        DECLINED = "declined", "Declined"

    pet = models.ForeignKey(
        Pet,
        on_delete=models.CASCADE,
        related_name="invites",
    )
    inviter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sent_pet_invites",
    )
    invitee_email = models.EmailField(db_index=True)
    invitee_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="received_pet_invites",
    )
    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["pet", "invitee_email", "status"],
                name="uniq_pending_pet_invite_per_email",
                condition=models.Q(status="pending"),
            )
        ]

    def __str__(self):
        return f"{self.invitee_email} invited to {self.pet} ({self.status})"