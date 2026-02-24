from rest_framework import serializers
from .models import Pet, PetUser

class PetSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Pet
        fields = [
            "id",
            "name",
            "photo_url",
            "species",
            "breed_text",
            "sex",
            "birthdate",
            "date_of_death",
            "weight_kg",
            "created_at",
            "updated_at",
            "role",
        ]
        read_only_fields = ["id", "created_at", "updated_at", "role"]

    def get_role(self, obj: Pet):
        request = self.context.get("request")
        if not request or not request.user or request.user.is_anonymous:
            return None
        link = PetUser.objects.filter(pet=obj, user=request.user).first()
        return link.role if link else None


class PetCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Pet
        fields = [
            "id",
            "name",
            "photo_url",
            "species",
            "breed_text",
            "sex",
            "spayed_neutered",
            "age_years",
            "birthdate",
            "weight_kg",
        ]
        read_only_fields = ["id"]

    def validate(self, attrs):
        errors = {}

        # Required strings: present + non-blank after trim
        required_str = ["name", "species", "breed_text", "sex"]
        for k in required_str:
            v = attrs.get(k, None)
            if v is None or (isinstance(v, str) and v.strip() == ""):
                errors[k] = "This field is required."

        # Required bool: must be True or False (not None / missing)
        if attrs.get("spayed_neutered", None) is None:
            errors["spayed_neutered"] = "This field is required."

        age_years = attrs.get("age_years")
        birthdate = attrs.get("birthdate")

        # require at least one of age_years or birthdate
        if age_years is None and birthdate is None:
            errors["age_years"] = "Provide age_years or birthdate."
            errors["birthdate"] = "Provide age_years or birthdate."

        # optional: sanity check age
        if age_years is not None and age_years > 40:
            errors["age_years"] = "Unrealistic age_years (max 40)."

        if errors:
            raise serializers.ValidationError(errors)

        return attrs