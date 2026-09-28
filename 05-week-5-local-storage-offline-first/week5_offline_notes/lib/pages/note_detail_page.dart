import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/note.dart';
import '../data/repositories/note_repository.dart';

final noteDetailProvider =
    FutureProvider.family<Note?, int>((ref, id) async {
  return ref
      .read(noteRepositoryProvider)
      .fetchNoteById(id);
});

class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({
    super.key,
    required this.id,
  });

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(noteDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Catatan'),
      ),
      body: noteAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Terjadi kesalahan: $error'),
        ),
        data: (note) {
          if (note == null) {
            return const Center(
              child: Text('Catatan tidak ditemukan.'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall,
                ),

                const SizedBox(height: 16),

                Text(
                  note.body.isEmpty
                      ? 'Tidak ada isi catatan.'
                      : note.body,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge,
                ),

                const SizedBox(height: 24),

                if (note.dirty)
                  const Chip(
                    avatar: Icon(
                      Icons.sync_problem,
                      size: 18,
                    ),
                    label: Text('Belum tersinkron'),
                  ),

                const SizedBox(height: 12),

                Text(
                  'Diperbarui: ${note.updatedAt}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}