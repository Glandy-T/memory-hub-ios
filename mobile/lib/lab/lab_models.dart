enum LabCaptureKind { task, deadline, document, purchase, itemLocation }

class LabCaptureSchedule {
  const LabCaptureSchedule({required this.date, this.minutesFromMidnight});

  final DateTime date;
  final int? minutesFromMidnight;
}

LabCaptureSchedule inferLabCaptureSchedule(String text, DateTime now) {
  var dayOffset = 0;
  if (text.contains('大后天')) {
    dayOffset = 3;
  } else if (text.contains('后天')) {
    dayOffset = 2;
  } else if (text.contains('明天')) {
    dayOffset = 1;
  }

  int? hour;
  var minute = 0;
  final colon = RegExp(r'(\d{1,2})\s*[:：]\s*(\d{1,2})').firstMatch(text);
  final oClock = RegExp(r'(\d{1,2})\s*点(半)?').firstMatch(text);
  if (colon != null) {
    hour = int.tryParse(colon.group(1)!);
    minute = int.tryParse(colon.group(2)!) ?? 0;
  } else if (oClock != null) {
    hour = int.tryParse(oClock.group(1)!);
    minute = oClock.group(2) == null ? 0 : 30;
  } else if (text.contains('凌晨')) {
    hour = 1;
  } else if (text.contains('早上') || text.contains('上午')) {
    hour = 9;
  } else if (text.contains('中午')) {
    hour = 12;
  } else if (text.contains('下午')) {
    hour = 14;
  } else if (text.contains('傍晚')) {
    hour = 18;
  } else if (text.contains('晚上')) {
    hour = 19;
  }

  if (hour != null &&
      hour < 12 &&
      (text.contains('下午') || text.contains('傍晚') || text.contains('晚上'))) {
    hour += 12;
  }
  final validTime = hour != null && hour >= 0 && hour <= 23 && minute <= 59;
  final date = DateTime(now.year, now.month, now.day).add(
    Duration(days: dayOffset),
  );
  return LabCaptureSchedule(
    date: date,
    minutesFromMidnight: validTime ? hour! * 60 + minute : null,
  );
}

class LabCapture {
  const LabCapture({
    required this.id,
    required this.text,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String text;
  final LabCaptureKind kind;
  final DateTime createdAt;

  String get label => switch (kind) {
    LabCaptureKind.task => '安排',
    LabCaptureKind.deadline => '截止日',
    LabCaptureKind.document => '文档',
    LabCaptureKind.purchase => '购买',
    LabCaptureKind.itemLocation => '物品位置',
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LabCapture.fromJson(Map<String, Object?> json) => LabCapture(
    id: json['id']! as String,
    text: json['text']! as String,
    kind: LabCaptureKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => LabCaptureKind.task,
    ),
    createdAt: DateTime.parse(json['createdAt']! as String),
  );
}

class LabStep {
  const LabStep({
    required this.id,
    required this.title,
    this.minutes = 3,
    this.done = false,
  });

  final String id;
  final String title;
  final int minutes;
  final bool done;

  LabStep copyWith({String? title, int? minutes, bool? done}) => LabStep(
    id: id,
    title: title ?? this.title,
    minutes: minutes ?? this.minutes,
    done: done ?? this.done,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'minutes': minutes,
    'done': done,
  };

  factory LabStep.fromJson(Map<String, Object?> json) => LabStep(
    id: json['id']! as String,
    title: json['title']! as String,
    minutes: json['minutes'] as int? ?? 3,
    done: json['done'] as bool? ?? false,
  );
}

class LabTaskPlan {
  const LabTaskPlan({
    required this.taskId,
    this.durationMinutes = 25,
    this.steps = const [],
    this.linkedDocumentId,
    this.linkedItemId,
    this.linkedDeadlineId,
    this.focusRemainingSeconds = 0,
    this.focusEndsAt,
    this.pauseNote,
  });

  final String taskId;
  final int durationMinutes;
  final List<LabStep> steps;
  final String? linkedDocumentId;
  final String? linkedItemId;
  final String? linkedDeadlineId;
  final int focusRemainingSeconds;
  final DateTime? focusEndsAt;
  final String? pauseNote;

  LabStep? get currentStep {
    for (final step in steps) {
      if (!step.done) return step;
    }
    return null;
  }

  LabTaskPlan copyWith({
    int? durationMinutes,
    List<LabStep>? steps,
    String? linkedDocumentId,
    bool clearDocument = false,
    String? linkedItemId,
    bool clearItem = false,
    String? linkedDeadlineId,
    bool clearDeadline = false,
    int? focusRemainingSeconds,
    DateTime? focusEndsAt,
    bool clearFocusEnd = false,
    String? pauseNote,
    bool clearPauseNote = false,
  }) => LabTaskPlan(
    taskId: taskId,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    steps: steps ?? this.steps,
    linkedDocumentId: clearDocument
        ? null
        : linkedDocumentId ?? this.linkedDocumentId,
    linkedItemId: clearItem ? null : linkedItemId ?? this.linkedItemId,
    linkedDeadlineId: clearDeadline
        ? null
        : linkedDeadlineId ?? this.linkedDeadlineId,
    focusRemainingSeconds: focusRemainingSeconds ?? this.focusRemainingSeconds,
    focusEndsAt: clearFocusEnd ? null : focusEndsAt ?? this.focusEndsAt,
    pauseNote: clearPauseNote ? null : pauseNote ?? this.pauseNote,
  );

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'durationMinutes': durationMinutes,
    'steps': steps.map((value) => value.toJson()).toList(),
    'linkedDocumentId': linkedDocumentId,
    'linkedItemId': linkedItemId,
    'linkedDeadlineId': linkedDeadlineId,
    'focusRemainingSeconds': focusRemainingSeconds,
    'focusEndsAt': focusEndsAt?.toIso8601String(),
    'pauseNote': pauseNote,
  };

  factory LabTaskPlan.fromJson(Map<String, Object?> json) => LabTaskPlan(
    taskId: json['taskId']! as String,
    durationMinutes: json['durationMinutes'] as int? ?? 25,
    steps: (json['steps'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(LabStep.fromJson)
        .toList(),
    linkedDocumentId: json['linkedDocumentId'] as String?,
    linkedItemId: json['linkedItemId'] as String?,
    linkedDeadlineId: json['linkedDeadlineId'] as String?,
    focusRemainingSeconds: json['focusRemainingSeconds'] as int? ?? 0,
    focusEndsAt: json['focusEndsAt'] == null
        ? null
        : DateTime.parse(json['focusEndsAt']! as String),
    pauseNote: json['pauseNote'] as String?,
  );
}

class LabData {
  const LabData({
    this.onboardingComplete = false,
    this.selectedNeeds = const {'remember', 'start', 'items'},
    this.captures = const [],
    this.plans = const {},
  });

  final bool onboardingComplete;
  final Set<String> selectedNeeds;
  final List<LabCapture> captures;
  final Map<String, LabTaskPlan> plans;

  LabData copyWith({
    bool? onboardingComplete,
    Set<String>? selectedNeeds,
    List<LabCapture>? captures,
    Map<String, LabTaskPlan>? plans,
  }) => LabData(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    selectedNeeds: selectedNeeds ?? this.selectedNeeds,
    captures: captures ?? this.captures,
    plans: plans ?? this.plans,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'onboardingComplete': onboardingComplete,
    'selectedNeeds': selectedNeeds.toList(),
    'captures': captures.map((value) => value.toJson()).toList(),
    'plans': {
      for (final entry in plans.entries) entry.key: entry.value.toJson(),
    },
  };

  factory LabData.fromJson(Map<String, Object?> json) {
    final rawPlans = json['plans'] as Map<String, Object?>? ?? const {};
    return LabData(
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      selectedNeeds: (json['selectedNeeds'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toSet(),
      captures: (json['captures'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(LabCapture.fromJson)
          .toList(),
      plans: {
        for (final entry in rawPlans.entries)
          if (entry.value is Map<String, Object?>)
            entry.key: LabTaskPlan.fromJson(
              entry.value! as Map<String, Object?>,
            ),
      },
    );
  }
}
