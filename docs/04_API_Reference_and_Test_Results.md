# API Reference & Quality Assurance Test Results
**Project:** Student Document Request, Processing, and Release Management System

---

## 1. REST API Endpoint Reference
Interactive OpenAPI 3 documentation is served live at:
* **Swagger UI**: `/api/docs/`
* **ReDoc**: `/api/redoc/`
* **OpenAPI Schema**: `/api/schema/`

| Method | Endpoint | Auth / Role | Description | Status Codes |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/auth/register/` | Public | Register a new student account & `StudentProfile`; returns DRF token. | `201`, `400` |
| `POST` | `/api/auth/login/` | Public | Authenticate user; returns DRF token, user details, and role. | `200`, `400`, `401` |
| `POST` | `/api/auth/logout/` | Authenticated | Revoke the user's server-side DRF token. | `200`, `401` |
| `GET` | `/api/auth/profile/` | Authenticated | Retrieve the signed-in user's profile and role. | `200`, `401` |
| `GET` | `/api/types/` | Public | List active document types (paginated). | `200` |
| `GET` | `/api/requests/` | Authenticated | List requests (students see own; staff/admin see all). Supports `?status=` and `?search=`. | `200`, `401` |
| `POST` | `/api/requests/` | Authenticated | Submit a new document request (JSON or `multipart/form-data` with optional `attachment`). | `201`, `400`, `401` |
| `GET` | `/api/requests/{id}/` | Authenticated | Retrieve full request details including `attachments` and `history` timeline. | `200`, `401`, `404` |
| `PATCH` / `DELETE` | `/api/requests/{id}/` | Staff / Admin | Modify or delete a request (students blocked with `403`). | `200`, `204`, `403`, `404` |
| `POST` | `/api/requests/{id}/update-status/` | Staff / Admin | Advance request along valid workflow transitions, reject, or record release. | `200`, `400`, `403`, `404` |
| `GET` | `/api/requests/stats/` | Authenticated | Return aggregate counts per workflow status. | `200`, `401` |
| `GET` | `/api/notifications/` | Authenticated | List in-app notifications for the current user. | `200`, `401` |
| `POST` | `/api/notifications/{id}/mark_as_read/` | Authenticated | Mark a single notification as read. | `200`, `401`, `404` |
| `POST` | `/api/notifications/mark_all_read/` | Authenticated | Mark all unread notifications for the user as read. | `200`, `401` |

---

## 2. Automated Backend Test Results (`backend/documents/tests.py`)
Executed via `python manage.py test documents` against PostgreSQL 18:

| Test Case ID | Test Method | Category | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **TC-BE-01** | `test_student_login` | Authentication | `200 OK` with token & `role = STUDENT` | `200 OK` with token | ✅ PASS |
| **TC-BE-02** | `test_student_login_invalid_password` | Negative Auth | `401 Unauthorized` | `401 Unauthorized` | ✅ PASS |
| **TC-BE-03** | `test_logout_revokes_token` | Session Security | `POST /api/auth/logout/` revokes token; subsequent `GET /api/auth/profile/` returns `401` | `200 OK` then `401 Unauthorized` | ✅ PASS |
| **TC-BE-04** | `test_list_document_types_public` | Functional | `200 OK` listing active document catalog | `200 OK` with catalog items | ✅ PASS |
| **TC-BE-05** | `test_create_document_request_authenticated` | Functional | `201 Created`, auto-generated `DOC-...` tracking code, status `SUBMITTED` | `201 Created` with tracking code | ✅ PASS |
| **TC-BE-06** | `test_create_request_with_valid_and_invalid_attachment` | Validation | `.exe` rejected (`400`), `.pdf` accepted (`201`) and persisted | `400` on `.exe`, `201` on `.pdf` | ✅ PASS |
| **TC-BE-07** | `test_unauthenticated_request_blocked` | Authorization | Unauthenticated `GET /api/requests/` returns `401` | `401 Unauthorized` | ✅ PASS |
| **TC-BE-08** | `test_student_cannot_view_other_student_request` | Object Isolation | Other student accessing request ID returns `404` | `404 Not Found` | ✅ PASS |
| **TC-BE-09** | `test_student_cannot_modify_delete_or_update_status` | Role Permission | Student `PATCH`, `DELETE`, and `update-status` all return `403` | `403 Forbidden` on all 3 | ✅ PASS |
| **TC-BE-10** | `test_staff_valid_and_invalid_workflow_transitions` | Workflow Rules | Invalid jump (`SUBMITTED → RELEASED`) returns `400`; valid path (`SUBMITTED → UNDER_VERIFICATION → FOR_PROCESSING`) returns `200` and logs history | `400` on jump, `200` on valid path | ✅ PASS |

**Backend Summary**: `Ran 10 tests in 27.526s — OK (0 failures, 0 errors)`

---

## 3. Mobile Static Analysis & Testing (`mobile/`)

| Check | Command | Result | Status |
| :--- | :--- | :--- | :---: |
| Dart/Flutter Static Analysis | `flutter analyze` | `No issues found! (ran in 2.8s)` | ✅ PASS |
| Flutter Widget Smoke Test | `flutter test` | `00:00 +1: All tests passed!` | ✅ PASS |
| Physical Device Integration | `flutter run` on Android `Z2464N` | Verified login, request creation, dropdown & dialog layouts, and live PostgreSQL persistence | ✅ PASS |
| Staff Web Portal Integration | Browser test on `/staff/dashboard/` & `/staff/requests/3/` | Verified login, queue filtering, review detail page, and status progression | ✅ PASS |
