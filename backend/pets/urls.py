from django.urls import path
from .views import PetListCreateView, PetDetailView, PetPhotoView

urlpatterns = [
    path("", PetListCreateView.as_view(), name="pet_list_create"),
    path("<int:pk>/", PetDetailView.as_view(), name="pet_detail"),
    path("<int:pk>/photo/", PetPhotoView.as_view(), name="pet_photo"),
]