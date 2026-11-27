# System Architecture, ERD & Data Dictionary
**Project:** Student Document Request, Processing, and Release Management System

---

## 1. System Architecture Diagram

```mermaid
flowchart LR
    subgraph ClientLayer["Client Layer"]
        FlutterApp["Flutter Android App (Dart)\n• Student & Staff Workflows\n• Encrypted Token Storage\n• File Picker (Multipart)"]
        Browser["Web Browser (Chrome/Edge)\n• Staff Portal (Bootstrap 5)\n• Django Admin\n• Swagger / ReDoc UI"]
    end

    subgraph AppLayer["Backend Application Layer (Python / Django 6.1)"]
        DRF["Django REST Framework\n• Token Auth & Role Guards\n• Serializers & Validators\n• Workflow State Machine\n• OpenAPI 3 (drf-spectacular)"]
        WebViews["Django Web Views\n• Staff Queue & KPIs\n• Verification & Release Forms\n• Session Auth"]
    end

    subgraph DataLayer["Persistence Layer"]
        Postgres[("PostgreSQL 18\n(document_request_db)")]
        Media[("Local Media Storage\n(media/attachments/)")]
    end

    FlutterApp -- "HTTPS / HTTP JSON + Multipart\n(Authorization: Token)" --> DRF
    Browser -- "HTTP / HTML Templates\n(Session Cookie + CSRF)" --> WebViews
    DRF --> Postgres
    DRF --> Media
    WebViews --> Postgres
```

---

## 2. Document Request Workflow State Machine

```mermaid
stateDiagram-v2
    [*] --> SUBMITTED : Student submits request
    SUBMITTED --> UNDER_VERIFICATION : Staff starts verification
    SUBMITTED --> REJECTED : Staff rejects deficient request
    UNDER_VERIFICATION --> FOR_PROCESSING : Requirements cleared
    UNDER_VERIFICATION --> REJECTED : Missing clearance / invalid file
    FOR_PROCESSING --> READY_FOR_RELEASE : Printed & stamped
    FOR_PROCESSING --> REJECTED : Processing issue
    READY_FOR_RELEASE --> RELEASED : Official release recorded
    READY_FOR_RELEASE --> REJECTED : Cancelled / unclaimed
    RELEASED --> [*]
    REJECTED --> [*]
```

---

## 3. Entity-Relationship Diagram (ERD)

```mermaid
erDiagram
    AUTH_USER ||--o| STUDENT_PROFILE : "has student profile"
    AUTH_USER ||--o| STAFF_PROFILE : "has staff profile"
    AUTH_USER ||--o{ DOCUMENT_REQUEST : "submits (student)"
    AUTH_USER ||--o{ DOCUMENT_REQUEST : "assigned to (staff)"
    DOCUMENT_TYPE ||--o{ DOCUMENT_REQUEST : "categorizes"
    DOCUMENT_REQUEST ||--o{ REQUEST_ATTACHMENT : "has attachments"
    DOCUMENT_REQUEST ||--o{ REQUEST_STATUS_HISTORY : "logs transitions"
    AUTH_USER ||--o{ REQUEST_STATUS_HISTORY : "changed by"
    AUTH_USER ||--o{ NOTIFICATION : "receives"
    DOCUMENT_REQUEST ||--o{ NOTIFICATION : "triggers"

    AUTH_USER {
        bigint id PK
        varchar username UK
        varchar password
        varchar email
        varchar first_name
        varchar last_name
        boolean is_staff
        boolean is_superuser
    }

    STUDENT_PROFILE {
        bigint id PK
        bigint user_id FK, UK
        varchar student_id UK
        varchar course
        int year_level
        varchar contact_number
    }

    STAFF_PROFILE {
        bigint id PK
        bigint user_id FK, UK
        varchar employee_id UK
        varchar department
    }

    DOCUMENT_TYPE {
        bigint id PK
        varchar name UK
        text description
        int processing_days
        decimal fee
        text requirements_info
        boolean is_active
        timestamp created_at
    }

    DOCUMENT_REQUEST {
        bigint id PK
        varchar tracking_number UK
        bigint student_id FK
        bigint document_type_id FK
        int copies
        text purpose
        varchar status
        bigint assigned_staff_id FK
        text rejection_reason
        varchar delivery_method
        timestamp released_at
        varchar recipient_name
        text release_notes
        timestamp created_at
        timestamp updated_at
    }

    REQUEST_ATTACHMENT {
        bigint id PK
        bigint request_id FK
        varchar file
        varchar file_type
        timestamp uploaded_at
    }

    REQUEST_STATUS_HISTORY {
        bigint id PK
        bigint request_id FK
        varchar from_status
        varchar to_status
        bigint changed_by_id FK
        text remarks
        timestamp timestamp
    }

    NOTIFICATION {
        bigint id PK
        bigint user_id FK
        bigint request_id FK
        varchar title
        text message
        boolean is_read
        timestamp created_at
    }
```

---

## 4. Data Dictionary

### Table: `documents_studentprofile`
| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | PK | Auto-increment primary key |
| `user_id` | `BIGINT` | FK (`auth_user.id`), UNIQUE, NOT NULL | Links 1-to-1 with Django user account |
| `student_id` | `VARCHAR(50)` | UNIQUE, NOT NULL | Official university student number (e.g., `2023-10492`) |
| `course` | `VARCHAR(150)` | NOT NULL | Enrolled degree program |
| `year_level` | `INTEGER` | DEFAULT `1`, NOT NULL | Current academic year level (1–5) |
| `contact_number` | `VARCHAR(20)` | DEFAULT `''` | Student mobile contact number |

### Table: `documents_staffprofile`
| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | PK | Auto-increment primary key |
| `user_id` | `BIGINT` | FK (`auth_user.id`), UNIQUE, NOT NULL | Links 1-to-1 with staff Django account |
| `employee_id` | `VARCHAR(50)` | UNIQUE, NOT NULL | Employee identifier (e.g., `EMP-002`) |
| `department` | `VARCHAR(100)` | DEFAULT `'Registrar / Records Office'` | Assigned office/section |

### Table: `documents_documenttype`
| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | PK | Auto-increment primary key |
| `name` | `VARCHAR(150)` | UNIQUE, NOT NULL | Document title (e.g., *Official Transcript of Records*) |
| `description` | `TEXT` | DEFAULT `''` | Summary of the document |
| `processing_days` | `INTEGER` | UNSIGNED, DEFAULT `3` | Estimated turnaround time in business days |
| `fee` | `NUMERIC(8,2)` | DEFAULT `0.00` | Processing fee in PHP |
| `requirements_info` | `TEXT` | NOT NULL | Required clearances or proofs |
| `is_active` | `BOOLEAN` | DEFAULT `TRUE` | Controls visibility in student catalog |
| `created_at` | `TIMESTAMPTZ` | AUTO_NOW_ADD | Record creation timestamp |

### Table: `documents_documentrequest`
| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | PK | Auto-increment primary key |
| `tracking_number` | `VARCHAR(32)` | UNIQUE, NOT NULL | Auto-generated code (`DOC-YYYYMM-XXXXXX`) |
| `student_id` | `BIGINT` | FK (`auth_user.id`), CASCADE | Requesting student |
| `document_type_id` | `BIGINT` | FK (`documents_documenttype.id`), PROTECT | Requested document type |
| `copies` | `INTEGER` | UNSIGNED, DEFAULT `1` | Requested copy count (validated 1–10) |
| `purpose` | `TEXT` | NOT NULL | Stated purpose of request |
| `status` | `VARCHAR(30)` | DEFAULT `'SUBMITTED'` | Current workflow state |
| `assigned_staff_id` | `BIGINT` | FK (`auth_user.id`), SET NULL, NULLABLE | Records staff handling the request |
| `rejection_reason` | `TEXT` | DEFAULT `''` | Explanation when `status = REJECTED` |
| `delivery_method` | `VARCHAR(20)` | DEFAULT `'PICKUP'` | `PICKUP`, `COURIER`, or `DIGITAL_COPY` |
| `released_at` | `TIMESTAMPTZ` | NULLABLE | Timestamp when document was officially released |
| `recipient_name` | `VARCHAR(150)` | DEFAULT `''` | Name of person who claimed/received the document |
| `release_notes` | `TEXT` | DEFAULT `''` | Counter number, ID check, or courier notes |
| `created_at` | `TIMESTAMPTZ` | AUTO_NOW_ADD | Submission timestamp |
| `updated_at` | `TIMESTAMPTZ` | AUTO_NOW | Last modification timestamp |

### Table: `documents_requestattachment`
| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | PK | Auto-increment primary key |
| `request_id` | `BIGINT` | FK (`documents_documentrequest.id`), CASCADE | Parent document request |
| `file` | `VARCHAR(100)` | NOT NULL | Relative path under `media/attachments/%Y/%m/` |
| `file_type` | `VARCHAR(100)` | DEFAULT `'Supporting Document'` | Label for uploaded requirement |
| `uploaded_at` | `TIMESTAMPTZ` | AUTO_NOW_ADD | Upload timestamp |

### Table: `documents_requeststatushistory`
| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | PK | Auto-increment primary key |
| `request_id` | `BIGINT` | FK (`documents_documentrequest.id`), CASCADE | Parent document request |
| `from_status` | `VARCHAR(30)` | DEFAULT `''` | Previous status before transition |
| `to_status` | `VARCHAR(30)` | NOT NULL | New status after transition |
| `changed_by_id` | `BIGINT` | FK (`auth_user.id`), SET NULL, NULLABLE | User who performed the action |
| `remarks` | `TEXT` | DEFAULT `''` | Staff notes or automated message |
| `timestamp` | `TIMESTAMPTZ` | AUTO_NOW_ADD | Exact time of transition |

### Table: `documents_notification`
| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGSERIAL` | PK | Auto-increment primary key |
| `user_id` | `BIGINT` | FK (`auth_user.id`), CASCADE | Recipient user |
| `request_id` | `BIGINT` | FK (`documents_documentrequest.id`), CASCADE, NULLABLE | Related document request |
| `title` | `VARCHAR(200)` | NOT NULL | Notification headline |
| `message` | `TEXT` | NOT NULL | Notification body |
| `is_read` | `BOOLEAN` | DEFAULT `FALSE` | Read/unread flag |
| `created_at` | `TIMESTAMPTZ` | AUTO_NOW_ADD | Creation timestamp |
