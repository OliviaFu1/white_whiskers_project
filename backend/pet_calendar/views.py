import os
import uuid

from django.conf import settings
from django.core.files.storage import default_storage
from django.db.models import Q
from django.utils.dateparse import parse_date

from rest_framework import permissions, status, viewsets
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from pets.models import PetUser
from .models import DailyCheckin, JournalEntry, JournalTag
from .permissions import JournalVisibilityPermission, IsAuthorForWriteOtherwiseReadOnly
from .serializers import (
    DailyCheckinSerializer,
    JournalEntrySerializer,
    JournalPhotoUploadSerializer,
    JournalTagSerializer,
)


class DailyCheckinViewSet(viewsets.ModelViewSet):
    serializer_class = DailyCheckinSerializer
    permission_classes = [IsAuthorForWriteOtherwiseReadOnly]

    def get_queryset(self):
        user = self.request.user

        qs = DailyCheckin.objects.filter(
            pet__petuser__user=user
        ).distinct()

        pet_id = self.request.query_params.get("pet_id")
        if pet_id:
            qs = qs.filter(pet_id=pet_id)

        day = parse_date(self.request.query_params.get("date", "") or "")
        if day:
            qs = qs.filter(checkin_date=day)

        mine_only = (
            self.request.query_params.get("mine_only", "").strip().lower()
            == "true"
        )
        if mine_only:
            qs = qs.filter(author=user)

        return qs.order_by("-checkin_date", "-created_at")

    def perform_create(self, serializer):
        pet_id = serializer.validated_data["pet_id"] if "pet_id" in serializer.validated_data else None
        if pet_id is None:
            pet_id = serializer.validated_data["pet"].id

        linked = PetUser.objects.filter(
            pet_id=pet_id,
            user=self.request.user,
        ).exists()
        if not linked:
            raise PermissionDenied("You are not linked to this pet.")

        serializer.save(author=self.request.user)


class JournalTagViewSet(viewsets.ModelViewSet):
    serializer_class = JournalTagSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return JournalTag.objects.filter(user=self.request.user).order_by("name")

    def perform_create(self, serializer):
        user = self.request.user
        current_count = JournalTag.objects.filter(user=user).count()

        if current_count >= 8:
            raise ValidationError(
                {"detail": f"You can create up to 8 tags only."}
            )

        serializer.save(user=user)

    def perform_update(self, serializer):
        serializer.save(user=self.request.user)


class JournalEntryViewSet(viewsets.ModelViewSet):
    serializer_class = JournalEntrySerializer
    permission_classes = [JournalVisibilityPermission]

    def get_queryset(self):
        user = self.request.user

        qs = JournalEntry.objects.all().prefetch_related("tags")

        pet_id = self.request.query_params.get("pet_id")
        if pet_id:
            qs = qs.filter(pet_id=pet_id)

        day = parse_date(self.request.query_params.get("date", "") or "")
        if day:
            qs = qs.filter(entry_date=day)

        tag = (self.request.query_params.get("tag") or "").strip().lower()
        if tag:
            qs = qs.filter(tags__name=tag)

        # only entries this user is allowed to see
        qs = qs.filter(Q(visibility="shared") | Q(author=user)).distinct()

        author_filter = (self.request.query_params.get("author_filter") or "all").strip().lower()
        if author_filter == "mine":
            qs = qs.filter(author=user)
        elif author_filter == "others":
            qs = qs.exclude(author=user)

        return qs.order_by("-entry_date", "-created_at")

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)


class UploadJournalPhotoView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = JournalPhotoUploadSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        photo = serializer.validated_data["photo"]
        ext = os.path.splitext(photo.name)[1] or ".jpg"
        filename = f"journal_photos/{uuid.uuid4().hex}{ext}"

        saved_path = default_storage.save(filename, photo)
        photo_url = request.build_absolute_uri(settings.MEDIA_URL + saved_path)

        return Response({"photo_url": photo_url}, status=status.HTTP_200_OK)