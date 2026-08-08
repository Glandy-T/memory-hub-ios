import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/memory_theme.dart';
import '../../models/memory_data.dart';
import '../../state/memory_controller.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('冰箱'),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final fridge = widget.controller.data.fridgeItems
              .where((item) => !item.deleted)
              .toList();
          final shopping = widget.controller.data.shoppingItems
              .where((item) => !item.bought)
              .toList();
          final history =
              widget.controller.data.fridgeItems
                  .where((item) => item.deleted)
                  .toList()
                ..sort(
                  (a, b) => (b.deletedAt ?? b.updatedAt).compareTo(
                    a.deletedAt ?? a.updatedAt,
                  ),
                );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('冰箱内容')),
                    ButtonSegment(value: 1, label: Text('待采购')),
                    ButtonSegment(value: 2, label: Text('15天历史')),
                  ],
                  selected: {_section},
                  onSelectionChanged: (value) =>
                      setState(() => _section = value.first),
                ),
              ),
              Expanded(
                child: _section == 0
                    ? _FridgeList(
                        items: fridge,
                        controller: widget.controller,
                        onEdit: _editFridgeItem,
                      )
                    : _section == 1
                    ? _ShoppingList(
                        items: shopping,
                        controller: widget.controller,
                      )
                    : _FridgeHistoryList(
                        items: history,
                        controller: widget.controller,
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _section == 2
          ? null
          : FloatingActionButton(
              tooltip: _section == 0 ? '添加食材' : '添加待采购',
              onPressed: _section == 0 ? _addFridgeItem : _addShoppingItem,
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  Future<void> _addFridgeItem() async {
    final result = await showModalBottomSheet<_FridgeDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FridgeEditor(),
    );
    if (result == null) return;
    await widget.controller.addFridgeItem(
      name: result.name,
      quantity: result.quantity,
      storage: result.storage,
      expiryDate: result.expiryDate,
      note: result.note,
      opened: result.opened,
    );
  }

  Future<void> _editFridgeItem(FridgeItem item) async {
    final result = await showModalBottomSheet<_FridgeDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FridgeEditor(item: item),
    );
    if (result == null) return;
    await widget.controller.updateFridgeItem(
      id: item.id,
      name: result.name,
      quantity: result.quantity,
      storage: result.storage,
      expiryDate: result.expiryDate,
      note: result.note,
      opened: result.opened,
    );
  }

  Future<void> _addShoppingItem() async {
    final value = await _askForText(context, title: '添加待采购', label: '名称');
    if (value != null) await widget.controller.addShoppingItem(value);
  }
}

class _FridgeList extends StatelessWidget {
  const _FridgeList({
    required this.items,
    required this.controller,
    required this.onEdit,
  });

  final List<FridgeItem> items;
  final MemoryController controller;
  final ValueChanged<FridgeItem> onEdit;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _LifeEmpty(icon: Icons.kitchen_outlined, text: '冰箱里还没有记录');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final expiry = item.expiryDate == null
            ? null
            : '至 ${DateFormat('M月d日', 'zh_CN').format(item.expiryDate!)}';
        return ListTile(
          onTap: () => onEdit(item),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            item.storage == FridgeStorage.frozen
                ? Icons.ac_unit_rounded
                : Icons.kitchen_outlined,
          ),
          title: Text(item.name),
          subtitle: Text(
            [
              item.quantity,
              item.opened ? '已开封' : null,
              expiry,
            ].whereType<String>().join(' · '),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                onEdit(item);
                return;
              }
              controller.removeFridgeItem(
                item.id,
                reason: switch (value) {
                  'discarded' => FridgeRemovalReason.discarded,
                  'removed' => FridgeRemovalReason.removed,
                  _ => FridgeRemovalReason.eaten,
                },
                addToShopping: value == 'shopping',
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'used', child: Text('已用完')),
              PopupMenuItem(value: 'shopping', child: Text('用完并加入待采购')),
              PopupMenuItem(value: 'discarded', child: Text('已丢弃')),
              PopupMenuItem(value: 'removed', child: Text('移出冰箱')),
            ],
          ),
        );
      },
    );
  }
}

class _FridgeHistoryList extends StatelessWidget {
  const _FridgeHistoryList({required this.items, required this.controller});

  final List<FridgeItem> items;
  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _LifeEmpty(
        icon: Icons.history_rounded,
        text: '最近 15 天没有移除记录',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final removedAt = item.deletedAt ?? item.updatedAt;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.name),
          subtitle: Text(
            '${_fridgeRemovalLabel(item.removalReason)} · ${DateFormat('M月d日 HH:mm', 'zh_CN').format(removedAt)}',
          ),
          trailing: TextButton(
            onPressed: () => controller.restoreFridgeItem(item.id),
            child: const Text('恢复'),
          ),
        );
      },
    );
  }
}

String _fridgeRemovalLabel(FridgeRemovalReason? reason) => switch (reason) {
  FridgeRemovalReason.eaten => '已用完',
  FridgeRemovalReason.discarded => '已丢弃',
  FridgeRemovalReason.removed => '已移出',
  null => '历史记录',
};

class _ShoppingList extends StatelessWidget {
  const _ShoppingList({required this.items, required this.controller});

  final List<ShoppingItem> items;
  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _LifeEmpty(
        icon: Icons.shopping_bag_outlined,
        text: '暂时没有待采购',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: item.bought,
          title: Text(item.name),
          onChanged: (value) =>
              controller.setShoppingBought(item.id, value ?? false),
        );
      },
    );
  }
}

class LocatedItemsScreen extends StatelessWidget {
  const LocatedItemsScreen({super.key, required this.controller});

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('物品位置'),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final items = controller.data.locatedItems
              .where((item) => !item.deleted)
              .toList();
          if (items.isEmpty) {
            return const _LifeEmpty(
              icon: Icons.location_on_outlined,
              text: '还没有记录物品位置',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                onTap: () => _editItem(context, item),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(item.name),
                subtitle: Text(
                  [
                    item.location,
                    item.container,
                    item.quantity,
                    _locatedStatusLabel(item.status),
                  ].whereType<String>().join(' · '),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editItem(context, item);
                    if (value == 'history') _showHistory(context, item);
                    if (value == 'delete') _confirmDelete(context, item);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(
                      value: 'history',
                      enabled: item.locationHistory.isNotEmpty,
                      child: const Text('位置历史'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '添加物品',
        onPressed: () => _addItem(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Future<void> _addItem(BuildContext context) async {
    final result = await showModalBottomSheet<_LocatedDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LocatedEditor(),
    );
    if (result == null) return;
    await controller.addLocatedItem(
      name: result.name,
      location: result.location,
      quantity: result.quantity,
      note: result.note,
      container: result.container,
      status: result.status,
    );
  }

  Future<void> _editItem(BuildContext context, LocatedItem item) async {
    final result = await showModalBottomSheet<_LocatedDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LocatedEditor(item: item),
    );
    if (result == null) return;
    await controller.updateLocatedItem(
      id: item.id,
      name: result.name,
      location: result.location,
      quantity: result.quantity,
      note: result.note,
      container: result.container,
      status: result.status,
    );
  }

  Future<void> _showHistory(BuildContext context, LocatedItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('位置历史', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '现在：${item.location}',
                style: const TextStyle(color: MemoryColors.secondaryInk),
              ),
              const SizedBox(height: 12),
              for (final entry in item.locationHistory.reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text(entry.location),
                  trailing: Text(
                    DateFormat('M月d日 HH:mm', 'zh_CN').format(entry.changedAt),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LocatedItem item) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除物品记录？'),
        content: Text('“${item.name}”会进入回收状态。'),
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
    if (approved == true) await controller.deleteLocatedItem(item.id);
  }
}

String _locatedStatusLabel(LocatedItemStatus status) => switch (status) {
  LocatedItemStatus.stored => '收纳中',
  LocatedItemStatus.inUse => '使用中',
  LocatedItemStatus.lentOut => '已借出',
  LocatedItemStatus.missing => '未找到',
};

class _LifeEmpty extends StatelessWidget {
  const _LifeEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: MemoryColors.secondaryInk),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: MemoryColors.secondaryInk)),
      ],
    ),
  );
}

class _FridgeDraft {
  const _FridgeDraft(
    this.name,
    this.quantity,
    this.storage,
    this.expiryDate,
    this.note,
    this.opened,
  );
  final String name;
  final String quantity;
  final FridgeStorage storage;
  final DateTime? expiryDate;
  final String note;
  final bool opened;
}

class _FridgeEditor extends StatefulWidget {
  const _FridgeEditor({this.item});

  final FridgeItem? item;
  @override
  State<_FridgeEditor> createState() => _FridgeEditorState();
}

class _FridgeEditorState extends State<_FridgeEditor> {
  late final TextEditingController name;
  late final TextEditingController quantity;
  late final TextEditingController note;
  late FridgeStorage storage;
  late DateTime? expiry;
  late bool opened;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    name = TextEditingController(text: item?.name ?? '');
    quantity = TextEditingController(text: item?.quantity ?? '1');
    note = TextEditingController(text: item?.note ?? '');
    storage = item?.storage ?? FridgeStorage.chilled;
    expiry = item?.expiryDate;
    opened = item?.opened ?? false;
  }

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EditorSheet(
    title: widget.item == null ? '添加食材' : '编辑食材',
    children: [
      TextField(
        controller: name,
        autofocus: true,
        decoration: const InputDecoration(labelText: '名称 *'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: quantity,
        decoration: const InputDecoration(labelText: '数量'),
      ),
      const SizedBox(height: 12),
      SegmentedButton<FridgeStorage>(
        segments: const [
          ButtonSegment(value: FridgeStorage.chilled, label: Text('冷藏')),
          ButtonSegment(value: FridgeStorage.frozen, label: Text('冷冻')),
        ],
        selected: {storage},
        onSelectionChanged: (value) => setState(() => storage = value.first),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('已经开封'),
        value: opened,
        onChanged: (value) => setState(() => opened = value),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('到期日（可选）'),
        trailing: Text(
          expiry == null ? '未设置' : DateFormat('y/M/d').format(expiry!),
        ),
        onTap: () async {
          final value = await showDatePicker(
            context: context,
            firstDate: DateTime.now().subtract(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (value != null) setState(() => expiry = value);
        },
      ),
      TextField(
        controller: note,
        maxLines: 2,
        decoration: const InputDecoration(labelText: '备注（可选）'),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () {
          if (name.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            _FridgeDraft(
              name.text.trim(),
              quantity.text,
              storage,
              expiry,
              note.text,
              opened,
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _LocatedDraft {
  const _LocatedDraft(
    this.name,
    this.location,
    this.quantity,
    this.note,
    this.container,
    this.status,
  );
  final String name;
  final String location;
  final String quantity;
  final String note;
  final String container;
  final LocatedItemStatus status;
}

class _LocatedEditor extends StatefulWidget {
  const _LocatedEditor({this.item});

  final LocatedItem? item;
  @override
  State<_LocatedEditor> createState() => _LocatedEditorState();
}

class _LocatedEditorState extends State<_LocatedEditor> {
  late final TextEditingController name;
  late final TextEditingController location;
  late final TextEditingController quantity;
  late final TextEditingController note;
  late final TextEditingController container;
  late LocatedItemStatus status;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    name = TextEditingController(text: item?.name ?? '');
    location = TextEditingController(text: item?.location ?? '');
    quantity = TextEditingController(text: item?.quantity ?? '1');
    note = TextEditingController(text: item?.note ?? '');
    container = TextEditingController(text: item?.container ?? '');
    status = item?.status ?? LocatedItemStatus.stored;
  }

  @override
  void dispose() {
    name.dispose();
    location.dispose();
    quantity.dispose();
    note.dispose();
    container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EditorSheet(
    title: widget.item == null ? '添加物品' : '编辑物品',
    children: [
      TextField(
        controller: name,
        autofocus: true,
        decoration: const InputDecoration(labelText: '物品名称 *'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: location,
        decoration: const InputDecoration(labelText: '所在位置（自由填写）*'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: quantity,
        decoration: const InputDecoration(labelText: '数量'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: container,
        decoration: const InputDecoration(labelText: '容器或收纳盒（可选）'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<LocatedItemStatus>(
        initialValue: status,
        decoration: const InputDecoration(labelText: '当前状态'),
        items: [
          for (final value in LocatedItemStatus.values)
            DropdownMenuItem(
              value: value,
              child: Text(_locatedStatusLabel(value)),
            ),
        ],
        onChanged: (value) => setState(() => status = value ?? status),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: note,
        maxLines: 2,
        decoration: const InputDecoration(labelText: '备注（可选）'),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () {
          if (name.text.trim().isEmpty || location.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            _LocatedDraft(
              name.text.trim(),
              location.text.trim(),
              quantity.text,
              note.text,
              container.text,
              status,
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _EditorSheet extends StatelessWidget {
  const _EditorSheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}

Future<String?> _askForText(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  final input = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
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
  return value == null || value.isEmpty ? null : value;
}
