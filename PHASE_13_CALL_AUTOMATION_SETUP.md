<!-- Developed by @Ramana Code Softwares -->

# DrivePro Phase 13 — Provider-independent Call Automation

This phase preserves the Phase 1–12 Flutter/Firebase application and adds a provider-neutral missed-call webhook plus a configurable REST SMS adapter.

## What is provider-independent

- Flutter UI and Firestore enquiry schema do not depend on a telephony/SMS vendor.
- Call provider name is stored as metadata. Incoming JSON/form webhook fields are normalized using `DRIVEPRO_CALL_FIELD_MAP_JSON`.
- SMS requests are sent through a generic REST adapter configured with URL, API key, auth header/prefix, method, content type, extra headers and a JSON request template.
- Switching between REST providers normally requires changing Firebase secrets and the provider's webhook field map, not Flutter source code.

## Important limits

No single implementation can automatically work with every vendor without knowing its API contract. Providers requiring HMAC request signing, OAuth token refresh, custom challenge verification, multipart payloads, non-REST protocols, or a proprietary call-control flow need a dedicated adapter in `functions/src/index.ts`. The included generic adapter supports common HTTPS REST APIs using JSON, URL-encoded form data, or GET query parameters.

The call webhook currently authenticates using the shared `x-drivepro-webhook-secret` header (or `?secret=` query parameter). If a vendor requires its own signature verification, implement and test that verification before production. Prefer the header; query secrets may appear in logs.

## 1. Prerequisites

- Node.js 20+
- Firebase CLI logged into the correct project
- Firebase project on the Blaze plan for deployed Cloud Functions and outbound API calls
- Firestore and Firebase Authentication configured
- A cloud telephony number/provider that can send missed/no-answer call events to an HTTPS webhook
- An SMS provider account and approved Indian DLT sender/template configuration

From the `drivepro` root:

```powershell
npm install -g firebase-tools
firebase login
firebase use --add
```

## 2. Configure the telephony webhook

The deployed endpoint is `callWebhook`. Configure the provider to POST its call event to the HTTPS function URL.

Set `DRIVEPRO_CALL_WEBHOOK_SECRET` to a long random secret. Ask the provider to send it as the `x-drivepro-webhook-secret` header.

The default field aliases support common names for:
- Caller number: `from`, `caller`, `caller_number`, `from_number`, `customer_number`, `phone`, `phoneNumber`, `source`, `msisdn`
- Unique call ID: `call_id`, `callId`, `id`, `uuid`, `sid`
- Call status: `status`, `call_status`, `disposition`, `event`, `event_type`
- Answered flag: `answered`
- Direction: `direction`, `call_direction`

If the provider uses different fields, set `DRIVEPRO_CALL_FIELD_MAP_JSON` to a JSON object containing dot paths. Example:

```json
{
  "phone": "data.customer.mobile",
  "callId": "data.call.uuid",
  "status": "data.call.disposition",
  "answered": "data.call.was_answered",
  "direction": "data.call.direction"
}
```

These paths are examples only. Replace them with paths from the actual vendor webhook sample. By default, call status must normalize to one of: `missed`, `missed_call`, `no_answer`, `unanswered`, `busy`, `failed`, `not_answered`, `cancelled`, `canceled`, `timeout`, `ring_timeout`, `caller_hangup`, or `abandoned`. If the vendor uses different status values, configure `DRIVEPRO_CALL_MISSED_STATUSES_JSON`, e.g. `["no-answer","caller-disconnected"]`. An answered flag other than false/0/empty causes the event to be ignored.

## 3. Configure SMS provider (generic REST)

The adapter accepts the following Firebase secrets:

| Secret | Example | Purpose |
|---|---|---|
| `DRIVEPRO_SMS_PROVIDER` | `my-sms-vendor` | Provider label saved with enquiry |
| `DRIVEPRO_SMS_API_URL` | `https://api.vendor.in/v1/messages` | HTTPS endpoint |
| `DRIVEPRO_SMS_API_KEY` | vendor API key | API credential; use `none` only if no key is required |
| `DRIVEPRO_SMS_AUTH_HEADER` | `Authorization` or `x-api-key` | Header carrying API key |
| `DRIVEPRO_SMS_AUTH_PREFIX` | `Bearer ` | Prefix before key; blank if none |
| `DRIVEPRO_SMS_HTTP_METHOD` | `POST` | `POST`, `PUT`, or `GET` supported by the endpoint |
| `DRIVEPRO_SMS_CONTENT_TYPE` | `application/json` | JSON or `application/x-www-form-urlencoded` |
| `DRIVEPRO_SMS_REQUEST_TEMPLATE_JSON` | `{"to":"{phone}","text":"{message}"}` | Vendor request body template |
| `DRIVEPRO_SMS_EXTRA_HEADERS_JSON` | `{}` | Additional static headers; `{apiKey}` token supported |
| `DRIVEPRO_SMS_TEMPLATE` | approved DLT text | Exact approved SMS content |

Available request-template tokens: `{phone}` (E.164, e.g. `+919876543210`), `{message}`, `{schoolName}`, `{callId}`, `{apiKey}`.

Example configuration for a generic JSON REST SMS API (adapt field names to the vendor's documentation):

```json
{
  "recipient": "{phone}",
  "message": "{message}",
  "sender": "YOUR_APPROVED_HEADER"
}
```

For an API that expects its key in a JSON body, include `"api_key":"{apiKey}"` in the request template and set the API-key secret. For an API that expects a custom header, configure `DRIVEPRO_SMS_AUTH_HEADER` and `DRIVEPRO_SMS_AUTH_PREFIX`, or use `DRIVEPRO_SMS_EXTRA_HEADERS_JSON`.

Set every secret from PowerShell at the project root. Firebase CLI prompts for each value:

```powershell
firebase functions:secrets:set DRIVEPRO_CALL_WEBHOOK_SECRET
firebase functions:secrets:set DRIVEPRO_CALL_PROVIDER
firebase functions:secrets:set DRIVEPRO_CALL_FIELD_MAP_JSON
firebase functions:secrets:set DRIVEPRO_CALL_MISSED_STATUSES_JSON
firebase functions:secrets:set DRIVEPRO_SMS_PROVIDER
firebase functions:secrets:set DRIVEPRO_SMS_API_URL
firebase functions:secrets:set DRIVEPRO_SMS_API_KEY
firebase functions:secrets:set DRIVEPRO_SMS_AUTH_HEADER
firebase functions:secrets:set DRIVEPRO_SMS_AUTH_PREFIX
firebase functions:secrets:set DRIVEPRO_SMS_HTTP_METHOD
firebase functions:secrets:set DRIVEPRO_SMS_CONTENT_TYPE
firebase functions:secrets:set DRIVEPRO_SMS_REQUEST_TEMPLATE_JSON
firebase functions:secrets:set DRIVEPRO_SMS_EXTRA_HEADERS_JSON
firebase functions:secrets:set DRIVEPRO_SMS_TEMPLATE
```

For secrets that are not needed, use safe values such as `none`, blank (if the CLI accepts it), `{}` or the documented defaults. To avoid ambiguity, recommended values are:

- `DRIVEPRO_CALL_PROVIDER`: the actual telephony vendor name
- `DRIVEPRO_CALL_FIELD_MAP_JSON`: `{}` when default aliases work
- `DRIVEPRO_CALL_MISSED_STATUSES_JSON`: `[]` when default missed statuses work
- `DRIVEPRO_SMS_PROVIDER`: the actual SMS vendor name
- `DRIVEPRO_SMS_AUTH_HEADER`: `Authorization`
- `DRIVEPRO_SMS_AUTH_PREFIX`: `Bearer ` or blank per vendor
- `DRIVEPRO_SMS_HTTP_METHOD`: `POST`
- `DRIVEPRO_SMS_CONTENT_TYPE`: `application/json`
- `DRIVEPRO_SMS_EXTRA_HEADERS_JSON`: `{}`

The request template and auth settings must match the selected provider's official API documentation. Never copy an example request without verifying it against your account/API version.

## 4. DLT / India SMS compliance

Before sending real messages in India, complete applicable Principal Entity/DLT registration, sender header and exact template approval. Use the matching approved template and any provider-required entity/template IDs. Confirm the SMS provider supports the approved service/transactional category and the intended customer-care acknowledgement. Do not send marketing content as a service message without the correct consent and classification.

## 5. Install, build and deploy

From the project root:

```powershell
cd functions
npm install
npm run build
cd ..
firebase deploy --only firestore:rules
firebase deploy --only functions:callWebhook
```

Get the deployed function URL from Firebase Console → Functions and paste it into the telephony provider's webhook configuration.

For Flutter:

```powershell
flutter pub get
flutter analyze
flutter run -d chrome
```

Sign in with an active admin account and open **Call Enquiries**.

## 6. Example webhook test (after deployment)

Use your deployed function URL and a test phone number you control. This example assumes default field aliases and a shared-secret header:

```powershell
$headers = @{ "x-drivepro-webhook-secret" = "YOUR_LONG_WEBHOOK_SECRET" }
$body = @{
  from = "9876543210"
  call_id = "drivepro-test-call-001"
  status = "no_answer"
  answered = $false
  direction = "inbound"
} | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "YOUR_CALL_WEBHOOK_URL" -Headers $headers -ContentType "application/json" -Body $body
```

Use a new call ID for each test. Reusing the same call ID intentionally exercises duplicate protection. Do not use a real customer's number without the appropriate notice/consent and compliant messaging setup.

## 7. Test checklist before buying/launching a number

- Answered call: no acknowledgement SMS.
- Ring timeout/no-answer: one enquiry and one SMS API submission.
- Caller hangs up before answer: verify provider actually emits a missed/unanswered event.
- Duplicate webhook delivery: no second enquiry/SMS.
- Invalid webhook secret: HTTP 401.
- Missing phone or call ID: HTTP 400.
- Invalid phone: event rejected.
- SMS API rejection: enquiry remains saved and SMS status is `failed`.
- Successful API acceptance: status is `submitted`, not `delivered`.
- Admin can read/update enquiry; non-admin cannot read or update it.
- Provider-specific signature verification, if required, is implemented and tested.

## 8. Operational notes

- `submitted` means the SMS API accepted the request; it is not proof of delivery. A provider delivery-report webhook is a future adapter enhancement.
- SMS failure is recorded but automatic retry is intentionally not enabled, to avoid accidental duplicate messages. Add provider-aware retry only after confirming idempotency.
- Call ID must be stable across webhook retries for deduplication to work.
- Caller ID withheld by the caller or invalid/non-Indian number is not sent an SMS.
- This code records missed calls only. It does not receive or record the audio call itself.
- Protect customer phone numbers, set retention rules, publish a privacy notice, and configure opt-out handling as applicable.
- The ZIP is source-code packaged and archive integrity checked. Run `npm run build`, `flutter analyze`, and real provider sandbox/live tests in your environment before production.
