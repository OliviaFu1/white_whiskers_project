from django.conf import settings
from django.db import models


class NotificationType(models.TextChoices):
    MEDICATION = "medication", "Medication"
    JOURNAL = "journal", "Journal"
    BIRTHDAY = "birthday", "Birthday"
    GENERAL = "general", "General"


class Notification(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )

    # Optional: link to pet if you want
    pet = models.ForeignKey(
        "pets.Pet",
        on_delete=models.CASCADE,
        related_name="notifications",
        null=True,
        blank=True,
    )

    title = models.CharField(max_length=200)
    message = models.TextField()

    notification_type = models.CharField(
        max_length=32,
        choices=NotificationType.choices,
        default=NotificationType.GENERAL,
    )

    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "is_read", "-created_at"]),
            models.Index(fields=["user", "-created_at"]),
        ]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user_id}: {self.title}"