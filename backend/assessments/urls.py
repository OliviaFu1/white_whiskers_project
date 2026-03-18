from rest_framework.routers import DefaultRouter
from .views import PetAssessmentViewSet

router = DefaultRouter()
router.register(r"", PetAssessmentViewSet, basename="assessments")

urlpatterns = router.urls