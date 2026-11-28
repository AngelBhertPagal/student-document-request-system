from datetime import timedelta
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.utils import timezone
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
    help = 'Seeds rich, realistic university data (staff, students, document catalog, and 26+ requests across all workflow stages)'

    def handle(self, *args, **kwargs):
        self.stdout.write("Seeding rich university dataset...")

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
        StaffProfile.objects.get_or_create(
            user=admin_user,
            defaults={'employee_id': 'EMP-001', 'department': 'Registrar Office'}
        )

        # 2. Records Staff Personnel (3 accounts)
        staff_defs = [
            ('staff', 'staff123', 'Maria', 'Santos', 'staff@univ.edu.ph', 'EMP-002', 'Records Section'),
            ('staff2', 'staff123', 'Roberto', 'Reyes', 'roberto.reyes@univ.edu.ph', 'EMP-003', 'Credentials & Release Desk'),
            ('staff3', 'staff123', 'Elena', 'Villanueva', 'elena.villanueva@univ.edu.ph', 'EMP-004', 'Verification Unit'),
        ]
        staff_users = []
        for uname, pwd, fname, lname, email, emp_id, dept in staff_defs:
            u, u_created = User.objects.get_or_create(
                username=uname,
                defaults={
                    'email': email,
                    'first_name': fname,
                    'last_name': lname,
                    'is_staff': True,
                }
            )
            if u_created:
                u.set_password(pwd)
                u.save()
            StaffProfile.objects.get_or_create(
                user=u,
                defaults={'employee_id': emp_id, 'department': dept}
            )
            staff_users.append(u)

        staff1, staff2, staff3 = staff_users

        # 3. Diverse Students (12 accounts across 12 degree programs)
        student_defs = [
            ('student1', 'Juan', 'Dela Cruz', '2023-10492', 'BS Information Technology', 4, '09171234567'),
            ('student2', 'Andrea', 'Mendoza', '2023-10518', 'BS Computer Science', 4, '09182345678'),
            ('student3', 'Carlo', 'Bautista', '2022-09412', 'BS Accountancy', 4, '09193456789'),
            ('student4', 'Patricia', 'Ramos', '2024-11204', 'BS Nursing', 3, '09204567890'),
            ('student5', 'Miguel', 'Torres', '2022-08765', 'BS Civil Engineering', 4, '09215678901'),
            ('student6', 'Sofia', 'Garcia', '2024-11890', 'BS Business Administration', 2, '09226789012'),
            ('student7', 'Daniel', 'Aquino', '2023-10221', 'BS Information Systems', 3, '09237890123'),
            ('student8', 'Camille', 'Navarro', '2025-12045', 'BS Psychology', 2, '09248901234'),
            ('student9', 'Joshua', 'Castillo', '2023-10774', 'BS Hospitality Management', 3, '09259012345'),
            ('student10', 'Bea', 'Soriano', '2022-09110', 'BS Education (Mathematics)', 4, '09260123456'),
            ('student11', 'Mark', 'Fernandez', '2024-11532', 'BS Electrical Engineering', 3, '09271234567'),
            ('student12', 'Katrina', 'Salazar', '2025-12419', 'BS Criminology', 1, '09282345678'),
        ]
        students = []
        for uname, fname, lname, sid, course, yr, phone in student_defs:
            u, u_created = User.objects.get_or_create(
                username=uname,
                defaults={
                    'email': f"{fname.lower()}.{lname.lower().replace(' ', '')}@student.univ.edu.ph",
                    'first_name': fname,
                    'last_name': lname,
                }
            )
            if u_created:
                u.set_password('student123')
                u.save()
            StudentProfile.objects.get_or_create(
                user=u,
                defaults={
                    'student_id': sid,
                    'course': course,
                    'year_level': yr,
                    'contact_number': phone,
                }
            )
            students.append(u)

        # 4. Expanded Academic Document Catalog (10 document types)
        catalog = [
            {
                'name': 'Certificate of Enrollment (COE)',
                'description': 'Certifies current active enrollment and registered academic units.',
                'processing_days': 3,
                'fee': 50.00,
                'requirements_info': 'Copy of current semester registration form or validated student ID.',
            },
            {
                'name': 'Official Transcript of Records (TOR)',
                'description': 'Official certified copy of all collegiate academic records and subjects taken.',
                'processing_days': 7,
                'fee': 150.00,
                'requirements_info': 'University clearance and documentary stamp.',
            },
            {
                'name': 'Certificate of Grades (COG)',
                'description': 'Summary of grades obtained for a specific semester or academic year.',
                'processing_days': 3,
                'fee': 50.00,
                'requirements_info': 'Valid Student ID.',
            },
            {
                'name': 'Certificate of Good Moral Character',
                'description': 'Issued by the Office of Student Affairs / Registrar verifying disciplinary standing.',
                'processing_days': 3,
                'fee': 75.00,
                'requirements_info': 'Student disciplinary clearance.',
            },
            {
                'name': 'Honorable Dismissal / Transfer Credential',
                'description': 'Document released to students transferring to another academic institution.',
                'processing_days': 5,
                'fee': 100.00,
                'requirements_info': 'Complete university exit clearance and surrender of student ID.',
            },
            {
                'name': 'Certificate of Graduation',
                'description': 'Official certification confirming degree completion and graduation date.',
                'processing_days': 5,
                'fee': 100.00,
                'requirements_info': 'Approved graduation clearance and valid government/student ID.',
            },
            {
                'name': 'Certificate of General Weighted Average (GWA)',
                'description': 'Official computation of cumulative General Weighted Average for honors or scholarships.',
                'processing_days': 3,
                'fee': 75.00,
                'requirements_info': 'Valid Student ID and latest grade evaluation sheet.',
            },
            {
                'name': 'Certified True Copy of Diploma',
                'description': 'Authenticated true copy of the official university diploma.',
                'processing_days': 10,
                'fee': 250.00,
                'requirements_info': 'Photocopy of original diploma and valid government-issued ID.',
            },
            {
                'name': 'Course Description / Syllabus Certification',
                'description': 'Certified course descriptions for credit transfer or foreign credential evaluation.',
                'processing_days': 5,
                'fee': 120.00,
                'requirements_info': 'List of subjects taken and Official Transcript reference.',
            },
            {
                'name': 'Certificate of Units Earned',
                'description': 'Certifies total academic units completed to date for employment or civil service.',
                'processing_days': 3,
                'fee': 60.00,
                'requirements_info': 'Valid Student ID.',
            },
        ]

        docs = {}
        for item in catalog:
            doc_type, _ = DocumentType.objects.get_or_create(
                name=item['name'],
                defaults=item
            )
            docs[item['name']] = doc_type

        # 5. Seed 26 Diverse Document Requests Across All 6 Workflow Statuses
        now = timezone.now()
        sample_requests = [
            # (student_idx, doc_name, copies, purpose, status, staff, delivery, days_ago, extra_note)
            (0, 'Official Transcript of Records (TOR)', 2, 'Employment application requirement', RequestStatus.FOR_PROCESSING, staff1, DeliveryMethod.PICKUP, 3, 'Requirements verified complete. Sent for processing.'),
            (0, 'Certificate of Enrollment (COE)', 1, 'DOST Scholarship renewal', RequestStatus.READY_FOR_RELEASE, staff1, DeliveryMethod.PICKUP, 4, 'Document printed, stamped, and ready for pickup at Counter 2.'),
            (0, 'Certificate of Good Moral Character', 1, 'Internship onboarding requirement', RequestStatus.RELEASED, staff2, DeliveryMethod.PICKUP, 9, 'Claimed in person with validated student ID at Counter 1.'),
            (0, 'Certificate of Grades (COG)', 1, 'CHED scholarship renewal', RequestStatus.SUBMITTED, None, DeliveryMethod.DIGITAL_COPY, 0, ''),

            (1, 'Official Transcript of Records (TOR)', 1, 'Graduate school admission (MS Computer Science)', RequestStatus.UNDER_VERIFICATION, staff3, DeliveryMethod.COURIER, 1, 'Checking final semester grade posting and clearance.'),
            (1, 'Certificate of General Weighted Average (GWA)', 2, 'Latin honors and scholarship evaluation', RequestStatus.RELEASED, staff2, DeliveryMethod.PICKUP, 12, 'Verified with student ID and released at Counter 2.'),
            (1, 'Course Description / Syllabus Certification', 1, 'Foreign university credit evaluation', RequestStatus.FOR_PROCESSING, staff1, DeliveryMethod.COURIER, 2, 'Department chair endorsed syllabus copies.'),

            (2, 'Official Transcript of Records (TOR)', 3, 'CPA Licensure Board Exam application (PRC)', RequestStatus.READY_FOR_RELEASE, staff2, DeliveryMethod.PICKUP, 5, 'Stamped with dry seal and ready at Window 3.'),
            (2, 'Certificate of Graduation', 2, 'Audit firm pre-employment requirement', RequestStatus.RELEASED, staff1, DeliveryMethod.PICKUP, 14, 'Released directly to student at Registrar Window 1.'),
            (2, 'Certified True Copy of Diploma', 2, 'Overseas employment verification', RequestStatus.UNDER_VERIFICATION, staff3, DeliveryMethod.COURIER, 2, 'Verifying diploma serial number in archives.'),

            (3, 'Certificate of Enrollment (COE)', 1, 'Hospital clinical duty affiliation requirement', RequestStatus.RELEASED, staff2, DeliveryMethod.DIGITAL_COPY, 7, 'Digitally signed PDF emailed to official student address.'),
            (3, 'Certificate of Good Moral Character', 2, 'Nursing clinical internship clearance', RequestStatus.FOR_PROCESSING, staff1, DeliveryMethod.PICKUP, 2, 'OSA clearance confirmed. Printing certificate.'),
            (3, 'Certificate of Grades (COG)', 1, 'Parent employer educational assistance', RequestStatus.SUBMITTED, None, DeliveryMethod.PICKUP, 0, ''),

            (4, 'Official Transcript of Records (TOR)', 2, 'Civil Engineering Board Exam (PRC) filing', RequestStatus.FOR_PROCESSING, staff2, DeliveryMethod.PICKUP, 4, 'Checking final thesis grade entry and printing.'),
            (4, 'Certificate of Units Earned', 1, 'DPWH cadetship application', RequestStatus.READY_FOR_RELEASE, staff1, DeliveryMethod.PICKUP, 3, 'Ready for claim at Counter 2.'),
            (4, 'Honorable Dismissal / Transfer Credential', 1, 'Transfer inquiry to another campus', RequestStatus.REJECTED, staff3, DeliveryMethod.PICKUP, 6, 'Incomplete exit clearance: pending Engineering Laboratory equipment return.'),

            (5, 'Certificate of Enrollment (COE)', 1, 'Student bank account opening requirement', RequestStatus.RELEASED, staff1, DeliveryMethod.PICKUP, 10, 'Claimed at Counter 1 by student.'),
            (5, 'Certificate of Grades (COG)', 2, 'City government academic scholarship', RequestStatus.UNDER_VERIFICATION, staff3, DeliveryMethod.PICKUP, 1, 'Verifying 1st semester official grades.'),

            (6, 'Certificate of Good Moral Character', 1, 'OJT company background check', RequestStatus.READY_FOR_RELEASE, staff2, DeliveryMethod.PICKUP, 3, 'Signed by Dean of Student Affairs. Ready at Counter 1.'),
            (6, 'Certificate of Units Earned', 1, 'Part-time IT support employment', RequestStatus.SUBMITTED, None, DeliveryMethod.DIGITAL_COPY, 0, ''),

            (7, 'Certificate of Enrollment (COE)', 1, 'Visa application for academic conference', RequestStatus.FOR_PROCESSING, staff1, DeliveryMethod.PICKUP, 2, 'Approved for printing with university dry seal.'),
            (7, 'Certificate of General Weighted Average (GWA)', 1, 'Dean\'s List scholarship application', RequestStatus.REJECTED, staff3, DeliveryMethod.PICKUP, 5, 'Pending unsettled library fine; please settle at Library Desk and re-apply.'),

            (8, 'Certificate of Good Moral Character', 1, 'Hotel practicum placement requirement', RequestStatus.SUBMITTED, None, DeliveryMethod.PICKUP, 0, ''),
            (9, 'Certificate of Graduation', 1, 'LET (Licensure Exam for Teachers) filing', RequestStatus.UNDER_VERIFICATION, staff3, DeliveryMethod.PICKUP, 1, 'Confirming graduation board resolution number.'),
            (10, 'Certificate of Grades (COG)', 1, 'Engineering scholarship stipend renewal', RequestStatus.REJECTED, staff3, DeliveryMethod.DIGITAL_COPY, 4, 'Uploaded student ID attachment was unreadable; please resubmit a clear copy.'),
            (11, 'Certificate of Enrollment (COE)', 1, 'Freshman ID validation & transport discount', RequestStatus.SUBMITTED, None, DeliveryMethod.PICKUP, 0, ''),
        ]

        created_count = 0
        for s_idx, doc_name, copies, purpose, req_status, staff_obj, delivery, days_ago, note in sample_requests:
            student_obj = students[s_idx]
            doc_obj = docs[doc_name]

            if DocumentRequest.objects.filter(student=student_obj, document_type=doc_obj, purpose=purpose).exists():
                continue

            req = DocumentRequest.objects.create(
                student=student_obj,
                document_type=doc_obj,
                copies=copies,
                purpose=purpose,
                status=req_status,
                assigned_staff=staff_obj,
                delivery_method=delivery,
                rejection_reason=note if req_status == RequestStatus.REJECTED else '',
                released_at=(now - timedelta(days=max(days_ago - 2, 0))) if req_status == RequestStatus.RELEASED else None,
                recipient_name=student_obj.get_full_name() if req_status == RequestStatus.RELEASED else '',
                release_notes=note if req_status == RequestStatus.RELEASED else '',
            )
            # Backdate created_at slightly for realistic timeline
            if days_ago > 0:
                DocumentRequest.objects.filter(pk=req.pk).update(created_at=now - timedelta(days=days_ago))

            # Build realistic history chain up to current status
            RequestStatusHistory.objects.create(
                request=req,
                from_status='',
                to_status=RequestStatus.SUBMITTED,
                changed_by=student_obj,
                remarks='Document request submitted by student.',
            )

            if req_status in (
                RequestStatus.UNDER_VERIFICATION,
                RequestStatus.FOR_PROCESSING,
                RequestStatus.READY_FOR_RELEASE,
                RequestStatus.RELEASED,
            ):
                RequestStatusHistory.objects.create(
                    request=req,
                    from_status=RequestStatus.SUBMITTED,
                    to_status=RequestStatus.UNDER_VERIFICATION,
                    changed_by=staff_obj or staff3,
                    remarks='Staff initiated verification of clearances and requirements.',
                )

            if req_status in (
                RequestStatus.FOR_PROCESSING,
                RequestStatus.READY_FOR_RELEASE,
                RequestStatus.RELEASED,
            ):
                RequestStatusHistory.objects.create(
                    request=req,
                    from_status=RequestStatus.UNDER_VERIFICATION,
                    to_status=RequestStatus.FOR_PROCESSING,
                    changed_by=staff_obj or staff1,
                    remarks='Requirements verified complete. Sent for document printing.',
                )

            if req_status in (RequestStatus.READY_FOR_RELEASE, RequestStatus.RELEASED):
                RequestStatusHistory.objects.create(
                    request=req,
                    from_status=RequestStatus.FOR_PROCESSING,
                    to_status=RequestStatus.READY_FOR_RELEASE,
                    changed_by=staff_obj or staff2,
                    remarks=note if req_status == RequestStatus.READY_FOR_RELEASE else 'Document printed, stamped, and ready for release.',
                )

            if req_status == RequestStatus.RELEASED:
                RequestStatusHistory.objects.create(
                    request=req,
                    from_status=RequestStatus.READY_FOR_RELEASE,
                    to_status=RequestStatus.RELEASED,
                    changed_by=staff_obj or staff2,
                    remarks=f"Official release recorded to {student_obj.get_full_name()}. {note}",
                )
            elif req_status == RequestStatus.REJECTED:
                RequestStatusHistory.objects.create(
                    request=req,
                    from_status=RequestStatus.SUBMITTED,
                    to_status=RequestStatus.REJECTED,
                    changed_by=staff_obj or staff3,
                    remarks=f"Request rejected. Reason: {note}",
                )

            # Create matching in-app notification
            Notification.objects.create(
                user=student_obj,
                request=req,
                title=f"Request {req.tracking_number} — {req.get_status_display()}",
                message=note or f"Your request for {doc_obj.name} has been received and logged.",
            )
            created_count += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Seeding complete! Total: {User.objects.count()} users, "
                f"{DocumentType.objects.count()} document types, "
                f"{DocumentRequest.objects.count()} requests ({created_count} newly added)."
            )
        )
