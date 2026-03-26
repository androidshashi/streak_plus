import '../models/streak_model.dart';
import '../storage/streak_storage.dart';
import 'streak_sync_adapter.dart';

/// Orchestrates push/pull between local storage and a remote adapter.
///
/// Conflict strategy: keep the model with the higher [StreakModel.longestStreak].
/// Ties are broken by keeping the local model (offline-first principle).
class SyncManager {
  final StreakStorage _storage;
  final StreakSyncAdapter _adapter;

  const SyncManager({
    required StreakStorage storage,
    required StreakSyncAdapter adapter,
  })  : _storage = storage,
        _adapter = adapter;

  // ---------------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------------

  /// Push the local model to the remote. No-op if local is empty.
  Future<void> pushToRemote() async {
    final local = await _storage.load();
    if (local == null) return;
    await _adapter.push(local);
  }

  // ---------------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------------

  /// Pull the remote model and merge it into local storage.
  ///
  /// Returns the winning [StreakModel] after merge (or local if remote is null).
  Future<StreakModel?> pullFromRemote() async {
    final remote = await _adapter.pull();
    if (remote == null) return await _storage.load();

    final local = await _storage.load();
    final merged = _resolve(local, remote);
    await _storage.save(merged);
    return merged;
  }

  // ---------------------------------------------------------------------------
  // Full sync
  // ---------------------------------------------------------------------------

  /// Bidirectional sync: pull → merge → push merged result back.
  Future<StreakModel?> sync() async {
    final merged = await pullFromRemote();
    if (merged != null) await _adapter.push(merged);
    return merged;
  }

  // ---------------------------------------------------------------------------
  // Conflict resolution
  // ---------------------------------------------------------------------------

  /// Choose the model with the higher [longestStreak].
  /// When equal, prefer [local] (offline-first).
  StreakModel _resolve(StreakModel? local, StreakModel remote) {
    if (local == null) return remote;
    if (remote.longestStreak > local.longestStreak) return remote;
    return _mergeActivityDates(local, remote);
  }

  /// After picking a winner, union both activity and freeze date lists so no
  /// logged events are lost in the merge.
  StreakModel _mergeActivityDates(StreakModel winner, StreakModel other) {
    final mergedActivity = {
      ...winner.activityDates,
      ...other.activityDates,
    }.toList()
      ..sort();

    final mergedFreeze = {
      ...winner.freezeDates,
      ...other.freezeDates,
    }.toList()
      ..sort();

    return winner.copyWith(
      activityDates: mergedActivity,
      freezeDates: mergedFreeze,
    );
  }
}
