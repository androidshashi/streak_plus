// ============================================================
// MockSyncAdapter — a concrete StreakSyncAdapter implementation.
//
// streak_plus ships only the abstract StreakSyncAdapter interface.
// Clients implement push() and pull() for their own backend.
//
// This mock stores the model in memory and adds a small delay to
// simulate network latency so the async behaviour is visible in the UI.
//
// Real-world example (Firebase Firestore):
// ============================================================
//
// class FirebaseStreakAdapter implements StreakSyncAdapter {
//   final String userId;
//   FirebaseStreakAdapter(this.userId);
//
//   @override
//   Future<void> push(StreakModel model) =>
//       FirebaseFirestore.instance
//           .collection('streaks')
//           .doc(userId)
//           .set(model.toMap());
//
//   @override
//   Future<StreakModel?> pull() async {
//     final doc = await FirebaseFirestore.instance
//         .collection('streaks')
//         .doc(userId)
//         .get();
//     if (!doc.exists) return null;
//     return StreakModel.fromMap(doc.data()!);
//   }
// }
// ============================================================

import 'package:streak_plus/streak_plus.dart';

class MockSyncAdapter implements StreakSyncAdapter {
  StreakModel? _remote;

  StreakModel? get remoteSnapshot => _remote;

  /// Pre-load the mock remote with data to demonstrate merge behaviour.
  void seedRemote(StreakModel model) => _remote = model;

  @override
  Future<void> push(StreakModel model) async {
    await Future.delayed(const Duration(milliseconds: 300)); // fake latency
    _remote = model;
  }

  @override
  Future<StreakModel?> pull() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _remote;
  }
}
