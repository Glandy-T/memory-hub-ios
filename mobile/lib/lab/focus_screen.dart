import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/memory_theme.dart';
import '../core/widgets/memory_surfaces.dart';
import '../models/memory_data.dart';
import '../state/memory_controller.dart';
import 'lab_state.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({
    super.key,
    required this.controller,
    required this.lab,
    required this.taskId,
  });

  final MemoryController controller;
  final LabState lab;
  final String taskId;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (widget.lab.remainingSeconds(widget.taskId) == 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.controller, widget.lab]),
    builder: (context, _) {
      final task = widget.controller.data.tasks
          .where((value) => value.id == widget.taskId)
          .firstOrNull;
      if (task == null) {
        return const Scaffold(body: Center(child: Text('事项已不存在')));
      }
      final plan = widget.lab.planFor(widget.taskId);
      final remaining = widget.lab.remainingSeconds(widget.taskId);
      final paused = plan.focusEndsAt == null && remaining > 0;
      final done = remaining == 0;
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('退出'),
                    ),
                    Expanded(
                      child: Text(
                        paused
                            ? '专注已暂停'
                            : done
                            ? '时间到了'
                            : '只做这一件',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 64),
                  ],
                ),
                const SizedBox(height: 42),
                Text(
                  task.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 30),
                _TimerRing(
                  remaining: remaining,
                  total: math.max(plan.durationMinutes * 60, remaining),
                ),
                if (paused && plan.pauseNote != null) ...[
                  const SizedBox(height: 22),
                  OpticalGlass(
                    radius: 16,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '离开前做到这里',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(plan.pauseNote!),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                OpticalGlass(
                  radius: 20,
                  padding: const EdgeInsets.all(18),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当前一步',
                          style: TextStyle(
                            color: MemoryColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan.currentStep?.title ?? task.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (paused)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _moveLater,
                          child: const Text('改到稍后'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _resume,
                          child: const Text('继续'),
                        ),
                      ),
                    ],
                  )
                else if (done)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _finish,
                          child: const Text('完成这一轮'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _addFive(restart: true),
                        child: const Text('再来 5 分钟'),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _pause,
                          child: const Text('暂停'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _addFive,
                          child: const Text('+5 分钟'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _finish,
                          child: const Text('完成'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _pause() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PauseSheet(),
    );
    if (value == null) return;
    await widget.lab.pauseFocus(widget.taskId, value);
  }

  Future<void> _resume() async {
    await widget.lab.startFocus(widget.taskId);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _addFive({bool restart = false}) async {
    await widget.lab.addFocusMinutes(widget.taskId, 5);
    if (restart) await widget.lab.startFocus(widget.taskId);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _finish() async {
    await widget.lab.finishCurrentStep(widget.taskId);
    final plan = widget.lab.planFor(widget.taskId);
    if (plan.currentStep == null) {
      await widget.controller.setTaskStatus(
        widget.taskId,
        MemoryTaskStatus.completed,
      );
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_rounded,
          color: MemoryColors.cyan,
          size: 36,
        ),
        title: const Text('这一轮完成了'),
        content: Text(
          plan.currentStep == null
              ? '事项已完成。'
              : '下一步：${plan.currentStep!.title}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _moveLater() async {
    final task = widget.controller.data.tasks
        .where((value) => value.id == widget.taskId)
        .firstOrNull;
    if (task == null) return;
    await widget.controller.updateTask(
      id: task.id,
      title: task.title,
      note: task.note,
      date: DateTime.now().add(const Duration(days: 1)),
      minutesFromMidnight: task.minutesFromMidnight,
    );
    if (mounted) Navigator.pop(context);
  }
}

class _PauseSheet extends StatefulWidget {
  const _PauseSheet();

  @override
  State<_PauseSheet> createState() => _PauseSheetState();
}

class _PauseSheetState extends State<_PauseSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '离开前做到哪里？',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _note,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '进度备注（可选）',
              hintText: '例如：正在找去年的报告',
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _note.text.trim()),
              child: const Text('保存并暂停'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.remaining, required this.total});
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return SizedBox.square(
      dimension: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: total == 0 ? 0 : remaining / total,
            strokeWidth: 10,
            backgroundColor: Colors.white.withValues(alpha: .62),
            color: MemoryColors.accent,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  '剩余时间',
                  style: TextStyle(color: MemoryColors.secondaryInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
