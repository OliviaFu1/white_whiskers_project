from django.conf import settings
from django.db import models
from django.utils import timezone


class DailyCheckin(models.Model):
    class DayRating(models.TextChoices):
        GOOD = "good", "Good"
        NEUTRAL = "neutral", "Neutral"
        BAD = "bad", "Bad"

    pet = models.ForeignKey(
        "pets.Pet",
        on_delete=models.CASCADE,
        related_name="daily_checkins",
        db_index=True,
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="daily_checkins",
        db_index=True,
    )

    checkin_date = models.DateField(db_index=True)
    day_rating = models.CharField(
        max_length=16,
        choices=DayRating.choices,
        default=DayRating.NEUTRAL,
    )
    notes = models.TextField(blank=True, default="")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["pet", "checkin_date"]),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=["pet", "author", "checkin_date"],
                name="uniq_checkin_per_pet_author_day",
            )
        ]
        ordering = ["-checkin_date", "-created_at"]


class JournalEntry(models.Model):
    class Visibility(models.TextChoices):
        SHARED = "shared", "Shared"
        PRIVATE = "private", "Private"

    class Tag(models.TextChoices):
        FOOD = "food", "Food"
        SLEEP = "sleep", "Sleep"
        MED = "med", "Medication"
        SYMPTOMS = "symptoms", "Symptoms"

    pet = models.ForeignKey(
        "pets.Pet",
        on_delete=models.CASCADE,
        related_name="journal_entries",
        db_index=True,
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="journal_entries",
        db_index=True,
    )

    entry_date = models.DateField()
    title = models.CharField(max_length=200, blank=True, default="")
    text = models.TextField(blank=True, default="")
    photo_url = models.URLField(blank=True, default="")

    visibility = models.CharField(
        max_length=16,
        choices=Visibility.choices,
        default=Visibility.SHARED,
        db_index=True,
    )
    tag = models.CharField(
        max_length=16,
        choices=Tag.choices,
        blank=True,
        default="",
        db_index=True,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["pet", "entry_date"]),
            models.Index(fields=["visibility", "entry_date"]),
        ]
        ordering = ["-entry_date", "-created_at"]