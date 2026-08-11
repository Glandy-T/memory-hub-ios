import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/motion/memory_motion.dart';
import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../models/memory_data.dart';
import '../../state/memory_controller.dart';
import 'deadline_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.controller,
    this.onOpenTimeline,
  });

  final MemoryController controller;
  final VoidCallback? onOpenTimeline;

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
          final deadlines = widget.controller.deadlinesFor(_selected);
          return CustomScrollView(
            key: const PageStorageKey('calendar-scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.onOpenTimeline != null)
                        _HeaderAction(
                          icon: Icons.view_timeline_outlined,
                          label: '时间线',
                          onPressed: widget.onOpenTimeline!,
                        ),
                      _HeaderAction(
                        icon: Icons.today_outlined,
                        label: '今天',
                        onPressed: _goToday,
                      ),
                      _HeaderAction(
                        icon: Icons.event_repeat_rounded,
                        label: '周期事项',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PeriodRulesScreen(
                              controller: widget.controller,
                            ),
                          ),
                        ),
                      ),
                      _HeaderAction(
                        icon: Icons.flag_outlined,
                        label: '截止日',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DeadlineScreen(controller: widget.controller),
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
                        widget.controller.tasksFor(date).isNotEmpty ||
                        widget.controller.deadlinesFor(date).isNotEmpty,
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
              if (deadlines.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  sliver: SliverList.list(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '当天截止',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      for (final deadline in deadlines) ...[
                        DeadlineRow(
                          deadline: deadline,
                          now: widget.controller.effectiveNow,
                          onTap: () => showDeadlineEditor(
                            context,
                            controller: widget.controller,
                            deadline: deadline,
                          ),
                          onCompleted:
                              deadline.status == MemoryDeadlineStatus.active
                              ? () => widget.controller.setDeadlineStatus(
                                  deadline.id,
                                  MemoryDeadlineStatus.completed,
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '当日安排',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      if (tasks.isNotEmpty)
                        Text(
                          '${tasks.length} 项',
                          style: Theme.of(context).textTheme.bodySmall,
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
                        _TaskRow(
                          task: task,
                          onTap: () => showTaskEditor(
                            context,
                            controller: widget.controller,
                            initialDate: _selected,
                            task: task,
                          ),
                        ),
                        const SizedBox(height: 10),
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

class PeriodRulesScreen extends StatelessWidget {
  const PeriodRulesScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('周期事项'),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final rules = controller.data.periodRules
              .where((rule) => !rule.deleted)
              .toList();
          if (rules.isEmpty) {
            return const Center(
              child: Text(
                '还没有周期事项',
                style: TextStyle(color: MemoryColors.secondaryInk),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            itemCount: rules.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final rule = rules[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(rule.title),
                subtitle: Text(_periodDescription(rule)),
                onTap: () => _edit(context, rule),
                trailing: Switch(
                  value: rule.active,
                  onChanged: (value) => controller.updatePeriodRule(
                    rule.id,
                    title: rule.title,
                    startDate: rule.startDate,
                    endDate: rule.endDate,
                    weekdays: rule.weekdays,
                    active: value,
                  ),
                ),
                onLongPress: () => _confirmDelete(context, rule),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新增周期事项',
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  String _periodDescription(PeriodRule rule) {
    const labels = {1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日'};
    final orderedDays = rule.weekdays.toList()..sort();
    final days = rule.weekdays.length == 7
        ? '每天'
        : '周${orderedDays.map((day) => labels[day]).join('、')}';
    final end = rule.endDate == null
        ? '持续'
        : '至 ${DateFormat('y/M/d').format(rule.endDate!)}';
    return '$days · $end${rule.active ? '' : ' · 已停止'}';
  }

  Future<void> _edit(BuildContext context, PeriodRule? rule) async {
    final draft = await showModalBottomSheet<_PeriodDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PeriodRuleEditor(rule: rule),
    );
    if (draft == null) return;
    if (rule == null) {
      await controller.addPeriodRule(
        title: draft.title,
        startDate: draft.startDate,
        endDate: draft.endDate,
        weekdays: draft.weekdays,
      );
    } else {
      await controller.updatePeriodRule(
        rule.id,
        title: draft.title,
        startDate: draft.startDate,
        endDate: draft.endDate,
        weekdays: draft.weekdays,
        active: draft.active,
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, PeriodRule rule) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除周期规则？'),
        content: const Text('未来不再生成，已经产生的日期历史会保留。'),
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
    if (approved == true) await controller.deletePeriodRule(rule.id);
  }
}

class _PeriodDraft {
  const _PeriodDraft({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.weekdays,
    required this.active,
  });

  final String title;
  final DateTime startDate;
  final DateTime? endDate;
  final Set<int> weekdays;
  final bool active;
}

class _PeriodRuleEditor extends StatefulWidget {
  const _PeriodRuleEditor({this.rule});

  final PeriodRule? rule;

  @override
  State<_PeriodRuleEditor> createState() => _PeriodRuleEditorState();
}

class _PeriodRuleEditorState extends State<_PeriodRuleEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.rule?.title ?? '',
  );
  late DateTime _start = widget.rule?.startDate ?? DateTime.now();
  late DateTime? _end = widget.rule?.endDate;
  late Set<int> _weekdays = {...?widget.rule?.weekdays};
  late bool _active = widget.rule?.active ?? true;

  @override
  void initState() {
    super.initState();
    if (_weekdays.isEmpty) _weekdays = {1, 2, 3, 4, 5, 6, 7};
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.rule == null ? '新增周期事项' : '编辑周期事项',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: '名称 *'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(['一', '二', '三', '四', '五', '六', '日'][day - 1]),
                  selected: _weekdays.contains(day),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _weekdays.add(day);
                    } else if (_weekdays.length > 1) {
                      _weekdays.remove(day);
                    }
                  }),
                ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('开始日期'),
            trailing: Text(DateFormat('y/M/d').format(_start)),
            onTap: () => _pickDate(isEnd: false),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('结束日期（可选）'),
            trailing: Text(
              _end == null ? '持续' : DateFormat('y/M/d').format(_end!),
            ),
            onTap: () => _pickDate(isEnd: true),
          ),
          if (widget.rule != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('继续生成未来事项'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              if (_title.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                _PeriodDraft(
                  title: _title.text.trim(),
                  startDate: _start,
                  endDate: _end,
                  weekdays: _weekdays,
                  active: _active,
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_end ?? _start) : _start,
      firstDate: isEnd ? _start : DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => isEnd ? _end = picked : _start = picked);
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

class _MonthPanel extends StatefulWidget {
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
  State<_MonthPanel> createState() => _MonthPanelState();
}

class _MonthPanelState extends State<_MonthPanel> {
  double _dragX = 0;
  bool _animate = false;
  bool _transitioning = false;
  Duration _duration = MemoryMotion.standard;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MemoryMotion.reduce(context);
    return LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: reduceMotion
              ? null
              : (details) =>
                    _followDrag(details, constraints.maxWidth + _panelGap),
          onHorizontalDragCancel: reduceMotion ? null : _returnToCenter,
          onHorizontalDragEnd: (details) => _finishDrag(
            details,
            constraints.maxWidth,
            reduceMotion: reduceMotion,
          ),
          child: TweenAnimationBuilder<double>(
            key: const ValueKey('calendar-month-motion'),
            tween: Tween<double>(end: _dragX),
            duration: _animate ? _duration : Duration.zero,
            curve: MemoryMotion.curve,
            builder: (context, offset, _) {
              final extent = constraints.maxWidth + _panelGap;
              final panelRows = [-1, 0, 1]
                  .map(
                    (delta) => _rowsForMonth(
                      DateTime(widget.month.year, widget.month.month + delta),
                    ),
                  )
                  .reduce((a, b) => a > b ? a : b);
              final textScaler = MediaQuery.textScalerOf(context);
              final scaledTitleHeight = textScaler.scale(22) * 1.2 + 16;
              final headerHeight = scaledTitleHeight > 48
                  ? scaledTitleHeight
                  : 48.0;
              final scaledWeekdayHeight = textScaler.scale(11) * 1.3;
              final weekdayHeight = scaledWeekdayHeight > 18
                  ? scaledWeekdayHeight
                  : 18.0;
              final panelHeight =
                  28 + headerHeight + weekdayHeight + 4 + panelRows * 50;
              return SizedBox(
                height: panelHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (final delta in [-1, 0, 1])
                      Positioned.fill(
                        child: Transform.translate(
                          key: ValueKey(
                            'calendar-month-painted-transform-$delta',
                          ),
                          offset: Offset(offset + delta * extent, 0),
                          child: IgnorePointer(
                            ignoring: delta != 0 || _transitioning,
                            child: ExcludeSemantics(
                              excluding: delta != 0,
                              child: SizedBox(
                                key: delta == 0
                                    ? const ValueKey(
                                        'calendar-month-painted-content',
                                      )
                                    : ValueKey(
                                        'calendar-month-adjacent-$delta',
                                      ),
                                child: _CalendarMonthCard(
                                  month: DateTime(
                                    widget.month.year,
                                    widget.month.month + delta,
                                  ),
                                  selected: widget.selected,
                                  today: widget.today,
                                  hasTasks: widget.hasTasks,
                                  onSelected: widget.onSelected,
                                  onJump: widget.onJump,
                                  trackRows: panelRows,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static const double _panelGap = 12;

  void _followDrag(DragUpdateDetails details, double extent) {
    if (_transitioning) return;
    setState(() {
      _animate = false;
      _dragX = (_dragX + details.delta.dx).clamp(-extent, extent);
    });
  }

  void _returnToCenter() {
    if (_transitioning) return;
    setState(() {
      _animate = true;
      _duration = MemoryMotion.exit;
      _dragX = 0;
    });
  }

  Future<void> _finishDrag(
    DragEndDetails details,
    double width, {
    required bool reduceMotion,
  }) async {
    if (_transitioning) return;
    final extent = width + _panelGap;
    final velocity = details.primaryVelocity ?? 0;
    final passesDistance = _dragX.abs() >= width * .16;
    final passesVelocity = velocity.abs() >= 450;
    if (!passesDistance && !passesVelocity) {
      _returnToCenter();
      return;
    }
    final goNext = passesVelocity ? velocity < 0 : _dragX < 0;
    if (reduceMotion) {
      goNext ? widget.onNext() : widget.onPrevious();
      return;
    }

    setState(() {
      _transitioning = true;
      _animate = true;
      _duration = MemoryMotion.standard;
      _dragX = goNext ? -extent : extent;
    });
    await Future<void>.delayed(MemoryMotion.standard);
    if (!mounted) return;
    goNext ? widget.onNext() : widget.onPrevious();
    setState(() {
      _animate = false;
      _dragX = 0;
      _transitioning = false;
    });
  }
}

int _rowsForMonth(DateTime month) {
  final first = DateTime(month.year, month.month);
  final dayCount = DateTime(month.year, month.month + 1, 0).day;
  final leading = (first.weekday - DateTime.monday) % 7;
  return ((leading + dayCount) / 7).ceil();
}

class _CalendarMonthCard extends StatelessWidget {
  const _CalendarMonthCard({
    required this.month,
    required this.selected,
    required this.today,
    required this.hasTasks,
    required this.onSelected,
    required this.onJump,
    required this.trackRows,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final bool Function(DateTime date) hasTasks;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onJump;
  final int trackRows;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday - DateTime.monday) % 7;
    return OpticalGlass(
      opacity: .46,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onJump,
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${month.year}年${month.month}月',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
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
            height: trackRows * 50,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 50,
              ),
              itemCount: trackRows * 7,
              itemBuilder: (context, index) {
                final day = index - leading + 1;
                if (day < 1 || day > dayCount) {
                  return const SizedBox.shrink();
                }
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
        child: AnimatedContainer(
          duration: MemoryMotion.duration(context, MemoryMotion.quick),
          curve: MemoryMotion.curve,
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
              AnimatedDefaultTextStyle(
                duration: MemoryMotion.duration(context, MemoryMotion.quick),
                curve: MemoryMotion.curve,
                style: TextStyle(
                  color: selected ? Colors.white : MemoryColors.ink,
                  fontWeight: FontWeight.w600,
                ),
                child: Text('${date.day}'),
              ),
              if (hasTask)
                Positioned(
                  bottom: 5,
                  child: AnimatedContainer(
                    duration: MemoryMotion.duration(
                      context,
                      MemoryMotion.quick,
                    ),
                    curve: MemoryMotion.curve,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : MemoryColors.violet,
                      shape: BoxShape.circle,
                    ),
                    width: 4,
                    height: 4,
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
        ? '全天'
        : '${(time ~/ 60).toString().padLeft(2, '0')}:${(time % 60).toString().padLeft(2, '0')}';
    final (statusIcon, statusLabel) = switch (task.status) {
      MemoryTaskStatus.completed => (Icons.check_circle_rounded, '已完成'),
      MemoryTaskStatus.skipped => (Icons.remove_circle_outline_rounded, '已无视'),
      _ => (Icons.chevron_right_rounded, '待处理'),
    };
    return Semantics(
      button: true,
      label: '${task.title}，$statusLabel，点击编辑或删除',
      child: OpticalGlass(
        opacity: .64,
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 66),
            child: Row(
              children: [
                SizedBox(
                  width: 68,
                  child: Text(
                    timeLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF506F9A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                        if (task.note != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(
                    statusIcon,
                    size: 20,
                    color: task.status == MemoryTaskStatus.active
                        ? MemoryColors.secondaryInk
                        : MemoryColors.accent,
                  ),
                ),
              ],
            ),
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
  var notificationMode = task?.notificationMode ?? TaskNotificationMode.none;
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
                          setSheetState(() {
                            time = selected;
                            if (notificationMode == TaskNotificationMode.none) {
                              notificationMode = TaskNotificationMode.normal;
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text(time?.format(context) ?? '不设时间'),
                    ),
                  ),
                ],
              ),
              if (time != null) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setSheetState(() {
                      time = null;
                      notificationMode = TaskNotificationMode.none;
                    }),
                    child: const Text('清除时间'),
                  ),
                ),
                const SizedBox(height: 4),
                Text('通知', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<TaskNotificationMode>(
                  segments: const [
                    ButtonSegment(
                      value: TaskNotificationMode.none,
                      label: Text('不通知'),
                    ),
                    ButtonSegment(
                      value: TaskNotificationMode.normal,
                      label: Text('普通'),
                    ),
                    ButtonSegment(
                      value: TaskNotificationMode.strong,
                      label: Text('强提醒'),
                    ),
                  ],
                  selected: {notificationMode},
                  onSelectionChanged: (value) =>
                      setSheetState(() => notificationMode = value.first),
                ),
              ],
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
                  final messenger = ScaffoldMessenger.of(context);
                  final minutes = time == null
                      ? null
                      : time!.hour * 60 + time!.minute;
                  bool notificationReady;
                  if (task == null) {
                    notificationReady = await controller.addTask(
                      title: titleController.text,
                      note: noteController.text,
                      date: date,
                      minutesFromMidnight: minutes,
                      notificationMode: notificationMode,
                    );
                  } else {
                    notificationReady = await controller.updateTask(
                      id: task.id,
                      title: titleController.text,
                      note: noteController.text,
                      date: date,
                      minutesFromMidnight: minutes,
                      notificationMode: notificationMode,
                    );
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (!notificationReady &&
                      notificationMode != TaskNotificationMode.none) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('事项已保存，但系统通知权限没有开启。')),
                    );
                  }
                },
                child: const Text('保存'),
              ),
              if (task != null) ...[
                const SizedBox(height: 8),
                if (task.status != MemoryTaskStatus.active)
                  TextButton.icon(
                    onPressed: () async {
                      await controller.setTaskStatus(
                        task.id,
                        MemoryTaskStatus.active,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('重新设为待处理'),
                  ),
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
