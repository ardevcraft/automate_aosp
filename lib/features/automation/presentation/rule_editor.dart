import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/automation_rule.dart';
import 'automation_provider.dart';
import 'rule_labels.dart';

class RuleEditor extends ConsumerStatefulWidget {
  const RuleEditor({super.key, this.rule});
  final AutomationRule? rule;
  @override
  ConsumerState<RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<RuleEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late List<RuleCondition> _conditions;
  late List<RuleAction> _actions;
  late MatchMode _match;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.rule?.name);
    _conditions = [...?widget.rule?.conditions];
    _actions = [...?widget.rule?.actions];
    _match = widget.rule?.match ?? MatchMode.all;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _condition([int? index]) async {
    final value = await showModalBottomSheet<RuleCondition>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          ConditionEditor(condition: index == null ? null : _conditions[index]),
    );
    if (value != null && mounted) {
      setState(() {
        if (index == null) {
          _conditions.add(value);
        } else {
          _conditions[index] = value;
        }
      });
    }
  }

  Future<void> _action([int? index]) async {
    final value = await showModalBottomSheet<RuleAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          ActionEditor(action: index == null ? null : _actions[index]),
    );
    if (value != null && mounted) {
      setState(() {
        if (index == null) {
          _actions.add(value);
        } else {
          _actions[index] = value;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (_conditions.isEmpty || _actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one IF condition and one THEN action.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(automationProvider.notifier)
          .save(
            AutomationRule(
              id:
                  widget.rule?.id ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              name: _name.text.trim(),
              conditions: _conditions,
              actions: _actions,
              match: _match,
              enabled: widget.rule?.enabled ?? true,
            ),
          );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.rule == null ? 'Add task' : 'Edit task')),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: AppSpacing.medium,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Save task'),
        ),
      ),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxWidth),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: [
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Task name',
                  hintText: 'For example: Quiet at night',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Give this task a name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.medium),
              Text('IF', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.small),
              SegmentedButton<MatchMode>(
                segments: const [
                  ButtonSegment(
                    value: MatchMode.all,
                    label: Text('All conditions'),
                  ),
                  ButtonSegment(
                    value: MatchMode.any,
                    label: Text('Any condition'),
                  ),
                ],
                selected: {_match},
                onSelectionChanged: (s) => setState(() => _match = s.first),
              ),
              for (var i = 0; i < _conditions.length; i++)
                Card(
                  child: ListTile(
                    title: Text(conditionLabel(_conditions[i])),
                    onTap: () => _condition(i),
                    trailing: IconButton(
                      tooltip: 'Remove condition',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _conditions.removeAt(i)),
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _condition(),
                icon: const Icon(Icons.add),
                label: const Text('Add condition'),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text('THEN', style: Theme.of(context).textTheme.titleLarge),
              const Text('Actions execute from top to bottom.'),
              for (var i = 0; i < _actions.length; i++)
                Card(
                  child: ListTile(
                    leading: Text('${i + 1}'),
                    title: Text(actionLabel(_actions[i])),
                    onTap: () => _action(i),
                    trailing: IconButton(
                      tooltip: 'Remove action',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _actions.removeAt(i)),
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _action(),
                icon: const Icon(Icons.add),
                label: const Text('Add action'),
              ),
              const SizedBox(height: AppSpacing.medium),
              const Text(
                'App conditions need Accessibility permission. Radio actions need root or Shizuku. Set these up in Permissions & settings before enabling monitoring.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ConditionEditor extends ConsumerStatefulWidget {
  const ConditionEditor({super.key, this.condition});
  final RuleCondition? condition;
  @override
  ConsumerState<ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends ConsumerState<ConditionEditor> {
  late ConditionType _type;
  late int _value;
  late final TextEditingController _package;
  @override
  void initState() {
    super.initState();
    _type = widget.condition?.type ?? ConditionType.bluetooth;
    _value = widget.condition?.value ?? 1;
    _package = TextEditingController(text: widget.condition?.text);
  }

  @override
  void dispose() {
    _package.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app =
        _type == ConditionType.appOpen || _type == ConditionType.appLeave;
    final battery =
        _type == ConditionType.batteryAbove ||
        _type == ConditionType.batteryBelow;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.medium,
          0,
          AppSpacing.medium,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.medium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('IF condition', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.medium),
            DropdownButtonFormField<ConditionType>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: ConditionType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(conditionName(t)),
                    ),
                  )
                  .toList(),
              onChanged: (t) {
                if (t != null) {
                  setState(() {
                    _type = t;
                    _value = t == ConditionType.time
                        ? 22 * 60
                        : (t == ConditionType.batteryBelow ||
                              t == ConditionType.batteryAbove)
                        ? 20
                        : 1;
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.medium),
            if (app) ...[
              ref
                  .watch(installedAppsProvider)
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => TextButton(
                      onPressed: () => ref.invalidate(installedAppsProvider),
                      child: const Text('Retry loading apps'),
                    ),
                    data: (apps) => DropdownButtonFormField<String>(
                      key: ValueKey(_package.text),
                      initialValue: apps.any((a) => a.package == _package.text)
                          ? _package.text
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Choose an app',
                      ),
                      items: apps
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.package,
                              child: Text(
                                a.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _package.text = v);
                        }
                      },
                    ),
                  ),
              const SizedBox(height: AppSpacing.medium),
              TextField(
                controller: _package,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Package name',
                  hintText: 'com.example.app',
                ),
              ),
            ] else if (_type == ConditionType.time)
              ListTile(
                title: Text(clock(_value)),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: _value ~/ 60,
                      minute: _value % 60,
                    ),
                  );
                  if (time != null && mounted) {
                    setState(() => _value = time.hour * 60 + time.minute);
                  }
                },
              )
            else if (battery) ...[
              Text('$_value%'),
              Slider(
                value: _value.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '$_value%',
                onChanged: (v) => setState(() => _value = v.round()),
              ),
            ] else
              SwitchListTile(
                title: Text(_value == 1 ? 'On' : 'Off'),
                value: _value == 1,
                onChanged: (v) => setState(() => _value = v ? 1 : 0),
              ),
            const SizedBox(height: AppSpacing.medium),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (app &&
                      !RegExp(
                        r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$',
                      ).hasMatch(_package.text.trim())) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Choose an app or enter a valid package name.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    RuleCondition(
                      type: _type,
                      value: _value,
                      text: app ? _package.text.trim() : '',
                    ),
                  );
                },
                child: const Text('Add condition'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionEditor extends StatefulWidget {
  const ActionEditor({super.key, this.action});
  final RuleAction? action;
  @override
  State<ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<ActionEditor> {
  late ActionType _type;
  late int _value;
  @override
  void initState() {
    super.initState();
    _type = widget.action?.type ?? ActionType.wifi;
    _value = widget.action?.value ?? 1;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('THEN action', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.medium),
          DropdownButtonFormField<ActionType>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Action'),
            items: ActionType.values
                .map(
                  (t) => DropdownMenuItem(value: t, child: Text(actionName(t))),
                )
                .toList(),
            onChanged: (t) {
              if (t != null) {
                setState(() {
                  _type = t;
                  _value = t == ActionType.brightness ? 50 : 1;
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.medium),
          if (_type == ActionType.orientation)
            DropdownButtonFormField<int>(
              key: ValueKey(_type),
              initialValue: _value,
              decoration: const InputDecoration(labelText: 'Orientation'),
              items: [
                for (var i = 0; i < 3; i++)
                  DropdownMenuItem(value: i, child: Text(orientation(i))),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _value = v);
                }
              },
            )
          else if (_type == ActionType.brightness) ...[
            Text('$_value%'),
            Slider(
              value: _value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$_value%',
              onChanged: (v) => setState(() => _value = v.round()),
            ),
          ] else
            SwitchListTile(
              title: Text(_value == 1 ? 'Enable' : 'Disable'),
              value: _value == 1,
              onChanged: (v) => setState(() => _value = v ? 1 : 0),
            ),
          const SizedBox(height: AppSpacing.medium),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                RuleAction(type: _type, value: _value),
              ),
              child: const Text('Add action'),
            ),
          ),
        ],
      ),
    ),
  );
}
