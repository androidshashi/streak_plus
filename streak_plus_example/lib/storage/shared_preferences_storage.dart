// ============================================================
// SharedPreferencesStorage — a concrete StreakStorage implementation.
//
// streak_plus ships only the abstract StreakStorage interface so the
// library has zero storage dependencies. Clients provide their own
// implementation for whatever backend they use.
//
// This file shows the pattern:
//   1. implement StreakStorage
//   2. serialize StreakModel with model.toMap() / StreakModel.fromMap()
//   3. read/write with your backend (here: shared_preferences)
//
// To use a different backend (Hive, SQLite, secure storage, etc.)
// copy this file and swap out the SharedPreferences calls.
// ============================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streak_plus/streak_plus.dart';

class SharedPreferencesStorage implements StreakStorage {
  /// Use a custom [storageKey] when you need multiple independent streaks
  /// in the same app (e.g. one per habit or per user account).
  final String storageKey;

  const SharedPreferencesStorage({this.storageKey = 'streak_plus_data'});

  @override
  Future<void> save(StreakModel model) async {
    final prefs = await SharedPreferences.getInstance();
    // StreakModel.toMap() produces a JSON-safe Map<String, dynamic>.
    await prefs.setString(storageKey, jsonEncode(model.toMap()));
  }

  @override
  Future<StreakModel?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(storageKey);
    if (json == null) return null;
    // StreakModel.fromMap() restores the full model including all dates.
    return StreakModel.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
