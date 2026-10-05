enum ConditionType {
  bluetooth,
  wifi,
  time,
  appOpen,
  appLeave,
  batteryBelow,
  batteryAbove,
  charging,
}

enum ActionType {
  bluetooth,
  wifi,
  airplane,
  dnd,
  mobileData,
  autoBrightness,
  brightness,
  orientation,
}

enum MatchMode { all, any }

enum ExecutionMode { standard, shizuku, root }

class RuleCondition {
  const RuleCondition({required this.type, this.value = 1, this.text = ''});
  final ConditionType type;
  final int value;
  final String text;
}

class RuleAction {
  const RuleAction({required this.type, this.value = 1});
  final ActionType type;
  final int value;
}

class AutomationRule {
  AutomationRule({
    required this.id,
    required this.name,
    required List<RuleCondition> conditions,
    required List<RuleAction> actions,
    this.match = MatchMode.all,
    this.enabled = true,
  }) : conditions = List.unmodifiable(conditions),
       actions = List.unmodifiable(actions);
  final String id;
  final String name;
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;
  final MatchMode match;
  final bool enabled;
  AutomationRule copyWith({
    String? name,
    List<RuleCondition>? conditions,
    List<RuleAction>? actions,
    MatchMode? match,
    bool? enabled,
  }) => AutomationRule(
    id: id,
    name: name ?? this.name,
    conditions: conditions ?? this.conditions,
    actions: actions ?? this.actions,
    match: match ?? this.match,
    enabled: enabled ?? this.enabled,
  );
}

class ExecutionEntry {
  const ExecutionEntry({
    required this.ruleId,
    required this.name,
    required this.at,
    required this.success,
    required this.message,
  });
  final String ruleId, name;
  final DateTime at;
  final bool success;
  final String message;
}

class AccessStatus {
  const AccessStatus({
    this.monitoring = false,
    this.running = false,
    this.notifications = false,
    this.bluetooth = false,
    this.writeSettings = false,
    this.dnd = false,
    this.accessibility = false,
    this.batteryExempt = false,
    this.exactAlarms = false,
    this.shizukuRunning = false,
    this.shizukuGranted = false,
    this.rootGranted = false,
    this.resultNotifications = true,
    this.mode = ExecutionMode.standard,
    this.engineError = '',
  });
  final bool monitoring,
      running,
      notifications,
      bluetooth,
      writeSettings,
      dnd,
      accessibility,
      batteryExempt,
      exactAlarms,
      shizukuRunning,
      shizukuGranted,
      rootGranted,
      resultNotifications;
  final ExecutionMode mode;
  final String engineError;
}

class AutomationSnapshot {
  AutomationSnapshot({
    required List<AutomationRule> rules,
    required List<ExecutionEntry> history,
    required this.access,
  }) : rules = List.unmodifiable(rules),
       history = List.unmodifiable(history);
  final List<AutomationRule> rules;
  final List<ExecutionEntry> history;
  final AccessStatus access;
}
