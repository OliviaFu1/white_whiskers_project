from rest_framework import generics, permissions, status
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from django.contrib.auth import get_user_model

from .models import UserSpecialist
from .serializers import (
    UserRegisterSerializer,
    UserPublicSerializer,
    UserMeUpdateSerializer,
    ChangeEmailSerializer,
    ChangePasswordSerializer,
    UserSpecialistSerializer,
)

User = get_user_model()


class RegisterView(generics.CreateAPIView):
    serializer_class = UserRegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        data = UserPublicSerializer(user, context={'request': request}).data
        return Response(data, status=status.HTTP_201_CREATED)


class MeView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user

    def get_serializer_class(self):
        if self.request.method in ["PATCH", "PUT"]:
            return UserMeUpdateSerializer
        return UserPublicSerializer

    def patch(self, request, *args, **kwargs):
        serializer = UserMeUpdateSerializer(self.get_object(), data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(UserPublicSerializer(user, context={'request': request}).data)

    def retrieve(self, request, *args, **kwargs):
        serializer = UserPublicSerializer(self.get_object(), context={'request': request})
        return Response(serializer.data)

    def delete(self, request, *args, **kwargs):
        user = self.get_object()
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChangeEmailView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, *args, **kwargs):
        serializer = ChangeEmailSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        request.user.email = serializer.validated_data['new_email']
        request.user.save()
        return Response({'detail': 'Email updated successfully.'})


class ChangePasswordView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, *args, **kwargs):
        serializer = ChangePasswordSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data['new_password'])
        request.user.save()
        return Response({'detail': 'Password updated successfully.'})


class PhotoUploadView(generics.UpdateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser]

    def get_object(self):
        return self.request.user

    def patch(self, request, *args, **kwargs):
        user = self.get_object()
        photo = request.FILES.get('photo')
        if not photo:
            return Response({'error': 'No photo provided.'}, status=status.HTTP_400_BAD_REQUEST)

        if user.photo:
            user.photo.delete(save=False)

        user.photo = photo
        user.save()

        serializer = UserPublicSerializer(user, context={'request': request})
        return Response(serializer.data)

    def delete(self, request, *args, **kwargs):
        user = self.get_object()
        if user.photo:
            user.photo.delete(save=False)
            user.photo = None
            user.save()
        serializer = UserPublicSerializer(user, context={'request': request})
        return Response(serializer.data)


class SpecialistListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = UserSpecialistSerializer

    def get_queryset(self):
        return UserSpecialist.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class SpecialistDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = UserSpecialistSerializer

    def get_queryset(self):
        return UserSpecialist.objects.filter(user=self.request.user)