from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from django.db.models import F
from .models import Pet, PetUser
from .serializers import PetSerializer, PetCreateSerializer
from medications.models import Medication, MedicationLog

_DEATH_NOTE = "auto-completed: pet_death"


class PetListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Pet.objects.filter(
            petuser__user=self.request.user
        ).distinct().order_by(F('birthdate').asc(nulls_last=True))

    def get_serializer_class(self):
        if self.request.method == "POST":
            return PetCreateSerializer
        return PetSerializer

    def perform_create(self, serializer):
        pet = serializer.save()
        PetUser.objects.create(
            pet=pet,
            user=self.request.user,
            role=PetUser.Role.OWNER,
        )


class PetDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = PetSerializer

    def get_queryset(self):
        return Pet.objects.filter(
            petuser__user=self.request.user
        ).distinct()

    def _sync_medications_for_death_change(self, pet, old_date_of_death):
        """
        When a pet's date_of_death transitions between set and None, update
        the statuses of its medications accordingly.
        """
        was_deceased = old_date_of_death is not None
        is_deceased = pet.date_of_death is not None

        if not was_deceased and is_deceased:
            # Pet just died — complete all active/paused medications.
            meds = Medication.objects.filter(
                pet=pet,
                status__in=["active", "paused"],
            )
            for med in meds:
                MedicationLog.objects.create(
                    medication=med,
                    event_type=MedicationLog.EventType.STATUS_CHANGE,
                    old_status=med.status,
                    new_status=Medication.Status.COMPLETED,
                    notes=_DEATH_NOTE,
                )
            meds.update(status=Medication.Status.COMPLETED)

        elif was_deceased and not is_deceased:
            # Pet marked as living again — revert each auto-completed medication.
            for med in Medication.objects.filter(pet=pet, status=Medication.Status.COMPLETED):
                log = (
                    MedicationLog.objects.filter(
                        medication=med,
                        event_type=MedicationLog.EventType.STATUS_CHANGE,
                        new_status=Medication.Status.COMPLETED,
                        notes=_DEATH_NOTE,
                    )
                    .order_by("-timestamp")
                    .first()
                )
                if log:
                    Medication.objects.filter(pk=med.pk).update(status=log.old_status)
                    log.delete()

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        old_date_of_death = instance.date_of_death
        response = super().update(request, *args, **kwargs)
        instance.refresh_from_db()
        self._sync_medications_for_death_change(instance, old_date_of_death)
        return response

    def partial_update(self, request, *args, **kwargs):
        instance = self.get_object()
        old_date_of_death = instance.date_of_death
        response = super().partial_update(request, *args, **kwargs)
        instance.refresh_from_db()
        self._sync_medications_for_death_change(instance, old_date_of_death)
        return response


class PetPhotoView(generics.UpdateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser]

    def get_object(self):
        pet = Pet.objects.filter(
            pk=self.kwargs["pk"],
            petuser__user=self.request.user,
        ).first()
        if pet is None:
            raise NotFound()
        return pet

    def patch(self, request, *args, **kwargs):
        pet = self.get_object()
        photo = request.FILES.get("photo")
        if not photo:
            return Response({"error": "No photo provided."}, status=status.HTTP_400_BAD_REQUEST)
        if pet.photo:
            pet.photo.delete(save=False)
        pet.photo = photo
        pet.save()
        return Response(PetSerializer(pet, context={"request": request}).data)