
package dev.orkitt.automate_aosp
import org.junit.Assert.*
import org.junit.Test
class RuleLogicTest {
    @Test fun allConditionsMustMatch() { assertFalse(RuleLogic.matches("all", listOf(true, false))); assertTrue(RuleLogic.matches("all", listOf(true, true))) }
    @Test fun anyConditionCanMatch() { assertTrue(RuleLogic.matches("any", listOf(true, false))); assertFalse(RuleLogic.matches("any", emptyList())) }
    @Test fun stableStateDoesNotRepeat() { assertFalse(RuleLogic.shouldRun(true, true, false, 100_000, 0)); assertTrue(RuleLogic.shouldRun(true, false, false, 100_000, 0)) }
    @Test fun eventsRetriggerAnyRulesButRespectCooldown() { assertTrue(RuleLogic.shouldRun(true, true, true, 100_000, 60_000)); assertFalse(RuleLogic.shouldRun(true, true, true, 100_000, 80_000)) }
    @Test fun clockMovingBackwardDoesNotBlockFutureEvents() { assertTrue(RuleLogic.shouldRun(true, true, true, 10_000, 100_000)) }
    @Test fun noExecutionWhenConditionIsFalse() { assertFalse(RuleLogic.shouldRun(false, false, true, 100_000, 0)) }
}
