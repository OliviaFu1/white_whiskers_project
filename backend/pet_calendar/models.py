from django.conf import settings
from django.core.validators import RegexValidator
from django.db import models


hex_color_validator = RegexValidator(
    regex=r"^#[0-9A-Fa-f]{6}$",
    message="Color must be a valid hex code like #917869.",
)


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


class JournalTag(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="journal_tags",
        db_index=True,
    )
    name = models.CharField(max_length=32)
    color = models.CharField(
        max_length=7,
        default="#917869",
        validators=[hex_color_validator],
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "name"],
                name="unique_journal_tag_per_user",
            )
        ]

    def save(self, *args, **kwargs):
        if self.name:
            self.name = self.name.strip().lower()
        if self.color:
            self.color = self.color.strip()
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name


class JournalEntry(models.Model):
    class Visibility(models.TextChoices):
        SHARED = "shared", "Shared"
        PRIVATE = "private", "Private"

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

    entry_date = models.DateField(db_index=True)
    title = models.CharField(max_length=200, blank=True, default="")
    text = models.TextField(blank=True, default="")
    photo_url = models.URLField(blank=True, default="")

    visibility = models.CharField(
        max_length=16,
        choices=Visibility.choices,
        default=Visibility.SHARED,
        db_index=True,
    )

    tags = models.ManyToManyField(
        "JournalTag",
        related_name="journal_entries",
        blank=True,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["pet", "entry_date"]),
            models.Index(fields=["visibility", "entry_date"]),
        ]
        ordering = ["-entry_date", "-created_at"]