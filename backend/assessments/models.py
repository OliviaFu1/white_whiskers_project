from django.conf import settings
from django.db import models


class PetAssessment(models.Model):
    pet = models.ForeignKey(
        "pets.Pet",
        on_delete=models.CASCADE,
        related_name="assessments",
    )
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="assessments",
    )

    # Full raw answers from frontend
    answers = models.JSONField(default=dict, blank=True)

    # Calculated outputs
    heart_score = models.IntegerField()
    condition_score = models.IntegerField()
    significantly_challenged = models.BooleanField(default=False)

    submitted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-submitted_at"]

    def __str__(self):
        return f"Assessment for pet_id={self.pet_id} at {self.submitted_at:%Y-%m-%d %H:%M}"