# DrivePro UI and Contact Update

## Included

- Expanded the admin School Profile settings with primary/alternate phone, email, full address, area/landmark, Google Maps directions URL, Facebook, Instagram and optional website URL.
- Saving School Profile writes the private `school_settings/general` document and a sanitized `public_info/school` document used by the public website.
- Reworked the public website footer into a responsive Contact Us section with address, tap-to-call phone numbers, email, route-map link and social links. Values are loaded live from Firestore.
- Improved the attendance page header wrapping and made the attendance dialog vertically scrollable on short screens to avoid RenderFlex overflow stripes (black/yellow overflow indicators).
- Improved lesson status handling: cancelling a lesson releases its instructor and vehicle booking-slot documents, so the public slot board can show the time as available again.
- The Schedule page is already part of the dashboard navigation and remains the place to view and manage scheduled lessons; its existing Book Lesson action remains available to admins.

## Admin setup

1. Sign in with an admin account.
2. Open **School Settings**.
3. Enter the school name, phone number(s), email, complete address and location/landmark.
4. Paste the full Google Maps directions/share URL.
5. Paste the Facebook page and Instagram profile URLs.
6. Select **Save and publish contact details**.
7. Refresh/open the public website footer and verify the Contact Us links.

## Firestore

The existing rules already allow admins to write `school_settings` and `public_info`, and allow public reads of `public_info`. No rules change is required for these fields. The public mirror contains only school contact information, not administrator credentials or private account data.

## Verification still required on the developer PC

Run:

```powershell
flutter pub get
dart format lib
dart format --output=none --set-exit-if-changed lib
flutter analyze
flutter test
```

Then test attendance on a narrow browser/mobile viewport, test map/social links, and verify that cancelling a lesson releases both instructor and vehicle slots. This archive was edited without a local Flutter SDK, so compilation and Firebase runtime tests have not been executed here.
