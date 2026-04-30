from django.urls import path
from .views import (
    PetListCreateView,
    PetDetailView,
    PetPhotoView,
    PetInviteCreateView,
    MyPendingPetInvitesView,
    PetInviteRespondView,
    PetInviteCancelView,
    PetLeaveView,
    PetJoinByCodeView,
    PetFamilyManagementView,
    PetFamilyMemberRoleUpdateView,
)

urlpatterns = [
    path("", PetListCreateView.as_view(), name="pet_list_create"),
    path("<int:pk>/", PetDetailView.as_view(), name="pet_detail"),
    path("<int:pk>/photo/", PetPhotoView.as_view(), name="pet_photo"),
    path("<int:pk>/leave/", PetLeaveView.as_view(), name="pet_leave"),
    
    path("join-by-code/", PetJoinByCodeView.as_view(), name="pet_join_by_code"),
    path("invites/", PetInviteCreateView.as_view(), name="pet_invite_create"),
    path("invites/mine/", MyPendingPetInvitesView.as_view(), name="my_pending_pet_invites"),
    path("invites/<int:pk>/respond/", PetInviteRespondView.as_view(), name="pet_invite_respond"),
    path("invites/<int:pk>/cancel/", PetInviteCancelView.as_view(), name="pet_invite_cancel"),

    path("<int:pk>/family-management/", PetFamilyManagementView.as_view(), name="pet_family_management"),
    path("<int:pk>/family-members/<int:user_id>/role/", PetFamilyMemberRoleUpdateView.as_view(), name="pet_family_member_role_update"),
]