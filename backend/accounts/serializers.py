from django.contrib.auth import get_user_model
from rest_framework import serializers

User = get_user_model()


class UserPublicSerializer(serializers.ModelSerializer):
    """Safe fields to return to the client."""
    class Meta:
        model = User
        fields = ("id", "email", "name", "photo_url", "created_at", "updated_at")
        read_only_fields = ("id", "email", "created_at", "updated_at")


class UserRegisterSerializer(serializers.ModelSerializer):
    """For signup. Writes password securely via set_password()."""
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ("email", "password", "name", "photo_url")

    def validate_email(self, value):
        return value.strip().lower()

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user

class UserMeUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("name", "photo_url")