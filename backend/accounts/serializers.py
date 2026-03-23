from django.contrib.auth import get_user_model
from rest_framework import serializers

User = get_user_model()


class UserPublicSerializer(serializers.ModelSerializer):
    """Safe fields to return to the client."""
    photo_url = serializers.SerializerMethodField()

    def get_photo_url(self, obj):
        request = self.context.get('request')
        if obj.photo and request:
            return request.build_absolute_uri(obj.photo.url)
        return None

    class Meta:
        model = User
        fields = ("id", "email", "name", "last_name", "photo_url", "location", "created_at", "updated_at")
        read_only_fields = ("id", "email", "created_at", "updated_at")


class UserRegisterSerializer(serializers.ModelSerializer):
    """For signup. Writes password securely via set_password()."""
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ("email", "password", "name")

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
        fields = ("name", "last_name", "location")


class ChangeEmailSerializer(serializers.Serializer):
    new_email = serializers.EmailField()

    def validate_new_email(self, value):
        value = value.strip().lower()
        user = self.context['request'].user
        if value == user.email:
            raise serializers.ValidationError("This is already your current email.")
        if User.objects.filter(email=value).exclude(pk=user.pk).exists():
            raise serializers.ValidationError("This email is already in use.")
        return value


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField()
    new_password = serializers.CharField(min_length=8)
    confirm_password = serializers.CharField()

    def validate(self, attrs):
        user = self.context['request'].user
        if not user.check_password(attrs['current_password']):
            raise serializers.ValidationError(
                {'current_password': 'Current password is incorrect.'}
            )
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError(
                {'confirm_password': 'Passwords do not match.'}
            )
        return attrs
