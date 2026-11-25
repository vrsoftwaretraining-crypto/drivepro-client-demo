# Schedule module: admin slots, website booking, student login

## What it does
1. **Admin > Schedule** is where the admin creates every bookable slot:
   date and time, lesson duration, instructor, vehicle, location, course name, course duration and fee.
   One form can create the same slot for many days (every day, Monday to Saturday, Monday to Friday).
2. The slots appear **live** in two places, location wise:
   - the public website (home page section "Available driving slots", no login needed)
   - the student login (card "Available driving slots", booking with one tap)
3. When a student or visitor books a slot, it turns to **Booked** everywhere at once. Two people can never
   get the same slot: the booking is one transaction, and the second person is told the slot was just taken.
4. The admin keeps full control: confirm a booking, cancel a booking (and reopen the slot or keep it cancelled),
   cancel a slot, reopen it, edit it, delete it, mark it completed, call or WhatsApp the person.
5. Confirming a booking of a registered student creates the **lesson** automatically, so it shows in
   Lessons, Attendance, the student's "My booked lessons" and the instructor's schedule.

## Where each screen is
| Who | Where | What |
|---|---|---|
| Admin | Dashboard > Schedule > Slots | add, edit, cancel, reopen, delete, complete slots; filter by date range, location, status |
| Admin | Dashboard > Schedule > Bookings | confirm or cancel bookings, call, WhatsApp |
| Visitor | Website home page, "Available driving slots" | choose location, book with name and phone |
| Student | Student login > Available driving slots | one-tap booking |
| Student | Student login > My slot bookings | status: awaiting confirmation, confirmed, cancelled |
| Instructor | Instructor login > My scheduled slots | upcoming slots assigned to the instructor |

The old "Booking Requests" and "Slot Settings" entries were removed from the admin menu: slots are now created by
the admin, not generated from instructor working hours. The old files are still in the project, unused.

## Data
- `schedule_slots` (public read): startAt, durationMinutes, location, vehicleId, vehicleName, instructorId,
  instructorName, courseName, courseDuration, fee, status (`available`, `booked`, `cancelled`, `completed`), bookingId.
  No personal data is stored here.
- `slot_bookings` (private: admin and the student who booked): slotId, name, phone, email, notes, studentUserId,
  studentId, status (`pending`, `confirmed`, `cancelled`), copy of the slot details, lessonId.

## Deploy (real project)
1. Copy `lib`, `firestore.rules`, `pubspec.yaml` into the project.
2. `flutter pub get`
3. Publish the new security rules (needed, or booking is refused):
   `firebase deploy --only firestore:rules`
4. Build and host the website:
   `flutter build web --release`
   `firebase deploy --only hosting`
5. Sign in as admin, add at least one instructor and one vehicle, then Schedule > Add slot.

No new Firestore index is needed.

## Quick test
1. Admin: Schedule > Add slot (tomorrow, 8:00 AM, 1 hr, location "Madhapur"). The slot shows as Available.
2. Open the website home page (signed out): the slot shows under "Madhapur" with a **Book this slot** button.
3. Book it with a name and phone. The card turns to **Booked** on the website and in the admin Slots list.
4. Admin: Schedule > Bookings: the booking is listed as Awaiting confirmation. Tap Confirm.
5. Sign in as a student: "Available driving slots" shows the same slots; book another; "My slot bookings" lists it.
6. Admin: Cancel booking > Reopen slot. The website shows it as Available again.
7. Admin: Cancel slot. It disappears from the website.

## Compared with the Mentor Keep Track app (Play Store listing)
Covered: day-by-day timetable and agenda list, lessons booked in short slots (15 minute lesson length is available),
pupil management (Students module), paid / unpaid tracking (Payments module), lesson duration and price,
lesson status tracking, WhatsApp and call buttons.
Not included: a weekly grid view and a pickup address field on the booking.
