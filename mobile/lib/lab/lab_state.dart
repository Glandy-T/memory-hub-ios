import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lab_models.dart';

class LabState extends ChangeNotifier {
  LabState._(this._preferences, this._data);

  static const storageKey = 'memory-hub-lab-features-v1';
  final SharedPreferences _preferences;
  LabData _data;

  LabData get data => _data;

  static Future<LabState> create() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return LabState._(preferences, const LabData());
    }
    try {
      return LabState._(
        preferences,
        LabData.fromJson(jsonDecode(raw) as Map<String, Object?>),
      );
    } on Object {
      await preferences.setString('$storageKey-damaged', raw);
      return LabState._(preferences, const LabData());
    }
  }

  Future<void> finishOnboarding(Set<String> selectedNeeds) => _commit(
    _data.copyWith(onboardingComplete: true, selectedNeeds: selectedNeeds),
  );

  Future<void> resetOnboarding() =>
      _commit(_data.copyWith(onboardingComplete: false));

  Future<void> addCapture(String text, LabCaptureKind kind) => _commit(
    _data.copyWith(
      captures: [
        ..._data.captures,
        LabCapture(
          id: 'capture-${DateTime.now().microsecondsSinceEpoch}',
          text: text.trim(),
          kind: kind,
          createdAt: DateTime.now(),
        ),
      ],
    ),
  );

  Future<void> removeCapture(String id) => _commit(
    _data.copyWith(
      captures: _data.captures.where((value) => value.id != id).toList(),
    ),
  );

  LabTaskPlan planFor(String taskId) =>
      _data.plans[taskId] ?? LabTaskPlan(taskId: taskId);

  Future<void> savePlan(LabTaskPlan plan) =>
      _commit(_data.copyWith(plans: {..._data.plans, plan.taskId: plan}));

  Future<void> ensureSuggestedSteps(
    String taskId,
    String title,
    int depth,
  ) async {
    final current = planFor(taskId);
    if (current.steps.isNotEmpty) return;
    final suggestions = _suggestSteps(title, depth);
    await savePlan(current.copyWith(steps: suggestions));
  }

  Future<void> startFocus(String taskId) async {
    final plan = planFor(taskId);
    final seconds = plan.focusRemainingSeconds > 0
        ? plan.focusRemainingSeconds
        : plan.durationMinutes * 60;
    await savePlan(
      plan.copyWith(
        focusRemainingSeconds: seconds,
        focusEndsAt: DateTime.now().add(Duration(seconds: seconds)),
        clearPauseNote: true,
      ),
    );
  }

  int remainingSeconds(String taskId, [DateTime? now]) {
    final plan = planFor(taskId);
    if (plan.focusEndsAt == null) return plan.focusRemainingSeconds;
    return plan.focusEndsAt!
        .difference(now ?? DateTime.now())
        .inSeconds
        .clamp(0, 24 * 60 * 60);
  }

  Future<void> pauseFocus(String taskId, String? note) async {
    final plan = planFor(taskId);
    await savePlan(
      plan.copyWith(
        focusRemainingSeconds: remainingSeconds(taskId),
        clearFocusEnd: true,
        pauseNote: note?.trim(),
        clearPauseNote: note == null || note.trim().isEmpty,
      ),
    );
  }

  Future<void> addFocusMinutes(String taskId, int minutes) async {
    final plan = planFor(taskId);
    final remaining = remainingSeconds(taskId) + minutes * 60;
    await savePlan(
      plan.copyWith(
        focusRemainingSeconds: remaining,
        focusEndsAt: plan.focusEndsAt == null
            ? null
            : DateTime.now().add(Duration(seconds: remaining)),
      ),
    );
  }

  Future<void> finishCurrentStep(String taskId) async {
    final plan = planFor(taskId);
    final current = plan.currentStep;
    await savePlan(
      plan.copyWith(
        steps: [
          for (final step in plan.steps)
            if (step.id == current?.id) step.copyWith(done: true) else step,
        ],
        focusRemainingSeconds: 0,
        clearFocusEnd: true,
        clearPauseNote: true,
      ),
    );
  }

  Future<void> _commit(LabData next) async {
    final encoded = jsonEncode(next.toJson());
    final written = await _preferences.setString(storageKey, encoded);
    if (!written) throw StateError('实验版数据没有写入');
    _data = next;
    notifyListeners();
  }

  List<LabStep> _suggestSteps(String title, int depth) {
    final compact = title.trim();
    final base = <String>[
      '打开与“$compact”有关的资料',
      '找到现在最需要处理的一项',
      '完成这一小步',
      '确认还缺少什么',
      '收好结果并设置提醒',
      '补充相关文档或物品位置',
      '检查一次是否可以结束',
      '把下一步留在容易看到的地方',
    ];
    final count = switch (depth) {
      0 => 3,
      2 => 8,
      _ => 5,
    };
    return [
      for (var index = 0; index < count; index++)
        LabStep(
          id: 'step-${DateTime.now().microsecondsSinceEpoch}-$index',
          title: base[index],
          minutes: index == 0 ? 2 : (index % 3 + 1) * 2,
        ),
    ];
  }
}
