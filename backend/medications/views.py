import datetime as dt
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from django.db.models.functions import Coalesce, TruncDate
from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from pets.models import Pet
from notifications.models import Notification, NotificationType
from .models import Medication, MedicationPrescription, MedicationLog
from .serializers import (
    MedicationSerializer,
    MedicationCreateSerializer,
    MedicationPrescriptionSerializer,
    MedicationLogSerializer,
)


def _count_elapsed_doses(schedule, since, until, user_tz=dt.timezone.utc):
    """Return the number of scheduled doses that fell between *since* and *until*.

    *since* and *until* must be timezone-aware UTC datetimes.
    *user_tz* is the user's local timezone so that stored local times
    (time_of_day) are interpreted correctly rather than as UTC.
    """
    schedule_type = schedule.schedule_type

    if schedule_type == "interval":
        interval_hours = schedule.interval_hours or 1
        hours_elapsed = (until - since).total_seconds() / 3600
        return int(hours_elapsed // interval_hours)

    elif schedule_type == "fixed_times":
        time_of_day = schedule.time_of_day  # stored in user's local time
        count = 0
        # Iterate over dates in the user's local timezone.
        since_local = since.astimezone(user_tz)
        until_local = until.astimezone(user_tz)
        check_date = since_local.date()
        while check_date <= until_local.date():
            dose_time = time_of_day if time_of_day is not None else dt.time(0, 0)
            # Build an aware datetime in the user's timezone.
            scheduled_dt = dt.datetime.combine(check_date, dose_time, tzinfo=user_tz)
            if since < scheduled_dt <= until:
                count += 1
            check_date += dt.timedelta(days=1)
        return count

    elif schedule_type == "weekly":
        days_of_week = schedule.days_of_week or []
        if not days_of_week:
            return 0
        day_map = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}
        target_days = {day_map[d.lower()] for d in days_of_week if d.lower() in day_map}
        dose_time = schedule.time_of_day if schedule.time_of_day is not None else dt.time(0, 0)
        count = 0
        since_local = since.astimezone(user_tz)
        until_local = until.astimezone(user_tz)
        check_date = since_local.date()
        while check_date <= until_local.date():
            if check_date.weekday() in target_days:
                scheduled_dt = dt.datetime.combine(check_date, dose_time, tzinfo=user_tz)
                if since < scheduled_dt <= until:
                    count += 1
            check_date += dt.timedelta(days=1)
        return count

    return 0


class MedicationViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = (
            Medication.objects.filter(pet__petuser__user=self.request.user)
            .distinct()
            .prefetch_related("schedules", "prescriptions")
            .order_by("-created_at")
        )
        pet_id = self.request.query_params.get("pet_id")
        if pet_id:
            qs = qs.filter(pet_id=pet_id)
        return qs

    def get_serializer_class(self):
        if self.request.method in ("POST", "PUT", "PATCH"):
            return MedicationCreateSerializer
        return MedicationSerializer

    def perform_create(self, serializer):
        pet_id = self.request.data.get("pet_id")
        pet = Pet.objects.filter(
            pk=pet_id,
            petuser__user=self.request.user,
        ).first()
        if pet is None:
            raise PermissionDenied("Pet not found or not yours.")
        serializer.save(pet=pet)

    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        old_status = instance.status
        event_date = request.data.get("event_date") or None
        log_notes = request.data.get("log_notes", "")
        response = super().partial_update(request, *args, **kwargs)
        instance.refresh_from_db()
        new_status = instance.status
        if old_status != new_status:
            MedicationLog.objects.create(
                medication=instance,
                event_type=MedicationLog.EventType.STATUS_CHANGE,
                old_status=old_status,
                new_status=new_status,
                event_date=event_date,
                notes=log_notes,
            )
            # When reactivating, stamp the prescription cursor to now so that
            # process-due-doses doesn't backfill notifications or supply
            # deductions for doses that elapsed while the medication was inactive.
            if old_status != "active" and new_status == "active":
                prescription = instance.prescriptions.order_by("-created_at").first()
                if prescription:
                    MedicationPrescription.objects.filter(pk=prescription.pk).update(
                        last_dose_logged_at=timezone.now()
                    )
        return response

    @action(detail=True, methods=["get"], url_path="logs")
    def logs(self, request, pk=None):
        medication = self.get_object()
        qs = medication.logs.annotate(
            effective_date=Coalesce("event_date", TruncDate("timestamp"))
        ).order_by("-effective_date", "-timestamp")
        return Response(MedicationLogSerializer(qs, many=True).data)

    @action(detail=False, methods=["post"], url_path="process-due-doses")
    def process_due_doses(self, request):
        """
        For each active medication with a schedule:
          1. Create an in-app notification if a dose is due today (deduplicated per day).
          2. Decrement quantity_remaining on active prescriptions where supply exists.
        Pass pet_id in the request body.
        """
        pet_id = request.data.get("pet_id") or request.query_params.get("pet_id")
        if not pet_id:
            return Response({"error": "pet_id required"}, status=status.HTTP_400_BAD_REQUEST)

        tz_name = request.data.get("timezone") or "UTC"
        try:
            user_tz = ZoneInfo(tz_name)
        except (ZoneInfoNotFoundError, Exception):
            user_tz = dt.timezone.utc

        now = timezone.now()
        today = now.astimezone(user_tz).date()
        midnight_local = dt.datetime.combine(today, dt.time(0, 0), tzinfo=user_tz)
        updated_count = 0

        # If the client supplies an ignore_before timestamp (UTC ISO-8601), use
        # max(midnight_local, ignore_before) as the effective start so that doses
        # which elapsed while notifications were disabled are not back-filled.
        ignore_before_str = request.data.get("ignore_before")
        if ignore_before_str:
            try:
                ignore_before_utc = dt.datetime.fromisoformat(ignore_before_str)
                if ignore_before_utc.tzinfo is None:
                    ignore_before_utc = ignore_before_utc.replace(tzinfo=dt.timezone.utc)
                effective_since = max(midnight_local, ignore_before_utc.astimezone(user_tz))
            except (ValueError, Exception):
                effective_since = midnight_local
        else:
            effective_since = midnight_local

        meds = Medication.objects.filter(
            pet_id=pet_id,
            pet__petuser__user=request.user,
            status="active",
        ).select_related("pet").prefetch_related("schedules", "prescriptions")

        # Pre-fetch already-created medication notification counts since
        # effective_since so we can allow one in-app notification per elapsed
        # dose rather than just one per message per day.
        effective_since_utc = effective_since.astimezone(dt.timezone.utc).replace(tzinfo=dt.timezone.utc)
        existing_counts: dict[str, int] = {}
        for msg in Notification.objects.filter(
            user=request.user,
            pet_id=pet_id,
            notification_type=NotificationType.MEDICATION,
            created_at__gte=effective_since_utc,
        ).values_list("message", flat=True):
            existing_counts[msg] = existing_counts.get(msg, 0) + 1

        for med in meds:
            schedules = [s for s in med.schedules.all() if s.active]
            if not schedules:
                continue

            # Fetch prescription early so its cursor can gate notifications.
            prescription = med.prescriptions.order_by("-created_at").first()

            # Use the prescription's dose cursor as the notification baseline when
            # set (i.e. after reactivation it is stamped to now), so doses that
            # elapsed before the medication was (re)activated are never notified.
            if prescription is not None and prescription.last_dose_logged_at is not None:
                notif_since = max(effective_since, prescription.last_dose_logged_at)
            else:
                notif_since = effective_since

            # --- In-app notifications — one notification per schedule per elapsed dose ---
            for schedule in schedules:
                doses_elapsed = _count_elapsed_doses(schedule, notif_since, now, user_tz)
                if doses_elapsed <= 0:
                    continue

                # Include clock time in the message so each time slot produces
                # a distinct message (supporting multiple daily doses and
                # re-firing correctly after the schedule time is edited).
                if schedule.time_of_day:
                    t = schedule.time_of_day
                    hour = t.hour % 12 or 12
                    ampm = "AM" if t.hour < 12 else "PM"
                    time_label = f"{hour}:{t.minute:02d} {ampm}"
                    msg = f"Time to give **{med.drug_name}** to **{med.pet.name}** at {time_label}."
                else:
                    msg = f"Time to give **{med.drug_name}** to **{med.pet.name}**."

                already_sent = existing_counts.get(msg, 0)
                to_create = doses_elapsed - already_sent
                for _ in range(to_create):
                    Notification.objects.create(
                        user=request.user,
                        pet=med.pet,
                        title="Medication reminder",
                        message=msg,
                        notification_type=NotificationType.MEDICATION,
                    )
                    existing_counts[msg] = existing_counts.get(msg, 0) + 1

            # --- Prescription supply deduction ---
            if prescription is None:
                continue
            if prescription.quantity_remaining is None or prescription.quantity_remaining <= 0:
                continue

            # On first call, start the cursor from local midnight today so any
            # dose that already passed today is counted immediately.
            if prescription.last_dose_logged_at is None:
                since = midnight_local
            else:
                since = prescription.last_dose_logged_at

            # Sum elapsed doses across ALL active schedules since the cursor.
            elapsed = sum(
                _count_elapsed_doses(s, since, now, user_tz) for s in schedules
            )
            # --- Refill in-app notification (≤ 7 days until expiration) ---
            if prescription.expiration_date is not None:
                days_left = (prescription.expiration_date - today).days
                if 0 <= days_left <= 7:
                    day_word = "day" if days_left == 1 else "days"
                    refill_msg = (
                        f"**{med.drug_name}** for **{med.pet.name}** "
                        f"runs out in {days_left} {day_word}. Time to request a refill!"
                    )
                    if existing_counts.get(refill_msg, 0) == 0:
                        Notification.objects.create(
                            user=request.user,
                            pet=med.pet,
                            title="Refill reminder",
                            message=refill_msg,
                            notification_type=NotificationType.MEDICATION,
                        )
                        existing_counts[refill_msg] = 1

            if elapsed <= 0:
                # No doses due yet — only persist the cursor on first init so
                # subsequent calls don't recompute from midnight every time.
                if prescription.last_dose_logged_at is None:
                    MedicationPrescription.objects.filter(pk=prescription.pk).update(
                        last_dose_logged_at=since
                    )
                continue

            deduction = med.dose_amount * elapsed
            new_remaining = max(0, prescription.quantity_remaining - deduction)

            # For a single interval schedule advance the cursor by exactly the
            # elapsed intervals so the rhythm stays consistent.  For all other
            # cases (fixed_times, weekly, or mixed) just stamp 'now'.
            if len(schedules) == 1 and schedules[0].schedule_type == "interval":
                interval_hours = schedules[0].interval_hours or 1
                new_cursor = since + dt.timedelta(
                    hours=int(elapsed) * interval_hours
                )
            else:
                new_cursor = now

            MedicationPrescription.objects.filter(pk=prescription.pk).update(
                quantity_remaining=new_remaining,
                last_dose_logged_at=new_cursor,
            )
            updated_count += 1

            # Auto-complete the medication when supply is exhausted and no
            # refills remain.
            if new_remaining == 0:
                refills_left = (
                    (prescription.refills_authorized or 0)
                    - (prescription.refills_used or 0)
                )
                if refills_left <= 0:
                    Medication.objects.filter(pk=med.pk).update(status="completed")

        return Response({"updated": updated_count})

    @action(detail=True, methods=["get", "post"], url_path="prescriptions")
    def prescriptions(self, request, pk=None):
        medication = self.get_object()

        if request.method == "GET":
            qs = medication.prescriptions.order_by("-created_at")
            serializer = MedicationPrescriptionSerializer(qs, many=True)
            return Response(serializer.data)

        # POST — create a new prescription for this medication
        serializer = MedicationPrescriptionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(medication=medication)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class PrescriptionViewSet(viewsets.ModelViewSet):
    """
    Standalone viewset for individual prescription operations (retrieve/update/delete).
    List and create go through MedicationViewSet.prescriptions action instead.
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MedicationPrescriptionSerializer
    # Only expose detail endpoints — list/create are on the medication nested action
    http_method_names = ["get", "patch", "delete", "head", "options"]

    def get_queryset(self):
        return MedicationPrescription.objects.filter(
            medication__pet__petuser__user=self.request.user
        )

    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        old_refills = instance.refills_used
        response = super().partial_update(request, *args, **kwargs)
        instance.refresh_from_db()
        if instance.refills_used > old_refills:
            MedicationLog.objects.create(
                medication=instance.medication,
                event_type=MedicationLog.EventType.REFILL,
                old_status=instance.medication.status,
                new_status=instance.medication.status,
            )
        return response


class MedicationLogViewSet(viewsets.GenericViewSet):
    """
    Exposes PATCH and DELETE /api/medications/logs/{id}/.
    Only the medication's owner may access.
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = MedicationLogSerializer
    http_method_names = ["patch", "delete", "head", "options"]

    def get_queryset(self):
        return MedicationLog.objects.filter(
            medication__pet__petuser__user=self.request.user
        )

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        notes = request.data.get("notes", "")
        instance.notes = notes
        instance.save(update_fields=["notes"])
        return Response(MedicationLogSerializer(instance).data)
