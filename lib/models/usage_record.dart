class UsageRecord {
  final int? id;
  final int childId;
  final String date;
  final int usedMinutes;
  final int sessionCount;

  UsageRecord({
    this.id,
    required this.childId,
    required this.date,
    required this.usedMinutes,
    this.sessionCount = 1,
  });

  UsageRecord copyWith({
    int? id,
    int? childId,
    String? date,
    int? usedMinutes,
    int? sessionCount,
  }) {
    return UsageRecord(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      date: date ?? this.date,
      usedMinutes: usedMinutes ?? this.usedMinutes,
      sessionCount: sessionCount ?? this.sessionCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'childId': childId,
      'date': date,
      'usedMinutes': usedMinutes,
      'sessionCount': sessionCount,
    };
  }

  factory UsageRecord.fromMap(Map<String, dynamic> map) {
    return UsageRecord(
      id: map['id'] as int?,
      childId: map['childId'] as int,
      date: map['date'] as String,
      usedMinutes: map['usedMinutes'] as int,
      sessionCount: map['sessionCount'] as int,
    );
  }
}
