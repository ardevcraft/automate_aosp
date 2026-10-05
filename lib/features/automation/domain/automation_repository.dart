import 'automation_rule.dart';

abstract interface class AutomationRepository {
  Future<AutomationSnapshot> load();
  Future<void> save(AutomationRule rule);
  Future<void> delete(String id);
  Future<void> setMonitoring(bool enabled);
  Future<void> setMode(ExecutionMode mode);
  Future<void> setNotifications(bool enabled);
  Future<void> requestAccess(String permission);
  Future<String> run(String id);
  Future<List<InstalledApp>> apps();
}

class InstalledApp {
  const InstalledApp({required this.package, required this.label});
  final String package;
  final String label;
}
