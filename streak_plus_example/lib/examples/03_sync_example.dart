// ============================================================
// Example 03 — Sync adapter
//
// streak_plus ships the abstract StreakSyncAdapter interface.
// Implement it for any backend — Firebase, Supabase, REST, etc.
//
// Interface (two methods):
//   Future<void>        push(StreakModel model)  — upload local state
//   Future<StreakModel?> pull()                  — fetch remote state
//
// Wire it in at construction time:
//   StreakPlus(storage: ..., sync: MyAdapter())
//
// Then call:
//   streak.pushToRemote()   — upload local  → remote
//   streak.syncWithRemote() — pull → merge  → push
//
// Conflict resolution (built into SyncManager):
//   • The model with the higher longestStreak wins.
//   • On a tie, local wins (offline-first).
//   • Activity dates from both sides are always *unioned* so no
//     logged events are lost during a merge.
// ============================================================

import 'package:flutter/material.dart';
import 'package:streak_plus/streak_plus.dart';

import '../storage/shared_preferences_storage.dart';
import '../sync/mock_sync_adapter.dart';

class SyncExample extends StatefulWidget {
  const SyncExample({super.key});

  @override
  State<SyncExample> createState() => _SyncExampleState();
}

class _SyncExampleState extends State<SyncExample> {
  late final MockSyncAdapter _adapter;
  late final StreakPlus _streak;

  bool _ready = false;
  bool _busy = false;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    _adapter = MockSyncAdapter();

    // Pre-seed the mock remote with data from an imaginary second device.
    // This makes the merge behaviour visible on first sync.
    _adapter.seedRemote(StreakModel(
      activityDates: [
        DateTime.utc(2026, 3, 20),
        DateTime.utc(2026, 3, 21),
        DateTime.utc(2026, 3, 22),
      ],
      freezeDates: [],
      currentStreak: 3,
      longestStreak: 3,
      lastActivityDate: DateTime.utc(2026, 3, 22),
    ));

    // -----------------------------------------------------------------
    // Pass the adapter to StreakPlus via the `sync` parameter.
    // That's all that's needed — the rest is handled internally.
    // -----------------------------------------------------------------
    _streak = StreakPlus(
      storage: SharedPreferencesStorage(),
      sync: _adapter, // <-- wire in your StreakSyncAdapter here
    );

    await _streak.init();
    setState(() => _ready = true);
  }

  Future<void> _logToday() async {
    await _streak.logEvent(DateTime.now());
    _appendLog('logEvent(today) → currentStreak: ${_streak.currentStreak}');
    setState(() {});
  }

  // -----------------------------------------------------------------
  // Push: uploads local state to the remote.
  // Use this when you want a one-way "save to cloud".
  // -----------------------------------------------------------------
  Future<void> _push() async {
    setState(() => _busy = true);

    await _streak.pushToRemote();

    final remote = _adapter.remoteSnapshot;
    _appendLog(
      'pushToRemote() → remote now has '
      '${remote?.activityDates.length ?? 0} activity dates',
    );
    setState(() => _busy = false);
  }

  // -----------------------------------------------------------------
  // Sync: pull remote → merge → push merged result back.
  //
  // After this call:
  //   • Local storage holds the merged model.
  //   • Remote holds the same merged model.
  //   • No activity dates are lost — both sides are unioned.
  // -----------------------------------------------------------------
  Future<void> _sync() async {
    setState(() => _busy = true);

    final before = _streak.currentStreak;
    await _streak.syncWithRemote();
    final after = _streak.currentStreak;

    _appendLog(
      'syncWithRemote() → streak $before → $after  '
      '(longest: ${_streak.longestStreak})',
    );
    setState(() => _busy = false);
  }

  void _appendLog(String line) {
    final ts = TimeOfDay.now().format(context);
    setState(() => _log = '[$ts] $line\n$_log');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('03 · Sync adapter')),
      body: _ready
          ? _buildBody()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final remote = _adapter.remoteSnapshot;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Local state ───────────────────────────────────────────────
        const _SectionLabel('Local (this device)'),
        _KVTable(rows: [
          ('streak.currentStreak', '${_streak.currentStreak}'),
          ('streak.longestStreak', '${_streak.longestStreak}'),
          ('streak.isActive',      '${_streak.isActive}'),
          ('activityDates.length',
              '${_streak.snapshot.activityDates.length}'),
        ]),

        const SizedBox(height: 20),

        // ── Remote state ──────────────────────────────────────────────
        const _SectionLabel('Remote (MockSyncAdapter)'),
        _KVTable(rows: [
          ('remote.currentStreak',
              '${remote?.currentStreak ?? '—'}'),
          ('remote.longestStreak',
              '${remote?.longestStreak ?? '—'}'),
          ('remote.activityDates.length',
              '${remote?.activityDates.length ?? '—'}'),
        ]),

        const SizedBox(height: 20),

        // ── Actions ───────────────────────────────────────────────────
        const _SectionLabel('Actions'),
        _CodeButton(
          label: 'Log today',
          code: 'streak.logEvent(DateTime.now())',
          busy: _busy,
          onTap: _logToday,
          filled: false,
        ),
        const SizedBox(height: 8),
        _CodeButton(
          label: 'Push local → remote',
          code: 'streak.pushToRemote()',
          busy: _busy,
          onTap: _push,
          filled: false,
        ),
        const SizedBox(height: 8),
        _CodeButton(
          label: 'Bidirectional sync',
          code: 'streak.syncWithRemote()  ← pull · merge · push →',
          busy: _busy,
          onTap: _sync,
          filled: true,
        ),

        const SizedBox(height: 20),

        // ── Activity log ──────────────────────────────────────────────
        if (_log.isNotEmpty) ...[
          const _SectionLabel('Activity log'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _log,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ── Adapter skeleton ──────────────────────────────────────────
        const _SectionLabel('Implement your own adapter'),
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'class MyBackendAdapter implements StreakSyncAdapter {\n'
              '  @override\n'
              '  Future<void> push(StreakModel model) async {\n'
              '    // serialize: model.toMap()\n'
              '    // upload to your backend\n'
              '  }\n\n'
              '  @override\n'
              '  Future<StreakModel?> pull() async {\n'
              '    // fetch from your backend\n'
              '    // deserialize: StreakModel.fromMap(data)\n'
              '  }\n'
              '}',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
      );
}

class _KVTable extends StatelessWidget {
  const _KVTable({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
          },
          children: [
            for (final (k, v) in rows)
              TableRow(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(k,
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace')),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(v,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.primary)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _CodeButton extends StatelessWidget {
  const _CodeButton({
    required this.label,
    required this.code,
    required this.busy,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final String code;
  final bool busy;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(code,
            style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.grey)),
      ],
    );

    if (filled) {
      return FilledButton(
        onPressed: busy ? null : onTap,
        child: Align(alignment: Alignment.centerLeft, child: child),
      );
    }
    return OutlinedButton(
      onPressed: busy ? null : onTap,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}
