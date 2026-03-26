import '../models/streak_model.dart';
import 'streak_storage.dart';

/// A non-persistent, in-memory [StreakStorage] implementation.
///
/// Useful for:
/// - Unit tests (no I/O needed)
/// - Guest / unauthenticated sessions
/// - Default fallback when no storage is configured
class MemoryStorage implements StreakStorage {
  StreakModel? _stored;

  @override
  Future<void> save(StreakModel model) async => _stored = model;

  @override
  Future<StreakModel?> load() async => _stored;

  @override
  Future<void> clear() async => _stored = null;
}
