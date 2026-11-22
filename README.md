<!-- Developed by @Ramana Code Softwares -->

# DrivePro — Phase 1 to Phase 3

Flutter + Firebase driving school management starter for Web and Android (iOS-ready).

## Included

- **Phase 1 — Foundation:** app theme, responsive layout, navigation, English/Telugu language toggle.
- **Phase 2 — Authentication:** Firebase email/password sign-in, sign-out, user profile role model and admin-created user profile support.
- **Phase 3 — Students:** Firestore student listing, create, edit, archive, search, and fee/status fields.

## Requirements

- Flutter stable (use `flutter --version`)
- A Firebase project
- Node.js (for Firebase CLI)
- FlutterFire CLI

## Setup

1. Extract the ZIP.
2. Open PowerShell in the extracted `drivepro` folder.
3. Run:

```powershell
flutter pub get
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

4. During `flutterfire configure`, select your Firebase project and enable **Web** and **Android** (iOS can also be selected if needed). This generates/replaces `lib/firebase_options.dart`.
5. In Firebase Console:
   - Enable **Authentication → Email/Password**.
   - Create a **Cloud Firestore** database.
   - Publish the rules from `firestore.rules` after reviewing them.
6. Create the first admin account using Firebase Authentication, then create a matching Firestore document at `users/{uid}` with fields:

```json
{
  "uid": "THE_AUTH_UID",
  "name": "School Admin",
  "email": "admin@example.com",
  "role": "admin",
  "active": true,
  "createdAt": "server timestamp"
}
```

The first admin profile must be provisioned by a trusted administrator. Do not allow public users to assign themselves the `admin` role.

7. Run:

```powershell
flutter run -d chrome
```

Android:

```powershell
flutter run -d android
```

## Important production notes

- `lib/firebase_options.dart` in this ZIP is a compile-safe setup placeholder. Run `flutterfire configure` to replace it with your project's real Firebase configuration before running the app.
- Never commit service-account JSON files or private keys.
- Review and test Firestore rules against your exact school workflows before production.
- For production onboarding, create instructor/student accounts through a trusted admin workflow or Cloud Functions. The included client does not expose public role assignment.
- The dashboard contains demo summary values until live analytics are added.
- Payment gateway integration, WhatsApp/SMS provider integration, push notifications, audit logs, automated tests and deployment pipelines are future phases.

## Developer credit

Every project file starts with the requested developer credit using the comment syntax supported by that file type.
\nNote: `firestore.indexes.json` is valid JSON and therefore cannot contain a comment line.\n
## Phase 4–6 additions

- **Phase 4 — Instructor management:** add, edit, list and archive instructors.
- **Phase 5 — Vehicle management:** register, edit and archive vehicles; record transmission, fuel, insurance expiry and fitness certificate expiry.
- **Phase 6 — Lesson scheduling:** book lessons by student, instructor, vehicle, date/time and duration; update lesson status (scheduled/completed/cancelled).

The dashboard now includes Students, Instructors, Vehicles and Lessons navigation. All records are stored in Cloud Firestore.

### Deploy updated Firestore rules

After reviewing the rules, deploy them from the project root:

```powershell
firebase deploy --only firestore:rules
```

The admin account must have a matching `users/{uid}` document with `role: "admin"` and `active: true`. Only admins can create or edit instructor, vehicle, student and lesson records in this starter. Lesson conflict detection, instructor availability, payment processing and automated reminders are not included yet.


## Phase 7–9 modules

### Phase 7 — Fee payments
- Record individual student payments with method, receipt number and notes.
- Uses a Firestore transaction to update `students.paidFee` and create a `payments` ledger record atomically.
- Rejects zero/negative payments and amounts above the current pending balance.

### Phase 8 — Lesson attendance
- Mark a scheduled lesson as present, absent or late, with optional notes.
- Stores one attendance record per lesson (re-saving that lesson updates its record).
- Attendance is restricted to admin writes; admins and instructors can read records under the included rules.

### Phase 9 — Reports and exports
- Fee summary, collected and pending totals, current-month collections, student count and attendance totals.
- Export fee balances, payment transactions and attendance to Excel (`.xlsx`).
- Print or save a PDF report containing the same report sections.

### Install and deploy
Run these commands from the `drivepro` project root:

```powershell
flutter pub get
flutterfire configure
flutter analyze
flutter run -d chrome
```

Deploy the updated security rules after checking that your admin user document exists and has `role: "admin"` and `active: true`:

```powershell
firebase deploy --only firestore:rules
```

**Important implementation notes**
- This is an integrated Phase 1–9 starter project, not a production-certified release. The archive was checked for ZIP integrity; Flutter compilation/analyzer and live Firebase testing were not run in this environment. Run `flutter analyze` after `flutter pub get` and share any errors for exact fixes.
- Payments are admin-only. The fee total and payment ledger are updated atomically. Do not manually edit `paidFee` after using the payment ledger.
- Attendance currently records one status per lesson; it does not yet support multiple attendance sessions within one lesson.
- PDF generation uses the device/browser print flow. Excel export uses the platform file-save flow. Test both on your target Android and web browsers.
- Add production validation, audit logging, backup/restore and role-specific screens before public deployment.


## Phase 10–12 additions

### Phase 10 — Student certificates
- Lists active students and generates a printable landscape course-completion certificate as PDF.
- The operator must verify course completion before issuing; this starter does not automatically verify lesson-hour requirements or persist certificate serial numbers.

### Phase 11 — Reminders
- Create, view and complete admin-managed reminders with a due date and optional details.
- Reminders are stored in Firestore. This phase provides an in-app reminder list; it does **not** send background push notifications, SMS or WhatsApp messages.

### Phase 12 — School profile and settings
- Save the driving school's name, phone, email and address in `school_settings/general`.
- The profile is admin-only and is intended as the source for future receipt/certificate branding.

### Phase 10–12 setup
Run from the `drivepro` project root:

```powershell
flutter pub get
flutterfire configure
flutter analyze
flutter run -d chrome
firebase deploy --only firestore:rules
```

**Important:** The ZIP was checked for archive integrity only. Flutter compilation, Firebase integration and browser/device printing were not executed in this environment. The new Firestore collections are admin-only. The reminder module is an in-app task list, not a scheduled notification service. Review security rules and test with an admin account before production use.


## Phase 13 — Call Automation & Enquiry Management

- Added an admin dashboard for missed-call enquiries, SMS submission status, follow-up status and notes.
- Added an admin dashboard for missed-call enquiries, SMS submission status, follow-up status and notes.
- Added a provider-independent Firebase Cloud Function webhook with configurable call-field mapping, shared-secret validation and atomic call-ID deduplication.
- Added a configurable generic REST SMS adapter. Provider URL, authentication header/prefix, HTTP method, content type, extra headers and JSON/form payload template are configured as Firebase secrets; provider names are not hardcoded into Flutter.
- Firestore client writes are blocked for call enquiries; trusted Cloud Functions create call events.
- Supports common REST APIs directly. Providers requiring HMAC signatures, OAuth token refresh, proprietary call webhook verification or unusual protocols need a small dedicated adapter.
- See `PHASE_13_CALL_AUTOMATION_SETUP.md` for provider configuration, secrets, DLT requirements, deployment and test steps.

**Important:** Provider webhook field mapping and SMS request format must be verified with real sample payloads and API documentation before production. A provider-independent adapter does not mean every provider has identical API behavior. Confirm KYC, number availability, call-event delivery and DLT requirements before purchasing a number.

## Phase 13 production-readiness additions

- Shared `AppLogger` writes structured severity-tagged messages through `dart:developer`.
- `AppExceptionHandler.guard` logs asynchronous operation failures and rethrows them for UI-level handling.
- Startup now captures Flutter, platform, zone, and Firebase initialization errors. Firebase startup failures show a safe user-facing message instead of a raw exception.
- Student write operations and attendance saves use the shared exception handler.
- The app theme now applies consistent adaptive density, button sizing, and card styling.
- Unit/widget tests cover logger output, exception propagation, and the startup error screen.

See `PRODUCTION_RUNNING_GUIDE.docx` and `RUNNING_STEPS.txt` for setup and release instructions.
