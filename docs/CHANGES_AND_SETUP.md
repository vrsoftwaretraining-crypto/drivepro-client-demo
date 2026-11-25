# DrivePro — Blaze-free version (Firebase Spark + local Emulator)

Developed by @Ramana Code Softwares

Cloud Functions need the Blaze (card) plan, so **everything now runs without functions**:
Flutter + Firebase Auth + Firestore (+ Hosting). `lib/core/services/school_service.dart`
holds all logic; `firestore.rules` enforces it. `functions/` is no longer deployed.

## Flow
1. Open web/app → landing page shows slots/day, total today, available now (read from Firestore).
2. **Book a slot** → date strip, **Any instructor** (default) or a chosen instructor, slot grid
   06–08 … 18–20 (admin-configurable). Booking types: *Test drive (trial lesson)*, Driving course, Licence test prep.
3. Booking = Firestore transaction → slot held 15 min (shows as booked for everyone, live).
4. Admin → Booking Requests → create student login → **Confirm payment & book slot**: admin can keep the
   requested slot or change instructor/date/slot; transaction marks it **BOOKED**, activates the student,
   creates first lesson + payment record. The public board updates instantly.
5. Student logs in (temporary password given by admin → must change + set security questions).

### "Any instructor"
If the student does not care, the app assigns the free instructor with the fewest lessons that day
(load balancing). Admin can still change the instructor at payment confirmation.

## Run locally (no Blaze, no card)
Needs: Flutter, Node.js, Java 17+, `npm i -g firebase-tools`.
```powershell
cd C:\drivingschool
flutter pub get
firebase emulators:start --only auth,firestore --project drivingschool-3fc49   # terminal 1
flutter run -d chrome --dart-define=USE_EMULATOR=true                           # terminal 2
```
Emulator UI: http://localhost:4000 (see Auth users, Firestore data, password-reset links).
Android emulator uses 10.0.2.2 automatically.

First run: open the site once (creates **admin / Admin@12345**), sign in with `admin`, set a new
password + 3 security questions. Then: Slot Settings → Vehicles → Instructors → test public booking
in a second browser window → Booking Requests → create student → confirm payment & slot.

## Migrate to Firebase (still free Spark)
```powershell
flutter build web
firebase deploy --only firestore:rules,hosting --project drivingschool-3fc49
flutter run -d chrome        # no flag = real Firebase
```
Open the live site **once right away** so the default admin is created by you, not a stranger.
Optionally enable App Check / reCAPTCHA in the Firebase console.

## Security trade-offs (honest list)
* Public users can create booking holds and enquiries (rules validate fields). With no server there is
  **no rate limiting**: a bot could hold many slots for 15 minutes. Mitigate with App Check.
* Security-question recovery **cannot set a password without a server**. After all 3 answers match, a
  Firebase reset **email link** is sent to the registered email. The hashes (5,000-round salted SHA-256)
  are publicly readable by design so logged-out users can be verified — short or guessable answers are weak.
* Accounts are created by admin with a temporary password (shown once); the user must change it at first login.
  Deactivating an account blocks the app, but Auth users can only be deleted in the Firebase console.
* Default admin credentials are public until changed — first login forces a change.
* Call-recording/SMS webhook in `functions/` needs Blaze; it is not deployed. Web enquiries still reach Call Enquiries.

## Data layout
`public_instructors`, `public_vehicles`, `public_info/school` (admin-mirrored, public read) ·
`booking_slots` (instructor + vehicle markers: held/booked) · `booking_requests` · `login_index` ·
`recovery` · `system/bootstrap` · existing `users/students/instructors/lessons/payments`.
Existing instructors/vehicles: Admin → Slot Settings → **Publish existing instructors & vehicles** (one click) so they appear publicly.

## Not verified here
Dart files parse (Dart 3.14 syntax check) but `flutter analyze`, the emulator run and the new
`firestore.rules` were **not executed** in this environment — run the checklist above and
`firebase emulators:start` (rules errors print at startup) before release.
