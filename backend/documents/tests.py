from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APITestCase
from rest_framework import status
from .models import DocumentType, DocumentRequest, RequestStatus, StudentProfile, StaffProfile


class DocumentRequestAPITests(APITestCase):
    def setUp(self):
        # Create student user
        self.student_user = User.objects.create_user(
            username='test_student',
            password='password123',
            email='test@univ.edu.ph',
            first_name='Test',
            last_name='Student'
        )
        self.student_profile = StudentProfile.objects.create(
            user=self.student_user,
            student_id='2024-99999',
            course='BSIT',
            year_level=3
        )

        # Create staff user
        self.staff_user = User.objects.create_user(
            username='test_staff',
            password='password123',
            is_staff=True
        )
        self.staff_profile = StaffProfile.objects.create(
            user=self.staff_user,
            employee_id='STAFF-01'
        )

        # Create document type
        self.doc_type = DocumentType.objects.create(
            name='Certificate of Enrollment',
            processing_days=3,
            fee=50.00
        )

    def test_student_login(self):
        """Test valid student login returns auth token and student profile."""
        response = self.client.post('/api/auth/login/', {
            'username': 'test_student',
            'password': 'password123'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('token', response.data)
        self.assertEqual(response.data['user']['role'], 'STUDENT')

    def test_student_login_invalid_password(self):
        """Test invalid credentials rejected."""
        response = self.client.post('/api/auth/login/', {
            'username': 'test_student',
            'password': 'wrongpassword'
        })
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_document_types_public(self):
        """Test document catalog is readable without authentication."""
        response = self.client.get('/api/types/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(response.data.get('results', response.data)), 1)

    def test_create_document_request_authenticated(self):
        """Test authenticated student can submit a document request."""
        # Login
        login_res = self.client.post('/api/auth/login/', {'username': 'test_student', 'password': 'password123'})
        token = login_res.data['token']
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token}')

        payload = {
            'document_type': self.doc_type.id,
            'copies': 2,
            'purpose': 'Scholarship application',
            'delivery_method': 'PICKUP'
        }
        response = self.client.post('/api/requests/', payload)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(DocumentRequest.objects.filter(student=self.student_user).exists())
        created_req = DocumentRequest.objects.get(student=self.student_user)
        self.assertTrue(created_req.tracking_number.startswith('DOC-'))
        self.assertEqual(created_req.status, RequestStatus.SUBMITTED)

    def test_unauthenticated_request_blocked(self):
        """Test unauthenticated user cannot view or create requests."""
        self.client.credentials()  # Clear credentials
        response = self.client.get('/api/requests/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_staff_update_status(self):
        """Test records staff can advance workflow status."""
        # Create request first
        doc_req = DocumentRequest.objects.create(
            student=self.student_user,
            document_type=self.doc_type,
            purpose='Employment'
        )

        # Login as staff
        login_res = self.client.post('/api/auth/login/', {'username': 'test_staff', 'password': 'password123'})
        token = login_res.data['token']
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token}')

        update_payload = {
            'status': RequestStatus.FOR_PROCESSING,
            'remarks': 'Requirements verified, processing transcript.'
        }
        response = self.client.post(f'/api/requests/{doc_req.id}/update-status/', update_payload)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        doc_req.refresh_from_db()
        self.assertEqual(doc_req.status, RequestStatus.FOR_PROCESSING)
        self.assertTrue(doc_req.history.filter(to_status=RequestStatus.FOR_PROCESSING).exists())
