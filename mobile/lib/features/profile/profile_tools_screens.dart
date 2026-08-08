import 'package:flutter/material.dart';

import '../../core/theme/memory_theme.dart';
import '../../models/memory_data.dart';
import '../../state/memory_controller.dart';
import '../categories/categories_screen.dart';

class ArchivedDocumentsScreen extends StatelessWidget {
  const ArchivedDocumentsScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('归档文档'),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final documents =
              controller.data.documents
                  .where((document) => document.archived && !document.deleted)
                  .toList()
                ..sort(
                  (left, right) => right.updatedAt.compareTo(left.updatedAt),
                );
          if (documents.isEmpty) {
            return const _QuietEmpty(
              icon: Icons.archive_outlined,
              title: '还没有归档文档',
              detail: '不常用但仍想保留的文档，可以从文档列表的编辑菜单归档。',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final document = documents[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(document.title),
                subtitle: Text(
                  '${document.records.where((record) => !record.deleted).length} 条记录',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DocumentDetailScreen(
                      controller: controller,
                      documentId: document.id,
                    ),
                  ),
                ),
                trailing: TextButton(
                  onPressed: () =>
                      controller.setDocumentArchived(document.id, false),
                  child: const Text('恢复'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ReminderPoolScreen extends StatelessWidget {
  const ReminderPoolScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文档提醒池'),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final documents =
              controller.data.documents
                  .where(
                    (document) =>
                        document.inReminderPool &&
                        !document.archived &&
                        !document.deleted,
                  )
                  .toList()
                ..sort(
                  (left, right) => right.updatedAt.compareTo(left.updatedAt),
                );
          if (documents.isEmpty) {
            return const _QuietEmpty(
              icon: Icons.notifications_none_rounded,
              title: '提醒池还是空的',
              detail: '进入分类中的文档列表，点“编辑”后勾选想偶尔回看的文档。',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final document = documents[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(document.title),
                subtitle: Text(
                  '${document.records.where((record) => !record.deleted).length} 条记录',
                ),
                trailing: TextButton(
                  onPressed: () =>
                      controller.toggleDocumentReminder(document.id, false),
                  child: const Text('移除'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RecycleBinScreen extends StatelessWidget {
  const RecycleBinScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final entries = _entries(context);
          if (entries.isEmpty) {
            return const _QuietEmpty(
              icon: Icons.delete_outline_rounded,
              title: '回收站是空的',
              detail: '删除的事项、分类、文档、记录和物品会先来到这里。',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => entries[index],
          );
        },
      ),
    );
  }

  List<Widget> _entries(BuildContext context) {
    final data = controller.data;
    final entries = <Widget>[];

    for (final task in data.tasks.where(
      (task) => task.status == MemoryTaskStatus.deleted,
    )) {
      entries.add(
        _TrashEntry(
          title: task.title,
          type: '事项',
          onRestore: () => controller.restoreTask(task.id),
          onDelete: () => _confirmPermanent(
            context,
            task.title,
            () => controller.permanentlyDeleteTask(task.id),
          ),
        ),
      );
    }
    for (final category in data.categories.where(
      (category) => category.deleted,
    )) {
      entries.add(
        _TrashEntry(
          title: category.name,
          type: '分类',
          onRestore: () => controller.restoreCategory(category.id),
          onDelete: () => _confirmPermanent(
            context,
            category.name,
            () => controller.permanentlyDeleteCategory(category.id),
          ),
        ),
      );
    }
    for (final document in data.documents.where(
      (document) => document.deleted && document.deletedWithCategoryId == null,
    )) {
      entries.add(
        _TrashEntry(
          title: document.title,
          type: '文档',
          onRestore: () => controller.restoreDocument(document.id),
          onDelete: () => _confirmPermanent(
            context,
            document.title,
            () => controller.permanentlyDeleteDocument(document.id),
          ),
        ),
      );
    }
    for (final document in data.documents.where(
      (document) => !document.deleted,
    )) {
      for (final record in document.records.where((record) => record.deleted)) {
        entries.add(
          _TrashEntry(
            title: _recordTitle(record.body),
            type: '记录 · ${document.title}',
            onRestore: () => controller.restoreRecord(document.id, record.id),
            onDelete: () => _confirmPermanent(
              context,
              _recordTitle(record.body),
              () => controller.permanentlyDeleteRecord(document.id, record.id),
            ),
          ),
        );
      }
    }
    for (final item in data.locatedItems.where((item) => item.deleted)) {
      entries.add(
        _TrashEntry(
          title: item.name,
          type: '物品位置',
          onRestore: () => controller.restoreLocatedItem(item.id),
          onDelete: () => _confirmPermanent(
            context,
            item.name,
            () => controller.permanentlyDeleteLocatedItem(item.id),
          ),
        ),
      );
    }
    return entries;
  }

  Future<void> _confirmPermanent(
    BuildContext context,
    String title,
    Future<void> Function() action,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除？'),
        content: Text('“$title”删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (approved == true) await action();
  }

  String _recordTitle(String body) {
    final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= 32 ? compact : '${compact.substring(0, 32)}…';
  }
}

class _TrashEntry extends StatelessWidget {
  const _TrashEntry({
    required this.title,
    required this.type,
    required this.onRestore,
    required this.onDelete,
  });

  final String title;
  final String type;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(type),
      trailing: PopupMenuButton<String>(
        tooltip: '回收站操作',
        onSelected: (value) => value == 'restore' ? onRestore() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'restore', child: Text('恢复')),
          PopupMenuItem(value: 'delete', child: Text('永久删除')),
        ],
      ),
    );
  }
}

class _QuietEmpty extends StatelessWidget {
  const _QuietEmpty({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: MemoryColors.secondaryInk),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 7),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
