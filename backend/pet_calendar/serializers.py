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
        fields = ["id", "name", "color", "created_at"]
        read_only_fields = ["id", "created_at"]

    def validate_name(self, value):
        value = (value or "").strip().lower()
        if not value:
            raise serializers.ValidationError("Tag name cannot be empty.")
        return value

    def validate_color(self, value):
        value = (value or "").strip()
        if not value:
            raise serializers.ValidationError("Color is required.")
        return value


class JournalEntrySerializer(serializers.ModelSerializer):
    author_user_id = serializers.IntegerField(source="author_id", read_only=True)
    author_name = serializers.CharField(source="author.name", read_only=True)
    pet_id = serializers.IntegerField()

    tags = JournalTagSerializer(many=True, read_only=True)
    tag_ids = serializers.PrimaryKeyRelatedField(
        many=True,
        write_only=True,
        required=False,
        queryset=JournalTag.objects.none(),
        source="tags",
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
            "tag_ids",
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

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            self.fields["tag_ids"].child_relation.queryset = JournalTag.objects.filter(
                user=request.user
            ).order_by("name")

    def create(self, validated_data):
        tags = validated_data.pop("tags", [])
        entry = JournalEntry.objects.create(**validated_data)
        if tags:
            entry.tags.set(tags)
        return entry

    def update(self, instance, validated_data):
        tags = validated_data.pop("tags", None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if tags is not None:
            instance.tags.set(tags)

        return instance


class JournalPhotoUploadSerializer(serializers.Serializer):
    photo = serializers.ImageField(required=True)