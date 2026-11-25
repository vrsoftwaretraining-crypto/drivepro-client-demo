# DrivePro passwordless demo fix report

## Fixed in this package

- Migrated Flutter Material imports from `package:flutter/material.dart` to `package:material_ui/material_ui.dart` and added `material_ui` dependency.
- Replaced deprecated `Color.withOpacity()` calls with `Color.withValues(alpha: ...)`.
- Replaced deprecated `DropdownButtonFormField.value` parameters with `initialValue` in Schedule screens.
- Removed unused imports: demo backend in `app.dart` and Firebase Auth imports from Admin Accounts and Role Portal.
- Removed the unused `_ComingSoonPage` widget and `isPast` variable.
- Added a mounted check after awaited provider loads in Lessons before using `BuildContext`.
- Added a smoke test that checks demo mode is disabled unless the build define is explicitly set.
- Updated GitHub Actions to migrate remaining Material imports (including tests), run automatic fixes, format, analyze, test, build with `DEMO_MODE=true`, and deploy to GitHub Pages.

## Verification limitation

Flutter and Dart SDKs are not installed in the environment used to edit this package. Static file checks were performed, but `flutter pub get`, `dart fix`, `dart format`, `flutter analyze`, `flutter test`, and the web release build could not be executed locally. The included GitHub Actions workflow runs these checks and stops deployment if analysis/tests/build fail.
