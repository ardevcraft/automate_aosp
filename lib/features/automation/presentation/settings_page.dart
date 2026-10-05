import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_theme.dart';
import '../domain/automation_rule.dart';
import 'automation_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver {
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(automationProvider.notifier).refresh();
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _access(String id) async {
    if (id == 'accessibility') {
      final consent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('App open / leave detection'),
          content: const Text(
            'Automate uses Accessibility to observe which app is in the foreground and when you leave it. It reads only window package names, not screen content, text, passwords, or gestures. App names stay on this device. Enable this only if you use app conditions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (consent != true) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    await _perform(() => ref.read(automationProvider.notifier).permission(id));
  }

  Widget _permission(String title, String details, bool granted, String id) =>
      Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text(details),
          leading: Icon(
            granted ? Icons.check_circle_outline : Icons.lock_outline,
          ),
          trailing: TextButton(
            onPressed: _busy ? null : () => _access(id),
            child: Text(granted ? 'Settings' : 'Grant'),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(automationProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions & settings')),
      body: ref
          .watch(automationProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: TextButton(
                onPressed: notifier.refresh,
                child: Text('$e • Retry'),
              ),
            ),
            data: (snapshot) {
              final a = snapshot.access;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.maxWidth,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    children: [
                      Text(
                        'Execution access',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      DropdownButtonFormField<ExecutionMode>(
                        initialValue: a.mode,
                        decoration: const InputDecoration(labelText: 'Backend'),
                        items: const [
                          DropdownMenuItem(
                            value: ExecutionMode.standard,
                            child: Text('Android permissions'),
                          ),
                          DropdownMenuItem(
                            value: ExecutionMode.shizuku,
                            child: Text('Shizuku / Sui'),
                          ),
                          DropdownMenuItem(
                            value: ExecutionMode.root,
                            child: Text('Root (su)'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) {
                                if (v != null) {
                                  _perform(() => notifier.mode(v));
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.small),
                      const Text(
                        'Wi-Fi, Bluetooth, mobile data and airplane mode need Shizuku or root on modern Android. AOSP by itself does not grant system privileges.',
                      ),
                      _permission(
                        'Shizuku',
                        a.shizukuRunning
                            ? 'Running • ${a.shizukuGranted ? 'authorized' : 'authorization needed'}'
                            : 'Start Shizuku first. Non-root users must start it again after a reboot.',
                        a.shizukuGranted,
                        'shizuku',
                      ),
                      _permission(
                        'Root authorization',
                        'Requests su access. Choose root only on a rooted device.',
                        a.rootGranted,
                        'root',
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        'Device permissions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _permission(
                        'Bluetooth access',
                        'Read Bluetooth on/off conditions (Android 12+).',
                        a.bluetooth,
                        'bluetooth',
                      ),
                      _permission(
                        'Modify system settings',
                        'Brightness, auto brightness and orientation with the Android backend.',
                        a.writeSettings,
                        'writeSettings',
                      ),
                      _permission(
                        'Do Not Disturb access',
                        'Manage Automate’s DND state. Other apps or user DND rules may still keep DND on.',
                        a.dnd,
                        'dnd',
                      ),
                      _permission(
                        'App detection',
                        'Optional Accessibility access for app open / leave conditions.',
                        a.accessibility,
                        'accessibility',
                      ),
                      _permission(
                        'Exact alarms',
                        'Wake the engine at the daily time you choose. Without this, time rules may be delayed.',
                        a.exactAlarms,
                        'exactAlarms',
                      ),
                      _permission(
                        'Battery optimization',
                        'Allow background monitoring during device idle. Manufacturer power restrictions may still apply.',
                        a.batteryExempt,
                        'battery',
                      ),
                      _permission(
                        'Notifications',
                        'Allow foreground monitoring and optional task-result alerts.',
                        a.notifications,
                        'notifications',
                      ),
                      Card(
                        child: SwitchListTile(
                          title: const Text('Task-result notifications'),
                          subtitle: const Text(
                            'Execution results always remain in recent activity. The monitoring service notification is required by Android.',
                          ),
                          value: a.resultNotifications,
                          onChanged: _busy
                              ? null
                              : (v) =>
                                    _perform(() => notifier.notifications(v)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      const Text(
                        'Background behavior\n\nRules are saved on-device and run without Flutter being open. Monitoring resumes after a reboot when Android permits it. Force-stop and the Android “Stop” control prevent guaranteed recovery: reopen Automate. On non-root devices, restart Shizuku after each reboot.\n\nState conditions run once when the rule changes from false to true; time runs daily; app conditions run on transitions. Combining app events with daily time using ALL requires that transition during the selected minute. Newly enabled rules may run immediately if their conditions already match. A 30-second cooldown limits feedback loops. Actions run in order and stop at the first failure.',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
