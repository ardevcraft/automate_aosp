import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/automation_repository.dart';
import '../domain/automation_rule.dart';
import 'rule_dto.dart';

class AndroidAutomationRepository implements AutomationRepository {
  static const _channel = MethodChannel('dev.orkitt.automate_aosp/automation');
  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw AutomationException(e.message ?? e.code);
    } on MissingPluginException {
      throw const AutomationException(
        'Automation is available on Android only.',
      );
    }
  }

  @override
  Future<AutomationSnapshot> load() async {
    final data =
        jsonDecode(await _call<String>('snapshot') ?? '{}')
            as Map<String, Object?>;
    final access = data['access'] as Map<String, Object?>;
    bool flag(String key) => access[key] == true;
    return AutomationSnapshot(
      rules: (data['rules'] as List<Object?>)
          .map((r) => RuleDto.fromJson(r as Map<String, Object?>).toDomain())
          .toList(),
      history: (data['history'] as List<Object?>).map((r) {
        final h = r as Map<String, Object?>;
        return ExecutionEntry(
          ruleId: h['id'] as String,
          name: h['name'] as String,
          at: DateTime.fromMillisecondsSinceEpoch(h['at'] as int),
          success: h['success'] as bool,
          message: h['message'] as String,
        );
      }).toList(),
      access: AccessStatus(
        monitoring: flag('monitoring'),
        running: flag('running'),
        notifications: flag('notifications'),
        bluetooth: flag('bluetooth'),
        writeSettings: flag('writeSettings'),
        dnd: flag('dnd'),
        accessibility: flag('accessibility'),
        batteryExempt: flag('batteryExempt'),
        exactAlarms: flag('exactAlarms'),
        shizukuRunning: flag('shizukuRunning'),
        shizukuGranted: flag('shizukuGranted'),
        rootGranted: flag('rootGranted'),
        resultNotifications: flag('resultNotifications'),
        mode: ExecutionMode.values.byName(access['mode'] as String),
        engineError: access['engineError'] as String? ?? '',
      ),
    );
  }

  @override
  Future<void> save(AutomationRule rule) => _call<void>('save', {
    'rule': jsonEncode(RuleDto.fromDomain(rule).toJson()),
  });
  @override
  Future<void> delete(String id) => _call<void>('delete', {'id': id});
  @override
  Future<void> setMonitoring(bool enabled) =>
      _call<void>('monitoring', {'enabled': enabled});
  @override
  Future<void> setMode(ExecutionMode mode) =>
      _call<void>('mode', {'mode': mode.name});
  @override
  Future<void> setNotifications(bool enabled) =>
      _call<void>('notifications', {'enabled': enabled});
  @override
  Future<void> requestAccess(String permission) =>
      _call<void>('permission', {'permission': permission});
  @override
  Future<String> run(String id) async =>
      await _call<String>('run', {'id': id}) ?? 'No result';
  @override
  Future<List<InstalledApp>> apps() async =>
      (jsonDecode(await _call<String>('apps') ?? '[]') as List<Object?>).map((
        r,
      ) {
        final a = r as Map<String, Object?>;
        return InstalledApp(
          package: a['package'] as String,
          label: a['label'] as String,
        );
      }).toList();
}

class AutomationException implements Exception {
  const AutomationException(this.message);
  final String message;
  @override
  String toString() => message;
}
