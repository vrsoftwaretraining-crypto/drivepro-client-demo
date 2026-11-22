// Developed by @Ramana Code Softwares

import { createHash, timingSafeEqual } from "node:crypto";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";
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
