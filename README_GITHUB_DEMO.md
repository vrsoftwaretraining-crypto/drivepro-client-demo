# DrivePro client demo — GitHub Pages (no Firebase / no database)

This package adds a GitHub Actions workflow that builds the existing Flutter project as a **database-free client demo** and publishes the web build to GitHub Pages.

## What this does

- Compiles the existing Flutter web app with `--dart-define=DEMO_MODE=true`.
- Uses the in-memory sample-data backend already included in `lib/core/demo/demo_backend.dart`.
- Does not initialize Firebase in demo mode and does not require a Firebase project, Firestore database, Firebase CLI, or Firebase secrets for the hosted demo.
- Publishes the website whenever code is pushed to `main` or `master`, or when the workflow is run manually.
- Runs `flutter analyze` and `flutter test` before deployment. If either fails, the deployment is stopped.

## Important: this is an overlay, not a complete standalone Flutter project

The development ZIP is a source overlay. Merge its files into your existing complete `C:\drivingschool` project. Keep the existing `android/`, `web/`, `ios/`, `assets/`, and other project files. GitHub Pages needs the **complete project repository**, including `pubspec.yaml`, `lib/`, and the Flutter `web/` platform folder. Do not upload only this ZIP overlay as the repository unless you also add the missing project files.

## 1. Apply this package

1. Back up your existing project.
2. Extract this ZIP.
3. Copy/merge its contents into the root of your existing Flutter project, replacing updated files when prompted.
4. Keep the existing native platform folders. If your project does not have a `web/` folder, the GitHub workflow will generate it during the build; locally you can run `flutter create . --platforms=web`.
5. On your PC run:

```bash
flutter pub get
flutter analyze
flutter test
```

## 2. Push the complete project to GitHub

1. Create a GitHub repository, for example `drivepro-client-demo`.
2. Push the **complete merged Flutter project** to the repository's `main` branch (or `master`).
3. Confirm this workflow exists in the repository at `.github/workflows/deploy-demo-pages.yml`.
4. In GitHub open **Settings → Pages** and set **Build and deployment → Source** to **GitHub Actions**.
5. Open the **Actions** tab. Wait for **Build and deploy DrivePro client demo** to finish successfully.
6. Open **Settings → Pages** to see the published website URL. For a project repository it is usually `https://YOUR_GITHUB_USERNAME.github.io/REPOSITORY_NAME/`.

Every push to `main`/`master` rebuilds and updates the demo website. You can also run the workflow manually from Actions → Build and deploy DrivePro client demo → Run workflow.

## 3. Demo logins

Use the sign-in page and choose the matching role. Any non-empty password is accepted for the seeded demo accounts.

| Role | Email / username |
|---|---|
| Admin | `admin@demo.com` or username `admin` |
| Instructor | `instructor@demo.com` |
| Student | `student@demo.com` |

Sign out before switching roles. Do not use real customer credentials.

## 4. What the client can test

The demo backend seeds sample school information, users, students, instructors, vehicles, payments, lessons, attendance, booking requests, enquiries, reminders and weekly schedule slots. The pages in the app can read and update the fake in-memory Firestore data while the demo is open. The sample dataset is restored on a full page reload.

The demo is intended to demonstrate the existing screens and workflows, not to store real customer data. Password reset emails, real SMS/phone automation, cloud photo uploads and persistent cross-device synchronization are not provided by this database-free demo. Some device-specific features may be unavailable in a browser.

## 5. Important hosting and privacy limits

- GitHub Pages hosts the **web demo only**. It does not run the Android app or provide a database/API server.
- Each client/browser session has its own in-memory sample data. A booking created by one visitor is not shared with another visitor and disappears after a full reload.
- A GitHub Pages website is public when hosted from a public repository. Anyone with the link can open the demo. The sample login is not secure authentication; never put real student, payment, personal or confidential data in the demo.
- The repository source is also visible for a public repository. Do not commit signing keys, passwords, service-account files, private certificates or production secrets.
- Do not publish this demo build as the live production website. Build the real app separately without `DEMO_MODE=true` and use the production Firebase configuration.

## 6. Local browser preview

```bash
flutter pub get
flutter run -d chrome --dart-define=DEMO_MODE=true
```

Production-style local web build:

```bash
flutter build web --release --dart-define=DEMO_MODE=true
```

The output is in `build/web`.

## 7. Android demo build (optional)

The same demo flag can be used for an Android demonstration build on a development PC:

```bash
flutter build apk --release --dart-define=DEMO_MODE=true
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`. Install it on a test phone and use the same demo accounts. GitHub Pages itself does not build, install, or host a running Android app; distribute the APK separately only if needed.

## 8. Build checks and troubleshooting

The workflow intentionally runs `flutter analyze` and `flutter test`. If these fail, GitHub Pages deployment will not happen. Open the failed Actions run, expand the failed step, and fix the reported source/test issue before pushing again. A successful GitHub Pages deployment confirms that the web artifact built and was published; it does not replace manual client acceptance testing on desktop and mobile browsers.

If the site opens as a blank page, check that the repository Pages source is GitHub Actions and that the deployed URL includes the repository path. The workflow sets Flutter's `--base-href` to that path automatically.
