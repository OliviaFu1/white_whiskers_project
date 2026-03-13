from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = [
            "id",
            "title",
            "message",
            "created_at",
            "notification_type",
            "is_read",
            "pet_id",
        ]
        read_only_fields = ["id", "created_at"]