import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/memory_theme.dart';
import '../core/widgets/memory_surfaces.dart';
import '../models/memory_data.dart';
import '../state/memory_controller.dart';
import 'lab_state.dart';
import 'task_detail_screen.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({
    super.key,
    required this.controller,
    required this.lab,
    required this.date,
  });

  final MemoryController controller;
  final LabState lab;
  final DateTime date;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([controller, lab]),
    builder: (context, _) {
      final tasks = controller.tasksFor(date, activeOnly: true)
        ..sort(
          (a, b) => (a.minutesFromMidnight ?? 24 * 60).compareTo(
            b.minutesFromMidnight ?? 24 * 60,
          ),
        );
      final planned = tasks.fold<int>(
        0,
        (sum, task) => sum + lab.planFor(task.id).durationMinutes,
      );
      final free = (10 * 60 - planned).clamp(0, 10 * 60);
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${DateFormat('M月d日', 'zh_CN').format(date)} · ${_isToday(date) ? '今天' : DateFormat('E', 'zh_CN').format(date)}',
          ),
          backgroundColor: Colors.transparent,
          actions: [
            TextButton(
              onPressed: () => _addRoutine(context),
              child: const Text('常用流程'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            OpticalGlass(
              radius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    free == 0 ? '今天的安排已经排满' : '今天还留有约 ${_duration(free)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    free == 0 ? '可以把灵活事项移到稍后。' : _bestWindow(tasks),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 72),
                child: Center(child: Text('这一天还没有安排')),
              )
            else
              _TimelineRail(
                tasks: tasks,
                lab: lab,
                onTap: (task) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LabTaskDetailScreen(
                      controller: controller,
                      lab: lab,
                      taskId: task.id,
                    ),
                  ),
                ),
                onMove: (task) => _move(context, task),
              ),
            if (free == 0 && tasks.isNotEmpty) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showReplan(context, tasks),
                  icon: const Icon(Icons.event_repeat_rounded),
                  label: const Text('调整安排'),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Future<void> _move(BuildContext context, MemoryTask task) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.date.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    await controller.updateTask(
      id: task.id,
      title: task.title,
      note: task.note,
      date: picked,
      minutesFromMidnight: task.minutesFromMidnight,
      notificationMode: task.notificationMode,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已移到 ${DateFormat('M月d日', 'zh_CN').format(picked)}'),
        ),
      );
    }
  }

  Future<void> _showReplan(BuildContext context, List<MemoryTask> tasks) async {
    final flexible =
        tasks.where((task) => task.minutesFromMidnight == null).firstOrNull ??
        tasks.last;
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('调整安排', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                flexible.title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              ListTile(
                title: const Text('移到明天'),
                onTap: () => Navigator.pop(context, 'tomorrow'),
              ),
              ListTile(
                title: const Text('选择日期'),
                onTap: () => Navigator.pop(context, 'choose'),
              ),
              ListTile(
                title: const Text('今天先不处理'),
                onTap: () => Navigator.pop(context, 'skip'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == 'tomorrow') {
      await controller.updateTask(
        id: flexible.id,
        title: flexible.title,
        note: flexible.note,
        date: date.add(const Duration(days: 1)),
        minutesFromMidnight: flexible.minutesFromMidnight,
      );
    } else if (result == 'choose' && context.mounted) {
      await _move(context, flexible);
    } else if (result == 'skip') {
      await controller.setTaskStatus(flexible.id, MemoryTaskStatus.skipped);
    }
  }

  Future<void> _addRoutine(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('常用流程')),
            ListTile(
              title: const Text('出门前检查'),
              subtitle: const Text('证件、钥匙、充电 · 10 分钟'),
              onTap: () => Navigator.pop(context, '出门前检查'),
            ),
            ListTile(
              title: const Text('睡前整理'),
              subtitle: const Text('明日安排、物品归位 · 15 分钟'),
              onTap: () => Navigator.pop(context, '睡前整理'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await controller.addTask(title: selected, date: date);
    if (!context.mounted) return;
    final task = controller.data.tasks.last;
    await lab.ensureSuggestedSteps(task.id, task.title, 0);
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.tasks,
    required this.lab,
    required this.onTap,
    required this.onMove,
  });
  final List<MemoryTask> tasks;
  final LabState lab;
  final ValueChanged<MemoryTask> onTap;
  final ValueChanged<MemoryTask> onMove;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 30,
        top: 22,
        bottom: 22,
        child: Container(width: 2, color: MemoryColors.hairline),
      ),
      Column(
        children: [
          for (var i = 0; i < tasks.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 62,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: tasks[i].minutesFromMidnight == null
                              ? MemoryColors.cyan
                              : MemoryColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: OpticalGlass(
                    radius: 16,
                    child: ListTile(
                      minTileHeight: 84,
                      leading: Container(
                        width: 5,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tasks[i].minutesFromMidnight == null
                              ? MemoryColors.cyan
                              : MemoryColors.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      title: Text(tasks[i].title),
                      subtitle: Text(
                        '${_taskTime(tasks[i])} · ${lab.planFor(tasks[i].id).durationMinutes} 分钟',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (_) => onMove(tasks[i]),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'move', child: Text('移动日期')),
                        ],
                      ),
                      onTap: () => onTap(tasks[i]),
                    ),
                  ),
                ),
              ],
            ),
            if (i < tasks.length - 1) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 62),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .48),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '转换与准备 · 保留 10 分钟',
                    style: TextStyle(
                      color: MemoryColors.secondaryInk,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    ],
  );
}

bool _isToday(DateTime value) {
  final now = DateTime.now();
  return value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
}

String _duration(int minutes) => minutes >= 60
    ? '${minutes ~/ 60} 小时${minutes % 60 == 0 ? '' : ' ${minutes % 60} 分钟'}'
    : '$minutes 分钟';

String _taskTime(MemoryTask task) {
  final value = task.minutesFromMidnight;
  if (value == null) return '灵活安排';
  return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

String _bestWindow(List<MemoryTask> tasks) {
  final latest = tasks
      .where((task) => task.minutesFromMidnight != null)
      .map((task) => task.minutesFromMidnight!)
      .fold<int>(17 * 60, (value, item) => item > value ? item : value);
  final start = (latest + 40).clamp(9 * 60, 20 * 60);
  return '${(start ~/ 60).toString().padLeft(2, '0')}:${(start % 60).toString().padLeft(2, '0')} 后可安排灵活事项';
}
