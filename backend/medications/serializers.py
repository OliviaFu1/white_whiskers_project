from rest_framework import serializers
from .models import Medication, MedicationSchedule, MedicationPrescription, MedicationLog


class MedicationLogSerializer(serializers.ModelSerializer):
    class Meta:
        model  = MedicationLog
        fields = ["id", "event_type", "old_status", "new_status", "event_date", "notes", "timestamp"]
        read_only_fields = ["id", "event_type", "old_status", "new_status", "event_date", "timestamp"]


class MedicationScheduleSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicationSchedule
        fields = [
            "id",
            "schedule_type",
            "time_of_day",
            "days_of_week",
            "interval_hours",
            "active",
        ]
        read_only_fields = ["id"]

    def validate(self, attrs):
        schedule_type = attrs.get("schedule_type")
        if schedule_type == MedicationSchedule.ScheduleType.INTERVAL:
            if not attrs.get("interval_hours"):
                raise serializers.ValidationError(
                    {"interval_hours": "Required when schedule_type is 'interval'."}
                )
        if schedule_type == MedicationSchedule.ScheduleType.FIXED_TIMES:
            if not attrs.get("time_of_day"):
                raise serializers.ValidationError(
                    {"time_of_day": "Required when schedule_type is 'fixed_times'."}
                )
        return attrs


class MedicationPrescriptionSerializer(serializers.ModelSerializer):
    # Not required on create — defaults to quantity_total via serializer.create()
    quantity_remaining = serializers.DecimalField(
        max_digits=10, decimal_places=4, required=False
    )

    class Meta:
        model = MedicationPrescription
        fields = [
            "id",
            "medication_id",
            "quantity_total",
            "quantity_unit",
            "quantity_remaining",
            "dose_amount",
            "dose_unit",
            "start_date",
            "expiration_date",
            "refills_authorized",
            "refills_used",
            "prescribing_vet_name",
            "notes",
            "status",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "medication_id", "created_at", "updated_at"]

    def create(self, validated_data):
        if "quantity_remaining" not in validated_data:
            validated_data["quantity_remaining"] = validated_data["quantity_total"]
        return super().create(validated_data)


class MedicationSerializer(serializers.ModelSerializer):
    schedules = MedicationScheduleSerializer(many=True, read_only=True)
    prescriptions = MedicationPrescriptionSerializer(many=True, read_only=True)

    class Meta:
        model = Medication
        fields = [
            "id",
            "pet_id",
            "drug_name",
            "generic_name",
            "brand_name",
            "form",
            "route",
            "form_description",
            "strength_value",
            "strength_unit",
            "concentration_value",
            "concentration_unit",
            "dose_amount",
            "dose_unit",
            "sig_text",
            "reason_for_use",
            "status",
            "start_date",
            "end_date",
            "as_needed",
            "max_doses_per_day",
            "with_food",
            "prescribing_vet_name",
            "prescribing_vet_clinic",
            "reminders_enabled",
            "created_at",
            "updated_at",
            "schedules",
            "prescriptions",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class MedicationCreateSerializer(serializers.ModelSerializer):
    schedules = MedicationScheduleSerializer(many=True, required=False, default=list)

    class Meta:
        model = Medication
        fields = [
            "id",
            "pet_id",
            "drug_name",
            "generic_name",
            "brand_name",
            "form",
            "route",
            "form_description",
            "strength_value",
            "strength_unit",
            "concentration_value",
            "concentration_unit",
            "dose_amount",
            "dose_unit",
            "sig_text",
            "reason_for_use",
            "status",
            "start_date",
            "end_date",
            "as_needed",
            "max_doses_per_day",
            "with_food",
            "prescribing_vet_name",
            "prescribing_vet_clinic",
            "reminders_enabled",
            "schedules",
        ]
        read_only_fields = ["id", "pet_id"]

    def validate(self, attrs):
        # pet must belong to the requesting user — validated in the view
        return attrs

    def create(self, validated_data):
        schedules_data = validated_data.pop("schedules", [])
        medication = Medication.objects.create(**validated_data)
        for s in schedules_data:
            MedicationSchedule.objects.create(medication=medication, **s)
        return medication

    def update(self, instance, validated_data):
        # schedules=None means not provided (partial patch) → leave unchanged
        # schedules=[] means explicitly cleared → delete all
        schedules_data = validated_data.pop("schedules", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if schedules_data is not None:
            instance.schedules.all().delete()
            for s in schedules_data:
                MedicationSchedule.objects.create(medication=instance, **s)
            # Clear stale prefetch cache so the response reflects new schedules
            if hasattr(instance, "_prefetched_objects_cache"):
                instance._prefetched_objects_cache.pop("schedules", None)
        return instance
