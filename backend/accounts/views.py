from rest_framework import generics, permissions, status
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

        data = UserPublicSerializer(user).data
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
        return self.partial_update(request, *args, **kwargs)