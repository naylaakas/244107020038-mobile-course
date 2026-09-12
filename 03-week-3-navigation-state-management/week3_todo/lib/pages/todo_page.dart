//Full Refactoring

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/todo_provider.dart';
import 'todo_tile.dart';

class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(incompleteTodoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ToDo Riverpod'),
      ),
      body: todos.isEmpty
          ? const Center(
              child: Text('Belum ada tugas'),
            )
          : ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];

                return TodoTile(
                  todo: todo,
                  onToggle: () {
                    final allTodos = ref.read(todoListProvider);
                    final originalIndex = allTodos.indexOf(todo);

                    ref
                        .read(todoListProvider.notifier)
                        .toggle(originalIndex);
                  },
                  onDelete: () {
                    final allTodos = ref.read(todoListProvider);
                    final originalIndex = allTodos.indexOf(todo);

                    ref
                        .read(todoListProvider.notifier)
                        .remove(originalIndex);
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(
    BuildContext context,
    WidgetRef ref,
  ) {
    final controller = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Tugas baru',
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          title: const Text('Tugas baru'),
          content: TextField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref
                      .read(todoListProvider.notifier)
                      .add(controller.text.trim());
                }
    
                Navigator.pop(context);
              },
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }
}