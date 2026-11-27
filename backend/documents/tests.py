from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth.models import User
from rest_framework.test import APITestCase
from rest_framework import status
from .models import DocumentType, DocumentRequest, RequestStatus, StudentProfile, StaffProfile


class DocumentRequestAPITests(APITestCase):
    def setUp(self):
        # Create primary student user
        self.student_user = User.objects.create_user(
            username='test_student',
            password='password123',
            email='test@univ.edu.ph',
            first_name='Test',
            last_name='Student',
        )
        self.student_profile = StudentProfile.objects.create(
            user=self.student_user,
            student_id='2024-99999',
            course='BSIT',
            year_level=3,
        )

        # Create a second student user for object-permission isolation tests
        self.other_student = User.objects.create_user(
            username='other_student',
            password='password123',
            email='other@univ.edu.ph',
        )
        StudentProfile.objects.create(
            user=self.other_student,
            student_id='2024-88888',
            course='BSCS',
            year_level=2,
        )

        # Create staff user
        self.staff_user = User.objects.create_user(
            username='test_staff',
            password='password123',
            is_staff=True,
        )
        self.staff_profile = StaffProfile.objects.create(
            user=self.staff_user,
            employee_id='STAFF-01',
        )

        # Create document type
        self.doc_type = DocumentType.objects.create(
            name='Certificate of Enrollment',
            processing_days=3,
            fee=50.00,
        )

    def _authenticate(self, username, password='password123'):
        res = self.client.post('/api/auth/login/', {'username': username, 'password': password})
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        token = res.data['token']
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token}')
        return token

    def test_student_login(self):
        """Test valid student login returns auth token and student profile."""
        response = self.client.post('/api/auth/login/', {
            'username': 'test_student',
            'password': 'password123',
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('token', response.data)
        self.assertEqual(response.data['user']['role'], 'STUDENT')

    def test_student_login_invalid_password(self):
        """Test invalid credentials rejected."""
        response = self.client.post('/api/auth/login/', {
            'username': 'test_student',
            'password': 'wrongpassword',
        })
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_logout_revokes_token(self):
        """Test logout deletes server token so subsequent requests fail with 401."""
        self._authenticate('test_student')
        logout_res = self.client.post('/api/auth/logout/')
        self.assertEqual(logout_res.status_code, status.HTTP_200_OK)

        # Reusing revoked token should now fail
        profile_res = self.client.get('/api/auth/profile/')
        self.assertEqual(profile_res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_document_types_public(self):
        """Test document catalog is readable without authentication."""
        response = self.client.get('/api/types/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(response.data.get('results', response.data)), 1)

    def test_create_document_request_authenticated(self):
        """Test authenticated student can submit a document request and receives tracking_number."""
        self._authenticate('test_student')
        payload = {
            'document_type': self.doc_type.id,
            'copies': 2,
            'purpose': 'Scholarship application',
            'delivery_method': 'PICKUP',
        }
        response = self.client.post('/api/requests/', payload)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('tracking_number', response.data)
        self.assertTrue(response.data['tracking_number'].startswith('DOC-'))
        self.assertEqual(response.data['status'], RequestStatus.SUBMITTED)

    def test_create_request_with_valid_and_invalid_attachment(self):
        """Test valid PDF attachment succeeds and unsupported executable extension is rejected."""
        self._authenticate('test_student')

        bad_file = SimpleUploadedFile('malware.exe', b'bad content', content_type='application/octet-stream')
        bad_res = self.client.post('/api/requests/', {
            'document_type': self.doc_type.id,
            'copies': 1,
            'purpose': 'Testing validation',
            'delivery_method': 'PICKUP',
            'attachment': bad_file,
        }, format='multipart')
        self.assertEqual(bad_res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('attachment', bad_res.data)

        good_file = SimpleUploadedFile('clearance.pdf', b'%PDF-1.4 sample', content_type='application/pdf')
        good_res = self.client.post('/api/requests/', {
            'document_type': self.doc_type.id,
            'copies': 1,
            'purpose': 'Testing valid attachment',
            'delivery_method': 'PICKUP',
            'attachment': good_file,
        }, format='multipart')
        self.assertEqual(good_res.status_code, status.HTTP_201_CREATED)
        req = DocumentRequest.objects.get(pk=good_res.data['id'])
        self.assertEqual(req.attachments.count(), 1)

    def test_unauthenticated_request_blocked(self):
        """Test unauthenticated user cannot view or create requests."""
        self.client.credentials()
        response = self.client.get('/api/requests/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_student_cannot_view_other_student_request(self):
        """Test object-level isolation: student cannot access another student's request."""
        doc_req = DocumentRequest.objects.create(
            student=self.student_user,
            document_type=self.doc_type,
            purpose='Private request',
        )
        self._authenticate('other_student')
        response = self.client.get(f'/api/requests/{doc_req.id}/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_student_cannot_modify_delete_or_update_status(self):
        """Test role enforcement: students cannot PATCH, DELETE, or call update-status."""
        doc_req = DocumentRequest.objects.create(
            student=self.student_user,
            document_type=self.doc_type,
            purpose='Employment',
        )
        self._authenticate('test_student')

        patch_res = self.client.patch(f'/api/requests/{doc_req.id}/', {'purpose': 'Tampered'})
        self.assertEqual(patch_res.status_code, status.HTTP_403_FORBIDDEN)

        del_res = self.client.delete(f'/api/requests/{doc_req.id}/')
        self.assertEqual(del_res.status_code, status.HTTP_403_FORBIDDEN)

        status_res = self.client.post(f'/api/requests/{doc_req.id}/update-status/', {
            'status': RequestStatus.UNDER_VERIFICATION,
        })
        self.assertEqual(status_res.status_code, status.HTTP_403_FORBIDDEN)

    def test_staff_valid_and_invalid_workflow_transitions(self):
        """Test staff can advance valid workflow transitions and invalid jumps are blocked."""
        doc_req = DocumentRequest.objects.create(
            student=self.student_user,
            document_type=self.doc_type,
            purpose='Employment',
        )
        self._authenticate('test_staff')

        # Invalid jump: SUBMITTED -> RELEASED must be rejected (400)
        jump_res = self.client.post(f'/api/requests/{doc_req.id}/update-status/', {
            'status': RequestStatus.RELEASED,
        })
        self.assertEqual(jump_res.status_code, status.HTTP_400_BAD_REQUEST)

        # Valid transition: SUBMITTED -> UNDER_VERIFICATION
        step1 = self.client.post(f'/api/requests/{doc_req.id}/update-status/', {
            'status': RequestStatus.UNDER_VERIFICATION,
            'remarks': 'Starting verification.',
        })
        self.assertEqual(step1.status_code, status.HTTP_200_OK)

        # Valid transition: UNDER_VERIFICATION -> FOR_PROCESSING
        step2 = self.client.post(f'/api/requests/{doc_req.id}/update-status/', {
            'status': RequestStatus.FOR_PROCESSING,
            'remarks': 'Requirements verified, processing document.',
        })
        self.assertEqual(step2.status_code, status.HTTP_200_OK)
        doc_req.refresh_from_db()
        self.assertEqual(doc_req.status, RequestStatus.FOR_PROCESSING)
        self.assertTrue(doc_req.history.filter(to_status=RequestStatus.FOR_PROCESSING).exists())
