import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memory_hub/lab/lab_models.dart';
import 'package:memory_hub/lab/lab_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lab capture and plans persist in an isolated key', () async {
    final state = await LabState.create();
    await state.addCapture('8月20日前提交材料', LabCaptureKind.deadline);
    await state.ensureSuggestedSteps('task-1', '整理体检资料', 1);

    final restored = await LabState.create();
    expect(restored.data.captures.single.kind, LabCaptureKind.deadline);
    expect(restored.planFor('task-1').steps, hasLength(5));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(LabState.storageKey), isTrue);
    expect(preferences.containsKey('memory-hub-mobile-database-v1'), isFalse);
  });

  test('focus pause preserves time and return note', () async {
    final state = await LabState.create();
    await state.savePlan(
      const LabTaskPlan(
        taskId: 'task-1',
        durationMinutes: 1,
        steps: [LabStep(id: 'step-1', title: '打开文件夹')],
      ),
    );
    await state.startFocus('task-1');
    expect(state.remainingSeconds('task-1'), inInclusiveRange(58, 60));

    await state.pauseFocus('task-1', '正在找去年的报告');
    final paused = state.planFor('task-1');
    expect(paused.focusEndsAt, isNull);
    expect(paused.pauseNote, '正在找去年的报告');
    expect(paused.focusRemainingSeconds, greaterThan(0));
  });

  test('quick capture infers relative date and optional time', () {
    final now = DateTime(2026, 8, 10, 17, 30);

    final afternoon = inferLabCaptureSchedule('明天下午给诊所打电话', now);
    expect(afternoon.date, DateTime(2026, 8, 11));
    expect(afternoon.minutesFromMidnight, 14 * 60);

    final exact = inferLabCaptureSchedule('后天晚上8点半吃药', now);
    expect(exact.date, DateTime(2026, 8, 12));
    expect(exact.minutesFromMidnight, 20 * 60 + 30);

    final allDay = inferLabCaptureSchedule('明天整理资料', now);
    expect(allDay.minutesFromMidnight, isNull);
  });
}
