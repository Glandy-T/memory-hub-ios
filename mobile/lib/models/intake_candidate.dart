enum IntakeTarget { calendar, deadline, document, purchase, fridge, homeItem }

class IntakeCandidate {
  const IntakeCandidate({
    required this.id,
    required this.target,
    required this.title,
    required this.payload,
    required this.sourceLabel,
    required this.receivedAt,
    this.note,
  });

  final String id;
  final IntakeTarget target;
  final String title;
  final String? note;
  final Map<String, Object?> payload;
  final String sourceLabel;
  final DateTime receivedAt;

  IntakeCandidate copyWith({
    String? title,
    String? note,
    Map<String, Object?>? payload,
  }) => IntakeCandidate(
    id: id,
    target: target,
    title: title ?? this.title,
    note: note ?? this.note,
    payload: payload ?? this.payload,
    sourceLabel: sourceLabel,
    receivedAt: receivedAt,
  );

  factory IntakeCandidate.fromJson(Map<String, Object?> json) {
    final source = json['source'];
    final payload = json['payload'];
    if (source is! Map || payload is! Map) {
      throw const FormatException('待收录内容格式不完整');
    }
    final sourceMap = Map<String, Object?>.from(source);
    return IntakeCandidate(
      id: json['id']! as String,
      target: IntakeTarget.values.firstWhere(
        (value) => value.name == json['target'],
        orElse: () => throw const FormatException('待收录类型不受支持'),
      ),
      title: json['title']! as String,
      note: json['note'] as String?,
      payload: Map<String, Object?>.from(payload),
      sourceLabel: sourceMap['label']! as String,
      receivedAt: DateTime.parse(json['receivedAt']! as String),
    );
  }

  Map<String, Object?> reviewJson() => {
    'id': id,
    'target': target.name,
    'title': title,
    'note': note,
    'payload': payload,
  };
}

class IntakeConnection {
  const IntakeConnection({
    required this.baseUrl,
    required this.deviceToken,
    required this.siteBypassToken,
  });

  final String baseUrl;
  final String deviceToken;
  final String siteBypassToken;

  factory IntakeConnection.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('连接文件版本不受支持');
    }
    final baseUrl = (json['baseUrl'] as String? ?? '').trim();
    final uri = Uri.tryParse(baseUrl);
    final deviceToken = (json['deviceToken'] as String? ?? '').trim();
    final siteBypassToken = (json['siteBypassToken'] as String? ?? '').trim();
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('连接地址无效');
    }
    if (deviceToken.length < 24 || siteBypassToken.length < 24) {
      throw const FormatException('连接凭证无效');
    }
    return IntakeConnection(
      baseUrl: uri.origin,
      deviceToken: deviceToken,
      siteBypassToken: siteBypassToken,
    );
  }
}
