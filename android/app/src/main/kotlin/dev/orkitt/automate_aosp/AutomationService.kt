
package dev.orkitt.automate_aosp

import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class AutomationService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) AppObserverService.leaveForeground(context)
            evaluate()
            if (intent.action in listOf(Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) {
                EngineWorker.executor.execute { AlarmScheduler.schedule(context) }
            }
        }
    }
    private val poll = object : Runnable {
        override fun run() { evaluate(); handler.postDelayed(this, 30_000) }
    }
    private fun evaluate(dueMinute: Int? = null) { EngineWorker.executor.execute {
        try { AutomationEngine(applicationContext).evaluate(dueMinute = dueMinute) }
        catch (e: Exception) { RuleStore(applicationContext).prefs.edit().putString("engineError", e.message ?: "Engine error").commit() }
    } }
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 34) startForeground(Notifications.MONITOR_ID, Notifications.monitor(this), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        else startForeground(Notifications.MONITOR_ID, Notifications.monitor(this))
        running = true
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_BATTERY_CHANGED); addAction(Intent.ACTION_POWER_CONNECTED); addAction(Intent.ACTION_POWER_DISCONNECTED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED); addAction(WifiManager.WIFI_STATE_CHANGED_ACTION)
            addAction(Intent.ACTION_SCREEN_OFF); addAction(Intent.ACTION_TIME_CHANGED); addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        // Bluetooth broadcasts originate from a privileged system UID, requiring EXPORTED.
        // Broadcasts only prompt a fresh OS-state read; no caller-supplied state is trusted.
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        else registerReceiver(receiver, filter)
        handler.post(poll)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val store = RuleStore(this)
        if (intent?.action == "pause") {
            store.setFlag("monitoring", false)
            AlarmScheduler.cancel(this); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return START_NOT_STICKY
        }
        if (!store.flag("monitoring")) {
            stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return START_NOT_STICKY
        }
        store.prefs.edit().remove("engineError").commit()
        evaluate(if (intent?.hasExtra("dueMinute") == true) intent.getIntExtra("dueMinute", -1) else null)
        EngineWorker.executor.execute { AlarmScheduler.schedule(applicationContext) }
        return START_STICKY
    }
    override fun onDestroy() { running = false; handler.removeCallbacksAndMessages(null); unregisterReceiver(receiver); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
    companion object {
        @Volatile var running = false
        fun start(context: Context, dueMinute: Int? = null) {
            if (!RuleStore(context).flag("monitoring")) return
            val intent = Intent(context, AutomationService::class.java)
            dueMinute?.let { intent.putExtra("dueMinute", it) }
            try { context.startForegroundService(intent) }
            catch (e: Exception) {
                RuleStore(context).prefs.edit().putString("engineError", "Android blocked monitoring: ${e.message}. Reopen Automate and restart monitoring.").commit()
            }
        }
    }
}
