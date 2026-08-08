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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('冰箱内容')),
                    ButtonSegment(value: 1, label: Text('待采购')),
                  ],
                  selected: {_section},
                  onSelectionChanged: (value) =>
                      setState(() => _section = value.first),
                ),
              ),
              Expanded(
                child: _section == 0
                    ? _FridgeList(items: fridge, controller: widget.controller)
                    : _ShoppingList(
                        items: shopping,
                        controller: widget.controller,
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
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
    );
  }

  Future<void> _addShoppingItem() async {
    final value = await _askForText(context, title: '添加待采购', label: '名称');
    if (value != null) await widget.controller.addShoppingItem(value);
  }
}

class _FridgeList extends StatelessWidget {
  const _FridgeList({required this.items, required this.controller});

  final List<FridgeItem> items;
  final MemoryController controller;

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
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            item.storage == FridgeStorage.frozen
                ? Icons.ac_unit_rounded
                : Icons.kitchen_outlined,
          ),
          title: Text(item.name),
          subtitle: Text(
            [item.quantity, expiry].whereType<String>().join(' · '),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) => controller.removeFridgeItem(
              item.id,
              addToShopping: value == 'shopping',
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'used', child: Text('已用完')),
              PopupMenuItem(value: 'shopping', child: Text('用完并加入待采购')),
            ],
          ),
        );
      },
    );
  }
}

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
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(item.name),
                subtitle: Text('${item.location} · ${item.quantity}'),
                trailing: IconButton(
                  tooltip: '删除',
                  onPressed: () => _confirmDelete(context, item),
                  icon: const Icon(Icons.more_horiz_rounded),
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
  );
  final String name;
  final String quantity;
  final FridgeStorage storage;
  final DateTime? expiryDate;
  final String note;
}

class _FridgeEditor extends StatefulWidget {
  const _FridgeEditor();
  @override
  State<_FridgeEditor> createState() => _FridgeEditorState();
}

class _FridgeEditorState extends State<_FridgeEditor> {
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final note = TextEditingController();
  FridgeStorage storage = FridgeStorage.chilled;
  DateTime? expiry;

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EditorSheet(
    title: '添加食材',
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
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _LocatedDraft {
  const _LocatedDraft(this.name, this.location, this.quantity, this.note);
  final String name;
  final String location;
  final String quantity;
  final String note;
}

class _LocatedEditor extends StatefulWidget {
  const _LocatedEditor();
  @override
  State<_LocatedEditor> createState() => _LocatedEditorState();
}

class _LocatedEditorState extends State<_LocatedEditor> {
  final name = TextEditingController();
  final location = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final note = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    location.dispose();
    quantity.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EditorSheet(
    title: '添加物品',
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
