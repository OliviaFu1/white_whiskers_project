from django.contrib.postgres.fields import ArrayField
from django.core.exceptions import ValidationError
from django.db import models


class Medication(models.Model):
    class Form(models.TextChoices):
        TABLET = "tablet", "Tablet"
        CAPSULE = "capsule", "Capsule"
        LIQUID = "liquid", "Liquid"
        INJECTION = "injection", "Injection"
        TOPICAL = "topical", "Topical"
        OTHER = "other", "Other"

    class Route(models.TextChoices):
        ORAL = "oral", "Oral"
        TOPICAL = "topical", "Topical"
        OPHTHALMIC = "ophthalmic", "Ophthalmic"
        OTIC = "otic", "Otic"
        INHALED = "inhaled", "Inhaled"
        INJECTABLE = "injectable", "Injectable"
        OTHER = "other", "Other"

    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        PAUSED = "paused", "Paused"
        STOPPED = "stopped", "Stopped"
        COMPLETED = "completed", "Completed"

    # medication_id is the implicit Django auto pk

    pet = models.ForeignKey(
        "pets.Pet",
        on_delete=models.CASCADE,
        related_name="medications",
        db_index=True,
    )

    # Drug identification
    drug_name = models.CharField(max_length=200)
    generic_name = models.CharField(max_length=200, blank=True, null=True)
    brand_name = models.CharField(max_length=200, blank=True, null=True)

    # Form & route
    form = models.CharField(max_length=50, choices=Form.choices)
    route = models.CharField(max_length=50, choices=Route.choices)
    # Free-text description used when form/route = "other"
    form_description = models.CharField(max_length=200, blank=True)

    # Strength (e.g. 500 mg)
    strength_value = models.DecimalField(max_digits=10, decimal_places=4, blank=True, null=True)
    strength_unit = models.CharField(max_length=20, blank=True, null=True)

    # Concentration for liquids (e.g. 50 mg/ml)
    concentration_value = models.DecimalField(max_digits=10, decimal_places=4, blank=True, null=True)
    concentration_unit = models.CharField(max_length=20, blank=True, null=True)

    # Dosing
    dose_amount = models.DecimalField(max_digits=10, decimal_places=4)
    dose_unit = models.CharField(max_length=50)
    sig_text = models.TextField()

    # Clinical context
    reason_for_use = models.CharField(max_length=500, blank=True, null=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)

    # Schedule dates
    start_date = models.DateField()
    end_date = models.DateField(blank=True, null=True)

    # PRN / limits
    as_needed = models.BooleanField(default=False)
    max_doses_per_day = models.PositiveSmallIntegerField(blank=True, null=True)

    # Administration notes
    with_food = models.BooleanField(blank=True, null=True)

    # Prescriber
    prescribing_vet_name = models.CharField(max_length=200, blank=True, null=True)
    prescribing_vet_clinic = models.CharField(max_length=200, blank=True, null=True)

    # Reminders
    reminders_enabled = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["pet"]),
        ]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.drug_name} for pet_id={self.pet_id} ({self.status})"


class MedicationSchedule(models.Model):
    class ScheduleType(models.TextChoices):
        FIXED_TIMES = "fixed_times", "Fixed Times"
        INTERVAL = "interval", "Interval"
        WEEKLY = "weekly", "Weekly"
        CUSTOM = "custom", "Custom"

    # schedule_id is the implicit Django auto pk

    medication = models.ForeignKey(
        Medication,
        on_delete=models.CASCADE,
        related_name="schedules",
        db_index=True,
    )

    schedule_type = models.CharField(max_length=20, choices=ScheduleType.choices)

    # Fixed-times schedule: specific time each day
    time_of_day = models.TimeField(blank=True, null=True)

    # Weekly schedule: which days of the week
    days_of_week = ArrayField(
        models.CharField(max_length=3),
        blank=True,
        null=True,
        help_text='e.g. ["mon","wed","fri"]',
    )

    # Interval schedule: every N hours
    interval_hours = models.PositiveSmallIntegerField(blank=True, null=True)

    active = models.BooleanField(default=True)

    class Meta:
        indexes = [
            models.Index(fields=["medication"]),
        ]
        constraints = [
            # interval schedules must have interval_hours
            models.CheckConstraint(
                condition=(
                    ~models.Q(schedule_type="interval") |
                    models.Q(interval_hours__isnull=False)
                ),
                name="ck_interval_requires_interval_hours",
            ),
            # fixed_times schedules must have time_of_day
            models.CheckConstraint(
                condition=(
                    ~models.Q(schedule_type="fixed_times") |
                    models.Q(time_of_day__isnull=False)
                ),
                name="ck_fixed_times_requires_time_of_day",
            ),
        ]

    def __str__(self):
        return f"Schedule({self.schedule_type}) for medication_id={self.medication_id}"


class MedicationPrescription(models.Model):
    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        COMPLETED = "completed", "Completed"
        EXPIRED = "expired", "Expired"

    medication = models.ForeignKey(
        Medication,
        on_delete=models.CASCADE,
        related_name="prescriptions",
        db_index=True,
    )

    # Supply
    quantity_total = models.DecimalField(max_digits=10, decimal_places=4)
    quantity_unit = models.CharField(max_length=50)
    quantity_remaining = models.DecimalField(max_digits=10, decimal_places=4)

    # Dose snapshot — intentionally duplicates Medication fields so prescription
    # history is accurate even if the medication dose changes later.
    dose_amount = models.DecimalField(max_digits=10, decimal_places=4)
    dose_unit = models.CharField(max_length=50)

    # Dates
    start_date = models.DateField()
    expiration_date = models.DateField(blank=True, null=True)

    # Refills
    refills_authorized = models.PositiveSmallIntegerField(default=0)
    refills_used = models.PositiveSmallIntegerField(default=0)

    # Prescribing info
    prescribing_vet_name = models.CharField(max_length=200, blank=True)
    notes = models.TextField(blank=True)

    # Status — not automatically derived; the application layer is responsible
    # for keeping this consistent with expiration_date and quantity_remaining.
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.ACTIVE,
    )

    # Tracks the last time doses were automatically deducted from quantity_remaining.
    # Null means tracking hasn't started yet; on first process_due_doses call it
    # is set to now() with 0 doses deducted (so we only count future doses).
    last_dose_logged_at = models.DateTimeField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["medication"]),
        ]
        ordering = ["-created_at"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(quantity_total__gt=0),
                name="ck_prescription_quantity_total_positive",
            ),
        ]

    def clean(self):
        if self.refills_used > self.refills_authorized:
            raise ValidationError(
                {"refills_used": "refills_used cannot exceed refills_authorized."}
            )

    def save(self, *args, **kwargs):
        # Default quantity_remaining to quantity_total on first save.
        if self.pk is None and self.quantity_remaining is None:
            self.quantity_remaining = self.quantity_total
        self.full_clean()
        super().save(*args, **kwargs)

    def calculate_total_doses(self):
        """
        Returns quantity_total / dose_amount.

        Assumes quantity_unit and dose_unit are compatible (e.g. both 'tablet'
        or both 'ml'). The caller is responsible for ensuring unit consistency
        before calling this method.
        """
        return self.quantity_total / self.dose_amount

    def __str__(self):
        return (
            f"Prescription({self.medication.drug_name}, "
            f"{self.quantity_total} {self.quantity_unit}, {self.status})"
        )


class MedicationLog(models.Model):
    class EventType(models.TextChoices):
        STATUS_CHANGE = "status_change"
        REFILL        = "refill"

    medication  = models.ForeignKey(Medication, on_delete=models.CASCADE, related_name="logs")
    event_type  = models.CharField(max_length=20, choices=EventType.choices)
    old_status  = models.CharField(max_length=20, blank=True, default="")
    new_status  = models.CharField(max_length=20, blank=True, default="")
    # Optional user-supplied date (e.g. when medication was actually paused/stopped).
    # Falls back to timestamp.date() when not set.
    event_date  = models.DateField(blank=True, null=True)
    notes       = models.TextField(blank=True, default="")
    timestamp   = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-timestamp"]
        indexes  = [models.Index(fields=["medication"])]
