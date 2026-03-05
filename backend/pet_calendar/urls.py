from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import DailyCheckinViewSet, JournalEntryViewSet

router = DefaultRouter()
router.register(r"daily-checkins", DailyCheckinViewSet, basename="daily-checkins")
router.register(r"journal-entries", JournalEntryViewSet, basename="journal-entries")

urlpatterns = [
    path("", include(router.urls)),
]