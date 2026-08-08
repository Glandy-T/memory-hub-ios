import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../models/memory_data.dart';
import '../../state/memory_controller.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selected = widget.controller.effectiveToday();
  late DateTime _month = DateTime(_selected.year, _selected.month);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final tasks = widget.controller.tasksFor(_selected);
          return CustomScrollView(
            key: const PageStorageKey('calendar-scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _HeaderAction(
                        icon: Icons.today_outlined,
                        label: '今天',
                        onPressed: _goToday,
                      ),
                      _HeaderAction(
                        icon: Icons.event_repeat_rounded,
                        label: '周期事项',
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('周期事项将在下一阶段接入同一数据模型'),
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _MonthPanel(
                    month: _month,
                    selected: _selected,
                    today: widget.controller.effectiveToday(),
                    hasTasks: (date) =>
                        widget.controller.tasksFor(date).isNotEmpty,
                    onSelected: (date) => setState(() => _selected = date),
                    onPrevious: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                    onJump: _jumpToDate,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('M月d日 EEEE', 'zh_CN').format(_selected),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList.builder(
                  itemCount: tasks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == tasks.length) {
                      return _AddTaskRow(
                        onPressed: () => showTaskEditor(
                          context,
                          controller: widget.controller,
                          initialDate: _selected,
                        ),
                      );
                    }
                    final task = tasks[index];
                    return Column(
                      children: [
                        const Divider(height: 1),
                        _TaskRow(
                          task: task,
                          onTap: () => showTaskEditor(
                            context,
                            controller: widget.controller,
                            initialDate: _selected,
                            task: task,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = DateTime(_month.year, _month.month, 1);
    });
  }

  void _goToday() {
    final today = widget.controller.effectiveToday();
    setState(() {
      _month = DateTime(today.year, today.month);
      _selected = today;
    });
  }

  Future<void> _jumpToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _selected = picked;
      _month = DateTime(picked.year, picked.month);
    });
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OpticalGlass(
    radius: 18,
    opacity: .48,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}

class _MonthPanel extends StatelessWidget {
  const _MonthPanel({
    required this.month,
    required this.selected,
    required this.today,
    required this.hasTasks,
    required this.onSelected,
    required this.onPrevious,
    required this.onNext,
    required this.onJump,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final bool Function(DateTime date) hasTasks;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday - DateTime.monday) % 7;
    final cells = leading + dayCount;
    final rows = (cells / 7).ceil();
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -180) onNext();
        if (velocity > 180) onPrevious();
      },
      child: OpticalGlass(
        opacity: .6,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onJump,
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${month.year}年${month.month}月',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                for (final label in ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: MemoryColors.secondaryInk,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: rows * 50,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 50,
                ),
                itemCount: rows * 7,
                itemBuilder: (context, index) {
                  final day = index - leading + 1;
                  if (day < 1 || day > dayCount) return const SizedBox.shrink();
                  final date = DateTime(month.year, month.month, day);
                  return _DayCell(
                    date: date,
                    selected: sameCalendarDay(date, selected),
                    today: sameCalendarDay(date, today),
                    hasTask: hasTasks(date),
                    onTap: () => onSelected(date),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.today,
    required this.hasTask,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final bool hasTask;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: '${date.month}月${date.day}日${hasTask ? '，有事项' : ''}',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? MemoryColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: today && !selected
                ? Border.all(color: MemoryColors.accent)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: selected ? Colors.white : MemoryColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasTask)
                Positioned(
                  bottom: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : MemoryColors.violet,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onTap});

  final MemoryTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = task.minutesFromMidnight;
    final timeLabel = time == null
        ? ''
        : '${(time ~/ 60).toString().padLeft(2, '0')}:${(time % 60).toString().padLeft(2, '0')}';
    final (statusIcon, statusLabel) = switch (task.status) {
      MemoryTaskStatus.completed => (Icons.check_rounded, '已完成'),
      MemoryTaskStatus.skipped => (Icons.horizontal_rule_rounded, '已无视'),
      _ => (Icons.close_rounded, '未完成'),
    };
    return Semantics(
      button: true,
      label: '${task.title}，$statusLabel，点击编辑或删除',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              SizedBox(
                width: 39,
                child: Icon(
                  statusIcon,
                  size: 23,
                  color: task.status == MemoryTaskStatus.active
                      ? MemoryColors.secondaryInk
                      : MemoryColors.accent,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (task.note != null)
                      Text(
                        task.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (timeLabel.isNotEmpty)
                Text(timeLabel, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTaskRow extends StatelessWidget {
  const _AddTaskRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(height: 1),
      SizedBox(
        height: 58,
        width: double.infinity,
        child: TextButton(onPressed: onPressed, child: const Text('＋ 新增事项')),
      ),
    ],
  );
}

Future<void> showTaskEditor(
  BuildContext context, {
  required MemoryController controller,
  required DateTime initialDate,
  MemoryTask? task,
}) async {
  final titleController = TextEditingController(text: task?.title ?? '');
  final noteController = TextEditingController(text: task?.note ?? '');
  var date = task?.date ?? initialDate;
  TimeOfDay? time = task?.minutesFromMidnight == null
      ? null
      : TimeOfDay(
          hour: task!.minutesFromMidnight! ~/ 60,
          minute: task.minutesFromMidnight! % 60,
        );
  await showModalBottomSheet<void>(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                task == null ? '新建事项' : '编辑事项',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 5),
              Text(
                '标题必填，时间和备注都可以留空。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 200,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: date,
                        );
                        if (selected != null) {
                          setSheetState(() => date = selected);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(DateFormat('M月d日', 'zh_CN').format(date)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showTimePicker(
                          context: context,
                          initialTime: time ?? TimeOfDay.now(),
                        );
                        if (selected != null) {
                          setSheetState(() => time = selected);
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text(time?.format(context) ?? '不设时间'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                maxLength: 4000,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  final minutes = time == null
                      ? null
                      : time!.hour * 60 + time!.minute;
                  if (task == null) {
                    await controller.addTask(
                      title: titleController.text,
                      note: noteController.text,
                      date: date,
                      minutesFromMidnight: minutes,
                    );
                  } else {
                    await controller.updateTask(
                      id: task.id,
                      title: titleController.text,
                      note: noteController.text,
                      date: date,
                      minutesFromMidnight: minutes,
                    );
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('保存'),
              ),
              if (task != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _confirmTaskDeletion(
                    sheetContext,
                    controller: controller,
                    task: task,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('删除事项'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 400));
  titleController.dispose();
  noteController.dispose();
}

Future<void> _confirmTaskDeletion(
  BuildContext sheetContext, {
  required MemoryController controller,
  required MemoryTask task,
}) async {
  final messenger = ScaffoldMessenger.of(sheetContext);
  final confirmed = await showDialog<bool>(
    context: sheetContext,
    builder: (context) => AlertDialog(
      title: const Text('删除这个事项？'),
      content: const Text('它会进入回收站，不会立即永久删除。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await controller.setTaskStatus(task.id, MemoryTaskStatus.deleted);
  if (!sheetContext.mounted) return;
  Navigator.pop(sheetContext);
  messenger.showSnackBar(
    SnackBar(
      content: const Text('事项已移入回收站'),
      action: SnackBarAction(
        label: '撤销',
        onPressed: () => controller.setTaskStatus(task.id, task.status),
      ),
    ),
  );
}
