// Developed by @Ramana Code Softwares
package __PACKAGE__

import android.Manifest
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "drivepro/call_autoreply")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getConfig" -> result.success(AutoReply.config(this))
                    "saveConfig" -> {
                        AutoReply.saveConfig(this, call.arguments as Map<*, *>)
                        result.success(true)
                    }
                    "permissions" -> result.success(AutoReply.permissions(this))
                    "requestPermissions" -> {
                        pending = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                Manifest.permission.SEND_SMS,
                                Manifest.permission.READ_CALL_LOG,
                                Manifest.permission.READ_PHONE_STATE,
                            ),
                            4711,
                        )
                    }
                    "getLog" -> result.success(AutoReply.log(this))
                    "markSynced" -> {
                        AutoReply.markSynced(this, call.arguments as List<*>)
                        result.success(true)
                    }
                    "sendTest" -> {
                        try {
                            val cfg = AutoReply.config(this)
                            val to = (call.arguments as String).replace(" ", "")
                            AutoReply.sendSms(
                                this, to,
                                AutoReply.render(cfg["answeredTemplate"] as String, cfg["schoolName"] as String),
                            )
                            result.success("sent")
                        } catch (e: Exception) {
                            result.error("sms_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4711) {
            pending?.success(AutoReply.permissions(this))
            pending = null
        }
    }
}
