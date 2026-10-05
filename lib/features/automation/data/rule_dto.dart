import 'package:json_annotation/json_annotation.dart';
import '../domain/automation_rule.dart';
part 'rule_dto.g.dart';

@JsonSerializable(explicitToJson: true)
class RuleDto {
  const RuleDto({
    required this.id,
    required this.name,
    required this.conditions,
    required this.actions,
    required this.match,
    required this.enabled,
  });
  final String id, name;
  final List<ConditionDto> conditions;
  final List<ActionDto> actions;
  final MatchMode match;
  final bool enabled;
  factory RuleDto.fromJson(Map<String, Object?> json) =>
      _$RuleDtoFromJson(json);
  Map<String, Object?> toJson() => _$RuleDtoToJson(this);
  factory RuleDto.fromDomain(AutomationRule rule) => RuleDto(
    id: rule.id,
    name: rule.name,
    conditions: rule.conditions
        .map((c) => ConditionDto(type: c.type, value: c.value, text: c.text))
        .toList(),
    actions: rule.actions
        .map((a) => ActionDto(type: a.type, value: a.value))
        .toList(),
    match: rule.match,
    enabled: rule.enabled,
  );
  AutomationRule toDomain() => AutomationRule(
    id: id,
    name: name,
    conditions: conditions.map((c) => c.toDomain()).toList(),
    actions: actions.map((a) => a.toDomain()).toList(),
    match: match,
    enabled: enabled,
  );
  RuleDto copyWith({
    String? name,
    List<ConditionDto>? conditions,
    List<ActionDto>? actions,
    MatchMode? match,
    bool? enabled,
  }) => RuleDto(
    id: id,
    name: name ?? this.name,
    conditions: conditions ?? this.conditions,
    actions: actions ?? this.actions,
    match: match ?? this.match,
    enabled: enabled ?? this.enabled,
  );
}

@JsonSerializable()
class ConditionDto {
  const ConditionDto({
    required this.type,
    required this.value,
    required this.text,
  });
  final ConditionType type;
  final int value;
  final String text;
  factory ConditionDto.fromJson(Map<String, Object?> json) =>
      _$ConditionDtoFromJson(json);
  Map<String, Object?> toJson() => _$ConditionDtoToJson(this);
  RuleCondition toDomain() =>
      RuleCondition(type: type, value: value, text: text);
  ConditionDto copyWith({ConditionType? type, int? value, String? text}) =>
      ConditionDto(
        type: type ?? this.type,
        value: value ?? this.value,
        text: text ?? this.text,
      );
}

@JsonSerializable()
class ActionDto {
  const ActionDto({required this.type, required this.value});
  final ActionType type;
  final int value;
  factory ActionDto.fromJson(Map<String, Object?> json) =>
      _$ActionDtoFromJson(json);
  Map<String, Object?> toJson() => _$ActionDtoToJson(this);
  RuleAction toDomain() => RuleAction(type: type, value: value);
  ActionDto copyWith({ActionType? type, int? value}) =>
      ActionDto(type: type ?? this.type, value: value ?? this.value);
}
