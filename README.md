# Automate — Android condition/action automation

Flutter UI with a native Kotlin rule engine for AOSP/custom-ROM, rooted, and non-root Shizuku devices. Android 8.0+; current Flutter stable with Dart 3.12+.

## Included

- Create/edit/delete named tasks, with readable IF → THEN summaries and enable switches.
- Multiple conditions using ALL or ANY; multiple actions executed in list order.
- Durable native storage, independent of Flutter and UI lifecycle.
- Foreground monitoring, system event receivers, daily wakeup alarms, reboot/package-update recovery, and optional app transition detection.
- Android permissions, root (su), and Shizuku/Sui backends.
- Optional task-result notifications, plus 100 recent execution records.
- Manual **Run actions now** and explicit errors for unavailable permissions or unsupported commands.
- Per-action execution checkpoints to resume unfinished work after process death.
- Material 3, system light/dark themes, responsive layout and manual Riverpod AsyncNotifier state.

## Conditions

| Condition | Values / meaning |
| --- | --- |
| Bluetooth | Radio on / off; not a connected-device check |
| Wi-Fi | Radio on / off; not an SSID / internet check |
| Daily time | A selected minute in the device's local timezone, once per day |
| Open app | An observed transition into the selected app |
| Leave app | An observed transition out of it; turning the screen off also counts |
| Battery | At or below / at or above a selected percentage |
| Charging | Power connected / disconnected |

## Actions and permissions

| Action | Android permission backend | Shizuku / root backend |
| --- | --- | --- |
| Wi-Fi, Bluetooth, airplane mode, mobile data | Unavailable for ordinary apps on modern Android | Predefined system commands; ROM/API support still applies |
| DND on/off | DND policy access | Uses Android DND access in every mode |
| Automatic/manual brightness | Modify system settings | Settings commands |
| Auto rotate / portrait / landscape | Modify system settings | Settings commands |

DND **on** requests priority interruptions. On Android 15+ the application owns an implicit DND rule. **Off** releases Automate's request; other DND rules can keep the device in DND. Mobile data affects the system's default data subscription; it does not select a SIM or guarantee internet connectivity. Orientation changes the system preference; an app with a fixed orientation can override it.

AOSP alone does not grant privileged permissions. Choose **Shizuku / Sui** for a non-root device or **Root (su)** for a rooted device. There is no silent permission grant or hidden fallback to a different backend. Privileged execution accepts only predefined actions and bounded values, never user-entered shell commands.

## First run

1. Extract the project and run `flutter pub get`, then `flutter run` on an Android device.
2. Open **Permissions & settings** and choose your execution backend.
3. For Shizuku: install/start Shizuku, then authorize Automate using its permission button. For root: request su authorization using **Root authorization**.
4. Grant Bluetooth access for Bluetooth conditions; grant Modify system settings for normal brightness/orientation actions; grant DND access for DND actions.
5. App open/leave rules require optional Accessibility access. The app discloses its use before opening Settings. It reads package transitions only, without screen content or gestures. If Android blocks Accessibility for a sideloaded app, enable **Allow restricted settings** in App info when your Android version offers it.
6. Grant exact-alarm access for daily time rules. Set the app's battery policy to unrestricted / exempt using the device's battery settings. Allow notifications if you want notification-drawer alerts.
7. Add IF conditions and THEN actions, save, and turn on **Background monitoring**. Rules remain saved while monitoring is paused.
8. Use **Run actions now** to verify actions on your ROM before relying on a rule. This deliberately ignores IF conditions and can run a disabled rule.

The ZIP also contains an ARM64 **debug APK** under `preview/` for device evaluation. It uses debug signing. Build from source for other architectures; configure your own release keystore before distribution.

## Execution semantics

- State conditions dispatch on a false → true edge. A newly enabled rule may run immediately if its state conditions already match.
- Time and app conditions are events. An ALL rule combining a daily time and an app event requires that app transition during the selected minute. They are not persistent "app is currently open" conditions.
- ANY rules can fire on a fresh time/app event even when a different state condition remains true.
- A 30-second cooldown per rule limits feedback loops. Very closely spaced events can be suppressed. Rules are evaluated in task-list order; later rules can change a setting changed by earlier ones.
- Battery/radio broadcasts prompt fresh OS-state reads. A 30-second fallback poll covers missed state changes while the service is awake. App events use Accessibility window transitions; rapid transitions and nonstandard vendor windows need device testing.
- Actions are ordered and stop on the first failure. Completed actions are not rolled back. Errors remain in recent activity; fix permissions and use **Run actions now**, or re-enable the rule to retry a state condition.
- Edge/day markers and the pending execution are committed together before automatic side effects. Progress is saved after every successful action. After a process restart, matching pending action definitions resume from the saved position. A deleted/disabled automatic task or changed action list cancels its pending recovery.
- If a crash occurs after a system call but before its checkpoint commits, that action can repeat. All actions set an explicit state, so repetition is idempotent. This is not a claim of exactly-once physical system effects.
- A command returning successfully means the command was accepted; actual radio/network behavior depends on Android and the ROM. Check device state during acceptance testing.

## Background limits

Closing Flutter or swiping away the app does not intentionally stop the native foreground service. Android can recreate a sticky service after ordinary process death. Reboot and package-update receivers restore monitoring when Android permits it. Rules and history stay on the device, even while the UI is closed.

**Force-stop is different:** Android suppresses the app until the user launches/interacts with it again. The Android foreground-app **Stop** control and manufacturer power managers can also prevent guaranteed recovery. Reopen Automate and restart monitoring if its status shows a stopped service. This application does not bypass user stop controls.

Non-root Shizuku must be started again after each reboot. Rules cannot perform privileged actions while Shizuku is unavailable. Missing exact-alarm permission makes time scheduling inexact and may prevent restarting a stopped monitor from the background. No missed-event replay is promised while the engine is stopped. A force-stop, uninstall, revoked permission, or disabled Accessibility service cannot be treated as guaranteed execution.

Task-result alerts can be disabled. Android still requires a foreground-service notification while monitoring; the app does not hide it. If notification permission is denied, Android controls where the foreground-service notice appears.

## Structure

```text
lib/features/automation/
  domain/        Immutable rules and repository contract
  data/          json_serializable DTOs and native-channel repository
  presentation/  Manual Riverpod notifier, editor, task list, settings
android/app/src/main/
  kotlin/dev/orkitt/automate_aosp/  Persistence, engine, receivers, permissions, execution
  aidl/dev/orkitt/automate_aosp/    Allowlisted Shizuku UserService interface
```

The supplied scheduling prototype had missing generated sources and invalid imports. Its broken services/model/UI were replaced by the condition/action feature. Old Hive scheduling data is not migrated; recreate prototype tasks. Application ID `dev.orkitt.automate_aosp` is retained.

Generated JSON source is included. After changing DTO fields:

```bash
dart run build_runner build
```

To check/build:

```bash
flutter pub get
flutter analyze
flutter test
cd android
./gradlew testDebugUnitTest
cd ..
flutter build apk --debug
```

## Verification

See `VALIDATION.md` for the executed checks and the remaining on-device acceptance checklist.

## Platform references

- [Android foreground-service special-use type](https://developer.android.com/develop/background-work/services/fgs/service-types#special-use)
- [Background foreground-service start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
- [Android stopped-state behavior](https://developer.android.com/about/versions/15/behavior-changes-all#stopped-state)
- [Shizuku API and UserService documentation](https://github.com/RikkaApps/Shizuku-API)
- [NotificationManager and Android 15 DND semantics](https://developer.android.com/reference/android/app/NotificationManager#setInterruptionFilter(int))
