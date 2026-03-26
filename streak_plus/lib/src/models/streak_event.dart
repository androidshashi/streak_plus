/// The type of event that can be logged against a streak.
enum StreakEventType {
  /// Normal activity log — advances the streak.
  activity,

  /// Freeze day — prevents streak reset for a missed day.
  freeze,
}

/// An immutable record of a single streak event.
class StreakEvent {
  final StreakEventType type;

  /// UTC date-only (time component is always midnight UTC).
  final DateTime date;

  const StreakEvent({required this.type, required this.date});

  /// Convenience constructors.
  factory StreakEvent.activity(DateTime date) =>
      StreakEvent(type: StreakEventType.activity, date: _toUtcDate(date));

  factory StreakEvent.freeze(DateTime date) =>
      StreakEvent(type: StreakEventType.freeze, date: _toUtcDate(date));

  /// Strips time, normalises to UTC midnight for timezone-safe comparisons.
  static DateTime _toUtcDate(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day);

  @override
  String toString() => 'StreakEvent(${type.name}, $date)';
}
