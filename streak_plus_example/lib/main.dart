import 'package:flutter/material.dart';

import 'examples/01_daily_streak.dart';
import 'examples/02_streak_types.dart';
import 'examples/03_sync_example.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'streak_plus examples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const ExampleMenu(),
    );
  }
}

/// Top-level menu — tap any item to open that example.
class ExampleMenu extends StatelessWidget {
  const ExampleMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('streak_plus examples')),
      body: ListView(
        children: [
          _ExampleTile(
            number: '01',
            title: 'Daily streak',
            subtitle: 'Init, logEvent, addFreezeDay, read state',
            page: const DailyStreakExample(),
          ),
          _ExampleTile(
            number: '02',
            title: 'Streak types',
            subtitle: 'daily · weekly · monthly · custom windows',
            page: const StreakTypesExample(),
          ),
          _ExampleTile(
            number: '03',
            title: 'Sync adapter',
            subtitle: 'Implement StreakSyncAdapter, push & bidirectional sync',
            page: const SyncExample(),
          ),
        ],
      ),
    );
  }
}

class _ExampleTile extends StatelessWidget {
  const _ExampleTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final String number;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(number)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ),
    );
  }
}
