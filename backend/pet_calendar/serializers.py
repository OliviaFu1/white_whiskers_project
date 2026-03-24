from rest_framework import serializers
from .models import DailyCheckin, JournalEntry
from accounts.serializers import UserPublicSerializer


class DailyCheckinSerializer(serializers.ModelSerializer):
    author_user_id = serializers.IntegerField(source="author_id", read_only=True)
    author_name = serializers.CharField(source="author.name", read_only=True)
    pet_id = serializers.IntegerField()

    class Meta:
        model = DailyCheckin
        fields = [
            "id",
            "pet_id",
            "author_user_id",
            "author_name",
            "checkin_date",
            "day_rating",
            "notes",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "author_user_id",
            "author_name",
            "created_at",
            "updated_at",
        ]


class JournalEntrySerializer(serializers.ModelSerializer):
    author_user_id = serializers.IntegerField(source="author_id", read_only=True)
    author_name = serializers.CharField(source="author.name", read_only=True)
    pet_id = serializers.IntegerField()

    class Meta:
        model = JournalEntry
        fields = [
            "id",
            "pet_id",
            "author_user_id",
            "author_name",
            "entry_date",
            "title",
            "text",
            "photo_url",
            "visibility",
            "tag",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "author_user_id",
            "author_name",
            "created_at",
            "updated_at",
        ]

class JournalPhotoUploadSerializer(serializers.Serializer):
    photo = serializers.ImageField(required=True)