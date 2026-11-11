from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.db.models import Q
from django.utils import timezone

from .models import (
    DocumentRequest,
    RequestStatus,
    RequestStatusHistory,
    Notification,
)


def staff_login_view(request):
    """Staff portal sign-in view."""
    if request.user.is_authenticated and (request.user.is_staff or hasattr(request.user, 'staff_profile')):
        return redirect('staff-dashboard')

    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)

        if user is not None:
            if user.is_staff or hasattr(user, 'staff_profile') or user.is_superuser:
                login(request, user)
                messages.success(request, f"Welcome back, {user.get_full_name() or user.username}!")
                return redirect('staff-dashboard')
            else:
                messages.error(request, "Access restricted to authorized records personnel and administrators.")
        else:
            messages.error(request, "Invalid username or password.")

    return render(request, 'staff/login.html')


def staff_logout_view(request):
    """Sign out of staff portal."""
    logout(request)
    messages.info(request, "You have been logged out of the staff portal.")
    return redirect('staff-login')


@login_required(login_url='staff-login')
def staff_dashboard_view(request):
    """Staff processing queue and statistics dashboard."""
    user = request.user
    if not (user.is_staff or hasattr(user, 'staff_profile') or user.is_superuser):
        messages.error(request, "You do not have permission to access the staff dashboard.")
        return redirect('staff-login')

    queryset = DocumentRequest.objects.all().select_related('document_type', 'student', 'student__student_profile', 'assigned_staff')

    # Status filter
    status_filter = request.GET.get('status')
    if status_filter and status_filter in RequestStatus.values:
        queryset = queryset.filter(status=status_filter)

    # Search filter
    search_query = request.GET.get('search', '').strip()
    if search_query:
        queryset = queryset.filter(
            Q(tracking_number__icontains=search_query) |
            Q(student__username__icontains=search_query) |
            Q(student__first_name__icontains=search_query) |
            Q(student__last_name__icontains=search_query) |
            Q(student__student_profile__student_id__icontains=search_query) |
            Q(document_type__name__icontains=search_query)
        )

    # Compute KPI statistics
    all_requests = DocumentRequest.objects.all()
    stats = {
        'total': all_requests.count(),
        'submitted': all_requests.filter(status=RequestStatus.SUBMITTED).count(),
        'under_verification': all_requests.filter(status=RequestStatus.UNDER_VERIFICATION).count(),
        'for_processing': all_requests.filter(status=RequestStatus.FOR_PROCESSING).count(),
        'ready_for_release': all_requests.filter(status=RequestStatus.READY_FOR_RELEASE).count(),
        'released': all_requests.filter(status=RequestStatus.RELEASED).count(),
        'rejected': all_requests.filter(status=RequestStatus.REJECTED).count(),
    }

    return render(request, 'staff/dashboard.html', {
        'requests': queryset,
        'stats': stats,
        'current_status': status_filter,
        'search_query': search_query,
    })


@login_required(login_url='staff-login')
def staff_request_detail_view(request, pk):
    """Detail view for records personnel to review and process a request."""
    user = request.user
    if not (user.is_staff or hasattr(user, 'staff_profile') or user.is_superuser):
        return redirect('staff-login')

    doc_request = get_object_or_404(
        DocumentRequest.objects.select_related('document_type', 'student', 'student__student_profile', 'assigned_staff').prefetch_related('history__changed_by', 'attachments'),
        pk=pk
    )

    return render(request, 'staff/request_detail.html', {
        'req': doc_request,
    })


@login_required(login_url='staff-login')
def staff_request_action_view(request, pk):
    """Handles workflow state transitions performed by staff."""
    user = request.user
    if not (user.is_staff or hasattr(user, 'staff_profile') or user.is_superuser):
        return redirect('staff-login')

    doc_request = get_object_or_404(DocumentRequest, pk=pk)
    old_status = doc_request.status

    if request.method == 'POST':
        action_type = request.POST.get('action_type')
        remarks = request.POST.get('remarks', '').strip()

        if action_type == 'START_VERIFICATION':
            doc_request.status = RequestStatus.UNDER_VERIFICATION
            doc_request.assigned_staff = user
            doc_request.save()
            RequestStatusHistory.objects.create(
                request=doc_request,
                from_status=old_status,
                to_status=RequestStatus.UNDER_VERIFICATION,
                changed_by=user,
                remarks="Staff initiated verification of submitted requirements."
            )
            Notification.objects.create(
                user=doc_request.student,
                request=doc_request,
                title=f"Request {doc_request.tracking_number} Under Verification",
                message=f"Records personnel ({user.get_full_name() or user.username}) has started verifying your request."
            )
            messages.success(request, f"Request {doc_request.tracking_number} is now Under Verification.")

        elif action_type == 'APPROVE_FOR_PROCESSING':
            doc_request.status = RequestStatus.FOR_PROCESSING
            doc_request.assigned_staff = user
            doc_request.save()
            RequestStatusHistory.objects.create(
                request=doc_request,
                from_status=old_status,
                to_status=RequestStatus.FOR_PROCESSING,
                changed_by=user,
                remarks=remarks or "Requirements verified and approved. Sent for document printing and certification."
            )
            Notification.objects.create(
                user=doc_request.student,
                request=doc_request,
                title=f"Request {doc_request.tracking_number} Processing",
                message="Your request has been verified and is now being printed and prepared."
            )
            messages.success(request, f"Request {doc_request.tracking_number} approved for processing.")

        elif action_type == 'MARK_READY':
            doc_request.status = RequestStatus.READY_FOR_RELEASE
            doc_request.assigned_staff = user
            doc_request.save()
            RequestStatusHistory.objects.create(
                request=doc_request,
                from_status=old_status,
                to_status=RequestStatus.READY_FOR_RELEASE,
                changed_by=user,
                remarks=remarks or "Document printed and stamped. Ready for pickup."
            )
            Notification.objects.create(
                user=doc_request.student,
                request=doc_request,
                title=f"Document Ready for Release! ({doc_request.tracking_number})",
                message=f"Your {doc_request.document_type.name} is ready for release! {remarks}"
            )
            messages.success(request, f"Request {doc_request.tracking_number} marked Ready for Release.")

        elif action_type == 'RECORD_RELEASE':
            recipient_name = request.POST.get('recipient_name', '').strip()
            delivery_method = request.POST.get('delivery_method')
            release_notes = request.POST.get('release_notes', '').strip()

            doc_request.status = RequestStatus.RELEASED
            doc_request.released_at = timezone.now()
            doc_request.recipient_name = recipient_name or doc_request.student.get_full_name() or doc_request.student.username
            if delivery_method:
                doc_request.delivery_method = delivery_method
            doc_request.release_notes = release_notes
            doc_request.assigned_staff = user
            doc_request.save()

            RequestStatusHistory.objects.create(
                request=doc_request,
                from_status=old_status,
                to_status=RequestStatus.RELEASED,
                changed_by=user,
                remarks=f"Official release transaction recorded. Recipient: {doc_request.recipient_name}. Delivery: {doc_request.get_delivery_method_display()}."
            )
            Notification.objects.create(
                user=doc_request.student,
                request=doc_request,
                title="Document Released",
                message=f"Your {doc_request.document_type.name} has been officially released to {doc_request.recipient_name}."
            )
            messages.success(request, f"Release transaction recorded for {doc_request.tracking_number}!")

        elif action_type == 'REJECT':
            rejection_reason = request.POST.get('rejection_reason', '').strip()
            doc_request.status = RequestStatus.REJECTED
            doc_request.rejection_reason = rejection_reason or "Requirements incomplete or invalid."
            doc_request.assigned_staff = user
            doc_request.save()

            RequestStatusHistory.objects.create(
                request=doc_request,
                from_status=old_status,
                to_status=RequestStatus.REJECTED,
                changed_by=user,
                remarks=f"Request rejected. Reason: {doc_request.rejection_reason}"
            )
            Notification.objects.create(
                user=doc_request.student,
                request=doc_request,
                title=f"Request {doc_request.tracking_number} Deficient / Rejected",
                message=f"Your request was rejected. Reason: {doc_request.rejection_reason}"
            )
            messages.warning(request, f"Request {doc_request.tracking_number} was rejected.")

    return redirect('staff-request-detail', pk=pk)
