
package dev.orkitt.automate_aosp

import android.app.NotificationManager
import android.content.Context
import android.provider.Settings
import org.json.JSONObject

class ActionExecutor(private val context: Context) {
    fun execute(action: JSONObject): String {
        val type = action.getString("type"); val value = action.getInt("value")
        if (type == "dnd") {
            val manager = context.getSystemService(NotificationManager::class.java)
            check(manager.isNotificationPolicyAccessGranted) { "Grant Do Not Disturb access" }
            manager.setInterruptionFilter(if (value == 1) NotificationManager.INTERRUPTION_FILTER_PRIORITY else NotificationManager.INTERRUPTION_FILTER_ALL)
            // Android 15+ updates the app-owned implicit Zen rule, not other apps' DND.
            return "DND ${if (value == 1) "on" else "off"} requested for Automate"
        }
        val mode = RuleStore(context).prefs.getString("mode", "standard")
        return when (mode) {
            "shizuku" -> PrivilegeBridge.execute(context, type, value)
            "root" -> {
                check(RuleStore(context).flag("rootGranted")) { "Authorize root first" }
                PrivilegeBridge.root(type, value)
            }
            else -> {
                check(Settings.System.canWrite(context)) { "Grant Modify system settings, or select root/Shizuku for radios" }
                fun write(key: String, v: Int) { check(Settings.System.putInt(context.contentResolver, key, v)) { "Could not change $key" } }
                when (type) {
                    "autoBrightness" -> write(Settings.System.SCREEN_BRIGHTNESS_MODE, value)
                    "brightness" -> { write(Settings.System.SCREEN_BRIGHTNESS_MODE, 0); write(Settings.System.SCREEN_BRIGHTNESS, value * 255 / 100) }
                    "orientation" -> {
                        write(Settings.System.ACCELEROMETER_ROTATION, if (value == 0) 1 else 0)
                        if (value != 0) write(Settings.System.USER_ROTATION, if (value == 1) 0 else 1)
                    }
                    else -> error("$type needs root or Shizuku on this Android device")
                }
                "$type applied"
            }
        }
    }
}
