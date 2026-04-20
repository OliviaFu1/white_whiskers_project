from django.conf import settings
from django.core.mail import EmailMessage
from django.utils import timezone

from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from pets.models import PetUser
from accounts.models import UserSpecialist
from .models import PetAssessment
from .serializers import PetAssessmentSerializer, ShareAssessmentSerializer


class PetAssessmentViewSet(
    mixins.CreateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.ReadOnlyModelViewSet,
):
    serializer_class = PetAssessmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = PetAssessment.objects.filter(
            pet__petuser__user=self.request.user
        ).distinct()

        pet_id = self.request.query_params.get("pet_id")
        if pet_id:
            qs = qs.filter(pet_id=pet_id)

        return qs.select_related("pet", "owner").order_by("-submitted_at")

    def perform_create(self, serializer):
        pet = serializer.validated_data["pet"]

        linked = PetUser.objects.filter(
            pet=pet,
            user=self.request.user,
        ).exists()
        if not linked:
            raise PermissionDenied("You are not linked to this pet.")

        serializer.save(owner=self.request.user)

    @action(detail=True, methods=["post"], url_path="share")
    def share(self, request, pk=None):
        assessment = self.get_object()
        if assessment.owner_id != request.user.id:
            raise PermissionDenied("Only the user who completed this assessment can share it.")

        serializer = ShareAssessmentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        recipient_name, recipient_email = self._resolve_account_recipient(
            user=request.user,
            recipient_type=data["recipient_type"],
            recipient_id=data["recipient_id"],
        )

        if not recipient_email:
            raise ValidationError("Selected recipient does not have an email address.")

        owner_name = self._display_name(assessment.owner)
        owner_email = (getattr(assessment.owner, "email", "") or "").strip()

        submitted_at_local = timezone.localtime(assessment.submitted_at)
        submitted_date = submitted_at_local.strftime("%m/%d/%Y")

        subject = (
            f"Updated Crossroads Personal Assessment - "
            f"{owner_name} - {assessment.pet.name}"
        )

        pet_info = self._pet_display(assessment.pet)
        pet_line = (
            f"Pet: {assessment.pet.name} ({pet_info})"
            if pet_info
            else f"Pet: {assessment.pet.name}"
        )

        lines = [
            pet_line,
            f"Assessment Date: {submitted_date}",
            f"Assessment Done By: {owner_name} ({owner_email})",
            f"Recipient: {recipient_name}",
        ]

        lines.extend([
            "",
            f"Heart Score: {assessment.heart_score}",
            f"Condition Score: {assessment.condition_score}",
            f"Significantly Challenged: {'Yes' if assessment.significantly_challenged else 'No'}",
            "",
            "Good Day / Bad Day Summary",
        ])

        MIN_28_DAY_INPUTS = 15
        MIN_7_DAY_INPUTS = 4

        all_time_good_pct = data.get("all_time_good_pct")
        if all_time_good_pct is not None:
            lines.append(f"- All-time: {all_time_good_pct}% good")

        past_28_days_good_pct = data.get("past_28_days_good_pct")
        if past_28_days_good_pct is not None:
            lines.append(f"- Past 28 days: {past_28_days_good_pct}% good")
        else:
            lines.append(f"- Past 28 days: less than {MIN_28_DAY_INPUTS} inputs")

        past_7_days_good_pct = data.get("past_7_days_good_pct")
        if past_7_days_good_pct is not None:
            lines.append(f"- Past 7 days: {past_7_days_good_pct}% good")
        else:
            lines.append(f"- Past 7 days: less than {MIN_7_DAY_INPUTS} inputs")

        questions_comments = (data.get("questions_comments") or "").strip()
        if questions_comments:
            lines.extend([
                "",
                "Questions / Comments",
                questions_comments,
            ])

        detail_lines = self._build_assessment_detail_lines(
            assessment=assessment,
            owner_name=owner_name,
        )
        if detail_lines:
            lines.extend(["", *detail_lines])
        
        lines.extend([""])
        lines.append(f"For questions about this assessment, please contact: {owner_name} ({owner_email})")

        body = "\n".join(lines)

        email = EmailMessage(
            subject=subject,
            body=body,
            from_email=getattr(settings, "DEFAULT_FROM_EMAIL", None),
            to=[recipient_email],
            reply_to=[owner_email] if owner_email else None,
        )
        email.send(fail_silently=False)

        return Response(
            {"detail": "Assessment shared successfully."},
            status=status.HTTP_200_OK,
        )

    def _pet_display(self, pet):
        parts = []

        if pet.birthdate:
            today = timezone.now().date()
            age_years = (today - pet.birthdate).days // 365
            if age_years > 0:
                parts.append(f"{age_years}-year-old")

        if pet.breed_text:
            parts.append(pet.breed_text.strip().title())

        if pet.species:
            parts.append(pet.species.strip().title())

        return " ".join(parts)

    def _display_name(self, user):
        name = getattr(user, "name", "")
        if isinstance(name, str) and name.strip():
            return name.strip()

        email = getattr(user, "email", "")
        if isinstance(email, str) and email.strip():
            return email.strip()

        return str(user.pk)

    def _resolve_account_recipient(self, user, recipient_type, recipient_id):
        if recipient_type == "primary":
            if recipient_id != 0:
                raise ValidationError("Primary vet recipient not found.")

            email = (user.primary_vet_email or "").strip()
            if not email:
                raise ValidationError("Primary vet email is missing.")

            name = (user.primary_vet_name or "").strip() or "Primary Vet"
            return name, email

        if recipient_type == "specialist":
            specialist = UserSpecialist.objects.filter(
                user=user,
                id=recipient_id,
            ).first()
            if specialist is None:
                raise ValidationError("Specialist recipient not found.")

            email = (specialist.vet_email or "").strip()
            if not email:
                raise ValidationError("Specialist email is missing.")

            name = (specialist.vet_name or "").strip() or "Specialist"
            return name, email

        raise ValidationError("Invalid recipient type.")
    

    def _build_assessment_detail_lines(self, assessment, owner_name):
        answers = assessment.answers if isinstance(assessment.answers, dict) else {}

        pet_things = self._list_of_strings(answers.get("favorite_pet_things"))
        shared_things = self._list_of_strings(answers.get("favorite_shared_things"))
        favorite_things = pet_things + shared_things

        concerns = self._list_of_strings(answers.get("biggest_concerns"))
        other_concern_text = self._clean(answers.get("other_concern_text"))
        if other_concern_text:
            concerns = [
                other_concern_text if c == "Other" else c
                for c in concerns
            ]

        lines = [
            "Assessment Details",
            "---------------------------",
        ]

        lines.extend(self._bullets("Favorite Things", favorite_things))

        lines.extend([""])
        lines.extend(self._bullets("Biggest Concerns", concerns))
        lines.append(f"Primary Concern Details: {self._value_or_dash(answers.get('concerns_expand'))}")
        lines.append(f"Duration: {self._value_or_dash(answers.get('concern_duration'))}")
        lines.append(f"More Good Days or Bad Days in Last 30 Days: {self._value_or_dash(answers.get('last_30_days'))}")
        lines.append(f"Boundaries: {self._value_or_dash(answers.get('boundaries'))}")

        lines.extend([
            "",
            f"Owner Preference: {self._value_or_dash(answers.get('preference_info'))}",
            f"Owner Understanding: {self._value_or_dash(answers.get('which_best_describes_you'))}",
            f"Patient Preference: {self._value_or_dash(answers.get('pet_tolerance'))}",
            f"Patient Med Success: {self._value_or_dash(answers.get('medicine_success'))}",
            f"Relationship with food these days: {self._value_or_dash(answers.get('food_relationship'))}",
        ])

        lines.extend([
            "",
            "Individual Scores",
        ])

        lines.extend(self._score_block(
            title="Physical Condition",
            score=answers.get("physical_score"),
            explanation=answers.get("physical_explanation"),
        ))
        lines.extend(self._score_block(
            title="Appetite",
            score=answers.get("appetite_score"),
            explanation=answers.get("appetite_explanation"),
        ))
        lines.extend(self._score_block(
            title="Thirst",
            score=answers.get("hydration_score"),
            explanation=answers.get("hydration_explanation"),
        ))
        lines.extend(self._score_block(
            title="Mobility",
            score=answers.get("mobility_score"),
            explanation=answers.get("mobility_explanation"),
        ))
        lines.extend(self._score_block(
            title="Hygiene",
            score=answers.get("cleanliness_score"),
            explanation=answers.get("cleanliness_explanation"),
        ))
        lines.extend(self._score_block(
            title="Cognition",
            score=answers.get("state_of_mind_score"),
            explanation=answers.get("state_of_mind_explanation"),
        ))
        lines.extend(self._score_block(
            title=f"{owner_name}'s State of Mind",
            score=answers.get("owner_state_score"),
            explanation=answers.get("owner_state_explanation"),
        ))

        lines.extend([
            "",
            "Joy of Life",
            f"Explanation: {self._value_or_dash(answers.get('joy_explanation'))}",
        ])

        joy_items = answers.get("joy_items")
        if isinstance(joy_items, list) and joy_items:
            for idx, item in enumerate(joy_items, start=1):
                if not isinstance(item, dict):
                    continue
                label = self._clean(item.get("label")) or f"Favorite activity {idx}"
                status = self._clean(item.get("status")) or "—"
                lines.append(f"- {label}: {status}")
        else:
            lines.append("- —")

        return lines


    def _score_block(self, title, score, explanation):
        return [
            f"- {title} ({self._value_or_dash(score)}): {self._value_or_dash(explanation)}"
    ]

    def _bullets(self, title, items):
        lines = [f"{title}:"]
        if not items:
            lines.append("- —")
            return lines

        for item in items:
            lines.append(f"- {item}")
        return lines

    def _list_of_strings(self, value):
        if not isinstance(value, list):
            return []
        cleaned = []
        for item in value:
            text = self._clean(item)
            if text:
                cleaned.append(text)
        return cleaned

    def _clean(self, value):
        if value is None:
            return ""
        return str(value).strip()

    def _value_or_dash(self, value):
        text = self._clean(value)
        return text if text else "—"