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
    photo_url = models.URLField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    def __str__(self):
        return self.email