// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RuleDto _$RuleDtoFromJson(Map<String, dynamic> json) => RuleDto(
  id: json['id'] as String,
  name: json['name'] as String,
  conditions: (json['conditions'] as List<dynamic>)
      .map((e) => ConditionDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  actions: (json['actions'] as List<dynamic>)
      .map((e) => ActionDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  match: $enumDecode(_$MatchModeEnumMap, json['match']),
  enabled: json['enabled'] as bool,
);

Map<String, dynamic> _$RuleDtoToJson(RuleDto instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'conditions': instance.conditions.map((e) => e.toJson()).toList(),
  'actions': instance.actions.map((e) => e.toJson()).toList(),
  'match': _$MatchModeEnumMap[instance.match]!,
  'enabled': instance.enabled,
};

const _$MatchModeEnumMap = {MatchMode.all: 'all', MatchMode.any: 'any'};

ConditionDto _$ConditionDtoFromJson(Map<String, dynamic> json) => ConditionDto(
  type: $enumDecode(_$ConditionTypeEnumMap, json['type']),
  value: (json['value'] as num).toInt(),
  text: json['text'] as String,
);

Map<String, dynamic> _$ConditionDtoToJson(ConditionDto instance) =>
    <String, dynamic>{
      'type': _$ConditionTypeEnumMap[instance.type]!,
      'value': instance.value,
      'text': instance.text,
    };

const _$ConditionTypeEnumMap = {
  ConditionType.bluetooth: 'bluetooth',
  ConditionType.wifi: 'wifi',
  ConditionType.time: 'time',
  ConditionType.appOpen: 'appOpen',
  ConditionType.appLeave: 'appLeave',
  ConditionType.batteryBelow: 'batteryBelow',
  ConditionType.batteryAbove: 'batteryAbove',
  ConditionType.charging: 'charging',
};

ActionDto _$ActionDtoFromJson(Map<String, dynamic> json) => ActionDto(
  type: $enumDecode(_$ActionTypeEnumMap, json['type']),
  value: (json['value'] as num).toInt(),
);

Map<String, dynamic> _$ActionDtoToJson(ActionDto instance) => <String, dynamic>{
  'type': _$ActionTypeEnumMap[instance.type]!,
  'value': instance.value,
};

const _$ActionTypeEnumMap = {
  ActionType.bluetooth: 'bluetooth',
  ActionType.wifi: 'wifi',
  ActionType.airplane: 'airplane',
  ActionType.dnd: 'dnd',
  ActionType.mobileData: 'mobileData',
  ActionType.autoBrightness: 'autoBrightness',
  ActionType.brightness: 'brightness',
  ActionType.orientation: 'orientation',
};
