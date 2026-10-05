
package dev.orkitt.automate_aosp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

object Notifications {
    const val MONITOR_ID = 1001
    private const val MONITOR = "automation_monitor"
    private const val RESULTS = "automation_results"
    fun channels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(MONITOR, "Background monitoring", NotificationManager.IMPORTANCE_LOW))
        manager.createNotificationChannel(NotificationChannel(RESULTS, "Task results", NotificationManager.IMPORTANCE_DEFAULT))
    }
    private fun open(context: Context): PendingIntent = PendingIntent.getActivity(context, 0,
        Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    fun monitor(context: Context): Notification {
        channels(context)
        val stop = PendingIntent.getService(context, 1, Intent(context, AutomationService::class.java).setAction("pause"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return Notification.Builder(context, MONITOR).setSmallIcon(R.drawable.ic_automation)
            .setContentTitle("Automate is monitoring your tasks").setContentText("Tap to manage • rules run on this device")
            .setContentIntent(open(context)).setOngoing(true).setOnlyAlertOnce(true)
            .addAction(Notification.Action.Builder(null, "Pause", stop).build()).build()
    }
    fun result(context: Context, name: String, message: String, success: Boolean) {
        channels(context)
        context.getSystemService(NotificationManager::class.java).notify(1002, Notification.Builder(context, RESULTS)
            .setSmallIcon(R.drawable.ic_automation).setContentTitle("$name • ${if (success) "executed" else "needs attention"}")
            .setContentText(message).setStyle(Notification.BigTextStyle().bigText(message))
            .setContentIntent(open(context)).setAutoCancel(true).build())
    }
}
