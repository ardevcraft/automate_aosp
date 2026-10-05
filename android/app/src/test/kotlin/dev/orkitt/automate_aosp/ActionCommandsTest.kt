
package dev.orkitt.automate_aosp
import org.junit.Assert.*
import org.junit.Test
class ActionCommandsTest {
    @Test fun maliciousActionNamesAreRejected() {
        assertThrows(IllegalStateException::class.java) { ActionCommands.commands("wifi; reboot", 1) }
    }
    @Test fun invalidValuesAreRejected() {
        assertThrows(IllegalArgumentException::class.java) { ActionCommands.commands("wifi", 2) }
        assertThrows(IllegalArgumentException::class.java) { ActionCommands.commands("brightness", 101) }
    }
    @Test fun brightnessDisablesAutomaticModeBeforeSettingLevel() {
        val commands = ActionCommands.commands("brightness", 50)
        assertEquals(listOf("settings", "put", "system", "screen_brightness_mode", "0"), commands[0])
        assertEquals("127", commands[1].last())
    }
    @Test fun portraitAndLandscapeLockRotation() {
        assertEquals("0", ActionCommands.commands("orientation", 1)[0].last())
        assertEquals("0", ActionCommands.commands("orientation", 1)[1].last())
        assertEquals("1", ActionCommands.commands("orientation", 2)[1].last())
        assertEquals(1, ActionCommands.commands("orientation", 0).size)
    }
}
