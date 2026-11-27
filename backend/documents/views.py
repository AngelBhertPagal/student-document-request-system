from rest_framework import status, viewsets, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.db.models import Count
from django.utils import timezone
from drf_spectacular.utils import extend_schema, OpenApiParameter

from .models import (
    DocumentType,
    DocumentRequest,
    RequestAttachment,
    RequestStatusHistory,
    Notification,
    RequestStatus,
    DeliveryMethod,
)
from .serializers import (
    UserSerializer,
    RegisterSerializer,
    DocumentTypeSerializer,
    DocumentRequestListSerializer,
    DocumentRequestDetailSerializer,
    CreateDocumentRequestSerializer,
    RequestStatusHistorySerializer,
    NotificationSerializer,
)


@extend_schema(request=RegisterSerializer, responses={201: UserSerializer})
@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register_student(request):
    """Register a new student and generate authentication token."""
    serializer = RegisterSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            'token': token.key,
            'user': UserSerializer(user).data,
            'message': 'Registration successful'
        }, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(
    request={'application/json': {'type': 'object', 'properties': {'username': {'type': 'string'}, 'password': {'type': 'string'}}}},
    responses={200: {'type': 'object', 'properties': {'token': {'type': 'string'}, 'user': UserSerializer}}}
)
@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def login_view(request):
    """Authenticate user with username and password, returns token and role."""
    username = request.data.get('username')
    password = request.data.get('password')

    if not username or not password:
        return Response({'detail': 'Please provide both username and password.'}, status=status.HTTP_400_BAD_REQUEST)

    user = authenticate(username=username, password=password)
    if not user:
        return Response({'detail': 'Invalid credentials.'}, status=status.HTTP_401_UNAUTHORIZED)

    token, _ = Token.objects.get_or_create(user=user)
    return Response({
        'token': token.key,
        'user': UserSerializer(user).data
    })


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def logout_view(request):
    """Revoke the current user's authentication token."""
    Token.objects.filter(user=request.user).delete()
    return Response({'detail': 'Successfully logged out.'}, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def current_user_profile(request):
    """Get profile of currently logged-in user."""
    return Response(UserSerializer(request.user).data)


class DocumentTypeViewSet(viewsets.ReadOnlyModelViewSet):
    """List available document types for requests."""
    queryset = DocumentType.objects.filter(is_active=True)
    serializer_class = DocumentTypeSerializer
    permission_classes = [permissions.AllowAny]


ALLOWED_STATUS_TRANSITIONS = {
    RequestStatus.SUBMITTED: {RequestStatus.UNDER_VERIFICATION, RequestStatus.REJECTED},
    RequestStatus.UNDER_VERIFICATION: {RequestStatus.FOR_PROCESSING, RequestStatus.REJECTED},
    RequestStatus.FOR_PROCESSING: {RequestStatus.READY_FOR_RELEASE, RequestStatus.REJECTED},
    RequestStatus.READY_FOR_RELEASE: {RequestStatus.RELEASED, RequestStatus.REJECTED},
    RequestStatus.RELEASED: set(),
    RequestStatus.REJECTED: set(),
}


def _is_staff_user(user):
    return bool(user and (user.is_staff or user.is_superuser or hasattr(user, 'staff_profile')))


class DocumentRequestViewSet(viewsets.ModelViewSet):
    """Manage student document requests, status transitions, and history."""
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = DocumentRequest.objects.all().select_related('document_type', 'student', 'student__student_profile')

        # Students only see their own requests; staff and admin see all
        if not _is_staff_user(user):
            queryset = queryset.filter(student=user)

        # Optional filters
        req_status = self.request.query_params.get('status')
        if req_status:
            queryset = queryset.filter(status=req_status)

        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(tracking_number__icontains=search)

        return queryset

    def get_serializer_class(self):
        if self.action == 'create':
            return CreateDocumentRequestSerializer
        elif self.action == 'retrieve':
            return DocumentRequestDetailSerializer
        return DocumentRequestListSerializer

    def perform_create(self, serializer):
        serializer.save(student=self.request.user)

    def update(self, request, *args, **kwargs):
        if not _is_staff_user(request.user):
            return Response(
                {'detail': 'Students cannot directly modify submitted requests.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().update(request, *args, **kwargs)

    def partial_update(self, request, *args, **kwargs):
        if not _is_staff_user(request.user):
            return Response(
                {'detail': 'Students cannot directly modify submitted requests.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().partial_update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        if not _is_staff_user(request.user):
            return Response(
                {'detail': 'Students cannot delete submitted requests.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().destroy(request, *args, **kwargs)

    @action(detail=True, methods=['post'], url_path='update-status', permission_classes=[permissions.IsAuthenticated])
    def update_status(self, request, pk=None):
        """Update the workflow status of a request (Staff/Admin only)."""
        doc_request = self.get_object()
        user = request.user

        # Only staff or admins can update workflow status
        if not _is_staff_user(user):
            return Response({'detail': 'Only records personnel or administrators can update request status.'}, status=status.HTTP_403_FORBIDDEN)

        new_status = request.data.get('status')
        remarks = request.data.get('remarks', '')
        rejection_reason = request.data.get('rejection_reason', '')
        delivery_method = request.data.get('delivery_method')
        recipient_name = request.data.get('recipient_name', '')
        release_notes = request.data.get('release_notes', '')

        if new_status not in RequestStatus.values:
            return Response({'detail': f'Invalid status. Allowed values: {RequestStatus.values}'}, status=status.HTTP_400_BAD_REQUEST)

        old_status = doc_request.status
        allowed_next = ALLOWED_STATUS_TRANSITIONS.get(old_status, set())
        if new_status not in allowed_next:
            return Response(
                {
                    'detail': f'Invalid workflow transition from {old_status} to {new_status}. '
                              f'Allowed next statuses: {sorted(allowed_next) if allowed_next else "None (terminal state)"}.'
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        doc_request.status = new_status
        doc_request.assigned_staff = user

        if new_status == RequestStatus.REJECTED:
            doc_request.rejection_reason = rejection_reason or remarks or 'Requirements incomplete or invalid.'

        if new_status == RequestStatus.RELEASED:
            doc_request.released_at = timezone.now()
            doc_request.recipient_name = recipient_name or doc_request.student.get_full_name() or doc_request.student.username
            if delivery_method:
                doc_request.delivery_method = delivery_method
            if release_notes:
                doc_request.release_notes = release_notes

        doc_request.save()

        # Record history
        RequestStatusHistory.objects.create(
            request=doc_request,
            from_status=old_status,
            to_status=new_status,
            changed_by=user,
            remarks=remarks or f"Status changed to {doc_request.get_status_display()}."
        )

        # Notify student
        Notification.objects.create(
            user=doc_request.student,
            request=doc_request,
            title=f"Request {doc_request.tracking_number} Status Update",
            message=f"Your request for {doc_request.document_type.name} is now: {doc_request.get_status_display()}."
        )

        return Response(DocumentRequestDetailSerializer(doc_request, context={'request': request}).data)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        """Return counts and metrics for admin dashboards and reports."""
        user = request.user
        queryset = DocumentRequest.objects.all()

        if not (user.is_staff or user.is_superuser or hasattr(user, 'staff_profile')):
            queryset = queryset.filter(student=user)

        total = queryset.count()
        submitted = queryset.filter(status=RequestStatus.SUBMITTED).count()
        under_verification = queryset.filter(status=RequestStatus.UNDER_VERIFICATION).count()
        for_processing = queryset.filter(status=RequestStatus.FOR_PROCESSING).count()
        ready_for_release = queryset.filter(status=RequestStatus.READY_FOR_RELEASE).count()
        released = queryset.filter(status=RequestStatus.RELEASED).count()
        rejected = queryset.filter(status=RequestStatus.REJECTED).count()

        return Response({
            'total_requests': total,
            'submitted': submitted,
            'under_verification': under_verification,
            'for_processing': for_processing,
            'ready_for_release': ready_for_release,
            'released': released,
            'rejected': rejected,
        })


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    """View and acknowledge in-app notifications."""
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)

    @action(detail=True, methods=['post'])
    def mark_as_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save()
        return Response({'status': 'marked as read'})

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({'status': 'all marked as read'})
