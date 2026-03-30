from rest_framework import serializers
from .models import DailyCheckin, JournalEntry, JournalTag


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


class JournalTagSerializer(serializers.ModelSerializer):
    class Meta:
        model = JournalTag
        fields = ["id", "name", "created_at"]
        read_only_fields = ["id", "created_at"]


class JournalEntrySerializer(serializers.ModelSerializer):
    author_user_id = serializers.IntegerField(source="author_id", read_only=True)
    author_name = serializers.CharField(source="author.name", read_only=True)
    pet_id = serializers.IntegerField()
    tags = serializers.ListField(
        child=serializers.CharField(max_length=32),
        required=False,
        allow_empty=True,
    )

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
            "tags",
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

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["tags"] = list(instance.tags.values_list("name", flat=True))
        return data

    def validate_tags(self, value):
        cleaned = []
        seen = set()

        for tag in value:
            name = (tag or "").strip().lower()
            if not name:
                continue
            if name not in seen:
                seen.add(name)
                cleaned.append(name)

        return cleaned

    def _get_or_create_user_tags(self, user, tag_names):
        tags = []
        for name in tag_names:
            tag_obj, _ = JournalTag.objects.get_or_create(
                user=user,
                name=name,
                defaults={"is_default": False},
            )
            tags.append(tag_obj)
        return tags

    def create(self, validated_data):
        tag_names = validated_data.pop("tags", [])
        entry = JournalEntry.objects.create(**validated_data)

        if tag_names:
            tags = self._get_or_create_user_tags(validated_data["author"], tag_names)
            entry.tags.set(tags)

        return entry

    def update(self, instance, validated_data):
        tag_names = validated_data.pop("tags", None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if tag_names is not None:
            tags = self._get_or_create_user_tags(instance.author, tag_names)
            instance.tags.set(tags)

        return instance


class JournalPhotoUploadSerializer(serializers.Serializer):
    photo = serializers.ImageField(required=True)