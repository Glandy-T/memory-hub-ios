import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../models/memory_data.dart';
import '../../state/memory_controller.dart';
import '../life/life_screens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final today = controller.effectiveToday();
          final tasks = controller.todayTasks;
          final reminders = controller.data.documents
              .where(
                (document) =>
                    document.inReminderPool &&
                    !document.archived &&
                    !document.deleted,
              )
              .take(3)
              .toList();
          return CustomScrollView(
            key: const PageStorageKey('home-scroll'),
            slivers: [
              SliverToBoxAdapter(child: _DateHeader(date: today)),
              SliverToBoxAdapter(child: _TodayHeading(count: tasks.length)),
              SliverToBoxAdapter(
                child: tasks.isEmpty
                    ? const _TodayEmpty()
                    : TaskCarousel(controller: controller, tasks: tasks),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 116)),
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
                          onPressed: () {},
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
                          subtitle: Text('${document.records.length} 条记录'),
                          trailing: const Icon(Icons.chevron_right_rounded),
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
                                    FridgeScreen(controller: controller),
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
                                builder: (_) =>
                                    LocatedItemsScreen(controller: controller),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('M月d日', 'zh_CN').format(date),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(width: 9),
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
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [
                            MemoryColors.coral.withValues(alpha: .08),
                            Colors.transparent,
                            MemoryColors.cyan.withValues(alpha: .08),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
          child: SizedBox(
            height: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFF4C789F), size: 24),
                const Spacer(),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
