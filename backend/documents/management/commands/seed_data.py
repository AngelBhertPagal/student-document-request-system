from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from documents.models import (
    StudentProfile,
    StaffProfile,
    DocumentType,
    DocumentRequest,
    RequestStatus,
    DeliveryMethod,
    RequestStatusHistory,
    Notification,
)


class Command(BaseCommand):
    help = 'Seeds initial document types and test users for demonstration'

    def handle(self, *args, **kwargs):
        self.stdout.write("Seeding data...")

        # 1. Superuser / Admin
        admin_user, created = User.objects.get_or_create(
            username='admin',
            defaults={
                'email': 'admin@univ.edu.ph',
                'first_name': 'System',
                'last_name': 'Administrator',
                'is_staff': True,
                'is_superuser': True,
            }
        )
        if created:
            admin_user.set_password('admin123')
            admin_user.save()
            StaffProfile.objects.create(
                user=admin_user,
                employee_id='EMP-001',
                department='Registrar Office'
            )
            self.stdout.write(self.style.SUCCESS("Created admin user: admin / admin123"))

        # 2. Records Staff
        staff_user, created = User.objects.get_or_create(
            username='staff',
            defaults={
                'email': 'staff@univ.edu.ph',
                'first_name': 'Maria',
                'last_name': 'Santos',
                'is_staff': True,
            }
        )
        if created:
            staff_user.set_password('staff123')
            staff_user.save()
            StaffProfile.objects.create(
                user=staff_user,
                employee_id='EMP-002',
                department='Records Section'
            )
            self.stdout.write(self.style.SUCCESS("Created staff user: staff / staff123"))

        # 3. Student
        student_user, created = User.objects.get_or_create(
            username='student1',
            defaults={
                'email': 'juan.delacruz@student.univ.edu.ph',
                'first_name': 'Juan',
                'last_name': 'Dela Cruz',
            }
        )
        if created:
            student_user.set_password('student123')
            student_user.save()
            StudentProfile.objects.create(
                user=student_user,
                student_id='2023-10492',
                course='Bachelor of Science in Information Technology',
                year_level=4,
                contact_number='09171234567'
            )
            self.stdout.write(self.style.SUCCESS("Created student user: student1 / student123"))

        # 4. Document Types
        catalog = [
            {
                'name': 'Certificate of Enrollment (COE)',
                'description': 'Certifies current active enrollment and registered academic units.',
                'processing_days': 3,
                'fee': 50.00,
                'requirements_info': 'Copy of current semester registration form or validated student ID.'
            },
            {
                'name': 'Official Transcript of Records (TOR)',
                'description': 'Official certified copy of all collegiate academic records and subjects taken.',
                'processing_days': 7,
                'fee': 150.00,
                'requirements_info': 'University clearance and documentary stamp.'
            },
            {
                'name': 'Certificate of Grades (COG)',
                'description': 'Summary of grades obtained for a specific semester or academic year.',
                'processing_days': 3,
                'fee': 50.00,
                'requirements_info': 'Valid Student ID.'
            },
            {
                'name': 'Certificate of Good Moral Character',
                'description': 'Issued by the Office of Student Affairs / Registrar verifying discipline standing.',
                'processing_days': 3,
                'fee': 75.00,
                'requirements_info': 'Student disciplinary clearance.'
            },
            {
                'name': 'Honorable Dismissal / Transfer Credential',
                'description': 'Document released to students transferring to another academic institution.',
                'processing_days': 5,
                'fee': 100.00,
                'requirements_info': 'Complete university exit clearance and surrender of student ID.'
            },
        ]

        for item in catalog:
            doc_type, _ = DocumentType.objects.get_or_create(
                name=item['name'],
                defaults=item
            )
            self.stdout.write(f"Document Type: {doc_type.name}")

        # 5. Create initial demo requests for student1
        doc_tor = DocumentType.objects.get(name__icontains='Transcript')
        doc_coe = DocumentType.objects.get(name__icontains='Enrollment')

        req1, created1 = DocumentRequest.objects.get_or_create(
            student=student_user,
            document_type=doc_tor,
            purpose='Employment application requirement',
            defaults={
                'copies': 2,
                'status': RequestStatus.FOR_PROCESSING,
                'assigned_staff': staff_user,
                'delivery_method': DeliveryMethod.PICKUP,
            }
        )
        if created1:
            RequestStatusHistory.objects.create(
                request=req1,
                from_status='',
                to_status=RequestStatus.SUBMITTED,
                changed_by=student_user,
                remarks='Submitted online request'
            )
            RequestStatusHistory.objects.create(
                request=req1,
                from_status=RequestStatus.SUBMITTED,
                to_status=RequestStatus.FOR_PROCESSING,
                changed_by=staff_user,
                remarks='Requirements verified complete. Sent for processing.'
            )

        req2, created2 = DocumentRequest.objects.get_or_create(
            student=student_user,
            document_type=doc_coe,
            purpose='DOST Scholarship renewal',
            defaults={
                'copies': 1,
                'status': RequestStatus.READY_FOR_RELEASE,
                'assigned_staff': staff_user,
                'delivery_method': DeliveryMethod.PICKUP,
            }
        )
        if created2:
            RequestStatusHistory.objects.create(
                request=req2,
                from_status='',
                to_status=RequestStatus.SUBMITTED,
                changed_by=student_user,
                remarks='Submitted online request'
            )
            RequestStatusHistory.objects.create(
                request=req2,
                from_status=RequestStatus.SUBMITTED,
                to_status=RequestStatus.READY_FOR_RELEASE,
                changed_by=staff_user,
                remarks='Document printed, stamped, and ready for pickup at Counter 2.'
            )
            Notification.objects.create(
                user=student_user,
                request=req2,
                title='Document Ready for Release',
                message='Your Certificate of Enrollment is ready for claim at Registrar Counter 2.'
            )

        self.stdout.write(self.style.SUCCESS("Successfully seeded initial data!"))
