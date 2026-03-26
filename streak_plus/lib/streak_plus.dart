/// streak_plus — Backend-agnostic, offline-first streak tracking engine.
///
/// ## Quick start
///
/// ```dart
/// import 'package:streak_plus/streak_plus.dart';
///
/// final streak = StreakPlus(storage: MemoryStorage());
/// await streak.init();
///
/// await streak.logEvent(DateTime.now());
/// print(streak.currentStreak); // 1
/// ```
///
/// ## With sync
///
/// ```dart
/// final streak = StreakPlus(
///   storage: MemoryStorage(),
///   sync: MyFirebaseAdapter(),
/// );
/// await streak.init();
/// await streak.syncWithRemote();
/// ```
library;
// Config
export 'src/config/streak_config.dart';

// Models
export 'src/models/streak_model.dart';
export 'src/models/streak_event.dart';

// Storage
export 'src/storage/streak_storage.dart';
export 'src/storage/memory_storage.dart';

// Sync
export 'src/sync/streak_sync_adapter.dart';
export 'src/sync/sync_manager.dart';

// Core
export 'src/core/streak_calculator.dart';
export 'src/core/streak_engine.dart';

import 'src/config/streak_config.dart';
import 'src/core/streak_engine.dart';
import 'src/models/streak_model.dart';
import 'src/storage/streak_storage.dart';
import 'src/sync/streak_sync_adapter.dart';
import 'src/sync/sync_manager.dart';

/// Top-level façade that composes [StreakEngine], [StreakStorage], and an
/// optional [StreakSyncAdapter] into a single easy-to-use object.
///
/// This is the primary entry point for consumers of the package.
class StreakPlus {
  final StreakStorage storage;
  final StreakSyncAdapter? sync;
  final StreakConfig config;

  late final StreakEngine _engine;

  StreakPlus({
    required this.storage,
    this.sync,
    this.config = StreakConfig.daily,
  }) {
    _engine = StreakEngine(
      storage: storage,
      config: config,
      syncManager: sync != null
          ? SyncManager(storage: storage, adapter: sync!)
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initialise the engine (loads persisted state + optional remote pull).
  ///
  /// **Must be awaited before calling any other method.**
  Future<void> init() => _engine.init();

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------

  /// Record an activity on [date]. Idempotent — same date logged twice is fine.
  Future<void> logEvent(DateTime date) => _engine.logEvent(date);

  /// Protect a day from breaking the streak (e.g. vacation, illness).
  Future<void> addFreezeDay(DateTime date) => _engine.addFreezeDay(date);

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The current running streak count.
  int get currentStreak => _engine.currentStreak;

  /// The all-time highest streak reached.
  int get longestStreak => _engine.longestStreak;

  /// Whether the streak is still active (logged today or yesterday).
  bool get isActive => _engine.isActive;

  /// The most recent activity date, or `null` if nothing logged yet.
  DateTime? get lastActivityDate => _engine.lastActivityDate;

  /// Full model snapshot (useful for serialisation / debugging).
  StreakModel get snapshot => _engine.snapshot;

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Push local state to remote. No-op when no [sync] adapter is provided.
  Future<void> pushToRemote() => _engine.pushToRemote();

  /// Bidirectional sync: pull → merge → push. No-op without a sync adapter.
  Future<void> syncWithRemote() => _engine.syncWithRemote();
}
