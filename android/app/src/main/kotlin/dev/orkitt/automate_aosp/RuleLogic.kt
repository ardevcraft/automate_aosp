
package dev.orkitt.automate_aosp

// Framework-free rule semantics, shared by the engine and JVM tests.
object RuleLogic {
    fun matches(mode: String, values: List<Boolean>): Boolean = values.isNotEmpty() &&
        if (mode == "all") values.all { it } else values.any { it }
    fun shouldRun(matched: Boolean, previouslyMatched: Boolean, eventHit: Boolean,
                  now: Long, lastRun: Long): Boolean = matched && (!previouslyMatched || eventHit) &&
        (lastRun == 0L || now < lastRun || now - lastRun >= 30_000L)
}
