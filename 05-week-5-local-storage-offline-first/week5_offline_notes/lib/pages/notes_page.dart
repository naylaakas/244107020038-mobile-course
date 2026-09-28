import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/note_repository.dart';
import '../widgets/note_tile.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final dirtyCountAsync = ref.watch(dirtyCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Offline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            onPressed: () {
              context.push('/posts');
            },
          ),
          dirtyCountAsync.when(
            data: (count) => Badge(
              label: Text('$count'),
              isLabelVisible: count > 0,
              child: IconButton(
                icon: const Icon(Icons.cloud_upload_outlined),
                onPressed: () async {
                  final repo = ref.read(noteRepositoryProvider);
                  final countDirty = await repo.countDirty();

                  if (countDirty > 0) {
                    await repo.markAllSynced();
                    ref.invalidate(notesProvider);
                    ref.invalidate(dirtyCountProvider);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$countDirty catatan berhasil disinkronkan',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(
              child: Text('Belum ada catatan.'),
            );
          }

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];

              return NoteTile(
                note: note,
                onTap: () {
                  context.push('/note/${note.id}');
                },
                onDelete: () async {
                  await ref
                      .read(noteRepositoryProvider)
                      .deleteNote(note.id!);

                  ref.invalidate(notesProvider);
                  ref.invalidate(dirtyCountProvider);
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Text('Terjadi kesalahan: $err'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddNoteDialog(
    BuildContext context,
    WidgetRef ref,
  ) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Catatan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Judul',
              ),
            ),
            TextField(
              controller: bodyController,
              decoration: const InputDecoration(
                labelText: 'Isi Catatan',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isNotEmpty) {
                await ref.read(noteRepositoryProvider).addNote(
                      title: titleController.text.trim(),
                      body: bodyController.text.trim(),
                    );

                ref.invalidate(notesProvider);
                ref.invalidate(dirtyCountProvider);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}