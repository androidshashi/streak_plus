/// The unit in which the streak is measured.
enum StreakType {
  /// One activity per calendar day.
  daily,

  /// A minimum number of activity days per calendar week (Mon–Sun).
  weekly,

  /// A minimum number of activity days per calendar month.
  monthly,

  /// A minimum number of activity days per calendar year.
  yearly,

  /// A minimum number of activity days within a rolling window of N days.
  custom,
}

/// Defines the frequency goal that determines whether a streak period is met.
///
/// Pass a [StreakConfig] to [StreakPlus] to change how streaks are calculated:
///
/// ```dart
/// // Classic: log every day
/// StreakPlus(storage: ..., config: StreakConfig.daily)
///
/// // 3 days a week
/// StreakPlus(storage: ..., config: StreakConfig.weekly(requiredDays: 3))
///
/// // 20 days a month
/// StreakPlus(storage: ..., config: StreakConfig.monthly(requiredDays: 20))
///
/// // At least 2 days every 5 days (custom rolling window)
/// StreakPlus(storage: ..., config: StreakConfig.custom(requiredDays: 2, everyDays: 5))
/// ```
///
/// The streak count is expressed in the period unit:
/// - [StreakType.daily]   → streak in days
/// - [StreakType.weekly]  → streak in weeks
/// - [StreakType.monthly] → streak in months
/// - [StreakType.yearly]  → streak in years
/// - [StreakType.custom]  → streak in N-day windows
class StreakConfig {
  /// How streak periods are defined.
  final StreakType type;

  /// How many activity days are required within each period to count it.
  final int requiredCount;

  /// Only used for [StreakType.custom]: the size of the rolling window in days.
  final int? periodDays;

  const StreakConfig._({
    required this.type,
    required this.requiredCount,
    this.periodDays,
  }) : assert(requiredCount > 0, 'requiredCount must be at least 1');

  /// One activity every calendar day (the default).
  static const StreakConfig daily = StreakConfig._(
    type: StreakType.daily,
    requiredCount: 1,
  );

  /// At least [requiredDays] activity days per calendar week (Mon–Sun).
  const StreakConfig.weekly({int requiredDays = 1})
      : this._(type: StreakType.weekly, requiredCount: requiredDays);

  /// At least [requiredDays] activity days per calendar month.
  const StreakConfig.monthly({int requiredDays = 1})
      : this._(type: StreakType.monthly, requiredCount: requiredDays);

  /// At least [requiredDays] activity days per calendar year.
  const StreakConfig.yearly({int requiredDays = 1})
      : this._(type: StreakType.yearly, requiredCount: requiredDays);

  /// At least [requiredDays] activity days within every [everyDays]-day window.
  ///
  /// Windows are fixed, non-overlapping buckets counted backwards from the
  /// Unix epoch, so two devices will always agree on period boundaries.
  const StreakConfig.custom({required int requiredDays, required int everyDays})
      : this._(
          type: StreakType.custom,
          requiredCount: requiredDays,
          periodDays: everyDays,
        );

  @override
  String toString() {
    switch (type) {
      case StreakType.daily:
        return 'daily';
      case StreakType.weekly:
        return '$requiredCount day(s)/week';
      case StreakType.monthly:
        return '$requiredCount day(s)/month';
      case StreakType.yearly:
        return '$requiredCount day(s)/year';
      case StreakType.custom:
        return '$requiredCount day(s) every ${periodDays}d';
    }
  }
}
