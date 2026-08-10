import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/memory_theme.dart';
import '../core/widgets/memory_surfaces.dart';
import '../state/memory_controller.dart';
import 'lab_models.dart';
import 'lab_state.dart';

class PendingCaptureScreen extends StatelessWidget {
  const PendingCaptureScreen({
    super.key,
    required this.controller,
    required this.lab,
  });
  final MemoryController controller;
  final LabState lab;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('待收录'),
      backgroundColor: Colors.transparent,
    ),
    body: AnimatedBuilder(
      animation: lab,
      builder: (context, _) {
        if (lab.data.captures.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 38,
                  color: MemoryColors.secondaryInk,
                ),
                SizedBox(height: 14),
                Text('还没有待收录内容'),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          itemCount: lab.data.captures.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final capture = lab.data.captures[index];
            return Dismissible(
              key: ValueKey(capture.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: Theme.of(context).colorScheme.errorContainer,
                child: const Icon(Icons.delete_outline_rounded),
              ),
              onDismissed: (_) => lab.removeCapture(capture.id),
              child: OpticalGlass(
                radius: 18,
                child: ListTile(
                  minTileHeight: 104,
                  title: Text(
                    capture.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${capture.label} · ${DateFormat('M月d日 HH:mm', 'zh_CN').format(capture.createdAt)}',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _review(context, capture),
                ),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _review(BuildContext context, LabCapture capture) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _CaptureReviewSheet(controller: controller, capture: capture),
    );
    if (accepted == true) await lab.removeCapture(capture.id);
  }
}

class _CaptureReviewSheet extends StatefulWidget {
  const _CaptureReviewSheet({required this.controller, required this.capture});
  final MemoryController controller;
  final LabCapture capture;

  @override
  State<_CaptureReviewSheet> createState() => _CaptureReviewSheetState();
}

class _CaptureReviewSheetState extends State<_CaptureReviewSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.capture.text,
  );
  final _detail = TextEditingController();
  late DateTime _date;
  int? _minutesFromMidnight;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final inferred = inferLabCaptureSchedule(
      widget.capture.text,
      DateTime.now(),
    );
    _date = inferred.date;
    _minutesFromMidnight = inferred.minutesFromMidnight;
    _categoryId = widget.controller.data.categories
        .where((value) => !value.deleted)
        .firstOrNull
        ?.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.capture.kind;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确认${widget.capture.label}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '内容'),
            ),
            if (kind == LabCaptureKind.task ||
                kind == LabCaptureKind.deadline) ...[
              const SizedBox(height: 14),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text('日期'),
                subtitle: Text(DateFormat('yyyy年M月d日', 'zh_CN').format(_date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              if (kind == LabCaptureKind.task)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text('时间'),
                  subtitle: Text(
                    _minutesFromMidnight == null
                        ? '全天'
                        : _formatMinutes(_minutesFromMidnight!),
                  ),
                  trailing: _minutesFromMidnight == null
                      ? const Icon(Icons.schedule_outlined)
                      : IconButton(
                          tooltip: '设为全天',
                          onPressed: () => setState(
                            () => _minutesFromMidnight = null,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onTap: _pickTime,
                ),
            ],
            if (kind == LabCaptureKind.document) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: '存入分类'),
                items: [
                  for (final category
                      in widget.controller.data.categories.where(
                        (value) => !value.deleted,
                      ))
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ],
            if (kind == LabCaptureKind.itemLocation) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _detail,
                decoration: const InputDecoration(
                  labelText: '所在位置',
                  hintText: '例如：书桌右侧抽屉',
                ),
              ),
            ],
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('稍后'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _accept,
                    child: Text(_saving ? '保存中' : '确认收录'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final initial = _minutesFromMidnight == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(
            hour: _minutesFromMidnight! ~/ 60,
            minute: _minutesFromMidnight! % 60,
          );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => _minutesFromMidnight = picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _accept() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (widget.capture.kind == LabCaptureKind.itemLocation &&
        _detail.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写所在位置')));
      return;
    }
    setState(() => _saving = true);
    switch (widget.capture.kind) {
      case LabCaptureKind.task:
        await widget.controller.addTask(
          title: title,
          date: _date,
          minutesFromMidnight: _minutesFromMidnight,
        );
      case LabCaptureKind.deadline:
        await widget.controller.addDeadline(title: title, date: _date);
      case LabCaptureKind.document:
        await widget.controller.addDocument(_categoryId!, title);
      case LabCaptureKind.purchase:
        await widget.controller.addShoppingItem(title);
      case LabCaptureKind.itemLocation:
        await widget.controller.addLocatedItem(
          name: title,
          location: _detail.text,
          quantity: '1',
        );
    }
    if (mounted) Navigator.pop(context, true);
  }
}

String _formatMinutes(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
