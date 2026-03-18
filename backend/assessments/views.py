from rest_framework import mixins, permissions, viewsets
from .models import PetAssessment
from .serializers import PetAssessmentSerializer

# Allow POST, GET, DELETE
class PetAssessmentViewSet(
    mixins.CreateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.ReadOnlyModelViewSet,
):
    serializer_class = PetAssessmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = PetAssessment.objects.filter(owner=self.request.user)

        pet_id = self.request.query_params.get("pet_id")
        if pet_id:
            qs = qs.filter(pet_id=pet_id)

        return qs.select_related("pet").order_by("-submitted_at")

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)