from django.contrib import admin
from django.utils import timezone
from .models import (
    StudentProfile,
    StaffProfile,
    DocumentType,
    DocumentRequest,
    RequestAttachment,
    RequestStatusHistory,
    Notification,
    RequestStatus,
)


class RequestAttachmentInline(admin.TabularInline):
    model = RequestAttachment
    extra = 0
    readonly_fields = ('uploaded_at',)


class RequestStatusHistoryInline(admin.TabularInline):
    model = RequestStatusHistory
    extra = 0
    readonly_fields = ('from_status', 'to_status', 'changed_by', 'remarks', 'timestamp')
    can_delete = False


@admin.register(DocumentType)
class DocumentTypeAdmin(admin.ModelAdmin):
    list_display = ('name', 'processing_days', 'fee', 'is_active', 'created_at')
    list_filter = ('is_active',)
    search_fields = ('name', 'description')


@admin.register(DocumentRequest)
class DocumentRequestAdmin(admin.ModelAdmin):
    list_display = (
        'tracking_number',
        'student',
        'document_type',
        'status',
        'copies',
        'assigned_staff',
        'delivery_method',
        'created_at',
    )
    list_filter = ('status', 'document_type', 'delivery_method', 'created_at')
    search_fields = ('tracking_number', 'student__username', 'student__first_name', 'student__last_name', 'purpose')
    readonly_fields = ('tracking_number', 'created_at', 'updated_at')
    inlines = [RequestAttachmentInline, RequestStatusHistoryInline]
    actions = [
        'mark_under_verification',
        'mark_for_processing',
        'mark_ready_for_release',
        'mark_released',
    ]

    def save_model(self, request, obj, form, change):
        if change:
            old_obj = DocumentRequest.objects.get(pk=obj.pk)
            if old_obj.status != obj.status:
                RequestStatusHistory.objects.create(
                    request=obj,
                    from_status=old_obj.status,
                    to_status=obj.status,
                    changed_by=request.user,
                    remarks=f"Status changed to {obj.status} via Admin portal."
                )
                Notification.objects.create(
                    user=obj.student,
                    request=obj,
                    title=f"Request {obj.tracking_number} Updated",
                    message=f"Your request for {obj.document_type.name} is now: {obj.get_status_display()}."
                )
        super().save_model(request, obj, form, change)

    @admin.action(description="Mark selected requests as Under Verification")
    def mark_under_verification(self, request, queryset):
        self._batch_update_status(request, queryset, RequestStatus.UNDER_VERIFICATION)

    @admin.action(description="Mark selected requests as For Processing")
    def mark_for_processing(self, request, queryset):
        self._batch_update_status(request, queryset, RequestStatus.FOR_PROCESSING)

    @admin.action(description="Mark selected requests as Ready for Release")
    def mark_ready_for_release(self, request, queryset):
        self._batch_update_status(request, queryset, RequestStatus.READY_FOR_RELEASE)

    @admin.action(description="Mark selected requests as Released")
    def mark_released(self, request, queryset):
        for req in queryset:
            old_status = req.status
            req.status = RequestStatus.RELEASED
            req.released_at = timezone.now()
            if not req.recipient_name:
                req.recipient_name = req.student.get_full_name() or req.student.username
            req.save()
            RequestStatusHistory.objects.create(
                request=req,
                from_status=old_status,
                to_status=RequestStatus.RELEASED,
                changed_by=request.user,
                remarks="Document officially released to student."
            )
            Notification.objects.create(
                user=req.student,
                request=req,
                title="Document Released",
                message=f"Your {req.document_type.name} has been released. Thank you!"
            )

    def _batch_update_status(self, request, queryset, new_status):
        for req in queryset:
            old_status = req.status
            req.status = new_status
            req.save()
            RequestStatusHistory.objects.create(
                request=req,
                from_status=old_status,
                to_status=new_status,
                changed_by=request.user,
                remarks=f"Status batch-updated to {new_status}."
            )
            Notification.objects.create(
                user=req.student,
                request=req,
                title=f"Request {req.tracking_number} Updated",
                message=f"Your request for {req.document_type.name} is now: {req.get_status_display()}."
            )


@admin.register(StudentProfile)
class StudentProfileAdmin(admin.ModelAdmin):
    list_display = ('student_id', 'user', 'course', 'year_level', 'contact_number')
    search_fields = ('student_id', 'user__username', 'user__first_name', 'user__last_name', 'course')


@admin.register(StaffProfile)
class StaffProfileAdmin(admin.ModelAdmin):
    list_display = ('employee_id', 'user', 'department')
    search_fields = ('employee_id', 'user__username', 'department')


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('user', 'title', 'is_read', 'created_at')
    list_filter = ('is_read', 'created_at')
    search_fields = ('user__username', 'title', 'message')
