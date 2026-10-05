
package dev.orkitt.automate_aosp

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.orkitt.automate_aosp/automation")
            .setMethodCallHandler { call, result ->
                if (call.method == "permission" && call.argument<String>("permission") != "root") {
                    try { requestAccess(call.argument<String>("permission") ?: ""); result.success(null) }
                    catch (e: Exception) { result.error("permission", e.message, null) }
                    return@setMethodCallHandler
                }
                EngineWorker.executor.execute {
                    try {
                        val store = RuleStore(applicationContext)
                        val response: Any? = when (call.method) {
                            "snapshot" -> JSONObject().put("rules", store.rules()).put("history", store.history())
                                .put("access", DeviceAccess.status(applicationContext)).toString()
                            "save" -> {
                                val rule = JSONObject(requireNotNull(call.argument<String>("rule")))
                                if (store.flag("monitoring") && rule.optBoolean("enabled")) {
                                    store.validate(rule)
                                    val missing = DeviceAccess.missing(applicationContext, rule)
                                    check(missing.isEmpty()) { "Grant permissions before enabling this task: ${missing.joinToString(", ")}" }
                                }
                                store.save(rule); AlarmScheduler.schedule(applicationContext)
                                if (store.flag("monitoring")) {
                                    main.post { AutomationService.start(applicationContext) }
                                }; null
                            }
                            "delete" -> { store.delete(requireNotNull(call.argument<String>("id"))); AlarmScheduler.schedule(applicationContext); null }
                            "monitoring" -> {
                                val enabled = call.argument<Boolean>("enabled") == true
                                if (enabled) {
                                    val missing = linkedSetOf<String>(); val rules = store.rules()
                                    for (i in 0 until rules.length()) if (rules.getJSONObject(i).getBoolean("enabled"))
                                        missing.addAll(DeviceAccess.missing(applicationContext, rules.getJSONObject(i)))
                                    check(missing.isEmpty()) { "Open Permissions & settings: ${missing.joinToString(", ")}" }
                                }
                                if (enabled && !store.flag("monitoring")) {
                                    val editor = store.prefs.edit(); val rules = store.rules()
                                    for (i in 0 until rules.length()) editor.remove("matched_${rules.getJSONObject(i).getString("id")}")
                                    check(editor.commit())
                                }
                                store.setFlag("monitoring", enabled)
                                main.post {
                                    if (enabled) AutomationService.start(applicationContext)
                                    else stopService(Intent(applicationContext, AutomationService::class.java))
                                }
                                AlarmScheduler.schedule(applicationContext); null
                            }
                            "mode" -> {
                                val mode = requireNotNull(call.argument<String>("mode"))
                                require(mode in listOf("standard", "shizuku", "root"))
                                check(store.prefs.edit().putString("mode", mode).commit()); null
                            }
                            "notifications" -> {
                                val enabled = call.argument<Boolean>("enabled") == true
                                store.setFlag("resultNotifications", enabled)
                                if (!enabled) getSystemService(android.app.NotificationManager::class.java).cancel(1002)
                                null
                            }
                            "permission" -> {
                                store.setFlag("rootGranted", false)
                                check(PrivilegeBridge.authorizeRoot()) { "Root access denied" }
                                store.setFlag("rootGranted", true); null
                            }
                            "run" -> {
                                val rules = store.rules(); var rule: JSONObject? = null
                                for (i in 0 until rules.length()) if (rules.getJSONObject(i).getString("id") == call.argument<String>("id")) rule = rules.getJSONObject(i)
                                checkNotNull(rule) { "Task no longer exists" }
                                // Prevent an automatic echo immediately after a manual run.
                                check(store.prefs.edit().putLong("last_${rule.getString("id")}", System.currentTimeMillis())
                                    .putString("pendingRule", rule.toString()).putInt("pendingIndex", 0).putBoolean("pendingManual", true).commit())
                                AutomationEngine(applicationContext).runRule(rule, manual = true)
                            }
                            "apps" -> {
                                val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                                @Suppress("DEPRECATION")
                                val apps = packageManager.queryIntentActivities(intent, 0).distinctBy { it.activityInfo.packageName }
                                    .sortedBy { it.loadLabel(packageManager).toString().lowercase() }
                                JSONArray().apply { apps.forEach { put(JSONObject().put("package", it.activityInfo.packageName)
                                    .put("label", it.loadLabel(packageManager).toString())) } }.toString()
                            }
                            else -> { main.post { result.notImplemented() }; return@execute }
                        }
                        main.post { result.success(response) }
                    } catch (e: Exception) { main.post { result.error("automation", e.message ?: "Automation failed", null) } }
                }
            }
    }
    override fun onResume() {
        super.onResume()
        EngineWorker.executor.execute {
            try { AutomationEngine(applicationContext).recoverPending() }
            catch (e: Exception) { RuleStore(applicationContext).prefs.edit().putString("engineError", e.message ?: "Recovery failed").commit() }
            AlarmScheduler.schedule(applicationContext)
        }
        if (RuleStore(this).flag("monitoring")) AutomationService.start(this)
    }
    private fun requestAccess(permission: String) {
        val packageUri = Uri.parse("package:$packageName")
        val intent = when (permission) {
            "bluetooth" -> {
                if (Build.VERSION.SDK_INT >= 31) {
                    if (shouldShowRequestPermissionRationale(Manifest.permission.BLUETOOTH_CONNECT) ||
                        !RuleStore(this).flag("askedBluetooth")) {
                        RuleStore(this).setFlag("askedBluetooth", true)
                        requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 701); return
                    }
                } else return
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri)
            }
            "notifications" -> {
                if (Build.VERSION.SDK_INT >= 33 && !DeviceAccess.permission(this, Manifest.permission.POST_NOTIFICATIONS) &&
                    (shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) || !RuleStore(this).flag("askedNotifications"))) {
                    RuleStore(this).setFlag("askedNotifications", true)
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 702); return
                }
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            "writeSettings" -> Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, packageUri)
            "dnd" -> Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "battery" -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            "exactAlarms" -> if (Build.VERSION.SDK_INT >= 31) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, packageUri) else return
            "shizuku" -> { PrivilegeBridge.request(); return }
            else -> error("Unknown permission")
        }
        try { startActivity(intent) }
        catch (_: android.content.ActivityNotFoundException) { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri)) }
    }
}
