// Developed by @Ramana Code Softwares

import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getAuth, type UserRecord } from "firebase-admin/auth";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

initializeApp();
const db = getFirestore();

// Provider settings are secrets/configuration, not Flutter-side constants.
const webhookSecret = defineSecret("DRIVEPRO_CALL_WEBHOOK_SECRET");
const callProvider = defineSecret("DRIVEPRO_CALL_PROVIDER");
const callFieldMap = defineSecret("DRIVEPRO_CALL_FIELD_MAP_JSON");
const missedStatuses = defineSecret("DRIVEPRO_CALL_MISSED_STATUSES_JSON");
const smsProvider = defineSecret("DRIVEPRO_SMS_PROVIDER");
const smsApiUrl = defineSecret("DRIVEPRO_SMS_API_URL");
const smsApiKey = defineSecret("DRIVEPRO_SMS_API_KEY");
const smsAuthHeader = defineSecret("DRIVEPRO_SMS_AUTH_HEADER");
const smsAuthPrefix = defineSecret("DRIVEPRO_SMS_AUTH_PREFIX");
const smsHttpMethod = defineSecret("DRIVEPRO_SMS_HTTP_METHOD");
const smsContentType = defineSecret("DRIVEPRO_SMS_CONTENT_TYPE");
const smsRequestTemplate = defineSecret("DRIVEPRO_SMS_REQUEST_TEMPLATE_JSON");
const smsExtraHeaders = defineSecret("DRIVEPRO_SMS_EXTRA_HEADERS_JSON");
const smsTemplate = defineSecret("DRIVEPRO_SMS_TEMPLATE");

function firstString(...values: unknown[]): string {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
    if (typeof value === "number") return String(value);
  }
  return "";
}

function getPath(source: Record<string, unknown>, path: string): unknown {
  return path.split(".").reduce<unknown>((current, key) => {
    if (current && typeof current === "object") {
      return (current as Record<string, unknown>)[key];
    }
    return undefined;
  }, source);
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function normalizePhone(value: string): string {
  const digits = value.replace(/\D/g, "");
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith("91")) return `+${digits}`;
  if (digits.length === 13 && digits.startsWith("+91")) return `+${digits.slice(1)}`;
  return "";
}

function safeEqual(left: string, right: string): boolean {
  if (!left || !right) return false;
  const a = createHash("sha256").update(left).digest();
  const b = createHash("sha256").update(right).digest();
  return timingSafeEqual(a, b);
}

function parseJsonSecret<T>(raw: string, fallback: T): T {
  if (!raw.trim() || raw.trim().toLowerCase() === "none") return fallback;
  return JSON.parse(raw) as T;
}

function optionalSecret(raw: string, fallback: string): string {
  return !raw.trim() || raw.trim().toLowerCase() === "none" ? fallback : raw.trim();
}

function readCallEvent(body: Record<string, unknown>): {
  phoneNumber: string;
  callId: string;
  status: string;
  answered: unknown;
  direction: string;
} {
  const nested = asRecord(body.data ?? body.call ?? body.payload ?? body.event);
  const combined = { ...body, ...nested };
  const mapping = parseJsonSecret<Record<string, string>>(callFieldMap.value(), {});
  const mapped = (key: string, aliases: string[]) => {
    const mappedPath = mapping[key];
    if (mappedPath) {
      const value = getPath(body, mappedPath);
      if (value !== undefined && value !== null) return firstString(value);
    }
    return firstString(...aliases.map((alias) => getPath(combined, alias)));
  };
  const rawPhone = mapped("phone", [
    "from", "caller", "caller_number", "from_number", "customer_number",
    "phone", "phoneNumber", "source", "msisdn", "customer.phone",
  ]);
  return {
    phoneNumber: normalizePhone(rawPhone),
    callId: mapped("callId", ["call_id", "callId", "id", "uuid", "sid", "call.uuid"]),
    status: mapped("status", ["status", "call_status", "disposition", "event", "event_type"]).toLowerCase(),
    answered: getPath(combined, mapping.answered ?? "answered"),
    direction: mapped("direction", ["direction", "call_direction"]) || "inbound",
  };
}

function isMissedCall(status: string, answered: unknown, configuredStatuses: string[]): boolean {
  const normalized = status.toLowerCase().replace(/[\s_-]/g, "");
  const answeredText = firstString(answered).toLowerCase();
  const explicitlyNotAnswered = answered === undefined || answered === null
    || answered === false || answered === 0
    || answeredText === "" || answeredText === "false" || answeredText === "0";
  if (answered === true || answered === 1 || answeredText === "true" || answeredText === "1") {
    return false;
  }
  if (!explicitlyNotAnswered) return false;
  const defaults = [
    "missed", "missedcall", "noanswer", "unanswered", "busy", "failed",
    "notanswered", "cancelled", "canceled", "timeout", "ringtimeout",
    "callerhangup", "abandoned",
  ];
  const allowed = configuredStatuses.length ? configuredStatuses : defaults;
  return allowed.map((value) => value.toLowerCase().replace(/[\s_-]/g, ""))
    .includes(normalized);
}

function replaceTokens(value: unknown, tokens: Record<string, string>): unknown {
  if (typeof value === "string") {
    return value.replace(/\{(phone|message|schoolName|callId|apiKey)\}/g,
      (match, key: string) => tokens[key] ?? match);
  }
  if (Array.isArray(value)) return value.map((item) => replaceTokens(item, tokens));
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value as Record<string, unknown>)
      .map(([key, item]) => [key, replaceTokens(item, tokens)]));
  }
  return value;
}

interface SmsAdapter {
  send(input: { phone: string; message: string; callId: string }): Promise<string>;
}

/**
 * Generic REST adapter. Configure URL, auth header, content type and JSON body
 * template as secrets. Providers requiring HMAC signing, OAuth refresh, custom
 * multipart payloads or non-REST protocols need a small dedicated adapter.
 */
class GenericRestSmsAdapter implements SmsAdapter {
  async send(input: { phone: string; message: string; callId: string }): Promise<string> {
    const url = smsApiUrl.value().trim();
    if (!url) throw new Error("DRIVEPRO_SMS_API_URL is not configured");
    if (!url.startsWith("https://")) throw new Error("SMS API URL must use HTTPS");
    const method = optionalSecret(smsHttpMethod.value(), "POST").toUpperCase();
    const contentType = optionalSecret(smsContentType.value(), "application/json");
    const authHeader = optionalSecret(smsAuthHeader.value(), "Authorization");
    const authPrefix = optionalSecret(smsAuthPrefix.value(), "");
    const rawExtraHeaders = parseJsonSecret<Record<string, string>>(smsExtraHeaders.value(), {});
    const extraHeaders = Object.fromEntries(Object.entries(rawExtraHeaders).map(([key, value]) => [
      key, value.replaceAll("{apiKey}", smsApiKey.value()),
    ]));
    const template = parseJsonSecret<Record<string, unknown>>(
      smsRequestTemplate.value(),
      { to: "{phone}", message: "{message}" },
    );
    const payload = replaceTokens(template, {
      phone: input.phone,
      message: input.message,
      schoolName: "DrivePro Driving School",
      callId: input.callId,
      apiKey: smsApiKey.value(),
    }) as Record<string, unknown>;
    const headers: Record<string, string> = {
      Accept: "application/json",
      ...extraHeaders,
    };
    if (smsApiKey.value() && smsApiKey.value() !== "none") {
      headers[authHeader] = `${authPrefix}${smsApiKey.value()}`;
    }

    let requestUrl = url;
    let body: string | undefined;
    if (method === "GET") {
      const query = new URLSearchParams();
      for (const [key, value] of Object.entries(payload)) {
        query.set(key, typeof value === "string" ? value : JSON.stringify(value));
      }
      requestUrl += `${requestUrl.includes("?") ? "&" : "?"}${query.toString()}`;
    } else if (contentType.includes("application/x-www-form-urlencoded")) {
      headers["Content-Type"] = contentType;
      const form = new URLSearchParams();
      for (const [key, value] of Object.entries(payload)) {
        form.set(key, typeof value === "string" ? value : JSON.stringify(value));
      }
      body = form.toString();
    } else {
      headers["Content-Type"] = contentType;
      body = JSON.stringify(payload);
    }

    const response = await fetch(requestUrl, { method, headers, body });
    const responseText = await response.text();
    if (!response.ok) {
      throw new Error(`SMS API HTTP ${response.status}: ${responseText.slice(0, 500)}`);
    }
    return responseText.slice(0, 1500);
  }
}

function createSmsAdapter(_providerName: string): SmsAdapter {
  // Provider name is metadata. Any provider with a configurable HTTP REST API
  // uses this adapter; providers with custom signing/protocols can get a new class.
  return new GenericRestSmsAdapter();
}

export const callWebhook = onRequest(
  {
    region: "asia-south1",
    secrets: [
      webhookSecret, callProvider, callFieldMap, missedStatuses, smsProvider, smsApiUrl, smsApiKey,
      smsAuthHeader, smsAuthPrefix, smsHttpMethod, smsContentType,
      smsRequestTemplate, smsExtraHeaders, smsTemplate,
    ],
    cors: false,
    maxInstances: 5,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("POST required");
      return;
    }

    const providedSecret = firstString(
      req.get("x-drivepro-webhook-secret"),
      req.query.secret,
      asRecord(req.body).secret,
    );
    if (!safeEqual(providedSecret, webhookSecret.value())) {
      res.status(401).send("Unauthorized");
      return;
    }

    const body = asRecord(req.body);
    const event = readCallEvent(body);
    if (!event.phoneNumber || !event.callId) {
      res.status(400).json({ error: "Valid caller phone and unique call ID are required" });
      return;
    }
    const statusList = parseJsonSecret<string[]>(missedStatuses.value(), []);
    if (!isMissedCall(event.status, event.answered, statusList)) {
      res.status(200).json({ ok: true, ignored: true, reason: "not a missed call" });
      return;
    }

    const ref = db.collection("call_enquiries").doc(
      createHash("sha256").update(`${callProvider.value()}:${event.callId}`).digest("hex"),
    );
    const created = await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(ref);
      if (existing.exists) return false;
      transaction.create(ref, {
        provider: callProvider.value() || "custom",
        providerCallId: event.callId,
        phoneNumber: event.phoneNumber,
        callStatus: event.status,
        direction: event.direction,
        receivedAt: FieldValue.serverTimestamp(),
        smsProvider: smsProvider.value() || "generic_rest",
        smsStatus: "sending",
        followUpStatus: "pending",
        followUpNotes: "",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (!created) {
      res.status(200).json({ ok: true, duplicate: true });
      return;
    }

    try {
      const message = smsTemplate.value().replaceAll(
        "{schoolName}", "DrivePro Driving School",
      );
      const adapter = createSmsAdapter(smsProvider.value() || "generic_rest");
      const providerResponse = await adapter.send({
        phone: event.phoneNumber,
        message,
        callId: event.callId,
      });
      await ref.update({
        smsStatus: "submitted",
        smsProviderResponse: providerResponse,
        smsSubmittedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      res.status(200).json({ ok: true, smsStatus: "submitted" });
    } catch (error) {
      logger.error("Missed-call SMS submission failed", error);
      await ref.update({
        smsStatus: "failed",
        smsError: error instanceof Error ? error.message : "Unknown SMS error",
        updatedAt: FieldValue.serverTimestamp(),
      });
      // Keep the enquiry record. Admin can inspect the failure; avoid blind retries.
      res.status(200).json({ ok: true, smsStatus: "failed" });
    }
  },
);


function requireAdmin(request: { auth?: { uid?: string } | null }): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in is required.");
  // Read the authoritative Firestore role on every privileged operation.
  return uid;
}

async function assertAdmin(uid: string): Promise<void> {
  const snapshot = await db.collection("users").doc(uid).get();
  const profile = snapshot.data();
  if (!snapshot.exists || profile?.active !== true || profile?.role !== "admin") {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }
}

function requiredText(value: unknown, label: string, max = 160): string {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text || text.length > max) {
    throw new HttpsError("invalid-argument", `${label} is required (maximum ${max} characters).`);
  }
  return text;
}

function safeDocId(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function parseClockMinutes(value: string): number | null {
  const match = value.trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i);
  if (!match) return null;
  let hour = Number(match[1]);
  const minute = Number(match[2]);
  const meridiem = (match[3] ?? "").toUpperCase();
  if (hour > 23 || minute > 59) return null;
  if (meridiem) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (meridiem === "PM" ? 12 : 0);
  }
  return hour * 60 + minute;
}

function isWithinWorkingHours(startAt: Date, durationMinutes: number, rawHours: string): boolean {
  if (!rawHours.trim()) return true;
  const parts = rawHours.split(/\s*-\s*/);
  if (parts.length !== 2) return true; // Unrecognised format is treated as not configured.
  const start = parseClockMinutes(parts[0]);
  const end = parseClockMinutes(parts[1]);
  if (start === null || end === null) return true;
  const indiaTime = new Date(startAt.getTime() + 330 * 60 * 1000);
  const minuteOfDay = indiaTime.getUTCHours() * 60 + indiaTime.getUTCMinutes();
  return minuteOfDay >= start && minuteOfDay + durationMinutes <= end;
}

/**
 * Returns only safe public catalogue fields. Instructor phone, email and
 * licence details are deliberately omitted from this unauthenticated response.
 */
export const getPublicCatalog = onCall(
  { region: "asia-south1", maxInstances: 10 },
  async () => {
    const [vehiclesSnap, instructorsSnap, slotsSnap, lessonsSnap] = await Promise.all([
      db.collection("vehicles").where("active", "==", true).limit(100).get(),
      db.collection("instructors").where("active", "==", true).limit(100).get(),
      db.collection("booking_slots").where("status", "in", ["held", "booked"]).limit(300).get(),
      db.collection("lessons").where("startAt", ">=", Timestamp.now()).limit(300).get(),
    ]);
    const vehicles = vehiclesSnap.docs.map((doc) => {
      const value = doc.data();
      return {
        id: doc.id,
        registrationNumber: firstString(value.registrationNumber),
        makeModel: firstString(value.makeModel),
        transmission: firstString(value.transmission),
        fuelType: firstString(value.fuelType),
        photoUrl: firstString(value.photoUrl),
      };
    });
    const instructors = instructorsSnap.docs.map((doc) => {
      const value = doc.data();
      return {
        id: doc.id,
        name: firstString(value.name),
        assignedVehicleId: firstString(value.assignedVehicleId),
        photoUrl: firstString(value.photoUrl),
        bio: firstString(value.bio),
        workingDays: Array.isArray(value.workingDays) ? value.workingDays : [],
        workingHours: firstString(value.workingHours),
      };
    });
    const slots = slotsSnap.docs.map((doc) => {
      const value = doc.data();
      const startAt = value.startAt as Timestamp | undefined;
      return {
        instructorId: firstString(value.instructorId),
        vehicleId: firstString(value.vehicleId),
        startAt: startAt?.toDate().toISOString() ?? "",
        status: value.status === "booked" ? "booked" : "held",
      };
    }).filter((slot) => slot.startAt);
    for (const doc of lessonsSnap.docs) {
      const value = doc.data();
      const startAt = value.startAt as Timestamp | undefined;
      if (startAt) {
        slots.push({
          instructorId: firstString(value.instructorId),
          vehicleId: firstString(value.vehicleId),
          startAt: startAt.toDate().toISOString(),
          status: "booked",
        });
      }
    }
    return { vehicles, instructors, slots };
  },
);

/**
 * Public booking request. A single deterministic slot document is transactionally
 * held for 15 minutes, preventing concurrent requests from double-booking it.
 * No student login is needed to submit this request.
 */
export const submitBookingRequest = onCall(
  { region: "asia-south1", maxInstances: 10 },
  async (request) => {
    const data = asRecord(request.data);
    const name = requiredText(data.name, "Name", 100);
    const phone = requiredText(data.phone, "Phone", 20);
    const phoneDigits = phone.replace(/\D/g, "");
    if (phoneDigits.length < 10 || phoneDigits.length > 13) {
      throw new HttpsError("invalid-argument", "Enter a valid mobile number.");
    }
    const email = firstString(data.email).toLowerCase();
    const vehicleId = requiredText(data.vehicleId, "Vehicle");
    const instructorId = requiredText(data.instructorId, "Instructor");
    const slotStart = new Date(requiredText(data.startAt, "Lesson date and time", 50));
    const durationMinutes = Number(data.durationMinutes ?? 60);
    const course = firstString(data.course) || "Driving course";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "A valid email address is required.");
    }
    if (Number.isNaN(slotStart.getTime()) || slotStart.getTime() <= Date.now()) {
      throw new HttpsError("invalid-argument", "Choose a future date and time.");
    }
    if (![30, 45, 60, 90, 120].includes(durationMinutes)) {
      throw new HttpsError("invalid-argument", "Unsupported lesson duration.");
    }

    const [vehicleSnap, instructorSnap] = await Promise.all([
      db.collection("vehicles").doc(vehicleId).get(),
      db.collection("instructors").doc(instructorId).get(),
    ]);
    if (!vehicleSnap.exists || vehicleSnap.data()?.active !== true) {
      throw new HttpsError("failed-precondition", "Selected vehicle is not available.");
    }
    if (!instructorSnap.exists || instructorSnap.data()?.active !== true) {
      throw new HttpsError("failed-precondition", "Selected instructor is not available.");
    }

    const vehicle = vehicleSnap.data()!;
    const instructor = instructorSnap.data()!;
    const assignedVehicleId = firstString(instructor.assignedVehicleId);
    if (assignedVehicleId && assignedVehicleId !== vehicleId) {
      throw new HttpsError("failed-precondition", "This instructor is not assigned to the selected vehicle.");
    }
    const workingDays = Array.isArray(instructor.workingDays)
      ? instructor.workingDays.map((day: unknown) => String(day).toLowerCase())
      : [];
    if (workingDays.length) {
      const indiaTime = new Date(slotStart.getTime() + 330 * 60 * 1000);
      const dayName = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"][indiaTime.getUTCDay()];
      const shortDay = dayName.slice(0, 3);
      if (!workingDays.some((day: string) => day === dayName || day === shortDay)) {
        throw new HttpsError("failed-precondition", "The instructor does not work on the selected day.");
      }
    }
    if (!isWithinWorkingHours(slotStart, durationMinutes, firstString(instructor.workingHours))) {
      throw new HttpsError("failed-precondition", "The selected time is outside the instructor's working hours.");
    }
    const slotKey = safeDocId([
      instructorId, vehicleId, slotStart.toISOString(), durationMinutes,
    ].join("|"));
    const slotRef = db.collection("booking_slots").doc(slotKey);
    const enquiryRef = db.collection("booking_requests").doc();
    const rateRef = db.collection("booking_rate_limits").doc(safeDocId(email));

    await db.runTransaction(async (transaction) => {
      const [slotSnap, instructorSlots, vehicleSlots, scheduledLessons, rateSnap] = await Promise.all([
        transaction.get(slotRef),
        transaction.get(db.collection("booking_slots")
          .where("instructorId", "==", instructorId)),
        transaction.get(db.collection("booking_slots")
          .where("vehicleId", "==", vehicleId)),
        transaction.get(db.collection("lessons")
          .where("startAt", ">=", Timestamp.fromMillis(slotStart.getTime() - 2 * 60 * 60 * 1000))
          .where("startAt", "<=", Timestamp.fromMillis(slotStart.getTime() + 2 * 60 * 60 * 1000))),
        transaction.get(rateRef),
      ]);
      const rate = rateSnap.data();
      const windowStart = rate?.windowStart as Timestamp | undefined;
      const withinHour = Boolean(windowStart && Date.now() - windowStart.toMillis() < 60 * 60 * 1000);
      const count = withinHour ? Number(rate?.count ?? 0) : 0;
      if (count >= 3) {
        throw new HttpsError("resource-exhausted", "Too many requests from this email. Please try again later.");
      }
      const slot = slotSnap.data();
      if (slotSnap.exists) {
        const expiry = slot?.holdExpiresAt as Timestamp | undefined;
        const expired = slot?.status === "held" && expiry && expiry.toMillis() <= Date.now();
        if (!expired && (slot?.status === "booked" || slot?.status === "held")) {
          throw new HttpsError("already-exists", "This time slot is no longer available. Please choose another.");
        }
      }
      const requestedEnd = slotStart.getTime() + durationMinutes * 60 * 1000;
      const overlaps = (item: Record<string, unknown>) => {
        const start = item.startAt as Timestamp | undefined;
        if (!start) return false;
        const end = start.toMillis() + Number(item.durationMinutes ?? 60) * 60 * 1000;
        return slotStart.getTime() < end && start.toMillis() < requestedEnd;
      };
      const conflicts = [...instructorSlots.docs, ...vehicleSlots.docs]
        .filter((doc) => doc.id !== slotKey)
        .some((doc) => {
          const item = doc.data();
          if (item.status !== "held" && item.status !== "booked") return false;
          const expiry = item.holdExpiresAt as Timestamp | undefined;
          if (item.status === "held" && expiry && expiry.toMillis() <= Date.now()) return false;
          return overlaps(item);
        });
      const lessonConflict = scheduledLessons.docs.some((doc) => {
        const item = doc.data();
        if (item.status === "cancelled" || item.status === "completed") return false;
        return (item.instructorId === instructorId || item.vehicleId === vehicleId)
          && overlaps(item);
      });
      if (conflicts || lessonConflict) {
        throw new HttpsError("already-exists", "The instructor or vehicle is already occupied during this time.");
      }
      const holdExpiresAt = Timestamp.fromMillis(Date.now() + 15 * 60 * 1000);
      transaction.set(slotRef, {
        instructorId,
        instructorName: firstString(instructor.name),
        vehicleId,
        vehicleRegistration: firstString(vehicle.registrationNumber),
        startAt: Timestamp.fromDate(slotStart),
        durationMinutes,
        status: "held",
        holdExpiresAt,
        bookingRequestId: enquiryRef.id,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(rateRef, {
        count: count + 1,
        windowStart: withinHour ? windowStart! : Timestamp.now(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(enquiryRef, {
        name,
        phone,
        email,
        course,
        instructorId,
        instructorName: firstString(instructor.name),
        vehicleId,
        vehicleRegistration: firstString(vehicle.registrationNumber),
        slotId: slotKey,
        startAt: Timestamp.fromDate(slotStart),
        durationMinutes,
        status: "pending_admin_contact",
        paymentStatus: "unpaid",
        holdExpiresAt,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {
      ok: true,
      requestId: enquiryRef.id,
      holdExpiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
      message: "Request received. The selected slot is temporarily held for 15 minutes. The school will contact you to confirm fees and payment.",
    };
  },
);

/**
 * Admin-only account provisioning. Auth user creation is server-side so the
 * current administrator session is never replaced. Student accounts remain
 * inactive until payment confirmation; instructors are active immediately.
 */
export const createSchoolAccount = onCall(
  { region: "asia-south1", maxInstances: 5 },
  async (request) => {
    const uid = requireAdmin(request);
    await assertAdmin(uid);
    const data = asRecord(request.data);
    const name = requiredText(data.name, "Name", 100);
    const email = requiredText(data.email, "Email", 254).toLowerCase();
    const phone = requiredText(data.phone, "Phone", 20);
    const role = firstString(data.role);
    const totalFee = Number(data.totalFee ?? 0);
    if (role === "student" && (!Number.isFinite(totalFee) || totalFee <= 0)) {
      throw new HttpsError("invalid-argument", "A valid total course fee is required for a student.");
    }
    if (!["student", "instructor"].includes(role)) {
      throw new HttpsError("invalid-argument", "Role must be student or instructor.");
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "Enter a valid email address.");
    }

    const authUser: UserRecord = await getAuth().createUser({
      email,
      displayName: name,
      emailVerified: false,
      disabled: false,
      password: `${randomBytes(32).toString("base64url")}A!9`,
    }).catch((error: unknown) => {
      logger.error("Could not create DrivePro account", error);
      throw new HttpsError("already-exists", "An account may already exist for this email.");
    });

    const profile = {
      uid: authUser.uid,
      name,
      email,
      phone,
      role,
      active: role === "instructor",
      paymentStatus: role === "instructor" ? "not_required" : "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    try {
      await db.collection("users").doc(authUser.uid).set(profile);
      if (role === "student") {
        const bookingRequestId = firstString(data.bookingRequestId);
        const requestSnap = bookingRequestId
          ? await db.collection("booking_requests").doc(bookingRequestId).get()
          : null;
        const requestData = requestSnap?.data();
        await db.collection("students").doc(authUser.uid).set({
          userId: authUser.uid,
          name,
          phone,
          email,
          course: firstString(data.course) || firstString(requestData?.course) || "Driving course",
          totalFee,
          paidFee: 0,
          active: false,
          bookingRequestId: bookingRequestId || null,
          assignedInstructorId: firstString(requestData?.instructorId),
          assignedInstructorName: firstString(requestData?.instructorName),
          assignedVehicleId: firstString(requestData?.vehicleId),
          assignedVehicleRegistration: firstString(requestData?.vehicleRegistration),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (bookingRequestId && requestSnap?.exists) {
          await db.collection("booking_requests").doc(bookingRequestId).update({
            studentUserId: authUser.uid,
            status: "registration_created_pending_payment",
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      } else {
        await db.collection("instructors").doc(authUser.uid).set({
          name,
          phone,
          email,
          active: true,
          userId: authUser.uid,
          assignedVehicleId: firstString(data.assignedVehicleId),
          workingDays: Array.isArray(data.workingDays) ? data.workingDays : [],
          workingHours: firstString(data.workingHours),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      const passwordSetupLink = await getAuth().generatePasswordResetLink(email);
      return { uid: authUser.uid, role, passwordSetupLink, active: role === "instructor" };
    } catch (error) {
      await getAuth().deleteUser(authUser.uid).catch((cleanupError) => {
        logger.error("Failed to roll back newly created Auth user", cleanupError);
      });
      await Promise.all([
        db.collection("users").doc(authUser.uid).delete().catch(() => undefined),
        db.collection("students").doc(authUser.uid).delete().catch(() => undefined),
        db.collection("instructors").doc(authUser.uid).delete().catch(() => undefined),
      ]);
      throw new HttpsError("internal", "Account setup failed. No active account was created.");
    }
  },
);

/** Admin confirms received payment; only then activate registration and book slot. */
export const confirmBookingPayment = onCall(
  { region: "asia-south1", maxInstances: 5 },
  async (request) => {
    const uid = requireAdmin(request);
    await assertAdmin(uid);
    const data = asRecord(request.data);
    const requestId = requiredText(data.requestId, "Booking request ID");
    const amount = Number(data.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new HttpsError("invalid-argument", "A valid payment amount is required.");
    }
    const requestRef = db.collection("booking_requests").doc(requestId);
    await db.runTransaction(async (transaction) => {
      const requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) throw new HttpsError("not-found", "Booking request not found.");
      const booking = requestSnap.data()!;
      const studentUid = firstString(booking.studentUserId);
      if (!studentUid) throw new HttpsError("failed-precondition", "Create the student account before confirming payment.");
      const slotRef = db.collection("booking_slots").doc(firstString(booking.slotId));
      const userRef = db.collection("users").doc(studentUid);
      const studentRef = db.collection("students").doc(studentUid);
      const paymentRef = db.collection("payments").doc();
      const lessonRef = db.collection("lessons").doc();
      const [slotSnap, userSnap] = await Promise.all([
        transaction.get(slotRef), transaction.get(userRef),
      ]);
      if (!slotSnap.exists || !userSnap.exists) {
        throw new HttpsError("failed-precondition", "Student profile or held slot is missing.");
      }
      const slot = slotSnap.data()!;
      const expiry = slot.holdExpiresAt as Timestamp | undefined;
      if (slot.status !== "held" || !expiry || expiry.toMillis() <= Date.now()) {
        throw new HttpsError("failed-precondition", "The temporary slot hold expired. Please choose a new slot.");
      }
      transaction.update(slotRef, {
        status: "booked",
        holdExpiresAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(requestRef, {
        status: "confirmed",
        paymentStatus: "paid",
        paidAmount: amount,
        paymentConfirmedBy: uid,
        paymentConfirmedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, { active: true, paymentStatus: "paid", updatedAt: FieldValue.serverTimestamp() });
      transaction.update(studentRef, { active: true, paidFee: amount, updatedAt: FieldValue.serverTimestamp() });
      transaction.create(lessonRef, {
        studentId: studentUid,
        studentUserId: studentUid,
        studentName: firstString(booking.name),
        instructorId: firstString(booking.instructorId),
        instructorName: firstString(booking.instructorName),
        vehicleId: firstString(booking.vehicleId),
        vehicleRegistration: firstString(booking.vehicleRegistration),
        startAt: booking.startAt,
        durationMinutes: Number(booking.durationMinutes ?? 60),
        notes: "Initial lesson created from confirmed public booking.",
        status: "scheduled",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(paymentRef, {
        studentId: studentUid,
        studentUserId: studentUid,
        studentName: firstString(booking.name),
        amount,
        method: firstString(data.method) || "manual",
        reference: firstString(data.paymentReference),
        status: "paid",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true, message: "Payment confirmed; student account activated and slot booked." };
  },
);

/** Release expired holds and mark their enquiry records expired. */
export const expireBookingHolds = onSchedule(
  { region: "asia-south1", schedule: "every 5 minutes", timeZone: "Asia/Kolkata" },
  async () => {
    const now = Timestamp.now();
    const expired = await db.collection("booking_slots")
      .where("holdExpiresAt", "<=", now)
      .limit(400)
      .get();
    const expiredHolds = expired.docs.filter((doc) => doc.data().status === "held");
    const batch = db.batch();
    for (const doc of expiredHolds) {
      const data = doc.data();
      batch.update(doc.ref, {
        status: "available",
        bookingRequestId: FieldValue.delete(),
        holdExpiresAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      const requestId = firstString(data.bookingRequestId);
      if (requestId) {
        batch.set(db.collection("booking_requests").doc(requestId), {
          status: "expired",
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    }
    if (expiredHolds.length > 0) await batch.commit();
    logger.info("Expired DrivePro booking holds processed", { count: expiredHolds.length });
  },
);

