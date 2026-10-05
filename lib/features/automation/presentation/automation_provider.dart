import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/android_automation_repository.dart';
import '../domain/automation_repository.dart';
import '../domain/automation_rule.dart';

final automationRepositoryProvider = Provider<AutomationRepository>(
  (ref) => AndroidAutomationRepository(),
);
final automationProvider =
    AsyncNotifierProvider<AutomationNotifier, AutomationSnapshot>(
      AutomationNotifier.new,
    );
final installedAppsProvider = FutureProvider<List<InstalledApp>>(
  (ref) => ref.read(automationRepositoryProvider).apps(),
);

class AutomationNotifier extends AsyncNotifier<AutomationSnapshot> {
  AutomationRepository get _repo => ref.read(automationRepositoryProvider);
  @override
  Future<AutomationSnapshot> build() => _repo.load();
  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.load);
  }

  Future<void> _change(Future<void> Function() action) async {
    await action();
    state = await AsyncValue.guard(_repo.load);
  }

  Future<void> save(AutomationRule rule) => _change(() => _repo.save(rule));
  Future<void> delete(String id) => _change(() => _repo.delete(id));
  Future<void> monitoring(bool enabled) =>
      _change(() => _repo.setMonitoring(enabled));
  Future<void> mode(ExecutionMode mode) => _change(() => _repo.setMode(mode));
  Future<void> notifications(bool enabled) =>
      _change(() => _repo.setNotifications(enabled));
  Future<void> permission(String permission) =>
      _change(() => _repo.requestAccess(permission));
  Future<String> run(String id) async {
    final result = await _repo.run(id);
    await refresh();
    return result;
  }
}
