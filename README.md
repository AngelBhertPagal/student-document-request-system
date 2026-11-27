# Student Document Request, Processing, and Release Management System
**Capstone Project 5** • Required Stack: Django • Django REST Framework (DRF) • Flutter (Dart) • PostgreSQL

---

## 📌 System Architecture Overview

* **Backend**: Python 3.13, Django 6.1, Django REST Framework (DRF)
* **Database**: PostgreSQL 18 (`document_request_db`) via Laragon
* **Mobile**: Flutter 3.38, Dart 3.10 (Target: Android)
* **Web Interfaces**: 
  * **Dedicated Staff Portal**: Modern Bootstrap 5 web portal for Records Personnel (`/staff/dashboard/`)
  * **System Administration**: Django Admin (`/admin/`)
* **API Documentation**: OpenAPI 3.0 / Swagger UI (`drf-spectacular`)
* **Security & Auth**: Token-based Authentication & Role Permissions (Student, Records Staff, Admin)

---

## 👥 Pre-seeded Demo Accounts

The database comes pre-populated with default document types and accounts for demonstration:

| Role | Username | Password | Purpose |
| :--- | :--- | :--- | :--- |
| **Administrator** | `admin` | `admin123` | Full access to Django admin portal (`/admin/`) |
| **Records Staff** | `staff` | `staff123` | Processes requests and records releases on Web & Mobile |
| **Student** | `student1` | `student123` | Juan Dela Cruz (BSIT 4th Year) |

---

## 🚀 How to Run the Project

### 1. Start the PostgreSQL Database
1. Open **Laragon**.
2. Click **Start All** (ensure PostgreSQL is active).

---

### 2. Run the Django Backend Server
Open a terminal in `C:\MobileAppDev\FinalProject\backend`:
```powershell
# Activate Python virtual environment
.\venv\Scripts\Activate.ps1

# (Optional) Re-seed sample data anytime
python manage.py seed_data

# Run the development server
python manage.py runserver 0.0.0.0:8000
```

Once running:
* **Registrar & Records Staff Web Portal**: [http://127.0.0.1:8000/staff/login/](http://127.0.0.1:8000/staff/login/)
* **Django Admin**: [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/)
* **Interactive Swagger API Docs**: [http://127.0.0.1:8000/api/docs/](http://127.0.0.1:8000/api/docs/)
* **ReDoc API Documentation**: [http://127.0.0.1:8000/api/redoc/](http://127.0.0.1:8000/api/redoc/)

To run backend automated tests:
```powershell
python manage.py test documents
```

---

### 3. Run the Flutter Mobile App
In a terminal:
```powershell
# Enable USB forwarding (if using a physical phone over USB)
adb reverse tcp:8000 tcp:8000

cd C:\MobileAppDev\FinalProject\mobile
flutter run
```

---

## 🖥️ Staff Interfaces Available

### A. Dedicated Web Portal (Desktop / Registrar Counter)
* Access at: [http://127.0.0.1:8000/staff/login/](http://127.0.0.1:8000/staff/login/)
* Sign in with: `staff` / `staff123`
* Features:
  * **Real-time KPI Cards**: Total requests, Under Verification, For Processing, Ready for Release, Released.
  * **Processing Queue**: Search by tracking number or student name, filter by status.
  * **Step-by-step Actions**:
    * *Start Verification*
    * *Approve & Send to Printing / Processing*
    * *Mark as Ready for Release* (with counter/pickup instructions)
    * *Record Official Release Transaction* (recipient name, delivery method, notes)
    * *Reject Deficient Request* (with clear feedback message)
  * **Full Audit Trail**: Visual timeline of all state transitions and timestamps.

### B. Mobile Staff Workflow (On the Go / Android Phone)
* In the Flutter app, sign out (from the Profile tab) and tap **"Staff Demo"** (or log in with `staff` / `staff123`).
* The app automatically switches to **Staff Mode**:
  * **Queue Tab**: View and search all incoming requests from students.
  * **Staff Detail Screen**: Perform workflow actions directly from the phone.
  * **Analytics Tab**: Live processing metrics and breakdown.
  * **Staff Profile Tab**: Employee details and department.

---

## 📚 Technical Documentation (`docs/`)
Ready-to-submit capstone documentation matching all evaluation checklist requirements:
1. [SRS, Scope, Problem Statement & Objectives](docs/01_SRS_and_Scope.md)
2. [Use-Case Model & Interface Wireframes](docs/02_Use_Case_Model_and_Wireframes.md)
3. [System Architecture, Workflow State Machine, ERD & Data Dictionary](docs/03_Architecture_ERD_and_Data_Dictionary.md)
4. [REST API Reference & QA Test Results Report](docs/04_API_Reference_and_Test_Results.md)
5. [Deployment Guide & User Manual](docs/05_Deployment_Guide_and_User_Manual.md)
