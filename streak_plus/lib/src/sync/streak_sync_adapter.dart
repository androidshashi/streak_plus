import '../models/streak_model.dart';

/// Contract for any remote sync backend.
///
/// Implement this to integrate Firebase, Supabase, a REST API, or any
/// other service.  The [SyncManager] calls push/pull and handles merging.
abstract class StreakSyncAdapter {
  /// Upload [model] to the remote store.
  Future<void> push(StreakModel model);

  /// Fetch the latest model from the remote store.
  /// Returns `null` when the remote has no data for this user.
  Future<StreakModel?> pull();
}
