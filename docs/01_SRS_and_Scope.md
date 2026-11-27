# Software Requirements Specification (SRS) & Project Scope
**Project Title:** Student Document Request, Processing, and Release Management System  
**Capstone Track:** Project 5 (Django • Django REST Framework • Flutter • PostgreSQL)

---

## 1. Problem Statement
In many colleges and universities, requesting official academic documents—such as Certificates of Enrollment (COE), Certificates of Grades (COG), Transcripts of Records (TOR), Certificates of Good Moral Character, and Honorable Dismissals—still relies on manual paper forms, in-person queues, and verbal follow-ups at the Registrar or Records Office. This manual process causes:
1. Long waiting lines and unnecessary campus trips just to check request status.
2. Lost or incomplete paper applications due to missing supporting requirements.
3. Lack of transparency and auditability regarding which staff member verified, processed, or released a document.
4. Difficulty generating accurate turnaround and pending-queue reports for records administrators.

---

## 2. Measurable Objectives
1. **Digitize Request Submission**: Provide a Flutter Android mobile application that allows students to browse the document catalog, submit requests with optional supporting file attachments, and receive a unique tracking number (`DOC-YYYYMM-XXXXXX`) persisted in PostgreSQL.
2. **Expose Secure REST APIs**: Build Django REST Framework (DRF) endpoints with token authentication, role-based permissions, serializer validation, pagination, filtering, and OpenAPI/Swagger documentation.
3. **Enforce Auditable Workflow Transitions**: Implement a controlled verification, processing, rejection, and release workflow (`Submitted → Under Verification → For Processing → Ready for Release → Released`, plus `Rejected`) with timestamped history logs and automatic in-app notifications.
4. **Provide Records Office Web & Mobile Management**: Deliver a Bootstrap 5 Django web portal (and staff mobile workflow) enabling records personnel to review requirements, assign requests, record official release transactions, and monitor KPI metrics.
5. **Verify Quality & Reliability**: Validate core functionality, security permissions, and end-to-end integration through automated Django API tests and Flutter static analysis/widget tests.

---

## 3. Scope and Limitations

### In Scope
* Student registration, login, encrypted mobile session storage, and profile management.
* Document catalog management (document types, fees, estimated processing days, required clearances).
* Electronic document request submission with supporting file upload (`.pdf`, `.jpg`, `.jpeg`, `.png`, max 5 MB).
* Controlled workflow state transitions, staff assignment, rejection with reason, and official release recording (recipient, date, delivery method, release notes).
* In-app student notifications and timestamped audit history logs.
* Web-based Records Staff Portal, Django Admin interface, and Staff Mobile mode.
* Processing dashboard metrics (counts by status).

### Out of Scope (Limitations)
* **No Generation or Modification of Official Academic Records**: Per the capstone brief, this system manages *document requests and release tracking only*; it does not generate official PDF transcripts or alter student grade records.
* **No Online Payment Gateway**: Fees are displayed for reference; payment verification is handled through supporting receipt uploads or Registrar counter clearance.
* **Android Mobile Target**: The mobile client targets Android devices (physical devices and emulators); iOS deployment is outside the current scope.

---

## 4. User Roles and Permissions Matrix

| Feature / Endpoint | Student | Records Personnel (`staff`) | Administrator (`admin`) |
| :--- | :---: | :---: | :---: |
| Browse Document Catalog | ✅ | ✅ | ✅ |
| Register / Sign In / Sign Out | ✅ | ✅ | ✅ |
| Submit Document Request + Attachment | ✅ | ✅ | ✅ |
| View Own Requests & Status History | ✅ | ✅ | ✅ |
| View All Students' Requests | ❌ (404/Scoped) | ✅ | ✅ |
| Modify (`PATCH`) or Delete (`DELETE`) Request | ❌ (403) | ✅ | ✅ |
| Advance Request Status / Reject / Record Release | ❌ (403) | ✅ | ✅ |
| Access Staff Web Portal (`/staff/dashboard/`) | ❌ (Blocked) | ✅ | ✅ |
| Manage Document Catalog & Users (`/admin/`) | ❌ (Blocked) | ⚠️ Limited | ✅ Full |

---

## 5. Functional Requirements

| ID | Module | Requirement Description |
| :--- | :--- | :--- |
| **FR-01** | Authentication | The system shall authenticate users via DRF Token Authentication and store tokens securely on mobile using `flutter_secure_storage`. |
| **FR-02** | Session Management | The system shall revoke tokens on logout (`POST /api/auth/logout/`) and redirect mobile users to Login on `401 Unauthorized`. |
| **FR-03** | Document Catalog | The system shall list active academic document types with fee, estimated processing days, and requirement guidelines. |
| **FR-04** | Request Submission | Students shall submit requests specifying document type, copies (1–10), delivery method (`PICKUP`, `COURIER`, `DIGITAL_COPY`), purpose, and optional attachment. |
| **FR-05** | Unique Identification | The system shall auto-generate a unique tracking number (`DOC-YYYYMM-XXXXXX`) and timestamp upon submission. |
| **FR-06** | Workflow Enforcement | Only authorized staff may transition request statuses along valid workflow paths; terminal states (`RELEASED`, `REJECTED`) cannot be altered. |
| **FR-07** | Audit History | Every status change shall automatically create a `RequestStatusHistory` record storing `from_status`, `to_status`, `changed_by`, `remarks`, and `timestamp`. |
| **FR-08** | Notifications | Every request submission and status update shall automatically generate an in-app `Notification` for the requesting student. |
| **FR-09** | Release Recording | Marking a request `RELEASED` shall record `released_at`, `recipient_name`, `delivery_method`, and `release_notes`. |
| **FR-10** | Dashboard & Reports | The staff web portal and `/api/requests/stats/` endpoint shall display real-time counts by workflow status. |

---

## 6. Non-Functional Requirements

* **Security**: Password hashing via Django's PBKDF2; role-based access control on all write/workflow endpoints; encrypted mobile credential storage via Android Keystore (`flutter_secure_storage`); file extension and size validation on uploads.
* **Usability**: Clean Material 3 mobile interface with responsive layouts (`SingleChildScrollView`, `Expanded`) and Bootstrap 5 desktop web portal; clear loading, empty, offline, and error states.
* **Reliability & Data Integrity**: Relational PostgreSQL 18 database with foreign-key integrity (`PROTECT` on referenced document types, `CASCADE` on request children) and repeatable Django migrations.
* **Maintainability**: Modular separation (`backend/core`, `backend/documents`, `mobile/lib/config`, `mobile/lib/services`, `mobile/lib/screens`) tracked under Git with automated API and widget tests.
