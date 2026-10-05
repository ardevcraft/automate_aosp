# Validation — 5 October 2026

## Executed

| Check | Result |
| --- | --- |
| json_serializable generation | Generated `rule_dto.g.dart` successfully |
| Dart formatting | Passed |
| Flutter analysis | No issues |
| Flutter tests | 4 passed |
| Native AIDL generation | Passed |
| Android resource compilation/linking | Passed against Android 36 |
| Kotlin source compilation | Passed against Android 36, Flutter embedding and Shizuku API 13.1.5 |
| Android `assembleDebug` | Passed; ARM64 debug APK produced |
| Android `testDebugUnitTest` | 10 passed, zero errors/failures |

Flutter 3.47.6 / Dart 3.13.5 were used. Android compilation used the supplied AGP 8.11.1, Gradle 8.14, Kotlin 2.2.20 and Java 17. Existing Gradle/Kotlin deprecation warnings do not block this debug build. Release packaging was not run.

Dart tests cover native-channel data reload, ordered multi-condition/action rules, disable/delete, notification preference, observable save errors, editor creation, and a small screen with the keyboard open. They mock the platform channel; they do not prove Android persistence or radio changes on a physical device.

Native tests cover ALL/ANY matching, edge deduplication, event retriggering, cooldown, backward wall-clock changes, action allowlisting, invalid inputs, and brightness/orientation command order. Native execution checkpoints were compiled and reviewed; interruption recovery has not been tested on a device.

The APK was packaged, not installed or run here. No physical or emulated Android device was available. Root permission dialogs, Shizuku binding, real radio/settings changes, manufacturer behavior, reboot recovery and Accessibility transitions remain on-device acceptance work.

## Device acceptance

1. Select your backend and grant only the permissions needed by your rule. Deny a permission first and confirm a clear setup/execution error; then grant it.
2. Try each required action with **Run actions now**, checking the actual device setting. Test both on and off. Inspect recent activity for unsupported-ROM commands.
3. Create a battery/charging rule and toggle its input. Verify one execution per false → true edge, and no continuous retrigger while the input remains true.
4. Try ALL/ANY rules with more than one condition and an ordered action list.
5. Schedule a daily rule a few minutes ahead. Close/swipe the UI, turn the screen off and wait. Repeat in device idle with exact-alarm access and unrestricted battery policy.
6. Enable optional Accessibility access and test app open/leave, the launcher, screen-off, and apps you actually use. Check that popups/keyboards do not trigger unexpected departures.
7. Disable a task and confirm it stays disabled after app relaunch/reboot. Pause monitoring and confirm no automatic changes occur.
8. On a rooted test device, interrupt the process during a multi-action rule and confirm unfinished work resumes when the service/app restarts. Changed/deleted/disabled automatic tasks must cancel recovery.
9. Reboot with monitoring enabled. Non-root devices must restart Shizuku. Confirm the monitor status and behavior after permission restoration.
10. Force-stop the app from Android Settings. Verify it stays stopped, then reopen it to resume. Do not expect automation while force-stopped.
11. Disable task-result notifications. Confirm results stay in history and the mandatory foreground-service notice remains under Android's control.

`preview/automate-arm64-debug.apk` is for ARM64 Android devices and uses debug signing. Source is included for rebuilding and production signing.
