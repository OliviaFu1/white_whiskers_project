from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import DailyCheckinViewSet, JournalEntryViewSet, UploadJournalPhotoView

router = DefaultRouter()
router.register(r"daily-checkins", DailyCheckinViewSet, basename="daily-checkins")
router.register(r"journal-entries", JournalEntryViewSet, basename="journal-entries")

urlpatterns = [
    path("journal-upload-photo/", UploadJournalPhotoView.as_view(), name="journal-upload-photo"),
    path("", include(router.urls)),
]