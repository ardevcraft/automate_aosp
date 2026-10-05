
package dev.orkitt.automate_aosp

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.view.accessibility.AccessibilityEvent

// Receives package transitions only; no window content retrieval or gestures.
class AppObserverService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        val className = event.className?.toString() ?: return
        // Ignore popups, keyboards, and system overlays that are not activities.
        try { @Suppress("DEPRECATION") packageManager.getActivityInfo(ComponentName(packageName, className), 0) }
        catch (_: Exception) { return }
        val left = foreground
        if (left == packageName) return
        foreground = packageName
        dispatch(applicationContext, AppTransition(packageName, left))
    }
    override fun onInterrupt() { foreground = "" }
    override fun onDestroy() { foreground = ""; super.onDestroy() }
    companion object {
        @Volatile private var foreground = ""
        private fun dispatch(context: Context, event: AppTransition) {
            if (!RuleStore(context).flag("monitoring")) return
            EngineWorker.executor.execute {
                try { AutomationEngine(context).evaluate(event) }
                catch (e: Exception) { RuleStore(context).prefs.edit().putString("engineError", e.message ?: "App event failed").commit() }
            }
        }
        fun leaveForeground(context: Context) {
            val left = foreground; foreground = ""
            if (left.isNotBlank()) dispatch(context.applicationContext, AppTransition("", left))
        }
    }
}
