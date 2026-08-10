import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../models/memory_data.dart';
import '../../state/memory_controller.dart';

class DeadlineScreen extends StatefulWidget {
  const DeadlineScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  State<DeadlineScreen> createState() => _DeadlineScreenState();
}

class _DeadlineScreenState extends State<DeadlineScreen> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('截止日'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '新增截止日',
            onPressed: () =>
                showDeadlineEditor(context, controller: widget.controller),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final deadlines =
              widget.controller.data.deadlines
                  .where(
                    (deadline) =>
                        deadline.status ==
                        (_showCompleted
                            ? MemoryDeadlineStatus.completed
                            : MemoryDeadlineStatus.active),
                  )
                  .toList()
                ..sort((left, right) => left.dueAt.compareTo(right.dueAt));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                '只放必须在某天前完成的事情。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('进行中')),
                    ButtonSegment(value: true, label: Text('已完成')),
                  ],
                  selected: {_showCompleted},
                  onSelectionChanged: (values) =>
                      setState(() => _showCompleted = values.single),
                ),
              ),
              const SizedBox(height: 18),
              if (deadlines.isEmpty)
                _DeadlineEmpty(completed: _showCompleted)
              else
                for (final deadline in deadlines) ...[
                  DeadlineRow(
                    deadline: deadline,
                    now: widget.controller.effectiveNow,
                    onTap: () => showDeadlineEditor(
                      context,
                      controller: widget.controller,
                      deadline: deadline,
                    ),
                    onCompleted: _showCompleted
                        ? null
                        : () => widget.controller.setDeadlineStatus(
                            deadline.id,
                            MemoryDeadlineStatus.completed,
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class DeadlineRow extends StatelessWidget {
  const DeadlineRow({
    super.key,
    required this.deadline,
    required this.now,
    required this.onTap,
    this.onCompleted,
  });

  final MemoryDeadline deadline;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final urgency = deadlineUrgency(deadline, now);
    return Semantics(
      button: true,
      label: '${deadline.title}，${deadlineCountdownLabel(deadline, now)}，点击编辑',
      child: OpticalGlass(
        opacity: .64,
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: urgency,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deadline.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        deadlineDateLabel(deadline),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      deadlineCountdownLabel(deadline, now),
                      style: TextStyle(
                        color: urgency,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (onCompleted != null)
                      SizedBox(
                        height: 30,
                        child: TextButton(
                          onPressed: onCompleted,
                          child: const Text('完成'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NearestDeadlineTile extends StatelessWidget {
  const NearestDeadlineTile({
    super.key,
    required this.deadline,
    required this.now,
    required this.onTap,
  });

  final MemoryDeadline deadline;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgency = deadlineUrgency(deadline, now);
    return OpticalGlass(
      opacity: .62,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: urgency,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deadline.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      deadlineDateLabel(deadline),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                deadlineCountdownLabel(deadline, now),
                style: TextStyle(color: urgency, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeadlineEmpty extends StatelessWidget {
  const _DeadlineEmpty({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
    child: Column(
      children: [
        const Icon(
          Icons.flag_outlined,
          size: 36,
          color: MemoryColors.secondaryInk,
        ),
        const SizedBox(height: 14),
        Text(completed ? '还没有完成记录' : '暂时没有截止日'),
        const SizedBox(height: 6),
        Text(
          completed ? '完成的截止日会留在这里。' : '需要在某天前完成的事情，可以放在这里。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

String deadlineDateLabel(MemoryDeadline deadline) {
  final date = DateFormat('M月d日', 'zh_CN').format(deadline.date);
  final minutes = deadline.minutesFromMidnight;
  if (minutes == null) return '$date截止';
  final time =
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  return '$date · $time';
}

String deadlineCountdownLabel(MemoryDeadline deadline, DateTime now) {
  if (deadline.minutesFromMidnight == null) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      deadline.date.year,
      deadline.date.month,
      deadline.date.day,
    );
    final days = due.difference(today).inDays;
    if (days < 0) return '已逾期 ${-days} 天';
    if (days == 0) return '今天截止';
    if (days == 1) return '明天';
    return '还有 $days 天';
  }
  final difference = deadline.dueAt.difference(now);
  final overdue = difference.isNegative;
  final duration = overdue ? -difference : difference;
  final minutes = duration.inMinutes.clamp(1, 1 << 30);
  final value = minutes < 60
      ? '$minutes 分钟'
      : minutes < 48 * 60
      ? '${(minutes / 60).ceil()} 小时'
      : '${(minutes / (24 * 60)).ceil()} 天';
  return overdue ? '已逾期 $value' : '还有 $value';
}

Color deadlineUrgency(MemoryDeadline deadline, DateTime now) {
  final remaining = deadline.dueAt.difference(now);
  if (remaining.isNegative) return const Color(0xFFE85D6A);
  if (remaining <= const Duration(hours: 48)) return const Color(0xFFF0B83F);
  if (remaining <= const Duration(days: 14)) return MemoryColors.violet;
  return MemoryColors.cyan;
}

Future<void> showDeadlineEditor(
  BuildContext context, {
  required MemoryController controller,
  MemoryDeadline? deadline,
}) async {
  final title = TextEditingController(text: deadline?.title ?? '');
  final note = TextEditingController(text: deadline?.note ?? '');
  var date = deadline?.date ?? controller.effectiveToday();
  TimeOfDay? time = deadline?.minutesFromMidnight == null
      ? null
      : TimeOfDay(
          hour: deadline!.minutesFromMidnight! ~/ 60,
          minute: deadline.minutesFromMidnight! % 60,
        );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              deadline == null ? '新建截止日' : '编辑截止日',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '日期必填；具体时间和备注可以留空。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: title,
              autofocus: deadline == null,
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
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
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
            if (time != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setSheetState(() => time = null),
                  child: const Text('清除时间'),
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 4,
              maxLength: 4000,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                final minutes = time == null
                    ? null
                    : time!.hour * 60 + time!.minute;
                if (deadline == null) {
                  await controller.addDeadline(
                    title: title.text,
                    note: note.text,
                    date: date,
                    minutesFromMidnight: minutes,
                  );
                } else {
                  await controller.updateDeadline(
                    id: deadline.id,
                    title: title.text,
                    note: note.text,
                    date: date,
                    minutesFromMidnight: minutes,
                  );
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: const Text('保存截止日'),
            ),
            if (deadline != null) ...[
              const SizedBox(height: 8),
              if (deadline.status == MemoryDeadlineStatus.completed)
                TextButton.icon(
                  onPressed: () async {
                    await controller.setDeadlineStatus(
                      deadline.id,
                      MemoryDeadlineStatus.active,
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('重新设为待处理'),
                ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () async {
                  final approved = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('删除这个截止日？'),
                      content: const Text('它会先进入回收站。'),
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
                  if (approved != true) return;
                  await controller.setDeadlineStatus(
                    deadline.id,
                    MemoryDeadlineStatus.deleted,
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('删除截止日'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  title.dispose();
  note.dispose();
}
