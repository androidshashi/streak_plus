import '../models/streak_model.dart';

/// Contract for any persistence layer used by [StreakEngine].
///
/// Implement this interface to plug in shared-preferences, Hive, SQLite,
/// secure storage, or any other backend.
abstract class StreakStorage {
  /// Persist [model] to the underlying store.
  Future<void> save(StreakModel model);

  /// Load the previously saved model, or `null` if nothing has been stored.
  Future<StreakModel?> load();

  /// Wipe all stored streak data (useful for testing / sign-out flows).
  Future<void> clear();
}
