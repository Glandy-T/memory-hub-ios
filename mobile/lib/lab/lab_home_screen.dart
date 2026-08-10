import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../models/memory_data.dart';
import '../state/memory_controller.dart';
import 'lab_models.dart';
import 'lab_state.dart';
import 'task_detail_screen.dart';

class LabHomeScreen extends StatelessWidget {
  const LabHomeScreen({
    super.key,
    required this.controller,
    required this.lab,
    required this.reminderRefreshEpoch,
  });

  final MemoryController controller;
  final LabState lab;
  final int reminderRefreshEpoch;

  @override
  Widget build(BuildContext context) => HomeScreen(
    controller: controller,
    reminderRefreshEpoch: reminderRefreshEpoch,
    onTaskTap: (task) => _openTask(context, task),
    headerAction: IconButton.filledTonal(
      tooltip: '快速记录',
      onPressed: () => showQuickCapture(context, lab),
      icon: const Icon(Icons.add_rounded),
    ),
    emphasizeEmptyState: true,
  );

  void _openTask(BuildContext context, MemoryTask task) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LabTaskDetailScreen(
          controller: controller,
          lab: lab,
          taskId: task.id,
        ),
      ),
    );
  }
}

Future<void> showQuickCapture(BuildContext context, LabState lab) async {
  final text = TextEditingController();
  var kind = LabCaptureKind.task;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('快速记录', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('保存到待收录', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 22),
              TextField(
                controller: text,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '想到什么？',
                  hintText: '输入一句话',
                ),
              ),
              const SizedBox(height: 20),
              Text('内容类型', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in LabCaptureKind.values)
                    ChoiceChip(
                      label: Text(_kindLabel(value)),
                      selected: kind == value,
                      onSelected: (_) => setSheetState(() => kind = value),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    if (text.text.trim().isEmpty) return;
                    await lab.addCapture(text.text, kind);
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  },
                  child: const Text('存入待收录'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  text.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已加入待收录')));
  }
}

String _kindLabel(LabCaptureKind kind) => switch (kind) {
  LabCaptureKind.task => '安排',
  LabCaptureKind.deadline => '截止日',
  LabCaptureKind.document => '文档',
  LabCaptureKind.purchase => '购买',
  LabCaptureKind.itemLocation => '物品位置',
};
