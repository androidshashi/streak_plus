// ============================================================
// Example 02 — Streak types  (StreakConfig)
//
// By default StreakPlus counts consecutive *days*.
// Pass a StreakConfig to measure streaks in any other unit:
//
//   StreakConfig.daily                              — 1 day / day  (default)
//   StreakConfig.weekly(requiredDays: 3)            — 3 days / week
//   StreakConfig.monthly(requiredDays: 20)          — 20 days / month
//   StreakConfig.yearly(requiredDays: 100)          — 100 days / year
//   StreakConfig.custom(requiredDays:2, everyDays:5)— 2 days / 5-day window
//
// The streak *count* is expressed in the matching unit:
//   daily → days · weekly → weeks · monthly → months · etc.
//
// All four instances below share the same SharedPreferences key, so a
// single logEvent() call is reflected in every card simultaneously.
// ============================================================

import 'package:flutter/material.dart';
import 'package:streak_plus/streak_plus.dart';

import '../storage/shared_preferences_storage.dart';

class StreakTypesExample extends StatefulWidget {
  const StreakTypesExample({super.key});

  @override
  State<StreakTypesExample> createState() => _StreakTypesExampleState();
}

class _StreakTypesExampleState extends State<StreakTypesExample> {
  // -----------------------------------------------------------------
  // Four StreakPlus instances — one per StreakConfig.
  // Each interprets the same stored activity dates differently.
  // -----------------------------------------------------------------
  late final StreakPlus _daily;
  late final StreakPlus _weekly;
  late final StreakPlus _monthly;
  late final StreakPlus _custom;

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    _daily = StreakPlus(
      storage: SharedPreferencesStorage(),
      // StreakConfig.daily is the default — shown here for clarity.
      config: StreakConfig.daily,
    );

    _weekly = StreakPlus(
      storage: SharedPreferencesStorage(),
      // Streak counts qualifying *weeks*.
      // A week qualifies when it has >= 3 activity days (Mon–Sun).
      config: const StreakConfig.weekly(requiredDays: 3),
    );

    _monthly = StreakPlus(
      storage: SharedPreferencesStorage(),
      // Streak counts qualifying *months*.
      // A month qualifies when it has >= 20 activity days.
      config: const StreakConfig.monthly(requiredDays: 20),
    );

    _custom = StreakPlus(
      storage: SharedPreferencesStorage(),
      // Streak counts qualifying *5-day windows*.
      // A window qualifies when it has >= 2 activity days.
      // Windows are fixed, non-overlapping buckets so two devices
      // always agree on the period boundaries.
      config: const StreakConfig.custom(requiredDays: 2, everyDays: 5),
    );

    await Future.wait([
      _daily.init(),
      _weekly.init(),
      _monthly.init(),
      _custom.init(),
    ]);

    setState(() => _ready = true);
  }

  // Log today on all four instances at once.
  Future<void> _logToday() async {
    await Future.wait([
      _daily.logEvent(DateTime.now()),
      _weekly.logEvent(DateTime.now()),
      _monthly.logEvent(DateTime.now()),
      _custom.logEvent(DateTime.now()),
    ]);
    setState(() {});
  }

  // Populate a week's worth of data (5 of 7 days) so weekly / custom
  // configs have enough activity to show a non-zero streak.
  Future<void> _simulateWeek() async {
    final today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      if (i == 3 || i == 6) continue; // skip 2 days to stay realistic
      final day = today.subtract(Duration(days: i));
      await Future.wait([
        _daily.logEvent(day),
        _weekly.logEvent(day),
        _monthly.logEvent(day),
        _custom.logEvent(day),
      ]);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('02 · Streak types')),
      body: _ready
          ? _buildBody()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // -----------------------------------------------------------------
        // Each row: constructor call · current streak · longest · active
        // -----------------------------------------------------------------
        _ConfigRow(
          constructorCall: 'StreakConfig.daily',
          unit: 'days',
          streak: _daily,
        ),
        _ConfigRow(
          constructorCall: 'StreakConfig.weekly(requiredDays: 3)',
          unit: 'weeks',
          streak: _weekly,
        ),
        _ConfigRow(
          constructorCall: 'StreakConfig.monthly(requiredDays: 20)',
          unit: 'months',
          streak: _monthly,
        ),
        _ConfigRow(
          constructorCall:
              'StreakConfig.custom(requiredDays: 2, everyDays: 5)',
          unit: '5d windows',
          streak: _custom,
        ),

        const SizedBox(height: 28),
        const Text('Actions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),

        OutlinedButton(
          onPressed: _logToday,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log today',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('streak.logEvent(DateTime.now())  — all configs',
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _simulateWeek,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Simulate 5 days this week',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('logEvent(today - n)  for n in 0..6  (skip 2)',
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.constructorCall,
    required this.unit,
    required this.streak,
  });

  final String constructorCall;
  final String unit;
  final StreakPlus streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Constructor call the dev would write
            Text(
              constructorCall,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Stat(
                    label: 'current',
                    value: '${streak.currentStreak} $unit'),
                const SizedBox(width: 24),
                _Stat(
                    label: 'longest',
                    value: '${streak.longestStreak} $unit'),
                const SizedBox(width: 24),
                _Stat(
                  label: 'active',
                  value: streak.isActive ? 'yes' : 'no',
                  valueColor:
                      streak.isActive ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: valueColor,
            )),
      ],
    );
  }
}
