import '../domain/automation_rule.dart';

String conditionName(ConditionType t) => switch (t) {
  ConditionType.bluetooth => 'Bluetooth',
  ConditionType.wifi => 'Wi-Fi',
  ConditionType.time => 'Daily time',
  ConditionType.appOpen => 'Open app',
  ConditionType.appLeave => 'Leave app',
  ConditionType.batteryBelow => 'Battery at or below',
  ConditionType.batteryAbove => 'Battery at or above',
  ConditionType.charging => 'Charging',
};
String actionName(ActionType t) => switch (t) {
  ActionType.bluetooth => 'Bluetooth',
  ActionType.wifi => 'Wi-Fi',
  ActionType.airplane => 'Airplane mode',
  ActionType.dnd => 'Do Not Disturb',
  ActionType.mobileData => 'Mobile data',
  ActionType.autoBrightness => 'Auto brightness',
  ActionType.brightness => 'Brightness',
  ActionType.orientation => 'Orientation',
};
String clock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String orientation(int value) => switch (value) {
  0 => 'Auto rotate',
  1 => 'Portrait',
  _ => 'Landscape',
};
String conditionLabel(RuleCondition c) => switch (c.type) {
  ConditionType.time => 'At ${clock(c.value)}',
  ConditionType.appOpen => 'Open ${c.text}',
  ConditionType.appLeave => 'Leave ${c.text}',
  ConditionType.batteryBelow ||
  ConditionType.batteryAbove => '${conditionName(c.type)} ${c.value}%',
  _ => '${conditionName(c.type)} ${c.value == 1 ? 'on' : 'off'}',
};
String actionLabel(RuleAction a) => switch (a.type) {
  ActionType.orientation => orientation(a.value),
  ActionType.brightness => 'Brightness ${a.value}%',
  _ => '${actionName(a.type)} ${a.value == 1 ? 'on' : 'off'}',
};
String ruleSummary(AutomationRule r) =>
    'IF ${r.conditions.map(conditionLabel).join(r.match == MatchMode.all ? ' AND ' : ' OR ')}\nTHEN ${r.actions.map(actionLabel).join(', ')}';
