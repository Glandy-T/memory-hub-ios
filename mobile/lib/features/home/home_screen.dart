import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../models/memory_data.dart';
import '../../state/memory_controller.dart';
import '../categories/categories_screen.dart';
import '../calendar/deadline_screen.dart';
import '../life/life_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.reminderRefreshEpoch = 0,
  });

  final MemoryController controller;
  final int reminderRefreshEpoch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _reminderIds = const [];
  String _poolSignature = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
    _drawReminders(notify: false);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reminderRefreshEpoch != oldWidget.reminderRefreshEpoch) {
      _drawReminders(notify: false);
    }
  }

  List<MemoryDocument> _eligibleReminders() {
    final now = DateTime.now();
    return widget.controller.data.documents.where((document) {
      final mutedUntil = document.reminderMutedUntil;
      return document.inReminderPool &&
          !document.archived &&
          !document.deleted &&
          (mutedUntil == null || !mutedUntil.isAfter(now));
    }).toList();
  }

  String _signatureOf(List<MemoryDocument> documents) => documents
      .map(
        (document) =>
            '${document.id}:${document.reminderMutedUntil?.millisecondsSinceEpoch ?? 0}',
      )
      .join('|');

  void _handleControllerChange() {
    final eligible = _eligibleReminders();
    if (_signatureOf(eligible) != _poolSignature) _drawReminders();
  }

  void _drawReminders({bool notify = true}) {
    final eligible = _eligibleReminders();
    _poolSignature = _signatureOf(eligible);
    var nextIds = <String>[];
    for (var attempt = 0; attempt < 6; attempt++) {
      eligible.shuffle();
      nextIds = eligible.take(3).map((document) => document.id).toList();
      if (nextIds.join('|') != _reminderIds.join('|') || eligible.length < 2) {
        break;
      }
    }
    if (notify && mounted) {
      setState(() => _reminderIds = nextIds);
    } else {
      _reminderIds = nextIds;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final today = widget.controller.effectiveToday();
          final tasks = widget.controller.todayTasks;
          final nearestDeadline = widget.controller.activeDeadlines.firstOrNull;
          final byId = {
            for (final document in _eligibleReminders()) document.id: document,
          };
          final reminders = _reminderIds
              .map((id) => byId[id])
              .whereType<MemoryDocument>()
              .toList();
          return CustomScrollView(
            key: const PageStorageKey('home-scroll'),
            slivers: [
              SliverToBoxAdapter(child: _DateHeader(date: today)),
              SliverToBoxAdapter(child: _TodayHeading(count: tasks.length)),
              SliverToBoxAdapter(
                child: tasks.isEmpty
                    ? const _TodayEmpty()
                    : TaskCarousel(controller: widget.controller, tasks: tasks),
              ),
              if (nearestDeadline != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: NearestDeadlineTile(
                      deadline: nearestDeadline,
                      now: widget.controller.effectiveNow,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DeadlineScreen(controller: widget.controller),
                        ),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: nearestDeadline == null ? 116 : 72),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '文档提醒',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '从提醒池中轻轻抽取',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '换一组',
                          onPressed: _drawReminders,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    if (reminders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          '在文档列表的编辑状态中，把想偶尔回看的文档加入提醒池。',
                          style: TextStyle(
                            color: MemoryColors.secondaryInk,
                            height: 1.55,
                          ),
                        ),
                      )
                    else
                      for (final document in reminders)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(document.title),
                          subtitle: Text(
                            '${document.records.where((record) => !record.deleted).length} 条记录',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DocumentDetailScreen(
                                controller: widget.controller,
                                documentId: document.id,
                              ),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: '提醒操作',
                            onSelected: (value) =>
                                _handleReminderAction(document, value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'hideToday',
                                child: Text('今天隐藏'),
                              ),
                              PopupMenuItem(
                                value: 'later',
                                child: Text('稍后提醒'),
                              ),
                              PopupMenuItem(
                                value: 'never',
                                child: Text('移出提醒池'),
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _LifeEntry(
                            icon: Icons.kitchen_outlined,
                            title: '冰箱',
                            detail: '食材与待采购',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    FridgeScreen(controller: widget.controller),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LifeEntry(
                            icon: Icons.location_on_outlined,
                            title: '物品位置',
                            detail: '位置与库存',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => LocatedItemsScreen(
                                  controller: widget.controller,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleReminderAction(
    MemoryDocument document,
    String action,
  ) async {
    switch (action) {
      case 'hideToday':
        final today = widget.controller.effectiveToday();
        await widget.controller.setDocumentReminderMutedUntil(
          document.id,
          DateTime(today.year, today.month, today.day + 1, 4),
        );
        return;
      case 'later':
        final selected = await _pickReminderTime();
        if (selected != null) {
          await widget.controller.setDocumentReminderMutedUntil(
            document.id,
            selected,
          );
        }
        return;
      case 'never':
        await widget.controller.toggleDocumentReminder(document.id, false);
        return;
    }
  }

  Future<DateTime?> _pickReminderTime() async {
    final now = DateTime.now();
    var selected = now.add(const Duration(hours: 1));
    return showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: 340,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '稍后提醒',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                use24hFormat: true,
                minimumDate: now.add(const Duration(minutes: 5)),
                maximumDate: now.add(const Duration(hours: 24)),
                initialDateTime: selected,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      child: Column(
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 9,
            runSpacing: 2,
            children: [
              Text(
                DateFormat('M月d日', 'zh_CN').format(date),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  DateFormat('E', 'zh_CN').format(date),
                  style: const TextStyle(
                    color: MemoryColors.secondaryInk,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _TodayHeading extends StatelessWidget {
  const _TodayHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: Column(
        children: [
          Text('今日事项', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: MemoryColors.violet,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 6),
              ),
              const SizedBox(width: 8),
              Text('$count 件待处理', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayEmpty extends StatelessWidget {
  const _TodayEmpty();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 330,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_rounded, color: MemoryColors.cyan, size: 30),
            SizedBox(height: 12),
            Text(
              '今天暂时没有待处理事项',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              '在日历中添加后会自动出现在这里',
              style: TextStyle(color: MemoryColors.secondaryInk),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskCarousel extends StatefulWidget {
  const TaskCarousel({
    super.key,
    required this.controller,
    required this.tasks,
  });

  final MemoryController controller;
  final List<MemoryTask> tasks;

  @override
  State<TaskCarousel> createState() => _TaskCarouselState();
}

class _TaskCarouselState extends State<TaskCarousel> {
  late final PageController _pageController = PageController(
    viewportFraction: .78,
    initialPage: widget.tasks.length >= 3 ? 1 : 0,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TaskCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks.length == widget.tasks.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || widget.tasks.isEmpty) {
        return;
      }
      final current = (_pageController.page ?? 0).round();
      final target = current.clamp(0, widget.tasks.length - 1);
      if (target != current) _pageController.jumpToPage(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardHeight = math.min(548.0, width * 1.274);
    return SizedBox(
      height: cardHeight + 18,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.tasks.length,
        padEnds: true,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              final page = _pageController.hasClients
                  ? (_pageController.page ??
                        _pageController.initialPage.toDouble())
                  : _pageController.initialPage.toDouble();
              final distance = (page - index).abs().clamp(0.0, 1.0);
              final scale = 1 - distance * .2;
              return Transform.scale(scale: scale, child: child);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _TaskCard(
                task: widget.tasks[index],
                controller: widget.controller,
                height: cardHeight,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.task,
    required this.controller,
    required this.height,
  });

  final MemoryTask task;
  final MemoryController controller;
  final double height;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  double _verticalOffset = 0;

  Future<void> _resolve(MemoryTaskStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.controller.setTaskStatus(widget.task.id, status);
    if (!mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(status == MemoryTaskStatus.completed ? '事项已完成' : '今天已无视'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => widget.controller.setTaskStatus(
            widget.task.id,
            MemoryTaskStatus.active,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final actions = <CustomSemanticsAction, VoidCallback>{
      const CustomSemanticsAction(label: '完成'): () =>
          _resolve(MemoryTaskStatus.completed),
      const CustomSemanticsAction(label: '无视'): () =>
          _resolve(MemoryTaskStatus.skipped),
    };
    return Semantics(
      label: '${widget.task.title}，${_timeLabel(widget.task)}',
      customSemanticsActions: actions,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => setState(() {
          _verticalOffset = (_verticalOffset + details.delta.dy).clamp(
            -110,
            110,
          );
        }),
        onVerticalDragEnd: (_) {
          final offset = _verticalOffset;
          setState(() => _verticalOffset = 0);
          if (offset <= -88) _resolve(MemoryTaskStatus.completed);
          if (offset >= 88) _resolve(MemoryTaskStatus.skipped);
        },
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _verticalOffset, 0),
          height: widget.height,
          child: OpticalGlass(
            radius: 20,
            opacity: .56,
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, -.48),
                  child: Text(
                    _timeLabel(widget.task),
                    style: const TextStyle(
                      color: Color(0x9470809A),
                      fontSize: 44,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.44,
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, .08),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.task.title,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xF0294563),
                            fontSize: 27,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                        if (widget.task.note != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.task.note!,
                            textAlign: TextAlign.center,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MemoryColors.secondaryInk,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_verticalOffset.abs() > 24)
                  Align(
                    alignment: _verticalOffset < 0
                        ? const Alignment(0, -.9)
                        : const Alignment(0, .9),
                    child: Text(
                      _verticalOffset < 0 ? '完成' : '无视',
                      style: const TextStyle(
                        color: MemoryColors.secondaryInk,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeLabel(MemoryTask task) {
    final minutes = task.minutesFromMidnight;
    if (minutes == null) return '全天';
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _LifeEntry extends StatelessWidget {
  const _LifeEntry({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title，$detail',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: OpticalGlass(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFF4C789F), size: 24),
                const SizedBox(height: 14),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
