import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/memory_theme.dart';
import '../../core/widgets/memory_surfaces.dart';
import '../../models/intake_candidate.dart';
import '../../services/memory_intake_service.dart';
import '../../state/memory_controller.dart';

class IntakeReviewScreen extends StatefulWidget {
  const IntakeReviewScreen({
    super.key,
    required this.controller,
    this.filePicker = const SystemIntakeConnectionFilePicker(),
  });

  final MemoryController controller;
  final IntakeConnectionFilePicker filePicker;

  @override
  State<IntakeReviewScreen> createState() => _IntakeReviewScreenState();
}

class _IntakeReviewScreenState extends State<IntakeReviewScreen> {
  final Map<String, IntakeCandidate> _edited = {};
  final Set<String> _workingIds = {};
  bool _connecting = false;

  MemoryIntakeService get _service => widget.controller.intake;

  @override
  void initState() {
    super.initState();
    if (_service.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _service.refresh(silent: true).catchError((_) {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('待收录'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_service.connected)
            IconButton(
              tooltip: '刷新待收录',
              onPressed: _service.refreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          if (_service.connected)
            PopupMenuButton<String>(
              tooltip: '连接设置',
              onSelected: (value) {
                if (value == 'disconnect') _disconnect();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'disconnect', child: Text('断开设备连接')),
              ],
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          if (!_service.connected) return _buildDisconnected();
          return RefreshIndicator(
            onRefresh: _service.refresh,
            child: _buildConnected(),
          );
        },
      ),
    );
  }

  Widget _buildDisconnected() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 32),
      children: [
        const Icon(
          Icons.move_to_inbox_outlined,
          size: 38,
          color: MemoryColors.violet,
        ),
        const SizedBox(height: 18),
        Text('把其他任务整理的内容接进来', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(
          '连接一次后，预约、时间表和生活信息会自动出现在这里。你仍可在写入正式内容前检查、修改或忽略。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: _connecting ? null : _connect,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(_connecting ? '正在连接…' : '导入连接文件'),
        ),
        const SizedBox(height: 14),
        Text(
          '连接文件只需导入一次。它由网页版“我的 → 连接 Android 原生版”生成，凭证会保存在系统安全存储中。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildConnected() {
    final items = _service.items;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        if (_service.error != null) ...[
          _SyncIssue(message: _service.error!, onRetry: _refresh),
          const SizedBox(height: 14),
        ],
        if (_service.refreshing) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 14),
        ],
        Text(
          items.isEmpty ? '没有等待确认的内容' : '${items.length} 条内容等待确认',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          items.isEmpty
              ? '其他 Codex 任务的新投递会在下次打开或下拉刷新时出现。'
              : '完整信息可以直接收录；缺少日期或位置时再补一次即可。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        for (final raw in items) ...[
          _CandidateCard(
            candidate: _edited[raw.id] ?? raw,
            working: _workingIds.contains(raw.id),
            onEdit: () => _edit(raw),
            onAccept: () => _accept(raw),
            onIgnore: () => _ignore(raw),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      final raw = await widget.filePicker.pick();
      if (raw == null) return;
      await _service.connectFromJson(raw);
      if (mounted) _showMessage('Android 已连接，待收录内容会自动同步');
    } on FormatException catch (error) {
      if (mounted) _showMessage('无法连接：${error.message}');
    } on MemoryIntakeException catch (error) {
      if (mounted) _showMessage('无法连接：${error.message}');
    } on Object {
      if (mounted) _showMessage('无法读取连接文件，请重新下载后再试');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _refresh() async {
    try {
      await _service.refresh();
    } on MemoryIntakeException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _edit(IntakeCandidate original) async {
    final edited = await showModalBottomSheet<IntakeCandidate>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _CandidateEditor(candidate: _edited[original.id] ?? original),
    );
    if (edited != null && mounted) {
      setState(() => _edited[original.id] = edited);
    }
  }

  Future<void> _accept(IntakeCandidate original) async {
    var candidate = _edited[original.id] ?? original;
    if (_requiresDetails(candidate)) {
      final edited = await showModalBottomSheet<IntakeCandidate>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _CandidateEditor(candidate: candidate),
      );
      if (edited == null) return;
      candidate = edited;
      if (_requiresDetails(candidate)) {
        _showMessage(
          candidate.target == IntakeTarget.calendar ? '请先补充日期' : '请先补充物品位置',
        );
        return;
      }
      if (mounted) setState(() => _edited[original.id] = candidate);
    }
    setState(() => _workingIds.add(original.id));
    try {
      await widget.controller.acceptIntakeCandidate(candidate);
      await _service.decide(candidate, accept: true);
      if (mounted) {
        setState(() => _edited.remove(original.id));
        _showMessage('已收录到${_targetLabel(candidate.target)}');
      }
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } on MemoryIntakeException catch (error) {
      if (mounted) _showMessage('已保存到本机；${error.message}');
    } finally {
      if (mounted) setState(() => _workingIds.remove(original.id));
    }
  }

  Future<void> _ignore(IntakeCandidate candidate) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('忽略这条内容？'),
        content: Text('“${candidate.title}”不会写入正式内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('忽略'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _workingIds.add(candidate.id));
    try {
      await _service.decide(candidate, accept: false);
      if (mounted) _showMessage('已忽略');
    } on MemoryIntakeException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _workingIds.remove(candidate.id));
    }
  }

  Future<void> _disconnect() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('断开设备连接？'),
        content: const Text('本机已经收录的内容不会删除。以后可以重新导入连接文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('断开'),
          ),
        ],
      ),
    );
    if (approved == true) await _service.disconnect();
  }

  bool _requiresDetails(IntakeCandidate candidate) {
    if (candidate.target == IntakeTarget.calendar) {
      return candidate.payload['scheduledAt'] == null &&
          candidate.payload['date'] == null;
    }
    if (candidate.target == IntakeTarget.homeItem) {
      return (candidate.payload['location'] as String?)?.trim().isNotEmpty !=
          true;
    }
    return false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.working,
    required this.onEdit,
    required this.onAccept,
    required this.onIgnore,
  });

  final IntakeCandidate candidate;
  final bool working;
  final VoidCallback onEdit;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    return OpticalGlass(
      opacity: .66,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _targetIcon(candidate.target),
                size: 19,
                color: MemoryColors.violet,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_targetLabel(candidate.target)} · 来自 ${candidate.sourceLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: '编辑待收录内容',
                onPressed: working ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ],
          ),
          Text(candidate.title, style: Theme.of(context).textTheme.titleMedium),
          if (candidate.note?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              candidate.note!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _candidateSummary(candidate),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: working ? null : onIgnore,
                child: const Text('忽略'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: working ? null : onAccept,
                child: Text(working ? '处理中…' : '收录'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidateEditor extends StatefulWidget {
  const _CandidateEditor({required this.candidate});

  final IntakeCandidate candidate;

  @override
  State<_CandidateEditor> createState() => _CandidateEditorState();
}

class _CandidateEditorState extends State<_CandidateEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.candidate.title,
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.candidate.note,
  );
  late final TextEditingController _location = TextEditingController(
    text: widget.candidate.payload['location'] as String? ?? '',
  );
  late final TextEditingController _quantity = TextEditingController(
    text: widget.candidate.payload['quantity'] as String? ?? '',
  );
  late DateTime? _date = _candidateDate(widget.candidate);
  late TimeOfDay? _time = _candidateTime(widget.candidate);
  late String _storage =
      widget.candidate.payload['storage'] as String? ?? 'chilled';

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _location.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('检查后收录', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 18),
            TextField(
              controller: _title,
              autofocus: false,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '备注（可不填）'),
            ),
            if (widget.candidate.target == IntakeTarget.calendar) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _date == null
                            ? '选择日期'
                            : DateFormat('M月d日 E', 'zh_CN').format(_date!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_time?.format(context) ?? '全天'),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.candidate.target == IntakeTarget.homeItem) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                decoration: const InputDecoration(labelText: '当前位置'),
              ),
            ],
            if ({
              IntakeTarget.purchase,
              IntakeTarget.fridge,
              IntakeTarget.homeItem,
            }.contains(widget.candidate.target)) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _quantity,
                decoration: const InputDecoration(labelText: '数量（可不填）'),
              ),
            ],
            if (widget.candidate.target == IntakeTarget.fridge) ...[
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'chilled', label: Text('冷藏')),
                  ButtonSegment(value: 'frozen', label: Text('冷冻')),
                ],
                selected: {_storage},
                onSelectionChanged: (value) =>
                    setState(() => _storage = value.single),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _save,
              child: const Text('保存修改'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final payload = Map<String, Object?>.from(widget.candidate.payload);
    if (_date != null) {
      payload.remove('scheduledAt');
      payload['date'] = _dateKey(_date!);
      if (_time == null) {
        payload.remove('time');
      } else {
        payload['time'] =
            '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
      }
    }
    if (widget.candidate.target == IntakeTarget.homeItem) {
      payload['location'] = _location.text.trim();
    }
    if ({
      IntakeTarget.purchase,
      IntakeTarget.fridge,
      IntakeTarget.homeItem,
    }.contains(widget.candidate.target)) {
      payload['quantity'] = _quantity.text.trim();
    }
    if (widget.candidate.target == IntakeTarget.fridge) {
      payload['storage'] = _storage;
    }
    Navigator.pop(
      context,
      widget.candidate.copyWith(
        title: title,
        note: _note.text.trim(),
        payload: payload,
      ),
    );
  }
}

class _SyncIssue extends StatelessWidget {
  const _SyncIssue({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        minTileHeight: 58,
        leading: Icon(
          Icons.cloud_off_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        title: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('重试')),
      ),
    );
  }
}

String _targetLabel(IntakeTarget target) => switch (target) {
  IntakeTarget.calendar => '日历',
  IntakeTarget.document => '文档',
  IntakeTarget.purchase => '待采购',
  IntakeTarget.fridge => '冰箱',
  IntakeTarget.homeItem => '物品位置',
};

IconData _targetIcon(IntakeTarget target) => switch (target) {
  IntakeTarget.calendar => Icons.calendar_month_outlined,
  IntakeTarget.document => Icons.description_outlined,
  IntakeTarget.purchase => Icons.shopping_basket_outlined,
  IntakeTarget.fridge => Icons.kitchen_outlined,
  IntakeTarget.homeItem => Icons.location_on_outlined,
};

String _candidateSummary(IntakeCandidate candidate) {
  switch (candidate.target) {
    case IntakeTarget.calendar:
      final date = _candidateDate(candidate);
      final time = _candidateTime(candidate);
      if (date == null) return '需要补充日期';
      return '${DateFormat('M月d日 E', 'zh_CN').format(date)} · ${time == null ? '全天' : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'}';
    case IntakeTarget.document:
      return '将保存到未分类文档';
    case IntakeTarget.purchase:
      return _value(candidate, 'quantity') ?? '数量未填写';
    case IntakeTarget.fridge:
      final storage = _value(candidate, 'storage');
      final quantity = _value(candidate, 'quantity');
      return [
        storage == 'frozen' || storage == '冷冻' ? '冷冻' : '冷藏',
        quantity,
      ].whereType<String>().join(' · ');
    case IntakeTarget.homeItem:
      return _value(candidate, 'location') ?? '需要补充位置';
  }
}

DateTime? _candidateDate(IntakeCandidate candidate) {
  final scheduled = candidate.payload['scheduledAt'];
  if (scheduled is String) return DateTime.tryParse(scheduled)?.toLocal();
  final date = candidate.payload['date'];
  return date is String ? DateTime.tryParse(date) : null;
}

TimeOfDay? _candidateTime(IntakeCandidate candidate) {
  final scheduled = candidate.payload['scheduledAt'];
  if (scheduled is String) {
    final date = DateTime.tryParse(scheduled)?.toLocal();
    if (date != null) return TimeOfDay(hour: date.hour, minute: date.minute);
  }
  final time = candidate.payload['time'];
  if (time is! String) return null;
  final parts = time.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String? _value(IntakeCandidate candidate, String key) {
  final value = candidate.payload[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
