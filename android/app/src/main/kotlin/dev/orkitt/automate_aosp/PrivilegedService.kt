
package dev.orkitt.automate_aosp

import org.json.JSONObject
import java.util.concurrent.TimeUnit

// Only predefined actions cross the privileged boundary. No arbitrary shell input.
object ActionCommands {
    fun commands(action: String, value: Int): List<List<String>> {
        val toggle = if (value == 1) "enable" else "disable"
        require(if (action == "brightness") value in 0..100 else if (action == "orientation") value in 0..2 else value in 0..1)
        return when (action) {
            "wifi" -> listOf(listOf("svc", "wifi", toggle))
            "bluetooth" -> listOf(listOf("cmd", "bluetooth_manager", toggle))
            "mobileData" -> listOf(listOf("svc", "data", toggle))
            "airplane" -> listOf(listOf("cmd", "connectivity", "airplane-mode", if (value == 1) "enable" else "disable"))
            "autoBrightness" -> listOf(listOf("settings", "put", "system", "screen_brightness_mode", value.toString()))
            "brightness" -> listOf(listOf("settings", "put", "system", "screen_brightness_mode", "0"),
                listOf("settings", "put", "system", "screen_brightness", (value * 255 / 100).toString()))
            "orientation" -> if (value == 0) listOf(listOf("settings", "put", "system", "accelerometer_rotation", "1"))
                else listOf(listOf("settings", "put", "system", "accelerometer_rotation", "0"),
                    listOf("settings", "put", "system", "user_rotation", if (value == 1) "0" else "1"))
            else -> error("Unsupported privileged action: $action")
        }
    }
}
object ProcessRunner {
    fun run(args: List<String>): String {
        val process = ProcessBuilder(args).redirectErrorStream(true).start()
        // Drain concurrently so a full pipe cannot deadlock waitFor(). Bound output.
        val output = StringBuilder()
        val reader = Thread {
            try { process.inputStream.bufferedReader().use { input ->
                val buffer = CharArray(1024)
                while (true) { val count = input.read(buffer); if (count < 0) break
                    synchronized(output) { if (output.length < 8192) output.append(buffer, 0, minOf(count, 8192 - output.length)) }
                }
            } } catch (_: Exception) { }
        }.apply { isDaemon = true; start() }
        if (!process.waitFor(12, TimeUnit.SECONDS)) {
            process.destroyForcibly(); error("Command timed out; check root authorization or device support")
        }
        reader.join(1000)
        val result = synchronized(output) { output.toString().trim() }
        check(process.exitValue() == 0) { result.ifBlank { "Command failed (${process.exitValue()})" } }
        check(!Regex("(?i)(permission denial|securityexception|unknown command|not found|error:|failed)").containsMatchIn(result)) {
            result.ifBlank { "Device rejected this action" }
        }
        return result
    }
}
class PrivilegedService : IPrivilegedService.Stub() {
    override fun execute(action: String, value: Int): String = try {
        val output = ActionCommands.commands(action, value).joinToString("\n") { ProcessRunner.run(it) }
        JSONObject().put("success", true).put("message", output.ifBlank { "$action command accepted" }).toString()
    } catch (e: Exception) {
        JSONObject().put("success", false).put("message", e.message ?: "Privileged action failed").toString()
    }
    override fun destroy() { kotlin.system.exitProcess(0) }
}
