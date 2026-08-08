import 'package:flutter/material.dart';

import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../state/memory_controller.dart';
import 'notification_settings_screen.dart';
import 'profile_tools_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: Listenable.merge([controller, controller.notifications]),
        builder: (context, _) {
          final reminderCount = controller.data.documents
              .where((document) => document.inReminderPool && !document.deleted)
              .length;
          final deletedCount =
              controller.data.tasks
                  .where((task) => task.status.name == 'deleted')
                  .length +
              controller.data.documents
                  .where((document) => document.deleted)
                  .length +
              controller.data.categories
                  .where((category) => category.deleted)
                  .length +
              controller.data.documents.fold<int>(
                0,
                (count, document) =>
                    count +
                    document.records.where((record) => record.deleted).length,
              ) +
              controller.data.locatedItems
                  .where((item) => item.deleted)
                  .length +
              controller.data.periodRules.where((rule) => rule.deleted).length;
          return ListView(
            key: const PageStorageKey('profile-scroll'),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const MemoryPageHeader(title: '我的'),
              _GroupTitle('内容与提醒'),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.notifications_none_rounded,
                    title: '文档提醒池',
                    value: '已选择 $reminderCount 篇',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ReminderPoolScreen(controller: controller),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.alarm_rounded,
                    title: '每日检查提醒',
                    value: controller.notifications.dailyEnabled
                        ? '${controller.notifications.dailyHour}:00'
                        : '关闭',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NotificationSettingsScreen(controller: controller),
                      ),
                    ),
                  ),
                ],
              ),
              _GroupTitle('数据与安全'),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.backup_outlined,
                    title: '数据备份',
                    value: '自动保留上一版',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BackupScreen(controller: controller),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.archive_outlined,
                    title: '归档文档',
                    value:
                        '${controller.data.documents.where((document) => document.archived && !document.deleted).length} 篇',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ArchivedDocumentsScreen(controller: controller),
                      ),
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.delete_outline_rounded,
                    title: '回收站',
                    value: '$deletedCount 项',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RecycleBinScreen(controller: controller),
                      ),
                    ),
                  ),
                ],
              ),
              _GroupTitle('外观'),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.palette_outlined,
                    title: '主题',
                    value: '浅色彩虹',
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Text(
                  'Memory Hub Android 预览版\nFlutter 共用工程已保留 iOS 目标',
                  style: TextStyle(
                    color: MemoryColors.secondaryInk,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: MemoryColors.secondaryInk,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OpticalGlass(
        opacity: .62,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 68,
      leading: Icon(icon, color: const Color(0xFF58769C), size: 22),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: Theme.of(context).textTheme.bodySmall),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: MemoryColors.secondaryInk,
              size: 19,
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
