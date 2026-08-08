import 'package:flutter/material.dart';

import '../../core/theme/memory_theme.dart';
import '../../state/memory_controller.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    final notifications = controller.notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知设置'),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: notifications,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('每日检查提醒'),
              subtitle: const Text('每天提醒一次，看看是否还有遗漏的事项和文档。'),
              value: notifications.dailyEnabled,
              onChanged: (enabled) => _setDaily(context, enabled),
            ),
            if (notifications.dailyEnabled) ...[
              const SizedBox(height: 12),
              Text('提醒时间', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 8, label: Text('8:00')),
                  ButtonSegment(value: 9, label: Text('9:00')),
                ],
                selected: {notifications.dailyHour},
                onSelectionChanged: (value) =>
                    _setDaily(context, true, hour: value.first),
              ),
            ],
            const Divider(height: 40),
            Text('强提醒间隔', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              '事项选择“强提醒”后最多提醒 6 次；完成、无视或删除会立即取消剩余通知。',
              style: TextStyle(color: MemoryColors.secondaryInk, height: 1.5),
            ),
            const SizedBox(height: 14),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 15, label: Text('15 分钟')),
                ButtonSegment(value: 30, label: Text('30 分钟')),
                ButtonSegment(value: 60, label: Text('60 分钟')),
              ],
              selected: {notifications.strongIntervalMinutes},
              onSelectionChanged: (value) => _setStrongInterval(value.first),
            ),
            const SizedBox(height: 18),
            const Text(
              '系统省电策略可能让通知比设定时间稍晚出现。Memory Hub 不申请精确闹钟或绕过勿扰模式。',
              style: TextStyle(
                color: MemoryColors.secondaryInk,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setDaily(
    BuildContext context,
    bool enabled, {
    int? hour,
  }) async {
    final accepted = await controller.notifications.setDailyCheck(
      enabled: enabled,
      hour: hour ?? controller.notifications.dailyHour,
    );
    if (!accepted && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有获得系统通知权限，设置未开启。')));
    }
  }

  Future<void> _setStrongInterval(int minutes) async {
    await controller.notifications.setStrongInterval(minutes);
    for (final task in controller.data.tasks) {
      await controller.notifications.syncTask(task);
    }
  }
}
