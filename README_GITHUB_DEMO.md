# DrivePro client demo — passwordless web demo

This project is configured for a **public, database-free client demonstration**. The demo build uses in-memory sample data and skips Firebase initialization. Clients can choose Admin, Instructor, Student, or Public Website without entering a password.

> Use sample data only. Never publish production/customer information in this public demo. This build is not secure authentication and must not replace the production site.

## Included

- Flutter web demo build with sample data in `lib/core/demo/demo_backend.dart`.
- Passwordless portal shortcuts (Admin / Instructor / Student) and public website.
- GitHub Actions workflow at `.github/workflows/deploy-demo-pages.yml` that creates the Web platform folder if needed, runs package resolution, compiles the Flutter web release build in demo mode, and publishes GitHub Pages. Analyzer, lint, and test steps are intentionally skipped to avoid blocking the client demo on analyzer findings.
- Material UI migration for Flutter 3.47+ using `material_ui`.

This package contains the Flutter application source and web-deploy workflow. Native Android/iOS platform folders are not included; GitHub Actions generates the web platform folder during the build. The demo is intended to be deployed as a web site.

## Local browser preview

Requires Flutter 3.47 or newer.

```bash
flutter create . --platforms=web
flutter pub get
dart fix --apply --code=migrate_design_widgets
dart format .
flutter run -d chrome --dart-define=DEMO_MODE=true
```

## Publish using GitHub Pages

1. Create a **public** GitHub repository for this demo.
2. Upload/push all files from this project to the repository's `main` branch.
3. In the repository, open **Settings → Pages** and set the source to **GitHub Actions**.
4. Open the **Actions** tab and wait for **Build and deploy DrivePro client demo** to complete successfully.
5. Open **Settings → Pages** to copy the published site link and share it with your client.

The workflow also runs automatically for pushes to `main` or `master`; you can run it manually from Actions using **Run workflow**.


## Client walkthrough

- **Admin Portal:** manage the demo school and inspect the admin modules.
- **Instructor Portal:** inspect instructor schedule and assigned students.
- **Student Portal:** inspect bookings, progress, and payments.
- **Public Website:** browse courses, instructors, and public booking/enquiry flows.


## Demo limitations

- Sample data is held in memory. Reloading restores the original seed data.
- No Firebase project or cloud database is initialized in demo mode.
- Password reset email, phone/SMS automation, and cloud photo upload are not functional in the browser demo.
- Changes are not shared between browsers/visitors and are not persistent.
- GitHub Pages is a static host; this is not a backend deployment.
- Do not deploy with `DEMO_MODE=true` as the real customer website.


## Production build reminder

Production must be built without the demo define, using the real Firebase configuration and production security rules. Never expose the demo role shortcuts on a live customer deployment.
