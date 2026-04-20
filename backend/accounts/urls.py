from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import (
    RegisterView,
    MeView,
    PhotoUploadView,
    ChangeEmailView,
    ChangePasswordView,
    SpecialistListCreateView,
    SpecialistDetailView,
)

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("me/", MeView.as_view(), name="me"),
    path("me/photo/", PhotoUploadView.as_view(), name="me-photo"),
    path("me/email/", ChangeEmailView.as_view(), name="me-email"),
    path("me/password/", ChangePasswordView.as_view(), name="me-password"),

    path("me/specialists/", SpecialistListCreateView.as_view(), name="me-specialists"),
    path("me/specialists/<int:pk>/", SpecialistDetailView.as_view(), name="me-specialist-detail"),

    # login + refresh
    path("token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
]