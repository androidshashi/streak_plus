// ============================================================
// Example 01 — Daily streak (the basics)
//
// Covers:
//   • StreakPlus setup with MemoryStorage vs SharedPreferencesStorage
//   • await streak.init()
//   • streak.logEvent(date)       — record activity
//   • streak.addFreezeDay(date)   — protect a gap from breaking the streak
//   • streak.currentStreak        — running count
//   • streak.longestStreak        — all-time best
//   • streak.isActive             — logged today or yesterday?
//   • streak.lastActivityDate     — most recent log
// ============================================================

import 'package:flutter/material.dart';
import 'package:streak_plus/streak_plus.dart';

import '../storage/shared_preferences_storage.dart';


class DailyStreakExample extends StatefulWidget {
  const DailyStreakExample({super.key});

  @override
  State<DailyStreakExample> createState() => _DailyStreakExampleState();
}

class _DailyStreakExampleState extends State<DailyStreakExample> {
  late StreakPlus _streak;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    // -----------------------------------------------------------------
    // 1. Pick a storage backend.
    //
    //    MemoryStorage()  — no persistence, resets on app restart.
    //                       Great for tests or guest sessions.
    //
    //    SharedPreferencesStorage() — survives restarts.
    //                       See lib/storage/shared_preferences_storage.dart
    //                       for how to implement your own backend.
    // -----------------------------------------------------------------
    _streak = StreakPlus(storage: SharedPreferencesStorage());

    // -----------------------------------------------------------------
    // 2. Always await init() before reading or writing any state.
    //    It loads the persisted model from storage.
    // -----------------------------------------------------------------
    await _streak.init();

    setState(() => _ready = true);
  }

  // -----------------------------------------------------------------
  // Log an activity on a specific date.
  // Calling logEvent() with the same date twice is safe — idempotent.
  // -----------------------------------------------------------------
  Future<void> _logToday() async {
    await _streak.logEvent(DateTime.now());
    setState(() {});
  }

  // -----------------------------------------------------------------
  // Simulate a multi-day streak by logging the past 5 days.
  // Useful for seeing currentStreak > 1 immediately.
  // -----------------------------------------------------------------
  Future<void> _simulateFiveDays() async {
    final today = DateTime.now();
    for (int i = 4; i >= 0; i--) {
      await _streak.logEvent(today.subtract(Duration(days: i)));
    }
    setState(() {});
  }

  // -----------------------------------------------------------------
  // Freeze yesterday.
  //
  // A freeze day bridges a single missing day so the streak doesn't
  // break. Useful for planned rest days, vacations, or illness.
  //
  // Rule: a gap of exactly 2 days is allowed when the middle day is
  // a freeze day. Larger gaps always reset the streak.
  // -----------------------------------------------------------------
  Future<void> _freezeYesterday() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await _streak.addFreezeDay(yesterday);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('01 · Daily streak')),
      body: _ready ? _buildBody() : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // -----------------------------------------------------------------
        // Reading state — all getters are synchronous after init().
        // -----------------------------------------------------------------
        _StateTable(rows: [
          ('streak.currentStreak',   '${_streak.currentStreak}'),
          ('streak.longestStreak',   '${_streak.longestStreak}'),
          ('streak.isActive',        '${_streak.isActive}'),
          ('streak.lastActivityDate',
              _streak.lastActivityDate != null
                  ? _fmtDate(_streak.lastActivityDate!)
                  : 'null'),
        ]),

        const SizedBox(height: 28),
        _SectionLabel('Actions'),

        _ActionButton(
          code: "streak.logEvent(DateTime.now())",
          label: 'Log today',
          onTap: _logToday,
        ),
        _ActionButton(
          code: "streak.logEvent(today - n days)  ×5",
          label: 'Simulate 5-day streak',
          onTap: _simulateFiveDays,
        ),
        _ActionButton(
          code: "streak.addFreezeDay(yesterday)",
          label: 'Freeze yesterday',
          onTap: _freezeYesterday,
        ),

        const SizedBox(height: 28),
        _SectionLabel('Snapshot (raw model)'),
        _SnapshotView(model: _streak.snapshot),
      ],
    );
  }

  String _fmtDate(DateTime d) => '${d.year}-${_p(d.month)}-${_p(d.day)}';
  String _p(int n) => n.toString().padLeft(2, '0');
}

// ── Shared display widgets used across all examples ─────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      );
}

/// Renders API method name + current value as a two-column table.
class _StateTable extends StatelessWidget {
  const _StateTable({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2)},
          children: [
            TableRow(
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300))),
              children: [
                _cell('Property', bold: true),
                _cell('Value', bold: true),
              ],
            ),
            for (final (prop, val) in rows)
              TableRow(children: [
                _cell(prop, mono: true),
                _cell(val,
                    color: Theme.of(context).colorScheme.primary, bold: true),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text,
      {bool bold = false, bool mono = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontFamily: mono ? 'monospace' : null,
            color: color,
          ),
        ),
      );
}

/// Button that shows the API call it invokes.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.code,
    required this.label,
    required this.onTap,
  });

  final String code;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(code,
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _SnapshotView extends StatelessWidget {
  const _SnapshotView({required this.model});
  final StreakModel model;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'activityDates (${model.activityDates.length}): '
          '${model.activityDates.map(_d).join(', ')}\n'
          'freezeDates   (${model.freezeDates.length}): '
          '${model.freezeDates.map(_d).join(', ')}',
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
    );
  }

  String _d(DateTime d) => '${d.month}/${d.day}';
}
