
package dev.orkitt.automate_aosp

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.Calendar

object AlarmScheduler {
    private fun pending(context: Context, minute: Int = -1): PendingIntent = PendingIntent.getBroadcast(context, 2001,
        Intent(context, AutomationReceiver::class.java).setAction("dev.orkitt.automate_aosp.TIME")
            .putExtra("dueMinute", minute), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun cancel(context: Context) { context.getSystemService(AlarmManager::class.java).cancel(pending(context)) }
    fun schedule(context: Context) {
        val store = RuleStore(context)
        if (!store.flag("monitoring")) { cancel(context); return }
        val now = System.currentTimeMillis(); var next = Long.MAX_VALUE; var nextMinute = -1
        val rules = store.rules()
        for (i in 0 until rules.length()) {
            val rule = rules.getJSONObject(i)
            if (!rule.getBoolean("enabled")) continue
            val conditions = rule.getJSONArray("conditions")
            for (j in 0 until conditions.length()) {
                val c = conditions.getJSONObject(j)
                if (c.getString("type") != "time") continue
                val minute = c.getInt("value")
                val time = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, minute / 60); set(Calendar.MINUTE, minute % 60)
                    set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
                    if (timeInMillis <= now) add(Calendar.DAY_OF_YEAR, 1)
                }.timeInMillis
                if (time < next) { next = time; nextMinute = minute }
            }
        }
        if (nextMinute < 0) { cancel(context); return }
        val manager = context.getSystemService(AlarmManager::class.java)
        try {
            if (DeviceAccess.exact(context)) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending(context, nextMinute))
            else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending(context, nextMinute))
        } catch (e: SecurityException) {
            store.prefs.edit().putString("engineError", "Exact-alarm access changed; time rules may be delayed.").commit()
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending(context, nextMinute))
        }
    }
}
class AutomationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!RuleStore(context).flag("monitoring")) return
        if (intent.action == "dev.orkitt.automate_aosp.TIME") {
            AutomationService.start(context, intent.getIntExtra("dueMinute", -1))
        } else AutomationService.start(context)
        // Scheduling only reads local JSON and calls AlarmManager. Do not queue a
        // BroadcastReceiver pending result behind potentially slow root commands.
        AlarmScheduler.schedule(context.applicationContext)
    }
}
