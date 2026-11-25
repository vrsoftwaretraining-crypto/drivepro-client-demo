# DrivePro — Development Build (Weekly Schedule + Pickup Address)

This is a Flutter source overlay for the supplied DrivePro project. It includes:
- Admin schedule **Weekly / List** view with previous/next week navigation and day columns.
- Public booking form with a required pickup address (5–300 characters).
- Pickup address saved with the booking request and displayed in Admin → Booking Requests.
- Existing Firebase transaction-based 15-minute slot holds are retained.
- Structured app logging for public booking/enquiry load and submission failures.
- Firestore rules validation for the new pickupAddress field.

## Apply the package
1. Back up your current project.
2. Extract this ZIP into the existing project root, preserving `android/`, `ios/`, `web/`, and local Firebase files.
3. Replace files when prompted. Do not merge this overlay with older phase ZIPs.
4. From the project root run:

```powershell
flutter --version
flutter pub get
flutter analyze
flutter test
```

## Local development with Firebase Emulator
Requirements: Flutter/Dart, Node.js 20+, Java 17+, Firebase CLI.

```powershell
npm install -g firebase-tools
firebase login
firebase emulators:start --only auth,firestore --project drivingschool-3fc49
```

In a second terminal:

```powershell
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

For Android emulator:

```powershell
flutter run --dart-define=USE_EMULATOR=true
```

The app's emulator configuration maps Android emulator localhost to `10.0.2.2`.
Use a separate Firebase project for development. Never point local test data at the live production project.

## Optional presentation-only demo
The source also supports an in-memory demo build:

```powershell
flutter run -d chrome --dart-define=DEMO_MODE=true
```

Demo data is temporary and resets on reload. It is not a production environment and must never be deployed for real students.

## Web build
Development build:

```powershell
flutter build web --debug --dart-define=USE_EMULATOR=true
```

Production build (real Firebase; no emulator or demo flags):

```powershell
flutter build web --release
```

Deploy only after validating the correct Firebase project, Firestore rules, Authentication providers, and hosting configuration:

```powershell
firebase use --add
firebase deploy --only firestore:rules,hosting --project YOUR_PRODUCTION_PROJECT_ID
```

## Feature verification checklist
1. Admin → Schedule → Weekly: verify all seven weekday columns.
2. Use previous/next controls and Today; verify slots move with the selected week.
3. Switch to List and back to Weekly; filters for location and status should remain effective.
4. Public website → Book a slot: pickup address is mandatory; test blank, under 5 characters, and over 300 characters.
5. Submit a valid booking. Confirm the request is visible in Admin → Booking Requests with pickup address.
6. Submit the same slot from two browser sessions; only one should obtain the hold.
7. Confirm payment/account creation flow still works and existing student/instructor roles remain restricted.
8. Check browser console and app logs for unexpected errors; no passwords, tokens, or payment secrets should be logged.

## Important production notes
- This is a source overlay, not a compiled APK or deployed website. Platform folders are intentionally not included.
- Flutter/Dart are not installed in the build environment used to prepare this package. Therefore `flutter analyze`, automated tests, emulator integration, and production deployment have **not** been run here. Run them on your development PC and fix any reported issues before release.
- The Firebase Emulator is for development only. For production, use your actual Firebase project and deploy the Firestore rules before publishing the app.
- The 15-minute hold workflow is retained; payment confirmation is still an administrator-entered action unless a payment gateway is separately integrated.
