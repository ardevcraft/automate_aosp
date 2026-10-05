
package dev.orkitt.automate_aosp

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import org.json.JSONObject

object DeviceAccess {
    fun permission(context: Context, name: String): Boolean = context.checkSelfPermission(name) == PackageManager.PERMISSION_GRANTED
    fun accessibility(context: Context): Boolean {
        val expected = "${context.packageName}/${AppObserverService::class.java.name}"
        return Settings.Secure.getInt(context.contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0) == 1 &&
            (Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: "")
                .split(':').any { android.content.ComponentName.unflattenFromString(it)?.flattenToString() == expected }
    }
    fun exact(context: Context): Boolean = Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    fun status(context: Context): JSONObject {
        val store = RuleStore(context)
        val nm = context.getSystemService(NotificationManager::class.java)
        return JSONObject().put("monitoring", store.flag("monitoring")).put("running", AutomationService.running)
            .put("notifications", nm.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 33 || permission(context, Manifest.permission.POST_NOTIFICATIONS)))
            .put("bluetooth", Build.VERSION.SDK_INT < 31 || permission(context, Manifest.permission.BLUETOOTH_CONNECT))
            .put("writeSettings", Settings.System.canWrite(context)).put("dnd", nm.isNotificationPolicyAccessGranted)
            .put("accessibility", accessibility(context)).put("batteryExempt", context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName))
            .put("exactAlarms", exact(context)).put("shizukuRunning", PrivilegeBridge.running()).put("shizukuGranted", PrivilegeBridge.granted())
            .put("rootGranted", store.flag("rootGranted")).put("resultNotifications", store.flag("resultNotifications", true))
            .put("mode", store.prefs.getString("mode", "standard")).put("engineError", store.prefs.getString("engineError", ""))
    }
    fun missing(context: Context, rule: JSONObject): List<String> {
        val missing = linkedSetOf<String>()
        val store = RuleStore(context)
        val mode = store.prefs.getString("mode", "standard")
        val conditions = rule.getJSONArray("conditions")
        for (i in 0 until conditions.length()) when (conditions.getJSONObject(i).getString("type")) {
            "bluetooth" -> if (Build.VERSION.SDK_INT >= 31 && !permission(context, Manifest.permission.BLUETOOTH_CONNECT)) missing.add("Bluetooth access")
            "appOpen", "appLeave" -> if (!accessibility(context)) missing.add("App detection (Accessibility)")
        }
        val actions = rule.getJSONArray("actions")
        for (i in 0 until actions.length()) when (actions.getJSONObject(i).getString("type")) {
            "wifi", "bluetooth", "mobileData", "airplane" -> when (mode) {
                "standard" -> missing.add("Select root or Shizuku for radio actions")
                "shizuku" -> if (!PrivilegeBridge.granted()) missing.add("Start and authorize Shizuku")
                "root" -> if (!store.flag("rootGranted")) missing.add("Root authorization")
            }
            "dnd" -> if (!context.getSystemService(NotificationManager::class.java).isNotificationPolicyAccessGranted) missing.add("Do Not Disturb access")
            else -> when (mode) {
                "standard" -> if (!Settings.System.canWrite(context)) missing.add("Modify system settings")
                "shizuku" -> if (!PrivilegeBridge.granted()) missing.add("Start and authorize Shizuku")
                "root" -> if (!store.flag("rootGranted")) missing.add("Root authorization")
            }
        }
        return missing.toList()
    }
}
