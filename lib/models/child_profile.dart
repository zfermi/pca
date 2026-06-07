class ChildProfile {
  final int? id;
  final String name;
  final int avatarColor;
  final int dailyLimitMinutes;
  final bool mondayAllowed;
  final bool tuesdayAllowed;
  final bool wednesdayAllowed;
  final bool thursdayAllowed;
  final bool fridayAllowed;
  final bool saturdayAllowed;
  final bool sundayAllowed;
  final int allowedStartHour;
  final int allowedStartMinute;
  final int allowedEndHour;
  final int allowedEndMinute;
  final bool isActive;

  ChildProfile({
    this.id,
    required this.name,
    required this.avatarColor,
    this.dailyLimitMinutes = 120,
    this.mondayAllowed = true,
    this.tuesdayAllowed = true,
    this.wednesdayAllowed = true,
    this.thursdayAllowed = true,
    this.fridayAllowed = true,
    this.saturdayAllowed = true,
    this.sundayAllowed = true,
    this.allowedStartHour = 8,
    this.allowedStartMinute = 0,
    this.allowedEndHour = 20,
    this.allowedEndMinute = 0,
    this.isActive = true,
  });

  ChildProfile copyWith({
    int? id,
    String? name,
    int? avatarColor,
    int? dailyLimitMinutes,
    bool? mondayAllowed,
    bool? tuesdayAllowed,
    bool? wednesdayAllowed,
    bool? thursdayAllowed,
    bool? fridayAllowed,
    bool? saturdayAllowed,
    bool? sundayAllowed,
    int? allowedStartHour,
    int? allowedStartMinute,
    int? allowedEndHour,
    int? allowedEndMinute,
    bool? isActive,
  }) {
    return ChildProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarColor: avatarColor ?? this.avatarColor,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      mondayAllowed: mondayAllowed ?? this.mondayAllowed,
      tuesdayAllowed: tuesdayAllowed ?? this.tuesdayAllowed,
      wednesdayAllowed: wednesdayAllowed ?? this.wednesdayAllowed,
      thursdayAllowed: thursdayAllowed ?? this.thursdayAllowed,
      fridayAllowed: fridayAllowed ?? this.fridayAllowed,
      saturdayAllowed: saturdayAllowed ?? this.saturdayAllowed,
      sundayAllowed: sundayAllowed ?? this.sundayAllowed,
      allowedStartHour: allowedStartHour ?? this.allowedStartHour,
      allowedStartMinute: allowedStartMinute ?? this.allowedStartMinute,
      allowedEndHour: allowedEndHour ?? this.allowedEndHour,
      allowedEndMinute: allowedEndMinute ?? this.allowedEndMinute,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'avatarColor': avatarColor,
      'dailyLimitMinutes': dailyLimitMinutes,
      'mondayAllowed': mondayAllowed ? 1 : 0,
      'tuesdayAllowed': tuesdayAllowed ? 1 : 0,
      'wednesdayAllowed': wednesdayAllowed ? 1 : 0,
      'thursdayAllowed': thursdayAllowed ? 1 : 0,
      'fridayAllowed': fridayAllowed ? 1 : 0,
      'saturdayAllowed': saturdayAllowed ? 1 : 0,
      'sundayAllowed': sundayAllowed ? 1 : 0,
      'allowedStartHour': allowedStartHour,
      'allowedStartMinute': allowedStartMinute,
      'allowedEndHour': allowedEndHour,
      'allowedEndMinute': allowedEndMinute,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory ChildProfile.fromMap(Map<String, dynamic> map) {
    return ChildProfile(
      id: map['id'] as int?,
      name: map['name'] as String,
      avatarColor: map['avatarColor'] as int,
      dailyLimitMinutes: map['dailyLimitMinutes'] as int,
      mondayAllowed: map['mondayAllowed'] == 1,
      tuesdayAllowed: map['tuesdayAllowed'] == 1,
      wednesdayAllowed: map['wednesdayAllowed'] == 1,
      thursdayAllowed: map['thursdayAllowed'] == 1,
      fridayAllowed: map['fridayAllowed'] == 1,
      saturdayAllowed: map['saturdayAllowed'] == 1,
      sundayAllowed: map['sundayAllowed'] == 1,
      allowedStartHour: map['allowedStartHour'] as int,
      allowedStartMinute: map['allowedStartMinute'] as int,
      allowedEndHour: map['allowedEndHour'] as int,
      allowedEndMinute: map['allowedEndMinute'] as int,
      isActive: map['isActive'] == 1,
    );
  }

  bool isDayAllowed(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return mondayAllowed;
      case DateTime.tuesday:
        return tuesdayAllowed;
      case DateTime.wednesday:
        return wednesdayAllowed;
      case DateTime.thursday:
        return thursdayAllowed;
      case DateTime.friday:
        return fridayAllowed;
      case DateTime.saturday:
        return saturdayAllowed;
      case DateTime.sunday:
        return sundayAllowed;
      default:
        return false;
    }
  }

  bool get isTodayAllowed => isDayAllowed(DateTime.now().weekday);

  bool get isWithinAllowedHours {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = allowedStartHour * 60 + allowedStartMinute;
    final endMinutes = allowedEndHour * 60 + allowedEndMinute;
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  int get minutesUntilEndOfAllowedTime {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final endMinutes = allowedEndHour * 60 + allowedEndMinute;
    return (endMinutes - nowMinutes).clamp(0, 1440);
  }

  String get allowedHoursString {
    final start = '${allowedStartHour.toString().padLeft(2, '0')}:${allowedStartMinute.toString().padLeft(2, '0')}';
    final end = '${allowedEndHour.toString().padLeft(2, '0')}:${allowedEndMinute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  String get allowedDaysString {
    final days = <String>[];
    if (mondayAllowed) days.add('Mon');
    if (tuesdayAllowed) days.add('Tue');
    if (wednesdayAllowed) days.add('Wed');
    if (thursdayAllowed) days.add('Thu');
    if (fridayAllowed) days.add('Fri');
    if (saturdayAllowed) days.add('Sat');
    if (sundayAllowed) days.add('Sun');
    return days.join(' ');
  }
}
