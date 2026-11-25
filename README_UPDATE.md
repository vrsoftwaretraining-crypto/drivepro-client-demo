# DrivePro update package

> **Latest update:** see `docs/CHANGES_AND_SETUP.md` (Blaze-free: local emulator → Spark).

This is an overlay package based on the exact source paths supplied in the uploaded ZIP. It contains the updated `lib/`, `functions/`, `firestore.rules`, `firebase.json`, `pubspec.yaml` and documentation.

It does not include Android/Web/iOS platform folders, build output, local Firebase CLI state or Git history. Merge these files into the existing `C:\drivingschool` project; do not replace or delete the rest of that project.

Start with:
- `docs/DEVELOPMENT_PRODUCTION_GUIDE.md`
- `docs/WORKFLOW_TEST_CHECKLIST.md`

The TypeScript source passed a syntax-transpilation check. A complete Flutter/Dart analysis, Firebase Functions typecheck, emulator test and deployment could not be run in this environment because Flutter/Dart and the Firebase Functions dependencies/CLI are not installed here. Run the validation commands in the guide on the development PC before production deployment.
