from rest_framework import serializers
from .models import PetAssessment


class PetAssessmentSerializer(serializers.ModelSerializer):
    owner = serializers.ReadOnlyField(source="owner.id")

    class Meta:
        model = PetAssessment
        fields = [
            "id",
            "pet",
            "owner",
            "answers",
            "heart_score",
            "condition_score",
            "significantly_challenged",
            "submitted_at",
        ]
        read_only_fields = ["id", "owner", "submitted_at"]

    def validate_answers(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError("answers must be a JSON object.")
        return value