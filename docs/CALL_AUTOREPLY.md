# Auto SMS after incoming calls (Android, no cloud, no Blaze)

Developed by @Ramana Code Softwares

## What it does
The app installed on the **school phone** watches incoming calls and sends an SMS from that phone's SIM:

| Call result | Default message (editable, `{school}` = school name) |
|---|---|
| Missed / not picked / rejected | "Sorry we missed your call to {school}. Thank you for your interest in our driving classes. We will call you back shortly. - {school}" |
| Answered (talked) | "Thank you for calling {school}. Thanks for your interest in our driving classes, we will get back to you soon. - {school}" |

* Works when the app is closed (native Android receiver).
* Same number is not messaged again within the cooldown (default 30 min).
* Hidden/private numbers are skipped. Outgoing calls are ignored.
* Every handled call is logged on the phone and copied to Firestore `call_enquiries` (Admin → Call Enquiries) when the admin is signed in on that phone.

## Install (once, on your PC)
```
cd C:\drivingschool
dart run tool/install_autoreply.dart      # copies Kotlin files, patches AndroidManifest.xml
flutter build apk --release               # or: flutter run (phone connected)
```
Install the APK on the school phone (outside Play Store; Play restricts SMS/Call-log permissions).

## Set up (on the school phone)
1. Sign in as admin → **Auto SMS (Phone)**.
2. Tap **Grant** → allow SMS, Call log, Phone.
3. Check school name and messages → switch **Auto SMS enabled** → **Save**.
4. **Send test SMS** to your own number.
5. Make a test call from another phone: let it ring out (missed) and another one you answer.
6. Battery: set the app to "No restrictions" and allow auto-start (Xiaomi/Oppo/Vivo/Samsung/Realme kill background apps).

## Limits
* SMS is charged by the SIM plan. Android may ask for confirmation if an app sends many SMS quickly.
* Needs a SIM that can send SMS and an Android phone (not iPhone, not web).
* Telugu text uses Unicode: 70 characters per SMS part (English 160).
* Dual-SIM: the phone's default SMS SIM is used.
* Not verified here: Kotlin was not compiled and no phone test was done. Run steps 4–5 before relying on it.
