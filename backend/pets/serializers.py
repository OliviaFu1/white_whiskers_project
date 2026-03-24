from rest_framework import serializers
from .models import Pet, PetUser

class PetSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField(read_only=True)
    photo_url = serializers.SerializerMethodField(read_only=True)

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
            "birthdate",
            "date_of_death",
            "weight_kg",
            "created_at",
            "updated_at",
            "role",
        ]
        read_only_fields = ["id", "created_at", "updated_at", "role", "photo_url"]

    def get_photo_url(self, obj: Pet):
        request = self.context.get("request")
        if obj.photo and request:
            return request.build_absolute_uri(obj.photo.url)
        return None

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
            "species",
            "breed_text",
            "sex",
            "spayed_neutered",
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

        # spayed_neutered is optional (null = unknown)

        if attrs.get("birthdate") is None:
            errors["birthdate"] = "Birthdate is required."

        if errors:
            raise serializers.ValidationError(errors)

        return attrs
