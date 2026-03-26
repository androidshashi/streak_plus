import '../config/streak_config.dart';
import '../models/streak_model.dart';
import '../models/streak_event.dart';
import '../storage/streak_storage.dart';
import '../sync/sync_manager.dart';
import 'streak_calculator.dart';

/// The central coordinator of the streak_plus package.
///
/// [StreakEngine] owns the current [StreakModel] and delegates:
/// - Calculation to [StreakCalculator] (pure logic, no I/O)
/// - Persistence to [StreakStorage] (pluggable)
/// - Remote sync to [SyncManager] (optional)
///
/// Call [init] once before using any other method.
class StreakEngine {
  final StreakStorage storage;
  final SyncManager? syncManager;
  final StreakConfig config;
  final StreakCalculator _calculator;

  StreakModel _model = StreakModel.empty();
  bool _initialised = false;

  StreakEngine({
    required this.storage,
    this.syncManager,
    this.config = StreakConfig.daily,
    StreakCalculator? calculator,
  }) : _calculator = calculator ?? const StreakCalculator();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Load persisted state (and optionally pull from remote).
  ///
  /// Must be awaited before calling any other method.
  Future<void> init() async {
    final stored = await storage.load();
    _model = stored ?? StreakModel.empty();

    // Optionally hydrate from remote on startup.
    if (syncManager != null) {
      final synced = await syncManager!.pullFromRemote();
      if (synced != null) {
        _model = synced;
        await storage.save(_model);
      }
    }

    _initialised = true;
  }

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------

  /// Record an activity event on [date].
  ///
  /// Duplicate dates are silently ignored (idempotent).
  Future<void> logEvent(DateTime date) async {
    _assertInit();
    final event = StreakEvent.activity(date);
    await _applyEvent(event);
  }

  /// Mark [date] as a freeze day (prevents streak reset for that gap).
  Future<void> addFreezeDay(DateTime date) async {
    _assertInit();
    final event = StreakEvent.freeze(date);
    await _applyEvent(event);
  }

  // ---------------------------------------------------------------------------
  // State accessors
  // ---------------------------------------------------------------------------

  int get currentStreak {
    _assertInit();
    return _model.currentStreak;
  }

  int get longestStreak {
    _assertInit();
    return _model.longestStreak;
  }

  DateTime? get lastActivityDate {
    _assertInit();
    return _model.lastActivityDate;
  }

  /// True when the streak is still continuable (logged today or yesterday).
  bool get isActive {
    _assertInit();
    return _calculator.isStreakActive(
      today: DateTime.now(),
      activityDates: _model.activityDates,
      freezeDates: _model.freezeDates,
      config: config,
    );
  }

  /// Expose a read-only snapshot of the full model.
  StreakModel get snapshot {
    _assertInit();
    return _model;
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Push local state to the remote backend.
  Future<void> pushToRemote() async {
    _assertInit();
    await syncManager?.pushToRemote();
  }

  /// Pull remote state, merge, and persist locally.
  Future<void> syncWithRemote() async {
    _assertInit();
    if (syncManager == null) return;
    final merged = await syncManager!.sync();
    if (merged != null) {
      _model = merged;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _applyEvent(StreakEvent event) async {
    final utcDate = event.date; // already normalised in StreakEvent

    if (event.type == StreakEventType.activity) {
      // Idempotency: skip if date already recorded.
      if (_model.activityDates.any((d) => _sameDay(d, utcDate))) return;

      final updated = List<DateTime>.from(_model.activityDates)..add(utcDate);
      updated.sort();

      final newCurrent = _calculator.calculateCurrentStreak(
        today: utcDate,
        activityDates: updated,
        freezeDates: _model.freezeDates,
        config: config,
      );

      final newLongest = _calculator.calculateLongestStreak(
        activityDates: updated,
        freezeDates: _model.freezeDates,
        config: config,
      );

      _model = _model.copyWith(
        activityDates: updated,
        currentStreak: newCurrent,
        longestStreak: newLongest > _model.longestStreak
            ? newLongest
            : _model.longestStreak,
        lastActivityDate: utcDate,
      );
    } else if (event.type == StreakEventType.freeze) {
      if (_model.freezeDates.any((d) => _sameDay(d, utcDate))) return;

      final updated = List<DateTime>.from(_model.freezeDates)..add(utcDate);
      updated.sort();

      // Recalculate streak — freeze may bridge a gap.
      final newCurrent = _calculator.calculateCurrentStreak(
        today: DateTime.now(),
        activityDates: _model.activityDates,
        freezeDates: updated,
        config: config,
      );

      _model = _model.copyWith(
        freezeDates: updated,
        currentStreak: newCurrent,
      );
    }

    await storage.save(_model);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _assertInit() {
    if (!_initialised) {
      throw StateError(
        'StreakEngine.init() must be called and awaited before use.',
      );
    }
  }
}
