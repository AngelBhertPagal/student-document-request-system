from rest_framework import serializers
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from .models import (
    StudentProfile,
    StaffProfile,
    DocumentType,
    DocumentRequest,
    RequestAttachment,
    RequestStatusHistory,
    Notification,
    RequestStatus,
    DeliveryMethod,
)


class StudentProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudentProfile
        fields = ['student_id', 'course', 'year_level', 'contact_number']


class UserSerializer(serializers.ModelSerializer):
    student_profile = StudentProfileSerializer(read_only=True)
    role = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'role', 'student_profile']

    def get_role(self, obj):
        if obj.is_superuser or obj.is_staff:
            return 'ADMIN'
        if hasattr(obj, 'staff_profile'):
            return 'RECORDS_STAFF'
        return 'STUDENT'


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    student_id = serializers.CharField(write_only=True, required=True)
    course = serializers.CharField(write_only=True, required=True)
    year_level = serializers.IntegerField(write_only=True, default=1)
    contact_number = serializers.CharField(write_only=True, required=False, default='')

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'first_name', 'last_name', 'student_id', 'course', 'year_level', 'contact_number']

    def create(self, validated_data):
        student_id = validated_data.pop('student_id')
        course = validated_data.pop('course')
        year_level = validated_data.pop('year_level')
        contact_number = validated_data.pop('contact_number')

        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data.get('email', ''),
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
        )

        StudentProfile.objects.create(
            user=user,
            student_id=student_id,
            course=course,
            year_level=year_level,
            contact_number=contact_number,
        )

        return user


class DocumentTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = DocumentType
        fields = ['id', 'name', 'description', 'processing_days', 'fee', 'requirements_info', 'is_active']


class RequestAttachmentSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = RequestAttachment
        fields = ['id', 'file', 'file_url', 'file_type', 'uploaded_at']

    def get_file_url(self, obj):
        request = self.context.get('request')
        if obj.file and request:
            return request.build_absolute_uri(obj.file.url)
        elif obj.file:
            return obj.file.url
        return None


class RequestStatusHistorySerializer(serializers.ModelSerializer):
    changed_by_name = serializers.SerializerMethodField()

    class Meta:
        model = RequestStatusHistory
        fields = ['id', 'from_status', 'to_status', 'changed_by_name', 'remarks', 'timestamp']

    def get_changed_by_name(self, obj):
        if obj.changed_by:
            return obj.changed_by.get_full_name() or obj.changed_by.username
        return 'System'


class DocumentRequestListSerializer(serializers.ModelSerializer):
    document_type_name = serializers.CharField(source='document_type.name', read_only=True)
    document_type_fee = serializers.DecimalField(source='document_type.fee', max_digits=8, decimal_places=2, read_only=True)
    student_name = serializers.SerializerMethodField()
    student_id = serializers.CharField(source='student.student_profile.student_id', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = DocumentRequest
        fields = [
            'id',
            'tracking_number',
            'document_type',
            'document_type_name',
            'document_type_fee',
            'student_name',
            'student_id',
            'copies',
            'purpose',
            'status',
            'status_display',
            'delivery_method',
            'created_at',
            'updated_at',
            'released_at',
        ]

    def get_student_name(self, obj):
        return obj.student.get_full_name() or obj.student.username


class DocumentRequestDetailSerializer(serializers.ModelSerializer):
    document_type = DocumentTypeSerializer(read_only=True)
    student = UserSerializer(read_only=True)
    attachments = RequestAttachmentSerializer(many=True, read_only=True)
    history = RequestStatusHistorySerializer(many=True, read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = DocumentRequest
        fields = [
            'id',
            'tracking_number',
            'student',
            'document_type',
            'copies',
            'purpose',
            'status',
            'status_display',
            'assigned_staff',
            'rejection_reason',
            'delivery_method',
            'released_at',
            'recipient_name',
            'release_notes',
            'created_at',
            'updated_at',
            'attachments',
            'history',
        ]


class CreateDocumentRequestSerializer(serializers.ModelSerializer):
    attachment = serializers.FileField(required=False, write_only=True)
    tracking_number = serializers.CharField(read_only=True)
    id = serializers.IntegerField(read_only=True)
    status = serializers.CharField(read_only=True)
    created_at = serializers.DateTimeField(read_only=True)

    ALLOWED_EXTENSIONS = ('.pdf', '.jpg', '.jpeg', '.png')
    MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024  # 5 MB

    class Meta:
        model = DocumentRequest
        fields = [
            'id',
            'tracking_number',
            'document_type',
            'copies',
            'purpose',
            'delivery_method',
            'status',
            'created_at',
            'attachment',
        ]

    def validate_copies(self, value):
        if value < 1 or value > 10:
            raise serializers.ValidationError('Number of copies must be between 1 and 10.')
        return value

    def validate_attachment(self, value):
        if value is None:
            return value
        name_lower = value.name.lower()
        if not any(name_lower.endswith(ext) for ext in self.ALLOWED_EXTENSIONS):
            raise serializers.ValidationError(
                'Unsupported file type. Allowed formats: PDF, JPG, JPEG, PNG.'
            )
        if value.size > self.MAX_FILE_SIZE_BYTES:
            raise serializers.ValidationError('File size must not exceed 5 MB.')
        return value

    def create(self, validated_data):
        attachment_file = validated_data.pop('attachment', None)
        request_obj = DocumentRequest.objects.create(**validated_data)

        # Record initial status in history
        RequestStatusHistory.objects.create(
            request=request_obj,
            from_status='',
            to_status=RequestStatus.SUBMITTED,
            changed_by=validated_data.get('student'),
            remarks='Document request submitted by student.'
        )

        # Save attachment if provided
        if attachment_file:
            RequestAttachment.objects.create(
                request=request_obj,
                file=attachment_file,
                file_type='Supporting Requirement'
            )

        # Notify student
        Notification.objects.create(
            user=request_obj.student,
            request=request_obj,
            title='Request Submitted',
            message=f"Your request {request_obj.tracking_number} for {request_obj.document_type.name} has been received."
        )

        return request_obj


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'title', 'message', 'is_read', 'created_at', 'request']
