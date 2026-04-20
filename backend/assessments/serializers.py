from rest_framework import serializers
from .models import PetAssessment


class PetAssessmentSerializer(serializers.ModelSerializer):
    owner = serializers.ReadOnlyField(source="owner.id")
    owner_name = serializers.SerializerMethodField()
    can_share = serializers.SerializerMethodField()

    class Meta:
        model = PetAssessment
        fields = [
            "id",
            "pet",
            "owner",
            "owner_name",
            "can_share",
            "answers",
            "heart_score",
            "condition_score",
            "significantly_challenged",
            "submitted_at",
        ]
        read_only_fields = ["id", "owner", "owner_name", "can_share", "submitted_at"]

    def get_owner_name(self, obj):
        return getattr(obj.owner, "name", "")
    
    def get_can_share(self, obj):
        request = self.context.get("request")
        if request is None or not getattr(request, "user", None):
            return False
        if not request.user.is_authenticated:
            return False
        return obj.owner_id == request.user.id

    def validate_answers(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError("answers must be a JSON object.")
        return value
    

class ShareAssessmentSerializer(serializers.Serializer):
    recipient_id = serializers.IntegerField()
    recipient_type = serializers.ChoiceField(choices=["primary", "specialist"])
    questions_comments = serializers.CharField(
        required=False,
        allow_blank=True,
        default="",
    )

    all_time_good_pct = serializers.IntegerField(required=False, allow_null=True)
    all_time_checkin_count = serializers.IntegerField(required=False, allow_null=True)

    past_28_days_good_pct = serializers.IntegerField(required=False, allow_null=True)
    past_28_days_checkin_count = serializers.IntegerField(required=False, allow_null=True)

    past_7_days_good_pct = serializers.IntegerField(required=False, allow_null=True)
    past_7_days_checkin_count = serializers.IntegerField(required=False, allow_null=True)