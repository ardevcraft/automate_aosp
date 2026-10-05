
package dev.orkitt.automate_aosp

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class RuleStore(context: Context) {
    val prefs = context.getSharedPreferences("automation_v1", Context.MODE_PRIVATE)
    fun rules(): JSONArray = JSONArray(prefs.getString("rules", "[]"))
    fun history(): JSONArray = JSONArray(prefs.getString("history", "[]"))
    fun flag(key: String, fallback: Boolean = false): Boolean = prefs.getBoolean(key, fallback)
    fun setFlag(key: String, value: Boolean) { check(prefs.edit().putBoolean(key, value).commit()) { "Could not save settings" } }
    fun save(rule: JSONObject) {
        validate(rule)
        val next = JSONArray(); var found = false; var conditionsChanged = false
        val old = rules()
        for (i in 0 until old.length()) {
            val existing = old.getJSONObject(i)
            if (existing.getString("id") == rule.getString("id")) {
                conditionsChanged = existing.getJSONArray("conditions").toString() != rule.getJSONArray("conditions").toString()
                next.put(rule); found = true
            } else next.put(existing)
        }
        if (!found) next.put(rule)
        val editor = prefs.edit().putString("rules", next.toString()).remove("matched_${rule.getString("id")}")
        if (conditionsChanged) prefs.all.keys.filter { it.startsWith("time_${rule.getString("id")}_") }.forEach { editor.remove(it) }
        check(editor.commit()) { "Could not save task" }
    }
    fun delete(id: String) {
        val next = JSONArray(); val old = rules()
        for (i in 0 until old.length()) if (old.getJSONObject(i).getString("id") != id) next.put(old.getJSONObject(i))
        val editor = prefs.edit().putString("rules", next.toString()).remove("matched_$id").remove("last_$id")
        prefs.all.keys.filter { it.startsWith("time_${id}_") }.forEach { editor.remove(it) }
        check(editor.commit()) { "Could not delete task" }
    }
    fun log(rule: JSONObject, success: Boolean, message: String) {
        val next = JSONArray().put(JSONObject().put("name", rule.getString("name")).put("id", rule.getString("id"))
            .put("at", System.currentTimeMillis()).put("success", success).put("message", message))
        val old = history()
        for (i in 0 until minOf(old.length(), 99)) next.put(old.get(i))
        check(prefs.edit().putString("history", next.toString()).remove("pendingRule").remove("pendingIndex").remove("pendingManual").commit()) { "Could not save execution history" }
    }
    fun validate(rule: JSONObject) {
        require(rule.getString("id").matches(Regex("[A-Za-z0-9_-]{1,100}"))) { "Invalid task id" }
        require(rule.getString("name").trim().length in 1..80) { "Task name must be 1–80 characters" }
        require(rule.getString("match") in listOf("all", "any"))
        rule.getBoolean("enabled")
        val conditions = rule.getJSONArray("conditions"); val actions = rule.getJSONArray("actions")
        require(conditions.length() in 1..20 && actions.length() in 1..20) { "Use 1–20 conditions and actions per task" }
        for (i in 0 until conditions.length()) {
            val c = conditions.getJSONObject(i); val v = c.getInt("value")
            when (c.getString("type")) {
                "wifi", "bluetooth", "charging" -> require(v in 0..1)
                "time" -> require(v in 0..1439)
                "batteryBelow", "batteryAbove" -> require(v in 0..100)
                "appOpen", "appLeave" -> require(c.getString("text").matches(Regex("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+")))
                else -> error("Unknown condition")
            }
        }
        for (i in 0 until actions.length()) {
            val a = actions.getJSONObject(i)
            if (a.getString("type") == "dnd") require(a.getInt("value") in 0..1)
            else ActionCommands.commands(a.getString("type"), a.getInt("value"))
        }
    }
}
