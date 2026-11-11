import uuid
from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone


class UserRole(models.TextChoices):
    STUDENT = 'STUDENT', 'Student'
    RECORDS_STAFF = 'RECORDS_STAFF', 'Records Personnel'
    ADMINISTRATOR = 'ADMIN', 'Administrator'


class StudentProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='student_profile')
    student_id = models.CharField(max_length=50, unique=True)
    course = models.CharField(max_length=150)
    year_level = models.IntegerField(default=1)
    contact_number = models.CharField(max_length=20, blank=True, default='')

    def __str__(self):
        return f"{self.student_id} - {self.user.get_full_name() or self.user.username}"


class StaffProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='staff_profile')
    employee_id = models.CharField(max_length=50, unique=True)
    department = models.CharField(max_length=100, default='Registrar / Records Office')

    def __str__(self):
        return f"{self.employee_id} - {self.user.get_full_name() or self.user.username}"


class DocumentType(models.Model):
    name = models.CharField(max_length=150, unique=True)
    description = models.TextField(blank=True, default='')
    processing_days = models.PositiveIntegerField(default=3)
    fee = models.DecimalField(max_digits=8, decimal_places=2, default=0.00)
    requirements_info = models.TextField(
        blank=True,
        default='Valid Student ID, Clearance, or Proof of Payment.'
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name} (PHP {self.fee})"


class RequestStatus(models.TextChoices):
    SUBMITTED = 'SUBMITTED', 'Submitted'
    UNDER_VERIFICATION = 'UNDER_VERIFICATION', 'Under Verification'
    FOR_PROCESSING = 'FOR_PROCESSING', 'For Processing'
    READY_FOR_RELEASE = 'READY_FOR_RELEASE', 'Ready for Release'
    RELEASED = 'RELEASED', 'Released'
    REJECTED = 'REJECTED', 'Rejected'


class DeliveryMethod(models.TextChoices):
    PICKUP = 'PICKUP', 'Personal Pickup'
    COURIER = 'COURIER', 'Courier / Shipping'
    DIGITAL_COPY = 'DIGITAL_COPY', 'Digital / E-Mail'


class DocumentRequest(models.Model):
    tracking_number = models.CharField(max_length=32, unique=True, editable=False)
    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='document_requests')
    document_type = models.ForeignKey(DocumentType, on_delete=models.PROTECT, related_name='requests')
    copies = models.PositiveIntegerField(default=1)
    purpose = models.TextField()
    
    status = models.CharField(
        max_length=30,
        choices=RequestStatus.choices,
        default=RequestStatus.SUBMITTED
    )
    
    assigned_staff = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_requests'
    )
    
    rejection_reason = models.TextField(blank=True, default='')
    
    # Release recording
    delivery_method = models.CharField(
        max_length=20,
        choices=DeliveryMethod.choices,
        default=DeliveryMethod.PICKUP
    )
    released_at = models.DateTimeField(null=True, blank=True)
    recipient_name = models.CharField(max_length=150, blank=True, default='')
    release_notes = models.TextField(blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.tracking_number:
            # Generate readable unique tracking code: e.g., REQ-202611-ABCD
            year_month = timezone.now().strftime('%Y%m')
            random_part = uuid.uuid4().hex[:6].upper()
            self.tracking_number = f"DOC-{year_month}-{random_part}"
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.tracking_number} - {self.document_type.name} ({self.status})"

    @property
    def assigned_staff_name(self):
        if self.assigned_staff:
            return self.assigned_staff.get_full_name() or self.assigned_staff.username
        return 'Unassigned'

    @property
    def student_name(self):
        if self.student:
            return self.student.get_full_name() or self.student.username
        return 'Unknown'


class RequestAttachment(models.Model):
    request = models.ForeignKey(DocumentRequest, on_delete=models.CASCADE, related_name='attachments')
    file = models.FileField(upload_to='attachments/%Y/%m/')
    file_type = models.CharField(max_length=100, default='Supporting Document')
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Attachment for {self.request.tracking_number}"


class RequestStatusHistory(models.Model):
    request = models.ForeignKey(DocumentRequest, on_delete=models.CASCADE, related_name='history')
    from_status = models.CharField(max_length=30, blank=True, default='')
    to_status = models.CharField(max_length=30)
    changed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    remarks = models.TextField(blank=True, default='')
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['timestamp']

    @property
    def changed_by_name(self):
        if self.changed_by:
            return self.changed_by.get_full_name() or self.changed_by.username
        return 'System'

    def __str__(self):
        return f"{self.request.tracking_number}: {self.from_status} -> {self.to_status}"


class Notification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    request = models.ForeignKey(DocumentRequest, on_delete=models.CASCADE, null=True, blank=True)
    title = models.CharField(max_length=200)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Notification for {self.user.username}: {self.title}"
