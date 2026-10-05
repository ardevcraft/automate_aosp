
package dev.orkitt.automate_aosp

import android.Manifest
import android.app.NotificationManager
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import org.json.JSONObject
import java.util.Calendar
import java.util.concurrent.Executors

object EngineWorker {
    val executor = Executors.newSingleThreadExecutor()
}
data class AppTransition(val opened: String, val left: String)
class AutomationEngine(private val context: Context) {
    private val store = RuleStore(context)
    private fun <T> awake(block: () -> T): T {
        val lock = context.getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Automate:execute")
        lock.acquire(600_000)
        return try { block() } finally { if (lock.isHeld) lock.release() }
    }
    fun evaluate(event: AppTransition? = null, dueMinute: Int? = null) = awake { evaluateAwake(event, dueMinute) }
    private fun evaluateAwake(event: AppTransition?, dueMinute: Int?) {
        if (!store.flag("monitoring")) return
        recoverPending()
        val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val percent = if (level >= 0 && scale > 0) level * 100 / scale else null
        val charging = battery?.let { it.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0 }
        val wifi = try { context.applicationContext.getSystemService(WifiManager::class.java).isWifiEnabled } catch (_: Exception) { null }
        val bluetooth = if (Build.VERSION.SDK_INT >= 31 && !DeviceAccess.permission(context, Manifest.permission.BLUETOOTH_CONNECT)) null
            else try { context.getSystemService(BluetoothManager::class.java).adapter?.isEnabled } catch (_: Exception) { null }
        val calendar = Calendar.getInstance()
        val minute = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        val day = "${calendar.get(Calendar.YEAR)}-${calendar.get(Calendar.DAY_OF_YEAR)}"
        val rules = store.rules()
        for (i in 0 until rules.length()) {
            // Edits and evaluations share one worker; a UI mutation cannot race this snapshot.
            val rule = rules.getJSONObject(i)
            if (!rule.getBoolean("enabled")) continue
            val id = rule.getString("id")
            val conditions = rule.getJSONArray("conditions")
            var eventHit = false
            val consumedTimes = mutableListOf<Int>()
            val values = (0 until conditions.length()).map { index ->
                val c = conditions.getJSONObject(index); val value = c.getInt("value")
                when (c.getString("type")) {
                    "bluetooth" -> bluetooth != null && bluetooth == (value == 1)
                    "wifi" -> wifi != null && wifi == (value == 1)
                    "charging" -> charging != null && charging == (value == 1)
                    "batteryBelow" -> percent != null && percent <= value
                    "batteryAbove" -> percent != null && percent >= value
                    "appOpen" -> (event?.opened == c.getString("text")).also { if (it) eventHit = true }
                    "appLeave" -> (event?.left == c.getString("text")).also { if (it) eventHit = true }
                    "time" -> ((minute == value || dueMinute == value) && store.prefs.getString("time_${id}_$index", "") != day).also {
                        if (it) { eventHit = true; consumedTimes.add(index) }
                    }
                    else -> false
                }
            }
            val matched = RuleLogic.matches(rule.getString("match"), values)
            val now = System.currentTimeMillis()
            val last = store.prefs.getLong("last_$id", 0)
            val run = RuleLogic.shouldRun(matched, store.flag("matched_$id"), eventHit, now, last)
            if (!run) { store.setFlag("matched_$id", matched); continue }
            // Persist the edge, daily dedup and pending execution atomically before
            // side effects. A process death can then resume unfinished actions.
            val editor = store.prefs.edit().putBoolean("matched_$id", matched).putLong("last_$id", now)
                .putString("pendingRule", rule.toString()).putInt("pendingIndex", 0).putBoolean("pendingManual", false)
            consumedTimes.forEach { editor.putString("time_${id}_$it", day) }
            check(editor.commit()) { "Could not persist execution state" }
            runRule(rule)
        }
    }
    fun recoverPending() {
        val saved = store.prefs.getString("pendingRule", null) ?: return
        val pending = JSONObject(saved)
        val rules = store.rules()
        val current = (0 until rules.length()).map { rules.getJSONObject(it) }
            .firstOrNull { it.getString("id") == pending.getString("id") }
        val manual = store.flag("pendingManual")
        if (current == null || (!manual && (!current.getBoolean("enabled") || !store.flag("monitoring"))) ||
            current.getJSONArray("actions").toString() != pending.getJSONArray("actions").toString()) {
            check(store.prefs.edit().remove("pendingRule").remove("pendingIndex").remove("pendingManual").commit())
            return
        }
        awake { runAwake(current, store.prefs.getInt("pendingIndex", 0), manual, recovering = true) }
    }
    fun runRule(rule: JSONObject, manual: Boolean = false): String = awake { runAwake(rule, 0, manual) }
    private fun runAwake(rule: JSONObject, start: Int, manual: Boolean, recovering: Boolean = false): String {
        val messages = mutableListOf<String>(); var success = true
        if (recovering) messages.add("Resumed after an interrupted execution (from action ${start + 1})")
        try {
            val missing = DeviceAccess.missing(context, rule)
            check(missing.isEmpty()) { "Permission needed: ${missing.joinToString(", ")}" }
            val actions = rule.getJSONArray("actions")
            val executor = ActionExecutor(context)
            check(store.prefs.edit().putString("pendingRule", rule.toString()).putInt("pendingIndex", start)
                .putBoolean("pendingManual", manual).commit()) { "Could not save execution checkpoint" }
            for (i in start until actions.length()) {
                try {
                    messages.add("${i + 1}. ${executor.execute(actions.getJSONObject(i))}")
                    // Actions set explicit states, so replay after a crash between the
                    // system call and checkpoint commit remains idempotent.
                    check(store.prefs.edit().putInt("pendingIndex", i + 1).commit()) { "Could not save action progress" }
                }
                catch (e: Exception) { error("Action ${i + 1} failed: ${e.message}. Remaining actions were skipped.") }
            }
        } catch (e: Exception) { success = false; messages.add(e.message ?: "Execution failed") }
        val message = messages.joinToString("\n")
        store.log(rule, success, message)
        if (store.flag("resultNotifications", true)) {
            try { Notifications.result(context, rule.getString("name"), message, success) } catch (_: SecurityException) { }
        }
        return message
    }
}
