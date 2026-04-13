from django.db.models import F
from django.utils import timezone

from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Pet, PetUser, PetInvite
from .serializers import (
    PetSerializer,
    PetCreateSerializer,
    PetInviteCreateSerializer,
    PetInviteSerializer,
    PetInviteRespondSerializer,
    PetJoinByCodeSerializer,
)


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

    def perform_update(self, serializer):
        pet = self.get_object()
        is_owner = PetUser.objects.filter(
            pet=pet,
            user=self.request.user,
            role=PetUser.Role.OWNER,
        ).exists()
        if not is_owner:
            raise PermissionDenied("Only the owner can edit this pet.")
        serializer.save()

    def perform_destroy(self, instance):
        is_owner = PetUser.objects.filter(
            pet=instance,
            user=self.request.user,
            role=PetUser.Role.OWNER,
        ).exists()
        if not is_owner:
            raise PermissionDenied("Only the owner can delete this pet.")
        instance.delete()


class PetPhotoView(generics.UpdateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser]

    def get_object(self):
        pet = Pet.objects.filter(pk=self.kwargs["pk"]).first()
        if pet is None:
            raise NotFound()

        is_owner = PetUser.objects.filter(
            pet=pet,
            user=self.request.user,
            role=PetUser.Role.OWNER,
        ).exists()
        if not is_owner:
            raise PermissionDenied("Only the owner can update photo.")

        return pet

    def patch(self, request, *args, **kwargs):
        pet = self.get_object()
        photo = request.FILES.get("photo")
        if not photo:
            return Response(
                {"error": "No photo provided."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if pet.photo:
            pet.photo.delete(save=False)
        pet.photo = photo
        pet.save()
        return Response(PetSerializer(pet, context={"request": request}).data)


class PetInviteCreateView(generics.CreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = PetInviteCreateSerializer


class MyPendingPetInvitesView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = PetInviteSerializer

    def get_queryset(self):
        email = (self.request.user.email or "").strip().lower()
        return (
            PetInvite.objects.filter(
                invitee_email__iexact=email,
                status=PetInvite.Status.PENDING,
            )
            .select_related("pet", "inviter")
            .order_by("-created_at")
        )


class PetInviteRespondView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        invite = (
            PetInvite.objects.select_related("pet", "inviter")
            .filter(pk=pk)
            .first()
        )
        if invite is None:
            raise NotFound()

        serializer = PetInviteRespondSerializer(
            data=request.data,
            context={"request": request, "invite": invite},
        )
        serializer.is_valid(raise_exception=True)
        invite = serializer.save()

        return Response(
            PetInviteSerializer(invite).data,
            status=status.HTTP_200_OK,
        )

class PetLeaveView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        pet = Pet.objects.filter(pk=pk).first()
        if pet is None:
            raise NotFound()

        link = PetUser.objects.filter(
            pet=pet,
            user=request.user,
        ).first()
        if link is None:
            raise NotFound("You are not linked to this pet.")

        if link.role == PetUser.Role.OWNER:
            raise PermissionDenied("The owner cannot leave the pet.")

        link.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

class PetJoinByCodeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = PetJoinByCodeSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        pet = serializer.save()

        return Response(
            PetSerializer(pet, context={"request": request}).data,
            status=status.HTTP_200_OK,
        )