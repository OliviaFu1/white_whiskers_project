from rest_framework import serializers
from .models import PetAssessment


class PetAssessmentSerializer(serializers.ModelSerializer):
    owner = serializers.ReadOnlyField(source="owner.id")
    owner_name = serializers.SerializerMethodField()

    class Meta:
        model = PetAssessment
        fields = [
            "id",
            "pet",
            "owner",
            "owner_name",
            "answers",
            "heart_score",
            "condition_score",
            "significantly_challenged",
            "submitted_at",
        ]
        read_only_fields = ["id", "owner", "owner_name", "submitted_at"]

    def get_owner_name(self, obj):
        return getattr(obj.owner, "name", "")

    def validate_answers(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError("answers must be a JSON object.")
        return value