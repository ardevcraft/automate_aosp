import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_automation/features/automation/data/android_automation_repository.dart';
import 'package:system_automation/features/automation/domain/automation_rule.dart';
import 'package:system_automation/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.orkitt.automate_aosp/automation');
  final saved = <String, Map<String, Object?>>{};
  var monitoring = false;
  var notifications = true;
  var failSave = false;
  setUp(() {
    saved.clear();
    monitoring = false;
    notifications = true;
    failSave = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map<Object?, Object?>?) ?? {};
          switch (call.method) {
            case 'snapshot':
              return jsonEncode({
                'rules': saved.values.toList(),
                'history': <Object?>[],
                'access': {
                  'monitoring': monitoring,
                  'running': monitoring,
                  'resultNotifications': notifications,
                  'mode': 'standard',
                },
              });
            case 'save':
              if (failSave) {
                throw PlatformException(
                  code: 'disk',
                  message: 'Storage unavailable',
                );
              }
              final json =
                  jsonDecode(args['rule'] as String) as Map<String, Object?>;
              saved[json['id'] as String] = json;
              return null;
            case 'delete':
              saved.remove(args['id']);
              return null;
            case 'monitoring':
              monitoring = args['enabled'] as bool;
              return null;
            case 'notifications':
              notifications = args['enabled'] as bool;
              return null;
            case 'apps':
              return '[]';
            default:
              return null;
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'Native contract preserves multiple conditions, ordered actions, and disable across reload',
    () async {
      final repo = AndroidAutomationRepository();
      final rule = AutomationRule(
        id: 'night',
        name: 'Night mode',
        match: MatchMode.all,
        conditions: const [
          RuleCondition(type: ConditionType.time, value: 1320),
          RuleCondition(type: ConditionType.charging),
        ],
        actions: const [
          RuleAction(type: ActionType.dnd),
          RuleAction(type: ActionType.autoBrightness, value: 0),
        ],
      );
      await repo.save(rule);
      // New repository instance reads native storage, not an in-memory Dart cache.
      final loaded = (await AndroidAutomationRepository().load()).rules.single;
      expect(loaded.conditions[0].value, 1320);
      expect(loaded.conditions[1].type, ConditionType.charging);
      expect(loaded.actions.map((a) => a.type), [
        ActionType.dnd,
        ActionType.autoBrightness,
      ]);
      await repo.save(loaded.copyWith(enabled: false));
      expect((await repo.load()).rules.single.enabled, false);
      await repo.setNotifications(false);
      expect((await repo.load()).access.resultNotifications, false);
      await repo.delete('night');
      expect((await repo.load()).rules, isEmpty);
    },
  );
  test(
    'Save errors remain observable and do not erase existing tasks',
    () async {
      final repo = AndroidAutomationRepository();
      final rule = AutomationRule(
        id: 'a',
        name: 'Existing',
        conditions: const [RuleCondition(type: ConditionType.wifi)],
        actions: const [RuleAction(type: ActionType.dnd)],
      );
      await repo.save(rule);
      failSave = true;
      await expectLater(
        repo.save(rule.copyWith(name: 'Changed')),
        throwsA(isA<AutomationException>()),
      );
      expect((await repo.load()).rules.single.name, 'Existing');
    },
  );
  testWidgets(
    'Create a task through IF/THEN sheets and show its saved details',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ProviderScope(child: AutomationApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Headphones routine',
      );
      await tester.tap(find.text('Add condition'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add condition'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add action'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(find.text('Headphones routine'), findsOneWidget);
      expect(find.text('IF Bluetooth on\nTHEN Wi-Fi on'), findsOneWidget);
      expect(saved.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Small-screen editor remains scrollable with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: AutomationApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, 'Small phone');
    expect(find.text('Save task'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
