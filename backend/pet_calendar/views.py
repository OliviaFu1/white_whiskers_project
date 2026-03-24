import os
import uuid
from django.db.models import Q
from django.utils.dateparse import parse_date
from django.conf import settings
from django.core.files.storage import default_storage

from rest_framework import viewsets, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import DailyCheckin, JournalEntry
from .serializers import DailyCheckinSerializer, JournalEntrySerializer, JournalPhotoUploadSerializer
from .permissions import JournalVisibilityPermission, IsAuthorForWriteOtherwiseReadOnly


class DailyCheckinViewSet(viewsets.ModelViewSet):
    serializer_class = DailyCheckinSerializer
    permission_classes = [IsAuthorForWriteOtherwiseReadOnly]

    def get_queryset(self):
        qs = DailyCheckin.objects.all()

        # For calendar: require pet_id
        pet_id = self.request.query_params.get("pet_id")
        if pet_id:
            qs = qs.filter(pet_id=pet_id)

        # Day filter
        day = parse_date(self.request.query_params.get("date", "") or "")
        if day:
            qs = qs.filter(checkin_date=day)

        return qs.order_by("-checkin_date", "-created_at")

    def perform_create(self, serializer):
        # Allows creating for any date provided
        serializer.save(author=self.request.user)


class JournalEntryViewSet(viewsets.ModelViewSet):
    serializer_class = JournalEntrySerializer
    permission_classes = [JournalVisibilityPermission]

    def get_queryset(self):
        qs = JournalEntry.objects.all()

        pet_id = self.request.query_params.get("pet_id")
        if pet_id:
            qs = qs.filter(pet_id=pet_id)

        # Day filter
        day = parse_date(self.request.query_params.get("date", "") or "")
        if day:
            qs = qs.filter(entry_date=day)

        tag = self.request.query_params.get("tag")
        if tag:
            qs = qs.filter(tag=tag)

        # Enforce visibility rules at query level too
        user = self.request.user
        qs = qs.filter()
        qs = qs.filter(Q(visibility="shared") | Q(author=user))

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

        return Response(
            {
                "photo_url": photo_url,
            },
            status=status.HTTP_200_OK,
        )