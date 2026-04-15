from rest_framework import mixins, permissions, viewsets
from rest_framework.exceptions import PermissionDenied

from pets.models import PetUser
from .models import PetAssessment
from .serializers import PetAssessmentSerializer


class PetAssessmentViewSet(
    mixins.CreateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.ReadOnlyModelViewSet,
):
    serializer_class = PetAssessmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = PetAssessment.objects.filter(
            pet__petuser__user=self.request.user
        ).distinct()

        pet_id = self.request.query_params.get("pet_id")
        if pet_id:
            qs = qs.filter(pet_id=pet_id)

        return qs.select_related("pet").order_by("-submitted_at")

    def perform_create(self, serializer):
        pet = serializer.validated_data["pet"]

        linked = PetUser.objects.filter(
            pet=pet,
            user=self.request.user,
        ).exists()
        if not linked:
            raise PermissionDenied("You are not linked to this pet.")

        serializer.save(owner=self.request.user)