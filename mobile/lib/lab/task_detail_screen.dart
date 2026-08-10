import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/memory_theme.dart';
import '../core/widgets/memory_surfaces.dart';
import '../models/memory_data.dart';
import '../state/memory_controller.dart';
import 'focus_screen.dart';
import 'lab_models.dart';
import 'lab_state.dart';

class LabTaskDetailScreen extends StatelessWidget {
  const LabTaskDetailScreen({
    super.key,
    required this.controller,
    required this.lab,
    required this.taskId,
  });

  final MemoryController controller;
  final LabState lab;
  final String taskId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([controller, lab]),
    builder: (context, _) {
      final task = controller.data.tasks
          .where((value) => value.id == taskId)
          .firstOrNull;
      if (task == null) {
        return const Scaffold(body: Center(child: Text('事项已不存在')));
      }
      final plan = lab.planFor(taskId);
      final deadline = _deadline(plan.linkedDeadlineId);
      return Scaffold(
        appBar: AppBar(
          title: Text(task.title),
          backgroundColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              '${DateFormat('M月d日', 'zh_CN').format(task.date)} · ${_time(task)} · 预计 ${plan.durationMinutes} 分钟',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            OpticalGlass(
              radius: 20,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (task.note != null) ...[
                    const SizedBox(height: 8),
                    Text(task.note!),
                  ],
                  if (deadline != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _deadlineLabel(deadline),
                      style: const TextStyle(
                        color: Color(0xFFB66B00),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel('下一步'),
            const SizedBox(height: 10),
            _NextAction(
              step: plan.currentStep,
              onTap: () => _openSteps(context, task),
            ),
            const SizedBox(height: 28),
            _SectionLabel('关联的记忆'),
            const SizedBox(height: 10),
            _MemoryLink(
              color: MemoryColors.violet,
              type: '文档',
              title: _documentTitle(plan.linkedDocumentId) ?? '选择文档',
              onTap: () => _chooseDocument(context, plan),
            ),
            const SizedBox(height: 10),
            _MemoryLink(
              color: MemoryColors.cyan,
              type: '物品',
              title: _itemTitle(plan.linkedItemId) ?? '选择物品与位置',
              onTap: () => _chooseItem(context, plan),
            ),
            const SizedBox(height: 10),
            _MemoryLink(
              color: const Color(0xFFFFB835),
              type: '期限',
              title: deadline?.title ?? '选择截止日',
              onTap: () => _chooseDeadline(context, plan),
            ),
            const SizedBox(height: 34),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openSteps(context, task),
                    child: const Text('拆成几步'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      if (plan.steps.isEmpty) {
                        await lab.ensureSuggestedSteps(task.id, task.title, 1);
                      }
                      if (!context.mounted) return;
                      await lab.startFocus(task.id);
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FocusScreen(
                            controller: controller,
                            lab: lab,
                            taskId: task.id,
                          ),
                        ),
                      );
                    },
                    child: const Text('开始专注'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  MemoryDeadline? _deadline(String? id) => id == null
      ? null
      : controller.data.deadlines.where((value) => value.id == id).firstOrNull;

  String? _documentTitle(String? id) {
    final document = id == null
        ? null
        : controller.data.documents
              .where((value) => value.id == id)
              .firstOrNull;
    if (document == null) return null;
    final category = controller.data.categories
        .where((value) => value.id == document.categoryId)
        .firstOrNull;
    return '${document.title}${category == null ? '' : ' · ${category.name}'}';
  }

  String? _itemTitle(String? id) {
    final item = id == null
        ? null
        : controller.data.locatedItems
              .where((value) => value.id == id)
              .firstOrNull;
    return item == null ? null : '${item.name} · ${item.location}';
  }

  Future<void> _openSteps(BuildContext context, MemoryTask task) async {
    var plan = lab.planFor(task.id);
    if (plan.steps.isEmpty) {
      final depth = await showModalBottomSheet<int>(
        context: context,
        builder: (context) => const _DepthSheet(),
      );
      if (depth == null) return;
      await lab.ensureSuggestedSteps(task.id, task.title, depth);
      plan = lab.planFor(task.id);
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StepEditorScreen(task: task, lab: lab),
      ),
    );
  }

  Future<void> _chooseDocument(BuildContext context, LabTaskPlan plan) async {
    final values = controller.data.documents
        .where((value) => !value.deleted && !value.archived)
        .toList();
    final selected = await _showChoice(
      context,
      title: '关联文档',
      values: values.map((value) => (value.id, value.title)).toList(),
    );
    if (selected != null) {
      await lab.savePlan(plan.copyWith(linkedDocumentId: selected));
    }
  }

  Future<void> _chooseItem(BuildContext context, LabTaskPlan plan) async {
    final values = controller.data.locatedItems
        .where((value) => !value.deleted)
        .toList();
    final selected = await _showChoice(
      context,
      title: '关联物品',
      values: values
          .map((value) => (value.id, '${value.name} · ${value.location}'))
          .toList(),
    );
    if (selected != null) {
      await lab.savePlan(plan.copyWith(linkedItemId: selected));
    }
  }

  Future<void> _chooseDeadline(BuildContext context, LabTaskPlan plan) async {
    final values = controller.data.deadlines
        .where((value) => value.status == MemoryDeadlineStatus.active)
        .toList();
    final selected = await _showChoice(
      context,
      title: '关联截止日',
      values: values.map((value) => (value.id, value.title)).toList(),
    );
    if (selected != null) {
      await lab.savePlan(plan.copyWith(linkedDeadlineId: selected));
    }
  }
}

class _DepthSheet extends StatelessWidget {
  const _DepthSheet();
  static const values = [
    ('轻一点', '3 步 · 只保留关键动作'),
    ('刚刚好', '5 步 · 保持清楚'),
    ('更细一点', '8 步 · 每步更具体'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('拆成几步', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          for (var index = 0; index < values.length; index++)
            ListTile(
              minTileHeight: 72,
              title: Text(values[index].$1),
              subtitle: Text(values[index].$2),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, index),
            ),
        ],
      ),
    ),
  );
}

class StepEditorScreen extends StatefulWidget {
  const StepEditorScreen({super.key, required this.task, required this.lab});
  final MemoryTask task;
  final LabState lab;

  @override
  State<StepEditorScreen> createState() => _StepEditorScreenState();
}

class _StepEditorScreenState extends State<StepEditorScreen> {
  late final List<LabStep> _steps = [
    ...widget.lab.planFor(widget.task.id).steps,
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('整理步骤'),
      backgroundColor: Colors.transparent,
      actions: [TextButton(onPressed: _save, child: const Text('保存'))],
    ),
    body: ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      itemCount: _steps.length + 1,
      onReorderItem: (oldIndex, newIndex) {
        if (oldIndex >= _steps.length) return;
        setState(() {
          _steps.insert(
            newIndex.clamp(0, _steps.length),
            _steps.removeAt(oldIndex),
          );
        });
      },
      itemBuilder: (context, index) {
        if (index == _steps.length) {
          return Padding(
            key: const ValueKey('add-step'),
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加一步'),
            ),
          );
        }
        final step = _steps[index];
        return Padding(
          key: ValueKey(step.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: OpticalGlass(
            radius: 18,
            child: ListTile(
              minTileHeight: 74,
              leading: CircleAvatar(
                backgroundColor: index == 0
                    ? MemoryColors.accent
                    : const Color(0xFFF5F8FC),
                foregroundColor: index == 0 ? Colors.white : MemoryColors.ink,
                child: Text('${index + 1}'),
              ),
              title: Text(step.title),
              subtitle: Text(index == 0 ? '当前下一步' : '${step.minutes} 分钟'),
              trailing: ReorderableDragStartListener(
                index: index,
                child: const SizedBox.square(
                  dimension: 48,
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
              onTap: () => _edit(index),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _add() async {
    final title = await _editStepText(context, '添加一步', '');
    if (title == null || title.isEmpty) return;
    setState(
      () => _steps.add(
        LabStep(
          id: 'step-${DateTime.now().microsecondsSinceEpoch}',
          title: title,
        ),
      ),
    );
  }

  Future<void> _edit(int index) async {
    final title = await _editStepText(context, '编辑步骤', _steps[index].title);
    if (title == null || title.isEmpty) return;
    setState(() => _steps[index] = _steps[index].copyWith(title: title));
  }

  Future<void> _save() async {
    await widget.lab.savePlan(
      widget.lab.planFor(widget.task.id).copyWith(steps: _steps),
    );
    if (mounted) Navigator.pop(context);
  }
}

Future<String?> _editStepText(
  BuildContext context,
  String title,
  String initial,
) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('完成'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<String?> _showChoice(
  BuildContext context, {
  required String title,
  required List<(String, String)> values,
}) => showModalBottomSheet<String>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (values.isEmpty)
          const Padding(padding: EdgeInsets.all(28), child: Text('还没有可关联的内容'))
        else
          for (final value in values.take(8))
            ListTile(
              title: Text(value.$2),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, value.$1),
            ),
      ],
    ),
  ),
);

class _NextAction extends StatelessWidget {
  const _NextAction({required this.step, required this.onTap});
  final LabStep? step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OpticalGlass(
    radius: 18,
    child: ListTile(
      minTileHeight: 78,
      title: Text(step?.title ?? '添加一个明确的下一步'),
      subtitle: Text(step == null ? '点按开始拆解' : '${step!.minutes} 分钟'),
      trailing: const Icon(
        Icons.check_circle_outline_rounded,
        color: MemoryColors.accent,
      ),
      onTap: onTap,
    ),
  );
}

class _MemoryLink extends StatelessWidget {
  const _MemoryLink({
    required this.color,
    required this.type,
    required this.title,
    required this.onTap,
  });
  final Color color;
  final String type;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OpticalGlass(
    radius: 16,
    child: ListTile(
      minTileHeight: 56,
      leading: Text(
        type,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: MemoryColors.secondaryInk,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}

String _time(MemoryTask task) {
  final minutes = task.minutesFromMidnight;
  if (minutes == null) return '全天';
  return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

String _deadlineLabel(MemoryDeadline deadline) {
  final days =
      DateTime(deadline.date.year, deadline.date.month, deadline.date.day)
          .difference(
            DateTime.now().copyWith(
              hour: 0,
              minute: 0,
              second: 0,
              millisecond: 0,
              microsecond: 0,
            ),
          )
          .inDays;
  if (days < 0) return '已超过截止日 ${-days} 天';
  if (days == 0) return '今天截止';
  return '距离截止日还有 $days 天';
}
