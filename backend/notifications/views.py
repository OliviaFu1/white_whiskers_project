from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Notification
from .serializers import NotificationSerializer



class IsOwner(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        return obj.user_id == request.user.id


class NotificationViewSet(viewsets.ModelViewSet):
    """
    GET /api/notifications/?unread=true
    GET /api/notifications/?pet_id=123
    PATCH /api/notifications/{id}/mark-read/
    POST /api/notifications/mark-all-read/
    POST /api/notifications/  (create)
    """
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = Notification.objects.filter(user=self.request.user)

        unread = self.request.query_params.get("unread")
        if unread in ("true", "1", "yes"):
            qs = qs.filter(is_read=False)

        pet_id = self.request.query_params.get("pet_id")
        if pet_id:
            qs = qs.filter(pet_id=pet_id)

        return qs

    def perform_create(self, serializer):
        # Force user = current user (client can't spoof).
        serializer.save(user=self.request.user)

    @action(detail=True, methods=["patch"], url_path="mark-read")
    def mark_read(self, request, pk=None):
        notif = self.get_object()
        if not notif.is_read:
            notif.is_read = True
            notif.save(update_fields=["is_read"])
        return Response(self.get_serializer(notif).data)
    
    # TODO: change generate test to real production
    @action(detail=False, methods=["post"])
    def generate_test(self, request):
        Notification.objects.create(
            user=request.user,
            title="Generated Notification",
            message="This was created from backend",
            notification_type="birthday",
        )
        return Response({"status": "created"})

    # @action(detail=False, methods=["post"], url_path="mark-all-read")
    # def mark_all_read(self, request):
    #     Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
    #     return Response({"ok": True}, status=status.HTTP_200_OK)