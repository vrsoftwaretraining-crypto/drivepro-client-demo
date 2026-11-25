# DrivePro passwordless client demo

This demo build is meant for client presentation only. It runs on sample data in memory, skips Firebase initialization, and does not require a username or password to enter the demo portals.

## Local web preview

Flutter 3.47+ is required because the project uses the standalone `material_ui` package.

```bash
flutter create . --platforms=web
flutter pub get
dart fix --apply --code=migrate_design_widgets
dart fix --apply
dart format .
flutter run -d chrome --dart-define=DEMO_MODE=true
```

## Build for hosting

```bash
flutter build web --release --dart-define=DEMO_MODE=true
```

The output is in `build/web`. This is a static web demo and can be hosted using GitHub Pages. The included GitHub Actions workflow creates the web platform folder when missing, performs migration/format/analyze/test checks, builds the demo and publishes Pages.

## Client demo access

The start screen has four buttons: Admin Portal, Instructor Portal, Student Portal, and Public Website. Clicking any portal button enters the demo account without asking for credentials. Sign out returns to the portal selector.


## Demo limitations

- The demo uses only sample data. Reloading resets the data.
- No Firebase project, Firestore database, or authentication service is initialized in demo mode.
- Data is not persisted or shared between visitors/browser sessions.
- Password reset emails, SMS/phone automation and cloud image uploads are not functional in this demo.
- Do not put real customer data in this demo.
- Do not deploy the `DEMO_MODE=true` build as the real customer website.
