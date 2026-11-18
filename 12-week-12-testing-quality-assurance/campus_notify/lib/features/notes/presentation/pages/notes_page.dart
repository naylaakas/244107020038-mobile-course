import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/note.dart';
import '../providers/notes_providers.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Kampus')),
      body: const Column(
        children: [
          _NotesSearchHeader(),
          Expanded(child: _NotesContentSection()),
        ],
      ),
    );
  }
}

class _NotesSearchHeader extends ConsumerWidget {
  const _NotesSearchHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Optimasi Riverpod select: hanya rebuild jika status hasQuery berubah (boolean)
    final hasQuery = ref.watch(
      noteSearchQueryProvider.select((q) => q.trim().isNotEmpty),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        key: const Key('notes_search_field'),
        decoration: InputDecoration(
          hintText: 'Cari judul catatan...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: hasQuery
              ? IconButton(
                  key: const Key('notes_search_clear_button'),
                  icon: const Icon(Icons.clear),
                  // Optimasi Tear-off alih-alih anonymous closure
                  onPressed: ref.read(noteSearchQueryProvider.notifier).clear,
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        // Optimasi Tear-off alih-alih anonymous closure
        onChanged: ref.read(noteSearchQueryProvider.notifier).setQuery,
      ),
    );
  }
}

class _NotesContentSection extends ConsumerWidget {
  const _NotesContentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filteredNotesProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _NotesErrorView(
        error: e.toString(),
        onRetry: () => ref.invalidate(notesProvider),
      ),
      data: (notes) {
        if (notes.isEmpty) {
          final query = ref.watch(noteSearchQueryProvider);
          return _NotesEmptyState(query: query);
        }
        return _NotesListView(notes: notes);
      },
    );
  }
}

class _NotesListView extends StatelessWidget {
  const _NotesListView({required this.notes});
  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    // Optimasi RepaintBoundary: mengisolasi render layer scrolling list
    return RepaintBoundary(
      child: ListView.separated(
        itemCount: notes.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final note = notes[index];
          // Optimasi ekstraksi widget class mandiri dengan key identik
          return _NoteListItem(
            key: ValueKey(note.id),
            note: note,
          );
        },
      ),
    );
  }
}

class _NoteListItem extends StatelessWidget {
  const _NoteListItem({super.key, required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        note.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: note.body.isNotEmpty ? Text(note.body) : null,
      leading: const CircleAvatar(
        child: Icon(Icons.note_outlined, size: 20),
      ),
    );
  }
}

class _NotesEmptyState extends StatelessWidget {
  const _NotesEmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final isSearching = query.trim().isNotEmpty;
    final message = isSearching
        ? 'Tidak ada catatan yang cocok dengan "$query".'
        : 'Belum ada catatan.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.notes_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesErrorView extends StatelessWidget {
  const _NotesErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Error: $error'),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}
