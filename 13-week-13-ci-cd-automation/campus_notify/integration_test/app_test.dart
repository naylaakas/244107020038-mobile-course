import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:campus_notify/features/notes/domain/entities/note.dart';
import 'package:campus_notify/features/notes/domain/repositories/note_repository.dart';
import 'package:campus_notify/features/notes/presentation/pages/notes_page.dart';
import 'package:campus_notify/features/notes/presentation/providers/notes_providers.dart';
import 'package:campus_notify/core/failures.dart';

// Fake repository untuk integration test
class FakeNoteRepository implements NoteRepository {
  final List<Note> notes;

  FakeNoteRepository({required this.notes});

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    return (notes: notes, failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    final newNote = Note(
      id: notes.length + 1,
      title: title,
      body: body,
      updatedAt: DateTime.now(),
    );
    return (note: newNote, failure: null);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final sampleNotes = [
    Note(
      id: 1,
      title: 'Catatan Kuliah Algoritma',
      body: 'Sorting dan Searching',
      updatedAt: DateTime(2026, 11, 1),
    ),
    Note(
      id: 2,
      title: 'Tugas Pemrograman Mobile',
      body: 'Buat aplikasi Flutter',
      updatedAt: DateTime(2026, 11, 5),
    ),
    Note(
      id: 3,
      title: 'Jadwal UTS',
      body: 'Senin minggu depan',
      updatedAt: DateTime(2026, 11, 10),
    ),
  ];

  testWidgets('alur utama: buka notes → cari → clear', (tester) async {
    // Arrange: jalankan app dengan fake data
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(
            FakeNoteRepository(notes: sampleNotes),
          ),
        ],
        child: const MaterialApp(home: NotesPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Assert: semua catatan tampil
    expect(find.text('Catatan Kuliah Algoritma'), findsOneWidget);
    expect(find.text('Tugas Pemrograman Mobile'), findsOneWidget);
    expect(find.text('Jadwal UTS'), findsOneWidget);

    // Act: ketik query pencarian
    await tester.enterText(
      find.byKey(const Key('notes_search_field')),
      'Algoritma',
    );
    await tester.pumpAndSettle();

    // Assert: hanya catatan yang cocok tampil
    expect(find.text('Catatan Kuliah Algoritma'), findsOneWidget);
    expect(find.text('Tugas Pemrograman Mobile'), findsNothing);
    expect(find.text('Jadwal UTS'), findsNothing);

    // Act: tap tombol clear
    await tester.tap(find.byKey(const Key('notes_search_clear_button')));
    await tester.pumpAndSettle();

    // Assert: semua catatan tampil kembali
    expect(find.text('Catatan Kuliah Algoritma'), findsOneWidget);
    expect(find.text('Tugas Pemrograman Mobile'), findsOneWidget);
    expect(find.text('Jadwal UTS'), findsOneWidget);
  });
}
