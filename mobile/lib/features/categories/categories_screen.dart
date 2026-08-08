import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../models/memory_data.dart';
import '../../state/memory_controller.dart';
import '../life/life_screens.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _managing = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final categories =
              widget.controller.data.categories
                  .where((category) => !category.deleted)
                  .toList()
                ..sort((left, right) => left.order.compareTo(right.order));
          return CustomScrollView(
            key: const PageStorageKey('categories-scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: MemoryPageHeader(
                  title: _managing ? '管理分类' : '分类',
                  action: _managing
                      ? TextButton(
                          onPressed: () => setState(() => _managing = false),
                          child: const Text('完成'),
                        )
                      : null,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: SearchBar(
                    hintText: '搜索文档和分类',
                    leading: const Icon(Icons.search_rounded),
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(
                      Colors.white.withValues(alpha: .68),
                    ),
                    readOnly: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            GlobalSearchScreen(controller: widget.controller),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                sliver: const SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(height: 1),
                      SizedBox(height: 22),
                      Text(
                        '全部分类',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverReorderableList(
                  itemCount: categories.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    if (!_managing) return;
                    final reordered = [...categories];
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);
                    await widget.controller.reorderCategories(
                      reordered.map((item) => item.id).toList(),
                    );
                  },
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Padding(
                      key: ValueKey(category.id),
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CategoryRow(
                        category: category,
                        dragIndex: index,
                        managing: _managing,
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          setState(() => _managing = true);
                        },
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DocumentListScreen(
                              controller: widget.controller,
                              category: category,
                            ),
                          ),
                        ),
                        onEdit: () => _editCategory(category),
                      ),
                    );
                  },
                ),
              ),
              if (_managing)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _editCategory(null),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('新增分类'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editCategory(MemoryCategory? category) async {
    final controller = TextEditingController(text: category?.name ?? '');
    var selectedColor = category?.colorValue ?? 0xFF41C7BE;
    final result = await showDialog<_CategoryEditResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? '新增分类' : '编辑分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const SizedBox(height: 12),
              Text('颜色', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: [
                  for (final color in const [
                    0xFF8F7CF6,
                    0xFFFFCA3A,
                    0xFF41C7BE,
                    0xFF5C8CFF,
                    0xFFFF6E67,
                  ])
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: MemoryColors.ink, width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            if (category != null && !category.isDefault)
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _CategoryEditResult.delete()),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('删除'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _CategoryEditResult.save(controller.text.trim(), selectedColor),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (result == null) return;
    if (result.delete) {
      await _deleteCategory(category!);
      return;
    }
    if (result.name.isEmpty) return;
    if (category == null) {
      await widget.controller.addCategory(result.name, result.colorValue);
    } else {
      await widget.controller.updateCategory(
        category.id,
        name: result.name,
        colorValue: result.colorValue,
      );
    }
  }

  Future<void> _deleteCategory(MemoryCategory category) async {
    final hasDocuments = widget.controller.data.documents.any(
      (document) => document.categoryId == category.id && !document.deleted,
    );
    final deleteDocuments = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除“${category.name}”？'),
        content: Text(
          hasDocuments
              ? '这个分类里还有文档。你可以只删除分类并把文档移到“未分类”，或把分类和文档一起移入回收站。'
              : '分类会进入回收站。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (hasDocuments)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('文档移到未分类'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(hasDocuments ? '分类和文档一起删除' : '删除'),
          ),
        ],
      ),
    );
    if (deleteDocuments == null) return;
    await widget.controller.deleteCategory(
      category.id,
      deleteDocuments: deleteDocuments,
    );
  }
}

class _CategoryEditResult {
  const _CategoryEditResult.save(this.name, this.colorValue) : delete = false;
  const _CategoryEditResult.delete() : name = '', colorValue = 0, delete = true;

  final String name;
  final int colorValue;
  final bool delete;
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.dragIndex,
    required this.managing,
    required this.onLongPress,
    required this.onOpen,
    required this.onEdit,
  });

  final MemoryCategory category;
  final int dragIndex;
  final bool managing;
  final VoidCallback onLongPress;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onLongPressHint: '进入分类管理',
      label: '${category.name}${managing ? '，管理模式' : ''}',
      child: OpticalGlass(
        radius: 18,
        opacity: .56,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: managing ? onEdit : onOpen,
          onLongPress: onLongPress,
          child: SizedBox(
            height: 54,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(category.colorValue),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 12),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (managing)
                    ReorderableDragStartListener(
                      index: dragIndex,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: MemoryColors.secondaryInk,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({
    super.key,
    required this.controller,
    required this.category,
  });

  final MemoryController controller;
  final MemoryCategory category;

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color(widget.category.colorValue),
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 7),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.category.name)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            child: Text(_editing ? '完成' : '编辑'),
          ),
        ],
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final documents =
              widget.controller.data.documents
                  .where(
                    (document) =>
                        document.categoryId == widget.category.id &&
                        !document.archived &&
                        !document.deleted,
                  )
                  .toList()
                ..sort(
                  (left, right) => right.updatedAt.compareTo(left.updatedAt),
                );
          if (documents.isEmpty) {
            return const Center(
              child: Text(
                '这个分类还没有文档',
                style: TextStyle(color: MemoryColors.secondaryInk),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final document = documents[index];
              return SizedBox(
                height: 72,
                child: Row(
                  children: [
                    if (_editing)
                      Checkbox(
                        value: document.inReminderPool,
                        onChanged: (value) =>
                            widget.controller.toggleDocumentReminder(
                              document.id,
                              value ?? false,
                            ),
                        semanticLabel: '加入文档提醒池',
                      ),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DocumentDetailScreen(
                              controller: widget.controller,
                              documentId: document.id,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${DateFormat('M月d日', 'zh_CN').format(document.updatedAt)}编辑',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_editing)
                      PopupMenuButton<String>(
                        tooltip: '文档操作',
                        onSelected: (value) =>
                            _handleDocumentAction(document, value),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('修改标题')),
                          PopupMenuItem(value: 'archive', child: Text('归档')),
                          PopupMenuDivider(),
                          PopupMenuItem(value: 'delete', child: Text('删除文档')),
                        ],
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: MemoryColors.secondaryInk,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建文档',
        onPressed: _createDocument,
        child: const Icon(Icons.add_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _createDocument() async {
    final input = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建文档'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    input.dispose();
    if (title != null && title.isNotEmpty) {
      await widget.controller.addDocument(widget.category.id, title);
    }
  }

  Future<void> _handleDocumentAction(
    MemoryDocument document,
    String action,
  ) async {
    switch (action) {
      case 'rename':
        await _renameDocument(document);
        return;
      case 'archive':
        await widget.controller.setDocumentArchived(document.id, true);
        return;
      case 'delete':
        await _deleteDocument(document);
        return;
    }
  }

  Future<void> _renameDocument(MemoryDocument document) async {
    final input = TextEditingController(text: document.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改文档标题'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: '标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    input.dispose();
    if (title != null && title.isNotEmpty && title != document.title) {
      await widget.controller.renameDocument(document.id, title);
    }
  }

  Future<void> _deleteDocument(MemoryDocument document) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这个文档？'),
        content: Text('“${document.title}”和其中的记录会进入回收站。'),
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
    if (approved == true) {
      await widget.controller.deleteDocument(document.id);
    }
  }
}

class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.controller,
    required this.documentId,
  });

  final MemoryController controller;
  final String documentId;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final _composer = TextEditingController();
  final _expandedRecords = <String>{};
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    final document = widget.controller.data.documents
        .where((item) => item.id == widget.documentId)
        .firstOrNull;
    _composer.text = document?.draftBody ?? '';
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (_composer.text.trim().isNotEmpty) {
      widget.controller.setDocumentDraft(widget.documentId, _composer.text);
    }
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final document = widget.controller.data.documents
            .where((item) => item.id == widget.documentId)
            .firstOrNull;
        if (document == null) {
          return const Scaffold(body: Center(child: Text('文档不存在')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(document.title),
            backgroundColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
            children: [
              if (!document.records.any((record) => !record.deleted))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: Text(
                    '这里还没有记录',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MemoryColors.secondaryInk),
                  ),
                ),
              for (final record in document.records.where(
                (record) => !record.deleted,
              ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.updatedAt == null
                                  ? DateFormat(
                                      'y年M月d日 · HH:mm',
                                      'zh_CN',
                                    ).format(record.createdAt)
                                  : '${DateFormat('y年M月d日 · HH:mm', 'zh_CN').format(record.updatedAt!)} 编辑',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '记录操作',
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editRecord(document.id, record);
                              } else if (value == 'delete') {
                                _deleteRecord(document.id, record);
                              } else if (value == 'history') {
                                _showRecordHistory(record);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('编辑'),
                              ),
                              if (record.previousBodies.isNotEmpty)
                                const PopupMenuItem(
                                  value: 'history',
                                  child: Text('历史版本'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        record.body,
                        maxLines: _expandedRecords.contains(record.id)
                            ? null
                            : 9,
                        overflow: _expandedRecords.contains(record.id)
                            ? TextOverflow.visible
                            : TextOverflow.fade,
                        style: const TextStyle(height: 1.65),
                      ),
                      if (_isLongRecord(record.body))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() {
                              if (!_expandedRecords.add(record.id)) {
                                _expandedRecords.remove(record.id);
                              }
                            }),
                            child: Text(
                              _expandedRecords.contains(record.id)
                                  ? '收起'
                                  : '展开',
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                    ],
                  ),
                ),
            ],
          ),
          bottomSheet: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: '添加一条记录…'),
                      onChanged: (value) {
                        _draftTimer?.cancel();
                        _draftTimer = Timer(
                          const Duration(milliseconds: 450),
                          () => widget.controller.setDocumentDraft(
                            document.id,
                            value,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: '保存记录',
                    onPressed: () async {
                      if (_composer.text.trim().isEmpty) return;
                      await widget.controller.addRecord(
                        document.id,
                        _composer.text,
                      );
                      _draftTimer?.cancel();
                      _composer.clear();
                    },
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isLongRecord(String body) =>
      body.length > 260 || '\n'.allMatches(body).length >= 8;

  Future<void> _showRecordHistory(MemoryRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .66,
        maxChildSize: .9,
        builder: (context, scrollController) => ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: record.previousBodies.length,
          separatorBuilder: (_, _) => const Divider(height: 28),
          itemBuilder: (context, index) {
            final body = record.previousBodies.reversed.elementAt(index);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  index == 0 ? '上一个版本' : '更早版本 ${index + 1}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 9),
                SelectableText(body, style: const TextStyle(height: 1.6)),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editRecord(String documentId, MemoryRecord record) async {
    final input = TextEditingController(text: record.body);
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑记录'),
        content: TextField(
          controller: input,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          maxLength: 12000,
          decoration: const InputDecoration(hintText: '记录内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('完成'),
          ),
        ],
      ),
    );
    input.dispose();
    if (body != null && body.isNotEmpty && body != record.body) {
      await widget.controller.updateRecord(documentId, record.id, body);
    }
  }

  Future<void> _deleteRecord(String documentId, MemoryRecord record) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记录？'),
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
    if (approved == true) {
      await widget.controller.deleteRecord(documentId, record.id);
    }
  }
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final results = _results(context, _query.text.trim().toLowerCase());
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SearchBar(
                  controller: _query,
                  hintText: '搜索文档和生活信息',
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_query.text.isNotEmpty)
                      IconButton(
                        tooltip: '清空',
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                  onChanged: (_) => setState(() {}),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    Colors.white.withValues(alpha: .72),
                  ),
                ),
              ),
              Expanded(
                child: _query.text.trim().isEmpty
                    ? const Center(
                        child: Text(
                          '输入名称、位置或记录内容',
                          style: TextStyle(color: MemoryColors.secondaryInk),
                        ),
                      )
                    : results.isEmpty
                    ? const Center(
                        child: Text(
                          '没有找到相关内容',
                          style: TextStyle(color: MemoryColors.secondaryInk),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => results[index],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _results(BuildContext context, String query) {
    if (query.isEmpty) return const [];
    final data = widget.controller.data;
    final results = <Widget>[];
    final categories = {
      for (final category in data.categories) category.id: category,
    };
    bool matches(String value) => value.toLowerCase().contains(query);

    for (final category in data.categories.where(
      (category) => !category.deleted && matches(category.name),
    )) {
      results.add(
        _SearchResultTile(
          icon: Icons.folder_outlined,
          title: category.name,
          detail: '分类',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DocumentListScreen(
                controller: widget.controller,
                category: category,
              ),
            ),
          ),
        ),
      );
    }
    for (final document in data.documents.where(
      (document) => !document.deleted,
    )) {
      final activeRecords = document.records.where((record) => !record.deleted);
      if (matches(document.title)) {
        results.add(
          _SearchResultTile(
            icon: Icons.description_outlined,
            title: document.title,
            detail:
                '${categories[document.categoryId]?.name ?? '未分类'}${document.archived ? ' · 已归档' : ''}',
            onTap: () => _openDocument(context, document.id),
          ),
        );
      }
      for (final record in activeRecords.where(
        (record) => matches(record.body),
      )) {
        results.add(
          _SearchResultTile(
            icon: Icons.notes_rounded,
            title: _excerpt(record.body, query),
            detail:
                '记录 · ${document.title}${document.archived ? ' · 已归档' : ''}',
            onTap: () => _openDocument(context, document.id),
          ),
        );
      }
    }
    for (final item in data.fridgeItems.where(
      (item) =>
          !item.deleted && (matches(item.name) || matches(item.note ?? '')),
    )) {
      results.add(
        _SearchResultTile(
          icon: Icons.kitchen_outlined,
          title: item.name,
          detail: '冰箱 · ${item.quantity}',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FridgeScreen(controller: widget.controller),
            ),
          ),
        ),
      );
    }
    for (final item in data.shoppingItems.where(
      (item) => !item.bought && matches(item.name),
    )) {
      results.add(
        _SearchResultTile(
          icon: Icons.shopping_bag_outlined,
          title: item.name,
          detail: '待采购',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FridgeScreen(controller: widget.controller),
            ),
          ),
        ),
      );
    }
    for (final item in data.locatedItems.where(
      (item) =>
          !item.deleted &&
          (matches(item.name) ||
              matches(item.location) ||
              matches(item.note ?? '') ||
              matches(item.container ?? '') ||
              item.locationHistory.any((entry) => matches(entry.location))),
    )) {
      results.add(
        _SearchResultTile(
          icon: Icons.inventory_2_outlined,
          title: item.name,
          detail: '物品位置 · ${item.location}',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LocatedItemsScreen(controller: widget.controller),
            ),
          ),
        ),
      );
    }
    return results;
  }

  void _openDocument(BuildContext context, String documentId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentDetailScreen(
          controller: widget.controller,
          documentId: documentId,
        ),
      ),
    );
  }

  String _excerpt(String body, String query) {
    final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final index = compact.toLowerCase().indexOf(query);
    final start = (index - 12).clamp(0, compact.length);
    final end = (start + 54).clamp(0, compact.length);
    final excerpt = compact.substring(start, end);
    return '${start > 0 ? '…' : ''}$excerpt${end < compact.length ? '…' : ''}';
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF58769C)),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: MemoryColors.secondaryInk,
      ),
      onTap: onTap,
    );
  }
}
