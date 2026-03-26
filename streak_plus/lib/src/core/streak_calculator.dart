import '../config/streak_config.dart';

/// Pure, stateless streak calculation logic.
///
/// All methods are deterministic: same inputs always produce the same output.
/// No I/O, no side effects — easy to unit-test in isolation.
class StreakCalculator {
  const StreakCalculator();

  // ---------------------------------------------------------------------------
  // Config-aware entry points
  // ---------------------------------------------------------------------------

  /// Compute the current streak as of [today], respecting [config].
  ///
  /// Returns a count in the period unit defined by [config]:
  /// - daily   → days
  /// - weekly  → weeks
  /// - monthly → months
  /// - yearly  → years
  /// - custom  → N-day windows
  int calculateCurrentStreak({
    required DateTime today,
    required List<DateTime> activityDates,
    required List<DateTime> freezeDates,
    StreakConfig config = StreakConfig.daily,
  }) {
    if (config.type == StreakType.daily) {
      return _dailyCurrentStreak(
        today: today,
        activityDates: activityDates,
        freezeDates: freezeDates,
      );
    }
    return _periodCurrentStreak(
      today: today,
      activityDates: activityDates,
      config: config,
    );
  }

  /// Compute the all-time longest streak, respecting [config].
  int calculateLongestStreak({
    required List<DateTime> activityDates,
    required List<DateTime> freezeDates,
    StreakConfig config = StreakConfig.daily,
  }) {
    if (config.type == StreakType.daily) {
      return _dailyLongestStreak(
        activityDates: activityDates,
        freezeDates: freezeDates,
      );
    }
    return _periodLongestStreak(
      activityDates: activityDates,
      config: config,
    );
  }

  /// Returns `true` when the streak is still alive and extendable as of [today].
  bool isStreakActive({
    required DateTime today,
    required List<DateTime> activityDates,
    required List<DateTime> freezeDates,
    StreakConfig config = StreakConfig.daily,
  }) {
    if (activityDates.isEmpty) return false;
    return calculateCurrentStreak(
          today: today,
          activityDates: activityDates,
          freezeDates: freezeDates,
          config: config,
        ) >
        0;
  }

  // ---------------------------------------------------------------------------
  // Daily implementation (original behaviour, unchanged)
  // ---------------------------------------------------------------------------

  int _dailyCurrentStreak({
    required DateTime today,
    required List<DateTime> activityDates,
    required List<DateTime> freezeDates,
  }) {
    final dates = _uniqueSortedDates(activityDates);
    if (dates.isEmpty) return 0;

    DateTime cursor = _toUtcDate(today);
    int streak = 0;

    for (int i = dates.length - 1; i >= 0; i--) {
      final date = dates[i];
      final gap = cursor.difference(date).inDays;

      if (gap == 0) {
        streak++;
        cursor = date.subtract(const Duration(days: 1));
      } else if (gap == 1) {
        streak++;
        cursor = date.subtract(const Duration(days: 1));
      } else if (gap == 2 &&
          _hasFreeze(cursor.subtract(const Duration(days: 1)), freezeDates)) {
        streak++;
        cursor = date.subtract(const Duration(days: 1));
      } else if (gap > 0) {
        break;
      }
    }

    return streak;
  }

  int _dailyLongestStreak({
    required List<DateTime> activityDates,
    required List<DateTime> freezeDates,
  }) {
    final dates = _uniqueSortedDates(activityDates);
    if (dates.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < dates.length; i++) {
      final gap = dates[i].difference(dates[i - 1]).inDays;

      if (gap == 1) {
        current++;
      } else if (gap == 2 &&
          _hasFreeze(
              dates[i - 1].add(const Duration(days: 1)), freezeDates)) {
        current++;
      } else {
        current = 1;
      }

      if (current > longest) longest = current;
    }

    return longest;
  }

  // ---------------------------------------------------------------------------
  // Period-based implementation (weekly / monthly / yearly / custom)
  // ---------------------------------------------------------------------------

  int _periodCurrentStreak({
    required DateTime today,
    required List<DateTime> activityDates,
    required StreakConfig config,
  }) {
    if (activityDates.isEmpty) return 0;

    final counts = _countByPeriod(activityDates, config);
    final todayPeriod = _periodOf(_toUtcDate(today), config);

    // Start from the current period if it already qualifies, otherwise try the
    // previous one (current period may still be in progress).
    int startPeriod;
    if ((counts[todayPeriod] ?? 0) >= config.requiredCount) {
      startPeriod = todayPeriod;
    } else if ((counts[todayPeriod - 1] ?? 0) >= config.requiredCount) {
      startPeriod = todayPeriod - 1;
    } else {
      return 0;
    }

    int streak = 0;
    int cursor = startPeriod;
    while ((counts[cursor] ?? 0) >= config.requiredCount) {
      streak++;
      cursor--;
    }
    return streak;
  }

  int _periodLongestStreak({
    required List<DateTime> activityDates,
    required StreakConfig config,
  }) {
    if (activityDates.isEmpty) return 0;

    final counts = _countByPeriod(activityDates, config);
    final sortedPeriods = counts.entries
        .where((e) => e.value >= config.requiredCount)
        .map((e) => e.key)
        .toList()
      ..sort();

    if (sortedPeriods.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < sortedPeriods.length; i++) {
      if (sortedPeriods[i] == sortedPeriods[i - 1] + 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }

    return longest;
  }

  /// Count activity days per period bucket.
  Map<int, int> _countByPeriod(
      List<DateTime> activityDates, StreakConfig config) {
    final counts = <int, int>{};
    for (final d in activityDates) {
      final p = _periodOf(_toUtcDate(d), config);
      counts[p] = (counts[p] ?? 0) + 1;
    }
    return counts;
  }

  /// Map a UTC date to an integer period index.
  ///
  /// Two dates in the same calendar week / month / year / window get the same
  /// index. Consecutive periods always differ by exactly 1, so a simple
  /// consecutive-integer check is sufficient for streak counting.
  int _periodOf(DateTime utcDate, StreakConfig config) {
    switch (config.type) {
      case StreakType.weekly:
        // Monday of this ISO week, expressed as days since Unix epoch / 7.
        final monday = utcDate.subtract(Duration(days: utcDate.weekday - 1));
        return monday.millisecondsSinceEpoch ~/
            const Duration(days: 7).inMilliseconds;

      case StreakType.monthly:
        return utcDate.year * 12 + utcDate.month - 1;

      case StreakType.yearly:
        return utcDate.year;

      case StreakType.custom:
        final windowMs =
            Duration(days: config.periodDays!).inMilliseconds;
        return utcDate.millisecondsSinceEpoch ~/ windowMs;

      case StreakType.daily:
        // Unreachable — daily uses its own code path.
        return utcDate.millisecondsSinceEpoch ~/
            const Duration(days: 1).inMilliseconds;
    }
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  bool _hasFreeze(DateTime date, List<DateTime> freezeDates) {
    final target = _toUtcDate(date);
    return freezeDates.any((f) => _toUtcDate(f) == target);
  }

  List<DateTime> _uniqueSortedDates(List<DateTime> dates) {
    final seen = <String>{};
    final unique = <DateTime>[];
    for (final d in dates) {
      final key = _dateKey(d);
      if (seen.add(key)) unique.add(_toUtcDate(d));
    }
    unique.sort();
    return unique;
  }

  DateTime _toUtcDate(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';
}
