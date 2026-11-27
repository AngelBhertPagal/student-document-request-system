# Deployment Guide & User Manual
**Project:** Student Document Request, Processing, and Release Management System

---

## Part 1: Local Development Setup Guide

### Prerequisites
* **Python 3.13+**
* **PostgreSQL 18** (via Laragon or standalone installer)
* **Flutter SDK 3.38+** & **Android Studio** (Android SDK)
* **Git**

### 1. Start PostgreSQL
1. Open **Laragon** and click **Start All**.
2. Ensure database `document_request_db` exists (already created on this machine).

### 2. Start the Django Backend
```powershell
cd C:\MobileAppDev\FinalProject\backend
.\venv\Scripts\Activate.ps1
python manage.py migrate
python manage.py seed_data
python manage.py runserver 0.0.0.0:8000
```
* **Staff Web Portal**: `http://127.0.0.1:8000/staff/login/`
* **Django Admin**: `http://127.0.0.1:8000/admin/`
* **Swagger API Docs**: `http://127.0.0.1:8000/api/docs/`

### 3. Run the Flutter Mobile App (Physical Android Phone)
```powershell
# Route phone localhost:8000 directly to PC port 8000 over USB
adb reverse tcp:8000 tcp:8000

cd C:\MobileAppDev\FinalProject\mobile
flutter run
```

---

## Part 2: Production Deployment & Release APK Guide

To satisfy the capstone requirement **"Release APK tested against a deployed backend"**:

### Step A: Deploy the Django Backend (Example: Render.com Free Tier)
1. Push your Git repository (`C:\MobileAppDev\FinalProject`) to GitHub.
2. On [Render.com](https://render.com):
   * Create a **PostgreSQL** database instance and copy its `Internal Database URL`.
   * Create a **Web Service** pointing to your GitHub repo (`Root Directory: backend`):
     * **Build Command**: `pip install -r requirements.txt && python manage.py collectstatic --noinput && python manage.py migrate && python manage.py seed_data`
     * **Start Command**: `gunicorn core.wsgi:application` *(add `gunicorn` and `whitenoise` to `requirements.txt` before deploying)*
   * Set environment variables: `DEBUG=False`, `SECRET_KEY=<random-key>`, `DATABASE_URL=<render-postgres-url>`.
3. Verify your live backend URL (e.g., `https://your-app-name.onrender.com/api/docs/`).

### Step B: Point Flutter to the Deployed URL & Build Release APK
1. Open `mobile/lib/config/constants.dart` and update `baseUrl`:
   ```dart
   static const String baseUrl = 'https://your-app-name.onrender.com/api';
   ```
2. Build the installable Android Release APK:
   ```powershell
   cd C:\MobileAppDev\FinalProject\mobile
   flutter build apk --release
   ```
3. The release APK is generated at:
   `mobile/build/app/outputs/flutter-apk/app-release.apk`
4. Copy `app-release.apk` onto your Android phone, install it, and verify live login and request submission over Wi-Fi/mobile data!

---

## Part 3: User Manual

### Default Demo Accounts
| Role | Username | Password |
| :--- | :--- | :--- |
| **Student** | `student1` | `student123` |
| **Records Staff** | `staff` | `staff123` |
| **Administrator** | `admin` | `admin123` |

---

### A. Student User Guide (Flutter Android App)
1. **Sign In / Register**:
   * Open the **Student Document Portal** app.
   * Tap **Register Here** to create a new student account, or sign in with your username and password (demo: `student1` / `student123`).
2. **Submit a New Document Request**:
   * Tap the **New Request** tab at the bottom navigation bar.
   * Choose the document from **Select Document Type** (estimated processing time and requirements appear automatically).
   * Adjust **Number of Copies**, pick your **Delivery Method**, and enter your **Purpose**.
   * *(Optional)* Tap **Attach ID / Clearance / Receipt** to upload a supporting PDF, JPG, or PNG file (max 5 MB).
   * Tap **Submit Request**. Save or copy the generated tracking number (`DOC-YYYYMM-XXXXXX`).
3. **Track Requests & Status Timeline**:
   * Open the **Requests** tab and pull down to refresh.
   * Filter by status using the chips at the top (`All`, `Submitted`, `Under Verification`, `For Processing`, `Ready for Release`, `Released`).
   * Tap any request card to see attached files, release instructions, and the full timestamped **Status Timeline**.
4. **View Notifications & Profile**:
   * Tap **Alerts** to see status update notifications from the Registrar.
   * Tap **Profile** to view your student information or **Sign Out**.

---

### B. Records Personnel Guide (Web Portal & Mobile App)
1. **Sign In**:
   * **Web**: Open `/staff/login/` and sign in with `staff` / `staff123`.
   * **Mobile**: Sign in on the Flutter app with `staff` / `staff123` (or tap **Staff Demo**).
2. **Review the Processing Queue**:
   * View live KPI counters at the top of the dashboard.
   * Filter requests by status or search by tracking number, student name, or student ID.
   * Click **Review & Process** (web) or tap a request card (mobile).
3. **Advance Workflow Status**:
   * `Submitted` → Click **Start Verification** to claim and inspect the request.
   * `Under Verification` → Click **Send to Processing & Printing**, or **Reject Deficient Request** with an explanation.
   * `For Processing` → Click **Mark as Ready for Release** with counter pickup notes.
   * `Ready for Release` → Click **Record Official Release Transaction**, confirm the recipient's full name, delivery method, and notes, and submit.
4. **Audit Trail**:
   * Every action automatically logs your name, timestamp, and remarks in the request's audit timeline and notifies the student in real time.

---

### C. Administrator Guide (Django Admin)
1. Open `/admin/` and sign in with `admin` / `admin123`.
2. Add or edit available academic documents under **Document types**.
3. Manage student profiles, staff profiles, and user permissions under **Users**, **Student profiles**, and **Staff profiles**.
4. Use batch actions in **Document requests** to process multiple requests at once if needed.
