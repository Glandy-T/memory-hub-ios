import 'package:flutter_test/flutter_test.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/features/calendar/deadline_screen.dart';
import 'package:memory_hub/models/intake_candidate.dart';
import 'package:memory_hub/models/memory_data.dart';
import 'package:memory_hub/state/memory_controller.dart';

void main() {
  test(
    'date-only countdown uses calendar days and timed countdown gets precise',
    () {
      final now = DateTime(2026, 8, 9, 12);
      final dateOnly = MemoryDeadline(
        id: 'date-only',
        title: '换护照',
        date: DateTime(2026, 8, 10),
        updatedAt: now,
      );
      final timed = MemoryDeadline(
        id: 'timed',
        title: '取消订阅',
        date: DateTime(2026, 8, 10),
        minutesFromMidnight: 13 * 60 + 30,
        updatedAt: now,
      );

      expect(deadlineCountdownLabel(dateOnly, now), '明天');
      expect(deadlineCountdownLabel(timed, now), '还有 26 小时');
      expect(
        deadlineCountdownLabel(dateOnly, DateTime(2026, 8, 12)),
        '已逾期 2 天',
      );
    },
  );

  test(
    'deadline CRUD persists and keeps deleted entries recoverable',
    () async {
      final repository = InMemoryRepository();
      final controller = await MemoryController.create(repository);

      await controller.addDeadline(
        title: '提交材料',
        date: DateTime(2026, 8, 14),
        minutesFromMidnight: 18 * 60,
      );
      final deadline = controller.activeDeadlines.single;
      await controller.setDeadlineStatus(
        deadline.id,
        MemoryDeadlineStatus.deleted,
      );

      final restoredController = await MemoryController.create(repository);
      expect(restoredController.activeDeadlines, isEmpty);
      expect(
        restoredController.data.deadlines.single.status,
        MemoryDeadlineStatus.deleted,
      );
      await restoredController.restoreDeadline(deadline.id);
      expect(restoredController.activeDeadlines.single.title, '提交材料');
    },
  );

  test('deadline intake is idempotent and requires a due date', () async {
    final controller = await MemoryController.create(InMemoryRepository());
    final candidate = IntakeCandidate(
      id: 'deadline-1',
      target: IntakeTarget.deadline,
      title: '续签证件',
      note: '带照片',
      payload: const {'date': '2026-08-21'},
      sourceLabel: 'Codex',
      receivedAt: DateTime(2026, 8, 9),
    );

    await controller.acceptIntakeCandidate(candidate);
    await controller.acceptIntakeCandidate(candidate);
    expect(controller.data.deadlines, hasLength(1));
    expect(controller.data.deadlines.single.minutesFromMidnight, isNull);

    await expectLater(
      controller.acceptIntakeCandidate(
        IntakeCandidate(
          id: 'deadline-missing',
          target: IntakeTarget.deadline,
          title: '待定截止日',
          payload: const {},
          sourceLabel: 'Codex',
          receivedAt: DateTime(2026, 8, 9),
        ),
      ),
      throwsFormatException,
    );
  });

  test('schema 8 data migrates with an empty deadline list', () {
    final raw = MemoryData.initial().toJson()
      ..['schemaVersion'] = 8
      ..remove('deadlines');

    final migrated = MemoryData.fromJson(raw);

    expect(migrated.schemaVersion, 9);
    expect(migrated.deadlines, isEmpty);
  });
}
