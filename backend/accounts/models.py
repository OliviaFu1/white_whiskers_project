from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    """
    Custom User: uses email as the login identifier, removes username.
    Hashed password in `password` field.
    """
    username = None
    email = models.EmailField(unique=True)

    name = models.CharField(max_length=150, blank=True)
    photo = models.ImageField(upload_to='profile_photos/', blank=True, null=True)
    location = models.CharField(max_length=150, blank=True)

    # Primary vet information
    primary_clinic = models.CharField(max_length=255, blank=True)
    primary_vet_name = models.CharField(max_length=255, blank=True)
    primary_vet_email = models.EmailField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    def __str__(self):
        return self.email


class UserSpecialist(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="specialists",
    )
    clinic_name = models.CharField(max_length=255, blank=True)
    vet_name = models.CharField(max_length=255)
    vet_email = models.EmailField(blank=True)
    specialty = models.CharField(max_length=255, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.vet_name} ({self.user.email})"