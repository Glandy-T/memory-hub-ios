import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../models/memory_data.dart';
import '../../state/memory_controller.dart';

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
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('全局搜索将在下一阶段接入移动端索引')),
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
                    Icon(
                      _editing
                          ? Icons.more_horiz_rounded
                          : Icons.chevron_right_rounded,
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

  @override
  void dispose() {
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
              if (document.records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: Text(
                    '这里还没有记录',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MemoryColors.secondaryInk),
                  ),
                ),
              for (final record in document.records)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat(
                          'y年M月d日 · HH:mm',
                          'zh_CN',
                        ).format(record.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 9),
                      Text(record.body, style: const TextStyle(height: 1.65)),
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
}
