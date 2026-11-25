// Developed by @Ramana Code Softwares
// Auto SMS for incoming calls (missed / answered). Runs from a manifest
// receiver, so it works even when the app is closed.
package __PACKAGE__

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.CallLog
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

object AutoReply {
    private const val PREFS = "drivepro_autoreply"
    const val DEFAULT_MISSED =
        "Sorry we missed your call to {school}. Thank you for your interest in our driving classes. We will call you back shortly. - {school}"
    const val DEFAULT_ANSWERED =
        "Thank you for calling {school}. Thanks for your interest in our driving classes, we will get back to you soon. - {school}"

    fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun has(c: Context, perm: String) =
        ContextCompat.checkSelfPermission(c, perm) == PackageManager.PERMISSION_GRANTED

    fun config(c: Context): Map<String, Any> {
        val p = prefs(c)
        return mapOf(
            "enabled" to p.getBoolean("enabled", false),
            "schoolName" to (p.getString("schoolName", "") ?: ""),
            "missedTemplate" to (p.getString("missedTemplate", DEFAULT_MISSED) ?: DEFAULT_MISSED),
            "answeredTemplate" to (p.getString("answeredTemplate", DEFAULT_ANSWERED) ?: DEFAULT_ANSWERED),
            "sendMissed" to p.getBoolean("sendMissed", true),
            "sendAnswered" to p.getBoolean("sendAnswered", true),
            "cooldownMinutes" to p.getInt("cooldownMinutes", 30),
        )
    }

    fun saveConfig(c: Context, m: Map<*, *>) {
        val e = prefs(c).edit()
        (m["enabled"] as? Boolean)?.let { e.putBoolean("enabled", it) }
        (m["schoolName"] as? String)?.let { e.putString("schoolName", it.trim()) }
        (m["missedTemplate"] as? String)?.let { e.putString("missedTemplate", it) }
        (m["answeredTemplate"] as? String)?.let { e.putString("answeredTemplate", it) }
        (m["sendMissed"] as? Boolean)?.let { e.putBoolean("sendMissed", it) }
        (m["sendAnswered"] as? Boolean)?.let { e.putBoolean("sendAnswered", it) }
        (m["cooldownMinutes"] as? Number)?.let { e.putInt("cooldownMinutes", it.toInt().coerceIn(0, 1440)) }
        e.apply()
    }

    fun permissions(c: Context) = mapOf(
        "sms" to has(c, Manifest.permission.SEND_SMS),
        "callLog" to has(c, Manifest.permission.READ_CALL_LOG),
        "phoneState" to has(c, Manifest.permission.READ_PHONE_STATE),
    )

    fun render(template: String, school: String): String =
        template.replace("{school}", if (school.isBlank()) "our driving school" else school)

    @Suppress("DEPRECATION")
    fun sendSms(c: Context, to: String, text: String) {
        val sms = if (Build.VERSION.SDK_INT >= 31) c.getSystemService(SmsManager::class.java)
        else SmsManager.getDefault()
        val parts = sms.divideMessage(text)
        sms.sendMultipartTextMessage(to, null, parts, null, null)
    }

    @Synchronized
    fun addLog(c: Context, entry: JSONObject) {
        val p = prefs(c)
        val old = JSONArray(p.getString("log", "[]"))
        val list = JSONArray()
        list.put(entry)
        for (i in 0 until minOf(old.length(), 99)) list.put(old.get(i))
        p.edit().putString("log", list.toString()).apply()
    }

    fun log(c: Context): String = prefs(c).getString("log", "[]") ?: "[]"

    @Synchronized
    fun markSynced(c: Context, ids: Collection<*>) {
        val p = prefs(c)
        val arr = JSONArray(p.getString("log", "[]"))
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (ids.contains(o.optString("id"))) o.put("synced", true)
        }
        p.edit().putString("log", arr.toString()).apply()
    }
}

class CallAutoReplyReceiver : BroadcastReceiver() {

    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        val p = AutoReply.prefs(context)

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                val e = p.edit().putBoolean("ringing", true)
                if (!p.getBoolean("ringing", false)) e.putBoolean("answered", false)
                if (!number.isNullOrBlank()) e.putString("number", number)
                e.putLong("ringAt", System.currentTimeMillis()).apply()
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                if (p.getBoolean("ringing", false)) p.edit().putBoolean("answered", true).apply()
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                val wasRinging = p.getBoolean("ringing", false)
                val answered = p.getBoolean("answered", false)
                val stored = p.getString("number", "") ?: ""
                val ringAt = p.getLong("ringAt", 0L)
                p.edit().putBoolean("ringing", false).putBoolean("answered", false)
                    .remove("number").apply()
                if (!wasRinging) return // outgoing call or duplicate broadcast
                val pending = goAsync()
                Thread {
                    try {
                        // The call log is written a moment after the call ends.
                        Thread.sleep(2500)
                        handle(context, stored, answered, ringAt)
                    } catch (_: Exception) {
                    } finally {
                        pending.finish()
                    }
                }.start()
            }
        }
    }

    private fun handle(context: Context, storedNumber: String, stateAnswered: Boolean, ringAt: Long) {
        val cfg = AutoReply.config(context)
        var number = storedNumber
        var answered = stateAnswered

        // Authoritative source when permitted: the latest call-log row.
        if (AutoReply.has(context, Manifest.permission.READ_CALL_LOG)) {
            try {
                context.contentResolver.query(
                    CallLog.Calls.CONTENT_URI,
                    arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DURATION, CallLog.Calls.DATE),
                    null, null, CallLog.Calls.DATE + " DESC",
                )?.use { c ->
                    if (c.moveToFirst()) {
                        val date = c.getLong(3)
                        val fresh = date >= ringAt - 5000 && date <= System.currentTimeMillis() + 5000
                        val type = c.getInt(1)
                        if (fresh && (type == CallLog.Calls.INCOMING_TYPE ||
                                type == CallLog.Calls.MISSED_TYPE ||
                                type == CallLog.Calls.REJECTED_TYPE)) {
                            if (number.isBlank()) number = c.getString(0) ?: ""
                            answered = type == CallLog.Calls.INCOMING_TYPE && c.getLong(2) > 0
                        }
                    }
                }
            } catch (_: SecurityException) {
            }
        }

        val kind = if (answered) "answered" else "missed"
        val digits = number.filter { it.isDigit() }
        val id = "${System.currentTimeMillis()}_$digits"
        fun log(status: String) = AutoReply.addLog(
            context,
            JSONObject().put("id", id).put("at", System.currentTimeMillis())
                .put("number", number).put("kind", kind).put("sms", status).put("synced", false),
        )

        if (cfg["enabled"] != true) return
        if (digits.length < 10) { // private number / short code
            log("skipped: number hidden")
            return
        }
        if (kind == "missed" && cfg["sendMissed"] != true) return
        if (kind == "answered" && cfg["sendAnswered"] != true) return
        if (!AutoReply.has(context, Manifest.permission.SEND_SMS)) {
            log("failed: SMS permission missing")
            return
        }
        val cooldown = (cfg["cooldownMinutes"] as Int) * 60_000L
        val p = AutoReply.prefs(context)
        val key = "last_" + digits.takeLast(10)
        val last = p.getLong(key, 0L)
        if (cooldown > 0 && System.currentTimeMillis() - last < cooldown) {
            log("skipped: already messaged recently")
            return
        }
        val template = (if (kind == "missed") cfg["missedTemplate"] else cfg["answeredTemplate"]) as String
        try {
            AutoReply.sendSms(context, number.replace(" ", ""), AutoReply.render(template, cfg["schoolName"] as String))
            p.edit().putLong(key, System.currentTimeMillis()).apply()
            log("sent")
        } catch (e: Exception) {
            log("failed: " + (e.message ?: "unknown error").take(80))
        }
    }
}
