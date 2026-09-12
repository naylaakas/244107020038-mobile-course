import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Todo {
  Todo(this.title, {this.done = false});

  final String title;
  final bool done;

  Todo copyWith({
    String? title,
    bool? done,
  }) =>
      Todo(
        title ?? this.title,
        done: done ?? this.done,
      );
}

class TodoListNotifier extends Notifier<List<Todo>> {
  @override
  List<Todo> build() => const [];

  void add(String title) {
    state = [...state, Todo(title)];
  }

  void toggle(int index) {
    final todos = [...state];
    todos[index] = todos[index].copyWith(
      done: !todos[index].done,
    );
    state = todos;
  }

  void remove(int index) {
    state = [...state]..removeAt(index);
  }
}

final todoListProvider =
    NotifierProvider<TodoListNotifier, List<Todo>>(
  TodoListNotifier.new,
);

// Provider untuk menampilkan hanya tugas yang belum selesai.
final incompleteTodoProvider = Provider<List<Todo>>((ref) {
  final todos = ref.watch(todoListProvider);

  return todos.where((todo) => !todo.done).toList();
});

// AsyncNotifier untuk mengambil dan mengelola data statistik ToDo.
class TodoStatsNotifier
    extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    // Memberikan jeda 2 detik untuk mensimulasikan
    // proses pengambilan data dari server/API.
    await Future.delayed(
      const Duration(seconds: 2),
    );

    // Simulasi error dengan kemungkinan 30%.
    if (Random().nextDouble() < 0.3) {
      throw Exception(
        'Gagal mengambil data statistik',
      );
    }

    // Mengambil daftar ToDo terbaru dari provider.
    final todos = ref.watch(todoListProvider);

    // Menghitung dan mengembalikan statistik ToDo.
    return {
      'total': todos.length,
      'completed': todos.where((todo) => todo.done).length,
      'incomplete': todos.where((todo) => !todo.done).length,
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await Future.delayed(
        const Duration(seconds: 2),
      );

      // Simulasi error dengan kemungkinan 30%.
      if (Random().nextDouble() < 0.3) {
        throw Exception(
          'Gagal mengambil data statistik',
        );
      }

      // Mengambil daftar ToDo terbaru dari provider.
      final todos = ref.read(todoListProvider);

      // Menghitung dan mengembalikan statistik ToDo.
      return {
        'total': todos.length,
        'completed': todos.where((todo) => todo.done).length,
        'incomplete': todos.where((todo) => !todo.done).length,
      };
    });
  }
}

final todoStatsProvider =
    AsyncNotifierProvider<TodoStatsNotifier, Map<String, int>>(
  TodoStatsNotifier.new,
);