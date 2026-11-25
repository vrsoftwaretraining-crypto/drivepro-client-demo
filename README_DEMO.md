# DrivePro DEMO build (no database, for client presentation)

In demo mode the whole app runs on sample data kept in memory inside the browser tab.
No Firebase project, no Firestore, no internet service is used. Every page and form opens and works;
anything you add or edit stays only until the page is reloaded.

The normal (production) build is not changed: the demo is switched on only by `--dart-define=DEMO_MODE=true`.

## 1. Put the files into your project
1. Copy your project folder `C:\drivingschool` to `C:\drivingschool_backup` first.
2. Extract this zip and copy its `lib` folder and `pubspec.yaml` into `C:\drivingschool` (Replace files).
   Keep your own `android`, `web`, `ios` folders as they are.
3. In `C:\drivingschool` run:
```
flutter pub get
```
(`pubspec.yaml` only gets one extra package: `fake_cloud_firestore`.)

## 2. Try it on your PC
```
flutter run -d chrome --dart-define=DEMO_MODE=true
```
The yellow bar at the top shows the demo logins. Any password works:

| Role | Email |
|---|---|
| Admin | admin@demo.com (username `admin` also works) |
| Instructor | instructor@demo.com |
| Student | student@demo.com |

In the sign-in form choose the same role as the email. To switch role, sign out and sign in with another email.
The public website, slot booking and enquiry forms work without any login.

## 3. Build the website
```
flutter build web --release --dart-define=DEMO_MODE=true
```

## 4. Host on Firebase for the client (free plan)
One time:
```
npm i -g firebase-tools
firebase login
```
Best: a separate preview link, so your live site is not touched:
```
firebase hosting:channel:deploy demo --expires 30d
```
Firebase prints a link like `https://PROJECT--demo-xxxx.web.app`. Send that link to the client.
Run the same command again after a new build to update the same link.

Or, to replace the main site with the demo: `firebase deploy --only hosting`
(do this only if the main site is not live for real customers).

## 5. Back to the real app (production)
Build WITHOUT the flag and deploy:
```
flutter build web --release
firebase deploy --only hosting
```
Never deploy a demo build to the real customer site: anyone could open the admin pages with the sample login.

## Schedule module in the demo
The demo already has sample slots (3 locations, next 7 days). Try: website > Available driving slots > Book a slot,
then sign in as admin > Schedule > Bookings to confirm or cancel it. Student login shows the same slots.

## What is different in demo mode
- Data resets on page reload (fresh sample data every time).
- New students, instructors, bookings, payments, lessons and enquiries can be added and appear in all pages until reload.
- Password reset e-mails, real phone call auto-reply (Android only) and photo upload do not run.
- PDF / Excel downloads work in the browser.

## Not tested here
These files were written without Flutter installed, so they were not compiled. If `flutter pub get` or the build
shows an error, copy the message and send it.

## Passwordless client walkthrough update

In demo mode, the initial screen now offers four shortcuts: Admin Portal, Instructor Portal, Student Portal, and Public Website. Selecting a role automatically signs into the seeded demo account (no username/password entry). Signing out returns to the role selector. Production builds without `DEMO_MODE=true` retain the original authentication flow.
