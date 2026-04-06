from django.urls import path
from .views import (
    PetListCreateView,
    PetDetailView,
    PetPhotoView,
    PetInviteCreateView,
    MyPendingPetInvitesView,
    PetInviteRespondView,
)

urlpatterns = [
    path("", PetListCreateView.as_view(), name="pet_list_create"),
    path("<int:pk>/", PetDetailView.as_view(), name="pet_detail"),
    path("<int:pk>/photo/", PetPhotoView.as_view(), name="pet_photo"),

    path("invites/", PetInviteCreateView.as_view(), name="pet_invite_create"),
    path("invites/mine/", MyPendingPetInvitesView.as_view(), name="my_pending_pet_invites"),
    path("invites/<int:pk>/respond/", PetInviteRespondView.as_view(), name="pet_invite_respond"),
]