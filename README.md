# Student Document Request, Processing, and Release Management System
**Capstone Project 5** • Required Stack: Django • Django REST Framework (DRF) • Flutter (Dart) • PostgreSQL

---

## 📌 System Architecture Overview

* **Backend**: Python 3.13, Django 6.1, Django REST Framework (DRF)
* **Database**: PostgreSQL 18 (`document_request_db`) via Laragon
* **Mobile**: Flutter 3.38, Dart 3.10 (Target: Android)
* **API Documentation**: OpenAPI 3.0 / Swagger UI (`drf-spectacular`)
* **Security & Auth**: Token-based Authentication & Role Permissions (Student, Records Staff, Admin)

---

## 👥 Pre-seeded Demo Accounts

The database comes pre-populated with default document types and accounts for demonstration:

| Role | Username | Password | Purpose |
| :--- | :--- | :--- | :--- |
| **Administrator** | `admin` | `admin123` | Full access to Django admin portal (`/admin`) |
| **Records Staff** | `staff` | `staff123` | Processes requests and updates statuses |
| **Student** | `student1` | `student123` | Juan Dela Cruz (BSIT 4th Year) |

---

## 🚀 How to Run the Project

### 1. Start the PostgreSQL Database
1. Open **Laragon**.
2. Click **Start All** (ensure PostgreSQL and Apache/MySQL are green).

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
* **Admin Web Portal**: [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/)
* **Interactive Swagger API Docs**: [http://127.0.0.1:8000/api/docs/](http://127.0.0.1:8000/api/docs/)
* **ReDoc API Documentation**: [http://127.0.0.1:8000/api/redoc/](http://127.0.0.1:8000/api/redoc/)

To run backend automated tests:
```powershell
python manage.py test documents
```

---

### 3. Run the Flutter Mobile App
Open Android Studio, launch your **Android Emulator** (or connect a physical Android device with USB debugging enabled).

In a terminal in `C:\MobileAppDev\FinalProject\mobile`:
```powershell
flutter run
```

*Note for Android Emulator*: The app is pre-configured to connect to `http://10.0.2.2:8000/api` (the emulator loopback for your PC's localhost). If running on a physical phone over Wi-Fi, change `baseUrl` in [`mobile/lib/config/constants.dart`](file:///C:/MobileAppDev/FinalProject/mobile/lib/config/constants.dart) to your PC's local IP address (e.g. `http://192.168.1.XX:8000/api`).

To run mobile tests:
```powershell
flutter test
```

---

## 🔄 Mandatory Capstone Demonstration Workflow

1. **Student Request in Flutter**:
   * Open the Flutter app.
   * Log in using `student1` / `student123` (or click "Use Demo Student").
   * Go to **New Request**, select a document (e.g., *Transcript of Records*), enter purpose, and submit.
   * Observe the unique tracking number generated (e.g., `DOC-202611-XXXX`).

2. **Verification & Processing in Django Admin**:
   * Open [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/) in Chrome.
   * Log in with `admin` / `admin123`.
   * Navigate to **Document Requests**.
   * Open the submitted request or select it using the checkbox action to transition:
     `Submitted` $\rightarrow$ `Under Verification` $\rightarrow$ `For Processing` $\rightarrow$ `Ready for Release` $\rightarrow$ `Released`.

3. **Observe Live Result in Flutter**:
   * Switch back to the mobile app and pull down to refresh the **Requests** tab.
   * The status badge updates in real time.
   * Tap the request to see the audit trail / status transition timeline and release details.
   * Check the **Alerts** tab for instant status notification.
