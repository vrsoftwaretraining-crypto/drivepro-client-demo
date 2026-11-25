# DrivePro — Development & Production Running Guide

Developed by @Ramana Code Softwares

## 1. Project overview

This update preserves the supplied Phase 1–13 source and adds a public lesson enquiry flow, server-controlled temporary slot holds, administrator account provisioning, payment confirmation, and separate student/instructor portals.

### Main workflow

1. Visitors can browse the public website without signing in.
2. The visitor selects an active vehicle, instructor, date and time and submits contact details.
3. A Cloud Function validates the selection and creates a 15-minute temporary hold in a Firestore transaction. The public form does not create an Auth account.
4. The request appears in Admin → Booking Requests.
5. Admin contacts the learner, agrees the fee, and creates the Student account.
6. The Cloud Function creates the Firebase Authentication user and Firestore profile using the Admin SDK. The administrator receives a Firebase password setup/reset link to share with the learner. The student profile remains inactive at this stage.
7. Admin confirms the payment actually received. A transaction marks the slot booked, records the payment, creates the first lesson, and activates the student account.
8. The student signs in and sees only the Student portal. An instructor signs in and sees only the Instructor portal. Admin retains the management dashboard.

A scheduled Cloud Function runs every five minutes and releases expired holds. A new booking submission also checks stale holds immediately.

## 2. Package scope and requirements

This ZIP is an overlay based on the exact source paths included in the uploaded `workingcopy.zip`: `lib/`, `functions/`, `firestore.rules`, `firebase.json` and `pubspec.yaml`. It does not contain platform folders such as `android/`, `web/`, `ios/`, local Firebase CLI state, build output or your Git history. Apply these files into the existing `C:\\drivingschool` project; do not delete the rest of your existing project. If the `web/` folder is missing in your existing project, run `flutter create . --platforms web` once from the project root.

- Flutter SDK compatible with the project's Dart constraint (`>=3.5.0 <4.0.0`).
- Node.js 20 for Firebase Functions.
- Firebase CLI, logged in to the school Firebase account.
- Firebase project `drivingschool-3fc49`.
- Firebase Authentication Email/Password provider enabled.
- Cloud Firestore database created.
- Firebase Functions deployment and Cloud Scheduler require a billing-enabled Firebase/Google Cloud project (Blaze plan may be required).

## 3. Development setup

Open PowerShell in the project root:

```powershell
cd C:\drivingschool
flutter --version
flutter pub get
```

Install Functions dependencies:

```powershell
cd C:\drivingschool\functions
npm install
npm run build
cd C:\drivingschool
```

If TypeScript build reports errors, stop and resolve them before deployment.

Select the Firebase project:

```powershell
firebase login
firebase use --add
```

Select `drivingschool-3fc49` when prompted. Alternatively, supply `--project drivingschool-3fc49` to each Firebase command.

Deploy Firestore rules and Cloud Functions. Existing Phase 13 call/SMS secrets must remain configured in Firebase Secret Manager; follow the existing Phase 13 setup guide if Firebase prompts for missing secret values.

```powershell
firebase deploy --only firestore:rules,functions --project drivingschool-3fc49
```

Run the web app locally:

```powershell
cd C:\drivingschool
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8081
```

Open `http://127.0.0.1:8081`.

For Chrome directly, use:

```powershell
flutter run -d chrome
```

## 4. Firebase administrator bootstrap

The first administrator must already exist in Firebase Authentication and have a matching Firestore document:

- Collection: `users`
- Document ID: the exact Firebase Authentication UID
- `name`: string
- `email`: string
- `role`: `admin`
- `active`: boolean `true`

Do not create an administrator role from the public website. The callable functions re-check the Firestore role and active flag for every privileged operation.

## 5. Prepare the public catalogue

In Admin → Vehicles, add or edit vehicles and provide:
- Registration number
- Make/model
- Transmission and fuel type
- Optional public photo URL (HTTPS)

In Admin → Instructors, add or edit instructor profiles and provide:
- Name and public profile photo URL (HTTPS)
- Short profile/experience description
- Assigned vehicle document ID (optional)
- Working days (comma-separated, e.g. `Monday, Tuesday, Wednesday, Thursday, Friday, Saturday`)
- Working hours in `09:00 AM - 05:00 PM` or 24-hour `09:00 - 17:00` format

Only active vehicles and instructors appear in the public catalogue. Public catalogue callable deliberately omits instructor phone, email and licence number.

For instructors who need a login, use Admin → Booking Requests → Create instructor account. That flow creates a login-linked instructor profile. Set the assigned vehicle ID and working schedule there. Do not create a second instructor profile for the same person without first reconciling the records.

## 6. Test the public booking flow

1. Open the website in a signed-out browser.
2. Select **Book a lesson**.
3. Confirm active vehicles and instructors appear.
4. Confirm photo URLs display where configured.
5. Select an instructor, vehicle, future date and time within the instructor's configured working days/hours.
6. Submit a valid name, Indian mobile number and email address.
7. Confirm the request appears in Admin → Booking Requests.
8. Submit the same slot from two separate browser sessions at nearly the same time. Only one should obtain the hold.
9. Try a slot overlapping a held/booked slot or existing scheduled lesson. The callable should reject it.
10. Wait for a hold to expire (15 minutes) and allow the scheduled cleanup (up to approximately five more minutes). Confirm the slot becomes available again.

The public page lists occupied times returned by the catalogue. Final availability is always rechecked server-side at submission time.

## 7. Student account and payment confirmation

1. Open the request in Admin → Booking Requests.
2. Contact the learner and agree the course fee.
3. Select **Create student account** and enter the total course fee.
4. Copy the password setup link and send it to the learner through a trusted channel.
5. Confirm the user is still inactive before payment confirmation.
6. After the school has actually received the payment, select **Confirm payment & activate** and enter the amount received.
7. Confirm the booking becomes `confirmed`, the slot becomes `booked`, the student profile becomes active, a payment record is created and the initial lesson is scheduled.
8. Complete the password setup flow and sign in using the Student login option.

**Important:** Payment is manually recorded by the administrator in this version. No payment gateway, UPI verification, automatic bank reconciliation or automatic SMS/email delivery is implemented by this change. Do not confirm payment until funds have actually been received.

A 15-minute hold can expire while the school is contacting the learner. If it expires, the payment confirmation function correctly refuses to book that old slot. The learner must submit a fresh request for a new available slot; account/booking reconciliation may be required by an administrator.

## 8. Instructor account

1. In Admin → Booking Requests, select **Create instructor account**.
2. Enter the instructor name, email, phone, optional assigned vehicle document ID, working days and working hours.
3. Copy and send the password setup link.
4. The instructor account is active immediately (no student payment gate).
5. The instructor signs in with Instructor login and sees the instructor portal.

The instructor portal lists lessons assigned to the instructor UID and students whose `assignedInstructorId` matches that UID. Ensure the public booking uses the login-linked instructor profile ID for this automatic linkage.

## 9. Production web deployment

Build and deploy:

```powershell
cd C:\drivingschool
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build web --release
firebase deploy --only hosting,firestore:rules,functions --project drivingschool-3fc49
```

Firebase Hosting is configured to publish `build/web`.

## 10. Android release

```powershell
cd C:\drivingschool
flutter build appbundle --release
```

Configure the Android release signing key in the Android Gradle build before Play Store submission. Keep keystores, passwords, service-account keys and API secrets out of Git.

## 11. Security and release checklist

- Firestore rules are deny-by-default.
- Public booking writes go only through `submitBookingRequest`.
- Admin-only account creation and payment confirmation run through callable Cloud Functions and verify the caller's active admin Firestore profile.
- Firebase Auth accounts are created with the Admin SDK; the administrator's client session is not replaced.
- The generated random temporary password is never returned. Only a Firebase password setup/reset link is returned.
- Student accounts remain inactive until the admin confirms payment.
- Student and instructor portals are separated by role.
- Public catalogue responses omit instructor contact and licence data.
- Slot holds and payment confirmation use Firestore transactions.
- Expired holds are cleaned up by a scheduled function.
- Do not store payment card data or passwords in Firestore.
- Restrict Firebase Authentication authorized domains to production domains.
- Configure Firebase App Check before public production launch.
- Monitor Cloud Function logs, quota, billing and scheduled-function execution.
- Test rules with the Firebase Emulator Suite before release.

## 12. Known boundaries in this delivery

- The supplied project did not include an existing payment gateway. Payment confirmation is an admin-entered manual workflow.
- No live SMS/email delivery is added for student registration; admin copies the password setup link and sends it using the school's approved channel.
- Vehicle/instructor photos are optional HTTPS URLs entered by Admin; there is no image upload/storage UI in this update.
- Instructor working hours are checked when they use the documented time format. If no working hours/days are configured, the system does not infer a schedule.
- Public booking accepts a preferred time and validates conflicts server-side; it is not a calendar grid of pre-generated time slots.
- Cloud Functions, Firestore rules, Firebase Auth, browser deployment and production billing must be tested in the target Firebase project. They cannot be certified from source inspection alone.
