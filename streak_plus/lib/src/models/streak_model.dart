/// Represents the full state of a user's streak at a point in time.
class StreakModel {
  /// Dates on which the user logged activity (stored as UTC date-only strings).
  final List<DateTime> activityDates;

  /// Dates designated as freeze days — they prevent streak resets.
  final List<DateTime> freezeDates;

  /// The current running streak count.
  final int currentStreak;

  /// The highest streak ever reached.
  final int longestStreak;

  /// The last date on which activity was logged (null if never).
  final DateTime? lastActivityDate;

  const StreakModel({
    required this.activityDates,
    required this.freezeDates,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
  });

  /// Empty initial state.
  factory StreakModel.empty() => const StreakModel(
        activityDates: [],
        freezeDates: [],
        currentStreak: 0,
        longestStreak: 0,
        lastActivityDate: null,
      );

  StreakModel copyWith({
    List<DateTime>? activityDates,
    List<DateTime>? freezeDates,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActivityDate,
    bool clearLastActivity = false,
  }) {
    return StreakModel(
      activityDates: activityDates ?? this.activityDates,
      freezeDates: freezeDates ?? this.freezeDates,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: clearLastActivity
          ? null
          : (lastActivityDate ?? this.lastActivityDate),
    );
  }

  /// Serialise to a plain map (e.g. for JSON persistence).
  Map<String, dynamic> toMap() => {
        'activityDates':
            activityDates.map((d) => _dateKey(d)).toList(),
        'freezeDates': freezeDates.map((d) => _dateKey(d)).toList(),
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActivityDate':
            lastActivityDate != null ? _dateKey(lastActivityDate!) : null,
      };

  factory StreakModel.fromMap(Map<String, dynamic> map) {
    DateTime parse(String s) {
      final parts = s.split('-');
      return DateTime.utc(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }

    return StreakModel(
      activityDates: (map['activityDates'] as List<dynamic>)
          .map((e) => parse(e as String))
          .toList(),
      freezeDates: (map['freezeDates'] as List<dynamic>)
          .map((e) => parse(e as String))
          .toList(),
      currentStreak: map['currentStreak'] as int,
      longestStreak: map['longestStreak'] as int,
      lastActivityDate: map['lastActivityDate'] != null
          ? parse(map['lastActivityDate'] as String)
          : null,
    );
  }

  /// Canonical date key: `yyyy-MM-dd` in UTC.
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';
}
