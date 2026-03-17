from rest_framework import generics, permissions, status
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from django.contrib.auth import get_user_model

from .serializers import UserRegisterSerializer, UserPublicSerializer, UserMeUpdateSerializer

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


class MeView(generics.RetrieveUpdateAPIView):
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
