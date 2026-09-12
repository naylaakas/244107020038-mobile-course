import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/todo_provider.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(todoStatsProvider);
    // final todos = ref.watch(todoListProvider);

    // final total = todos.length;
    // final completed =
    //     todos.where((todo) => todo.done).length;
    // final incomplete =
    //     todos.where((todo) => !todo.done).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik'),
      ),
      body: statsAsync.when(
        loading: () {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Memuat statistik...'),
              ],
            ),
          );
        },
      
        error: (error, stack) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 50,
                ),
                const SizedBox(height: 16),
                Text(
                  'Terjadi kesalahan:\n$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(todoStatsProvider.notifier)
                        .refresh();
                  },
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          );
        },
      
        data: (stats) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Total Tugas'),
                trailing: Text(
                  '${stats['total']}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('Tugas Selesai'),
                trailing: Text(
                  '${stats['completed']}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.pending),
                title: const Text('Belum Selesai'),
                trailing: Text(
                  '${stats['incomplete']}',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}