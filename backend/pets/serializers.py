from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import serializers

from .models import Pet, PetUser, PetInvite

User = get_user_model()


class PetSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField(read_only=True)
    photo_url = serializers.SerializerMethodField(read_only=True)
    family_members = serializers.SerializerMethodField(read_only=True)
    share_code = serializers.SerializerMethodField(read_only=True)

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
            "family_members",
            "share_code",
        ]
        read_only_fields = [
            "id",
            "created_at",
            "updated_at",
            "role",
            "photo_url",
            "family_members",
            "share_code",
        ]

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

    def get_family_members(self, obj: Pet):
        links = (
            PetUser.objects.filter(pet=obj)
            .select_related("user")
            .order_by("created_at")
        )
        return [
            {
                "user_id": link.user_id,
                "email": getattr(link.user, "email", ""),
                "role": link.role,
            }
            for link in links
        ]
    
    def get_share_code(self, obj: Pet):
        request = self.context.get("request")
        if not request or not request.user or request.user.is_anonymous:
            return None

        linked = PetUser.objects.filter(pet=obj, user=request.user).exists()
        if not linked:
            return None

        return obj.share_code


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

        required_str = ["name", "species", "breed_text", "sex"]
        for k in required_str:
            v = attrs.get(k, None)
            if v is None or (isinstance(v, str) and v.strip() == ""):
                errors[k] = "This field is required."

        if attrs.get("birthdate") is None:
            errors["birthdate"] = "Birthdate is required."

        if errors:
            raise serializers.ValidationError(errors)

        return attrs


class PetInviteCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PetInvite
        fields = ["id", "pet", "invitee_email"]
        read_only_fields = ["id"]

    def validate(self, attrs):
        request = self.context["request"]
        pet = attrs["pet"]
        invitee_email = attrs["invitee_email"].strip().lower()

        is_owner = PetUser.objects.filter(
            pet=pet,
            user=request.user,
            role=PetUser.Role.OWNER,
        ).exists()
        if not is_owner:
            raise serializers.ValidationError("Only the owner can invite family members.")

        if request.user.email and invitee_email == request.user.email.lower():
            raise serializers.ValidationError(
                {"invitee_email": "You cannot invite yourself."}
            )

        invitee_user = User.objects.filter(email__iexact=invitee_email).first()
        if invitee_user is None:
            raise serializers.ValidationError(
                {"invitee_email": "This user does not exist."}
            )

        already_member = PetUser.objects.filter(
            pet=pet,
            user=invitee_user,
        ).exists()
        if already_member:
            raise serializers.ValidationError(
                {"invitee_email": "This user is already linked to the pet."}
            )

        pending_exists = PetInvite.objects.filter(
            pet=pet,
            invitee_user=invitee_user,
            status=PetInvite.Status.PENDING,
        ).exists()
        if pending_exists:
            raise serializers.ValidationError(
                {"invitee_email": "A pending invite already exists for this user."}
            )

        attrs["invitee_email"] = invitee_email
        attrs["invitee_user"] = invitee_user
        return attrs

    def create(self, validated_data):
        invitee_user = validated_data.pop("invitee_user")

        return PetInvite.objects.create(
            pet=validated_data["pet"],
            inviter=self.context["request"].user,
            invitee_email=validated_data["invitee_email"],
            invitee_user=invitee_user,
        )


class PetInviteSerializer(serializers.ModelSerializer):
    pet_name = serializers.CharField(source="pet.name", read_only=True)
    inviter_name = serializers.SerializerMethodField()

    class Meta:
        model = PetInvite
        fields = [
            "id",
            "pet",
            "pet_name",
            "inviter_name",
            "invitee_email",
            "status",
            "created_at",
            "responded_at",
        ]

    def get_inviter_name(self, obj):
        inviter = obj.inviter
        return getattr(inviter, "name", None) or getattr(inviter, "email", "")


class PetInviteRespondSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=["accept", "decline"])

    def save(self, **kwargs):
        invite = self.context["invite"]
        request = self.context["request"]
        user = request.user
        action = self.validated_data["action"]

        if invite.status != PetInvite.Status.PENDING:
            raise serializers.ValidationError("This invite is no longer pending.")

        if invite.invitee_email.lower() != (user.email or "").lower():
            raise serializers.ValidationError("This invite is not for the current user.")

        if action == "accept":
            PetUser.objects.get_or_create(
                pet=invite.pet,
                user=user,
                defaults={"role": PetUser.Role.FAMILY},
            )
            invite.status = PetInvite.Status.ACCEPTED
        else:
            invite.status = PetInvite.Status.DECLINED

        invite.invitee_user = user
        invite.responded_at = timezone.now()
        invite.save(update_fields=["invitee_user", "status", "responded_at"])
        return invite


# new onboarding-family flow -- join by shared code
class PetJoinByCodeSerializer(serializers.Serializer):
    share_code = serializers.CharField(max_length=12)

    def validate_share_code(self, value):
        return value.strip().upper()

    def save(self, **kwargs):
        request = self.context["request"]
        user = request.user
        share_code = self.validated_data["share_code"]

        pet = Pet.objects.filter(share_code=share_code).first()
        if pet is None:
            raise serializers.ValidationError({"share_code": "Invalid pet code."})

        link = PetUser.objects.filter(pet=pet, user=user).first()
        if link is not None:
            raise serializers.ValidationError(
                {"share_code": "You are already linked to this pet."}
            )

        PetUser.objects.create(
            pet=pet,
            user=user,
            role=PetUser.Role.FAMILY,
        )

        return pet


# family member management
class PetFamilyMemberManageSerializer(serializers.ModelSerializer):
    status = serializers.SerializerMethodField()
    email = serializers.SerializerMethodField()
    name = serializers.SerializerMethodField()
    is_me = serializers.SerializerMethodField()

    class Meta:
        model = PetUser
        fields = ["user_id", "name", "email", "role", "status", "is_me"]

    def get_status(self, obj):
        return "connected"

    def get_email(self, obj):
        return getattr(obj.user, "email", "")

    def get_name(self, obj):
        user = obj.user

        name = getattr(user, "name", None)
        if isinstance(name, str) and name.strip():
            return name.strip()

        return ""

    def get_is_me(self, obj):
        request = self.context.get("request")
        if not request or not request.user or request.user.is_anonymous:
            return False
        return obj.user_id == request.user.id

class PetPendingInviteManageSerializer(serializers.ModelSerializer):
    status = serializers.SerializerMethodField()
    role = serializers.SerializerMethodField()
    name = serializers.SerializerMethodField()

    class Meta:
        model = PetInvite
        fields = ["id", "invitee_email", "name", "role", "status", "created_at"]

    def get_status(self, obj):
        return "pending"

    def get_role(self, obj):
        return "family"

    def get_name(self, obj):
        user = getattr(obj, "invitee_user", None)

        name = getattr(user, "name", None)
        if isinstance(name, str) and name.strip():
            return name.strip()

        return ""

class PetUserRoleUpdateSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=[PetUser.Role.OWNER, PetUser.Role.FAMILY])

    def save(self, **kwargs):
        pet = self.context["pet"]
        target_user_id = self.context["target_user_id"]
        request_user = self.context["request"].user

        is_owner = PetUser.objects.filter(
            pet=pet,
            user=request_user,
            role=PetUser.Role.OWNER,
        ).exists()
        if not is_owner:
            raise serializers.ValidationError("Only an owner can change roles.")

        link = PetUser.objects.filter(
            pet=pet,
            user_id=target_user_id,
        ).first()
        if link is None:
            raise serializers.ValidationError("This member is not linked to the pet.")

        new_role = self.validated_data["role"]

        if link.role == PetUser.Role.OWNER and new_role != PetUser.Role.OWNER:
            owner_count = PetUser.objects.filter(
                pet=pet,
                role=PetUser.Role.OWNER,
            ).count()
            if owner_count <= 1:
                raise serializers.ValidationError(
                    "The last owner cannot be changed to family."
                )

        link.role = new_role
        link.save(update_fields=["role"])
        return link