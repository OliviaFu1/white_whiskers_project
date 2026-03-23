from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from django.db.models import F
from .models import Pet, PetUser
from .serializers import PetSerializer, PetCreateSerializer


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