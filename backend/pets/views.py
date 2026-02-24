from rest_framework import generics, permissions
from .models import Pet, PetUser
from .serializers import PetSerializer, PetCreateSerializer


class PetListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Pet.objects.filter(
            petuser__user=self.request.user
        ).distinct().order_by("-created_at")

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