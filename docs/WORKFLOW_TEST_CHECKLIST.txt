# DrivePro workflow test checklist

## A. Public website
- [ ] Signed-out visitor can open Home, About Us and Success Stories.
- [ ] Login modal opens and enforces selected role.
- [ ] Book a lesson opens without authentication.
- [ ] Active vehicle and instructor catalogue loads.
- [ ] Public vehicle/instructor photos are shown when valid HTTPS URLs are set.
- [ ] Instructor phone, email and licence number are not present in the public catalogue response.
- [ ] Invalid email/mobile input is rejected.
- [ ] Past date/time is rejected.
- [ ] Inactive vehicle or instructor is rejected by the callable.
- [ ] Instructor/vehicle assignment mismatch is rejected.
- [ ] Configured instructor working day/time is enforced.
- [ ] A slot overlapping an active hold, booked slot or scheduled lesson is rejected.
- [ ] Simultaneous requests for the same resource/time cannot both obtain a hold.
- [ ] Per-email hourly request limit is enforced.

## B. Hold lifecycle
- [ ] A successful request creates one `booking_requests` document.
- [ ] A successful request creates one `booking_slots` document with status `held`.
- [ ] Hold expiry is approximately 15 minutes after submission.
- [ ] Expired hold cannot be payment-confirmed.
- [ ] Scheduled cleanup changes expired hold to `available`, clears hold fields and marks request `expired`.
- [ ] A fresh request can claim a released slot.

## C. Admin provisioning
- [ ] Non-admin cannot call `createSchoolAccount`.
- [ ] Inactive admin cannot call privileged functions.
- [ ] Duplicate email is handled without creating a duplicate profile.
- [ ] Student account is created in Firebase Authentication and `users/{uid}`.
- [ ] Student role is `student` and `active` is false before payment.
- [ ] Student record includes `userId`, `assignedInstructorId` and `assignedVehicleId`.
- [ ] Password setup link is returned to Admin and no temporary password is exposed.
- [ ] Instructor account is created with role `instructor`, active true and working schedule.
- [ ] Instructor profile links to the account UID.

## D. Payment and role access
- [ ] Payment confirmation rejects non-admin callers.
- [ ] Payment confirmation rejects missing/expired slot or missing student account.
- [ ] Payment confirmation atomically books the slot, records payment, creates the initial lesson and activates student profile.
- [ ] Student login shows only Student portal.
- [ ] Instructor login shows only Instructor portal.
- [ ] Admin login retains Admin dashboard and all existing Phase 1–13 modules.
- [ ] Student cannot read another student's profile, payments, lessons, attendance or reminders.
- [ ] Instructor can read only students assigned to their instructor UID.
- [ ] Instructor cannot modify another instructor's attendance.
- [ ] Direct client writes to booking requests/slots are denied.

## E. Existing project regression
- [ ] Existing Phase 1–13 login and admin modules still work.
- [ ] Existing student/instructor/vehicle/lesson/payment/attendance CRUD is tested.
- [ ] Call automation webhook and SMS adapter are tested with the configured provider.
- [ ] `flutter analyze` has no errors.
- [ ] `flutter test` passes.
- [ ] `npm run build` passes in `functions`.
- [ ] Firestore rules are tested with Firebase Emulator Suite.
- [ ] Production Hosting, Functions and scheduled expiry are verified after deployment.
