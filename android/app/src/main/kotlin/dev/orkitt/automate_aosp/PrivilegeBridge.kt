
package dev.orkitt.automate_aosp

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import rikka.shizuku.Shizuku
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.json.JSONObject

object PrivilegeBridge {
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var service: IPrivilegedService? = null
    private var binding = false
    private val waiters = mutableListOf<CountDownLatch>()
    private var args: Shizuku.UserServiceArgs? = null
    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            service = IPrivilegedService.Stub.asInterface(binder)
            binding = false
            waiters.forEach { it.countDown() }; waiters.clear()
        }
        override fun onServiceDisconnected(name: ComponentName) {
            service = null; binding = false
            waiters.forEach { it.countDown() }; waiters.clear()
        }
    }
    fun running(): Boolean = try { Shizuku.pingBinder() && !Shizuku.isPreV11() } catch (_: Exception) { false }
    fun granted(): Boolean = try { running() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED } catch (_: Exception) { false }
    fun request() {
        check(running()) { "Start Shizuku first, then return here to authorize Automate" }
        if (!granted()) {
            check(!Shizuku.shouldShowRequestPermissionRationale()) { "Allow Automate in Shizuku’s authorized apps" }
            Shizuku.requestPermission(730)
        }
    }
    // Called from the serialized engine worker, never the UI thread.
    fun execute(context: Context, action: String, value: Int): String {
        check(granted()) { "Shizuku is unavailable or permission was revoked. Start and authorize Shizuku." }
        val latch = CountDownLatch(1)
        main.post {
            if (service?.asBinder()?.isBinderAlive == true) { latch.countDown() }
            else {
                service = null; waiters.add(latch)
                if (!binding) {
                    binding = true
                    try {
                        val options = Shizuku.UserServiceArgs(ComponentName(context.packageName, PrivilegedService::class.java.name))
                            .daemon(false).processNameSuffix("automation_shell").debuggable(false).version(1)
                        args = options
                        Shizuku.bindUserService(options, connection)
                    } catch (_: Exception) {
                        binding = false; waiters.forEach { it.countDown() }; waiters.clear()
                    }
                }
            }
        }
        check(latch.await(8, TimeUnit.SECONDS)) {
            main.post {
                waiters.remove(latch)
                // Permit the next attempt to rebind after a failed connection.
                if (waiters.isEmpty() && service == null) {
                    binding = false
                    args?.let { try { Shizuku.unbindUserService(it, connection, true) } catch (_: Exception) {} }
                }
            }
            "Shizuku connection timed out; reopen Shizuku and retry"
        }
        val remote = checkNotNull(service) { "Shizuku service could not connect" }
        val response = JSONObject(remote.execute(action, value))
        check(response.getBoolean("success")) { response.getString("message") }
        return response.getString("message")
    }
    fun root(action: String, value: Int): String = ActionCommands.commands(action, value).joinToString("\n") {
        // All tokens originate in ActionCommands, not user-entered text.
        ProcessRunner.run(listOf("su", "-c", it.joinToString(" ")))
    }.ifBlank { "$action command accepted" }
    fun authorizeRoot(): Boolean = ProcessRunner.run(listOf("su", "-c", "id -u")).trim() == "0"
}
