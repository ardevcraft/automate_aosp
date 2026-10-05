import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_theme.dart';
import '../domain/automation_rule.dart';
import 'automation_provider.dart';
import 'rule_editor.dart';
import 'rule_labels.dart';
import 'settings_page.dart';

class AutomationPage extends ConsumerStatefulWidget {
  const AutomationPage({super.key});
  @override
  ConsumerState<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends ConsumerState<AutomationPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll();
  }

  void _poll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_busy) {
        unawaited(ref.read(automationProvider.notifier).refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(automationProvider.notifier).refresh());
      _poll();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  Future<void> _edit([AutomationRule? rule]) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => RuleEditor(rule: rule)));
    if (mounted) {
      await ref.read(automationProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(automationProvider);
    final notifier = ref.read(automationProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automate'),
        actions: [
          IconButton(
            tooltip: 'Permissions & settings',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.medium),
                FilledButton(
                  onPressed: notifier.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.maxWidth),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  AppSpacing.small,
                  AppSpacing.medium,
                  AppSpacing.large * 4,
                ),
                children: [
                  Card(
                    child: SwitchListTile(
                      title: const Text('Background monitoring'),
                      subtitle: Text(
                        data.access.running
                            ? 'Active • ${data.rules.where((r) => r.enabled).length} enabled tasks'
                            : data.access.monitoring
                            ? 'Requested • service is not running. Switch off and on to restart.'
                            : 'Paused • tasks stay saved',
                      ),
                      value: data.access.monitoring,
                      onChanged: _busy
                          ? null
                          : (v) => _perform(() => notifier.monitoring(v)),
                    ),
                  ),
                  if (data.access.engineError.isNotEmpty)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.warning_amber,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(data.access.engineError),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.medium,
                    ),
                    child: Text(
                      'Your tasks',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (data.rules.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.large),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bolt,
                              size: AppSpacing.large * 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: AppSpacing.medium),
                            const Text('Let your phone handle the routine.'),
                            const SizedBox(height: AppSpacing.small),
                            const Text(
                              'Add IF conditions and THEN actions. Turn on monitoring when you are ready.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final rule in data.rules)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rule.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Switch(
                                  value: rule.enabled,
                                  onChanged: _busy
                                      ? null
                                      : (v) => _perform(
                                          () => notifier.save(
                                            rule.copyWith(enabled: v),
                                          ),
                                        ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Task actions',
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _edit(rule);
                                    }
                                    if (value == 'run') {
                                      await _perform(() async {
                                        final result = await notifier.run(
                                          rule.id,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(result)),
                                          );
                                        }
                                      });
                                    }
                                    if (value == 'delete' && context.mounted) {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete task?'),
                                          content: Text(rule.name),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true && mounted) {
                                        await _perform(
                                          () => notifier.delete(rule.id),
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'run',
                                      child: Text('Run actions now'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              ruleSummary(rule),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (data.history.any(
                              (h) => h.ruleId == rule.id,
                            )) ...[
                              const SizedBox(height: AppSpacing.small),
                              Text(
                                data.history
                                    .firstWhere((h) => h.ruleId == rule.id)
                                    .message,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (data.history.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.medium,
                      ),
                      child: Text(
                        'System Log',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF0D1117,
                        ), // Terminal dark background
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: const Color(0xFF30363D), // Subtle dark border
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in data.history.take(20)) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Terminal Status Prefix
                                  Text(
                                    entry.success ? '[OK] ' : '[ERR]',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      color: entry.success
                                          ? const Color(
                                              0xFF3FB950,
                                            ) // Terminal Green
                                          : const Color(
                                              0xFFF85149,
                                            ), // Terminal Red
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.small),
                                  // Timestamp & Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12.0,
                                              color: Color(
                                                0xFFC9D1D9,
                                              ), // Primary terminal text
                                            ),
                                            children: [
                                              TextSpan(
                                                text:
                                                    '${entry.at.toLocal().toString().split('.').first} ',
                                                style: const TextStyle(
                                                  color: Color(
                                                    0xFF8B949E,
                                                  ), // Muted timestamp text
                                                ),
                                              ),
                                              TextSpan(
                                                text: entry.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (entry.message.isNotEmpty) ...[
                                          const SizedBox(height: 2.0),
                                          Text(
                                            '> ${entry.message}',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11.0,
                                              color: Color(0xFF8B949E),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (entry != data.history.take(20).last)
                              const Divider(
                                height: AppSpacing.medium,
                                thickness: 0.5,
                                color: Color(0xFF21262D),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
