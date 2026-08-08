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
                child: MemoryPageHeader(
                  title: '日历',
                  action: IconButton(
                    tooltip: '周期事项',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('周期事项将在下一阶段接入同一数据模型')),
                    ),
                    icon: const Icon(Icons.event_repeat_rounded),
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
                    onToday: _goToday,
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
                      TextButton.icon(
                        onPressed: () => showTaskEditor(
                          context,
                          controller: widget.controller,
                          initialDate: _selected,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: const Text('新增'),
                      ),
                    ],
                  ),
                ),
              ),
              if (tasks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 80),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            color: MemoryColors.secondaryInk,
                            size: 30,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '这一天还没有事项',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '只填写标题也可以，时间和备注都能留空。',
                            style: TextStyle(color: MemoryColors.secondaryInk),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _TaskRow(task: tasks[index]),
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
    required this.onToday,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final bool Function(DateTime date) hasTasks;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday - DateTime.monday) % 7;
    final cells = leading + dayCount;
    final rows = (cells / 7).ceil();
    return OpticalGlass(
      opacity: .6,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '上个月',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onToday,
                  child: Text('${month.year}年${month.month}月 · 今天'),
                ),
              ),
              IconButton(
                tooltip: '下个月',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
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
  const _TaskRow({required this.task});

  final MemoryTask task;

  @override
  Widget build(BuildContext context) {
    final time = task.minutesFromMidnight;
    final timeLabel = time == null
        ? ''
        : '${(time ~/ 60).toString().padLeft(2, '0')}:${(time % 60).toString().padLeft(2, '0')}';
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              timeLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
          if (task.status != MemoryTaskStatus.active)
            Text(
              task.status == MemoryTaskStatus.completed ? '已完成' : '已无视',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: MemoryColors.secondaryInk,
            ),
        ],
      ),
    );
  }
}

Future<void> showTaskEditor(
  BuildContext context, {
  required MemoryController controller,
  required DateTime initialDate,
}) async {
  final titleController = TextEditingController();
  final noteController = TextEditingController();
  var date = initialDate;
  TimeOfDay? time;
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
              Text('新建事项', style: Theme.of(context).textTheme.headlineSmall),
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
                  await controller.addTask(
                    title: titleController.text,
                    note: noteController.text,
                    date: date,
                    minutesFromMidnight: time == null
                        ? null
                        : time!.hour * 60 + time!.minute,
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  titleController.dispose();
  noteController.dispose();
}
