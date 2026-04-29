from rest_framework.routers import DefaultRouter
from .views import MedicationViewSet, PrescriptionViewSet, MedicationLogViewSet

med_router = DefaultRouter()
med_router.register("", MedicationViewSet, basename="medication")

# Registers /api/medications/prescriptions/{id}/ for retrieve/update/delete
rx_router = DefaultRouter()
rx_router.register("prescriptions", PrescriptionViewSet, basename="prescription")

# Registers /api/medications/logs/{id}/ for delete
log_router = DefaultRouter()
log_router.register("logs", MedicationLogViewSet, basename="medication-log")

urlpatterns = med_router.urls + rx_router.urls + log_router.urls
