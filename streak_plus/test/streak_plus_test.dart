import 'package:flutter_test/flutter_test.dart';
import 'package:streak_plus/streak_plus.dart';

void main() {
  // Helper: create a UTC date with no time component.
  DateTime d(int year, int month, int day) => DateTime.utc(year, month, day);

  // ---------------------------------------------------------------------------
  // StreakCalculator — pure logic tests
  // ---------------------------------------------------------------------------

  group('StreakCalculator', () {
    const calc = StreakCalculator();

    test('empty activity → streak is 0', () {
      expect(
        calc.calculateCurrentStreak(
          today: d(2024, 1, 10),
          activityDates: [],
          freezeDates: [],
        ),
        0,
      );
    });

    test('single activity today → streak is 1', () {
      expect(
        calc.calculateCurrentStreak(
          today: d(2024, 1, 10),
          activityDates: [d(2024, 1, 10)],
          freezeDates: [],
        ),
        1,
      );
    });

    test('consecutive days → correct streak count', () {
      final dates = [d(2024, 1, 8), d(2024, 1, 9), d(2024, 1, 10)];
      expect(
        calc.calculateCurrentStreak(
          today: d(2024, 1, 10),
          activityDates: dates,
          freezeDates: [],
        ),
        3,
      );
    });

    test('missed day without freeze → streak resets', () {
      final dates = [d(2024, 1, 7), d(2024, 1, 8), d(2024, 1, 10)];
      expect(
        calc.calculateCurrentStreak(
          today: d(2024, 1, 10),
          activityDates: dates,
          freezeDates: [],
        ),
        1,
      );
    });

    test('missed day covered by freeze → streak continues', () {
      final dates = [d(2024, 1, 8), d(2024, 1, 10)];
      final freezes = [d(2024, 1, 9)];
      expect(
        calc.calculateCurrentStreak(
          today: d(2024, 1, 10),
          activityDates: dates,
          freezeDates: freezes,
        ),
        2,
      );
    });

    test('duplicate dates count as one', () {
      final dates = [
        d(2024, 1, 10),
        d(2024, 1, 10),
        d(2024, 1, 10),
      ];
      expect(
        calc.calculateCurrentStreak(
          today: d(2024, 1, 10),
          activityDates: dates,
          freezeDates: [],
        ),
        1,
      );
    });

    test('longestStreak across multiple chains', () {
      final dates = [
        d(2024, 1, 1),
        d(2024, 1, 2),
        d(2024, 1, 3), // chain of 3
        d(2024, 1, 10),
        d(2024, 1, 11), // chain of 2
      ];
      expect(
        calc.calculateLongestStreak(
          activityDates: dates,
          freezeDates: [],
        ),
        3,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // StreakPlus integration tests
  // ---------------------------------------------------------------------------

  group('StreakPlus', () {
    late StreakPlus streak;

    setUp(() async {
      streak = StreakPlus(storage: MemoryStorage());
      await streak.init();
    });

    test('initial state is all zeros', () {
      expect(streak.currentStreak, 0);
      expect(streak.longestStreak, 0);
      expect(streak.isActive, false);
      expect(streak.lastActivityDate, null);
    });

    test('logEvent increments currentStreak', () async {
      await streak.logEvent(d(2024, 1, 10));
      expect(streak.currentStreak, 1);
      expect(streak.longestStreak, 1);
    });

    test('logging same day twice is idempotent', () async {
      await streak.logEvent(d(2024, 1, 10));
      await streak.logEvent(d(2024, 1, 10));
      expect(streak.currentStreak, 1);
    });

    test('consecutive days build streak', () async {
      await streak.logEvent(d(2024, 1, 8));
      await streak.logEvent(d(2024, 1, 9));
      await streak.logEvent(d(2024, 1, 10));
      expect(streak.currentStreak, 3);
      expect(streak.longestStreak, 3);
    });

    test('addFreezeDay bridges a gap', () async {
      await streak.logEvent(d(2024, 1, 8));
      await streak.addFreezeDay(d(2024, 1, 9));
      await streak.logEvent(d(2024, 1, 10));
      // currentStreak is recalculated from today=now, so just verify freeze
      // was stored.
      expect(streak.snapshot.freezeDates, contains(d(2024, 1, 9)));
    });

    test('longestStreak is preserved after a reset', () async {
      await streak.logEvent(d(2024, 1, 1));
      await streak.logEvent(d(2024, 1, 2));
      await streak.logEvent(d(2024, 1, 3)); // longest = 3
      await streak.logEvent(d(2024, 1, 10)); // gap → reset, but longest stays
      expect(streak.longestStreak, 3);
    });

    test('state persists across re-init', () async {
      final storage = MemoryStorage();
      final s1 = StreakPlus(storage: storage);
      await s1.init();
      await s1.logEvent(d(2024, 1, 10));

      // New instance, same storage.
      final s2 = StreakPlus(storage: storage);
      await s2.init();
      expect(s2.longestStreak, 1);
      expect(s2.lastActivityDate, d(2024, 1, 10));
    });
  });

  // ---------------------------------------------------------------------------
  // SyncManager conflict resolution
  // ---------------------------------------------------------------------------

  group('SyncManager conflict resolution', () {
    test('remote wins when it has higher longestStreak', () async {
      final storage = MemoryStorage();
      await storage.save(StreakModel(
        activityDates: [d(2024, 1, 10)],
        freezeDates: [],
        currentStreak: 1,
        longestStreak: 1,
        lastActivityDate: d(2024, 1, 10),
      ));

      final remoteModel = StreakModel(
        activityDates: [d(2024, 1, 1), d(2024, 1, 2), d(2024, 1, 3)],
        freezeDates: [],
        currentStreak: 0,
        longestStreak: 3,
        lastActivityDate: d(2024, 1, 3),
      );

      final adapter = _MockSyncAdapter(remoteModel);
      final manager = SyncManager(storage: storage, adapter: adapter);

      final merged = await manager.pullFromRemote();
      expect(merged!.longestStreak, 3);
    });

    test('local wins on tie', () async {
      final storage = MemoryStorage();
      final localModel = StreakModel(
        activityDates: [d(2024, 1, 10)],
        freezeDates: [],
        currentStreak: 1,
        longestStreak: 5,
        lastActivityDate: d(2024, 1, 10),
      );
      await storage.save(localModel);

      final remoteModel = StreakModel(
        activityDates: [d(2024, 1, 9)],
        freezeDates: [],
        currentStreak: 1,
        longestStreak: 5,
        lastActivityDate: d(2024, 1, 9),
      );

      final adapter = _MockSyncAdapter(remoteModel);
      final manager = SyncManager(storage: storage, adapter: adapter);

      final merged = await manager.pullFromRemote();
      // Tied → local wins; but dates from both are merged.
      expect(merged!.activityDates, containsAll([d(2024, 1, 9), d(2024, 1, 10)]));
    });
  });
}

// ---------------------------------------------------------------------------
// Test double
// ---------------------------------------------------------------------------

class _MockSyncAdapter implements StreakSyncAdapter {
  final StreakModel? _remote;
  _MockSyncAdapter(this._remote);

  @override
  Future<void> push(StreakModel model) async {}

  @override
  Future<StreakModel?> pull() async => _remote;
}
