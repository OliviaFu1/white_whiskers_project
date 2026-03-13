from rest_framework import permissions

class JournalVisibilityPermission(permissions.BasePermission):
    """
    - SAFE methods (GET/HEAD/OPTIONS):
        - shared: anyone authenticated
        - private: author only
    - WRITE methods (POST/PATCH/PUT/DELETE):
        - author only
    """

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        # Writes: author only
        if request.method not in permissions.SAFE_METHODS:
            return obj.author_id == request.user.id

        # Reads:
        if obj.visibility == "shared":
            return True
        return obj.author_id == request.user.id


class IsAuthorForWriteOtherwiseReadOnly(permissions.BasePermission):
    """
    Use for DailyCheckin:
    - everyone authenticated can read (for calendar viewing)
    - only author can edit/delete
    """

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.author_id == request.user.id