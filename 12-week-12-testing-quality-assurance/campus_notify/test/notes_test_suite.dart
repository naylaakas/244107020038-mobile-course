import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:campus_notify/features/notes/domain/entities/note.dart';
import 'package:campus_notify/features/notes/domain/usecases/add_notes.dart';
import 'package:campus_notify/features/notes/domain/usecases/search_notes.dart';
import 'package:campus_notify/features/notes/domain/usecases/get_notes.dart';
import 'package:campus_notify/features/notes/domain/repositories/note_repository.dart';
import 'package:campus_notify/features/notes/presentation/pages/notes_page.dart';
import 'package:campus_notify/features/notes/presentation/providers/notes_providers.dart';
import 'package:campus_notify/core/failures.dart';

// ============================================================
// Fake Repository — mengganti API sungguhan dengan data tiruan
// ============================================================

class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository({this.notes = const [], this.error});

  final List<Note> notes;
  final Exception? error;

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    if (error != null) {
      return (
        notes: const <Note>[],
        failure: LocalFailure(error.toString()),
      );
    }
    return (notes: notes, failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    if (title.trim().isEmpty) {
      return (
        note: null,
        failure: const LocalFailure('Judul tidak boleh kosong'),
      );
    }
    final newNote = Note(
      id: notes.length + 1,
      title: title,
      body: body,
      updatedAt: DateTime.now(),
    );
    return (note: newNote, failure: null);
  }
}

// ============================================================
// Data contoh untuk pengujian
// ============================================================

final _sampleNotes = [
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

// ============================================================
// LANGKAH 2: Uji Logika — Unit Test
// ============================================================

void main() {
  group('AddNotes — validasi judul', () {
    final addNotes = AddNotes();

    test('menerima judul yang berisi teks', () {
      expect(addNotes.validateTitle('Belajar Flutter'), isTrue);
    });

    test('menerima judul dengan spasi di awal/akhir', () {
      expect(addNotes.validateTitle('  Catatan Penting  '), isTrue);
    });

    test('menolak judul kosong', () {
      expect(addNotes.validateTitle(''), isFalse);
    });

    test('menolak judul yang hanya spasi', () {
      expect(addNotes.validateTitle('   '), isFalse);
    });
  });

  group('SearchNotes — filter catatan', () {
    const searchNotes = SearchNotes();

    test('mengembalikan semua catatan jika query kosong', () {
      final result = searchNotes.call(_sampleNotes, '');
      expect(result, _sampleNotes);
    });

    test('mengembalikan semua catatan jika query hanya spasi', () {
      final result = searchNotes.call(_sampleNotes, '   ');
      expect(result, _sampleNotes);
    });

    test('memfilter berdasarkan judul, case-insensitive', () {
      final result = searchNotes.call(_sampleNotes, 'algoritma');
      expect(result.length, 1);
      expect(result.first.title, 'Catatan Kuliah Algoritma');
    });

    test('memfilter berdasarkan sebagian judul', () {
      final result = searchNotes.call(_sampleNotes, 'tugas');
      expect(result.length, 1);
      expect(result.first.title, 'Tugas Pemrograman Mobile');
    });

    test('mengembalikan daftar kosong jika tidak cocok', () {
      final result = searchNotes.call(_sampleNotes, 'xyz tidak ada');
      expect(result, isEmpty);
    });
  });

  // ============================================================
  // LANGKAH 3: Uji Dependensi — Fake Repository + GetNotes
  // ============================================================

  group('GetNotes dengan FakeNoteRepository', () {
    test('meneruskan data dari repository', () async {
      final fakeRepo = FakeNoteRepository(notes: _sampleNotes);
      final getNotes = GetNotes(fakeRepo);

      final result = await getNotes.call();

      expect(result.notes, _sampleNotes);
      expect(result.failure, isNull);
    });

    test('meneruskan failure tanpa throw', () async {
      final fakeRepo = FakeNoteRepository(
        error: Exception('koneksi gagal'),
      );
      final getNotes = GetNotes(fakeRepo);

      final result = await getNotes.call();

      expect(result.notes, isEmpty);
      expect(result.failure, isNotNull);
      expect(result.failure!.message, contains('koneksi gagal'));
    });

    test('addNote berhasil mengembalikan note baru', () async {
      final fakeRepo = FakeNoteRepository(notes: _sampleNotes);

      final result = await fakeRepo.addNote(title: 'Catatan Baru');

      expect(result.note, isNotNull);
      expect(result.note!.title, 'Catatan Baru');
      expect(result.failure, isNull);
    });

    test('addNote gagal jika judul kosong', () async {
      final fakeRepo = FakeNoteRepository(notes: _sampleNotes);

      final result = await fakeRepo.addNote(title: '');

      expect(result.note, isNull);
      expect(result.failure, isNotNull);
      expect(result.failure!.message, contains('kosong'));
    });
  });

  // ============================================================
  // LANGKAH 4: Uji UI — Widget Test
  // ============================================================

  group('NotesPage — widget test', () {
    // Helper: bungkus NotesPage dengan ProviderScope + MaterialApp
    Widget buildTestApp({required FakeNoteRepository repository}) {
      return ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: NotesPage()),
      );
    }

    testWidgets('menampilkan search bar', (tester) async {
      await tester.pumpWidget(
        buildTestApp(repository: FakeNoteRepository(notes: _sampleNotes)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notes_search_field')), findsOneWidget);
    });

    testWidgets('menampilkan pesan kosong saat tidak ada data', (tester) async {
      await tester.pumpWidget(
        buildTestApp(repository: FakeNoteRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada catatan.'), findsOneWidget);
    });

    testWidgets('menampilkan daftar catatan', (tester) async {
      await tester.pumpWidget(
        buildTestApp(repository: FakeNoteRepository(notes: _sampleNotes)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Catatan Kuliah Algoritma'), findsOneWidget);
      expect(find.text('Tugas Pemrograman Mobile'), findsOneWidget);
      expect(find.text('Jadwal UTS'), findsOneWidget);
    });

    testWidgets('search memfilter hasil catatan', (tester) async {
      await tester.pumpWidget(
        buildTestApp(repository: FakeNoteRepository(notes: _sampleNotes)),
      );
      await tester.pumpAndSettle();

      // Ketik query pencarian
      await tester.enterText(
        find.byKey(const Key('notes_search_field')),
        'Algoritma',
      );
      await tester.pumpAndSettle();

      expect(find.text('Catatan Kuliah Algoritma'), findsOneWidget);
      expect(find.text('Tugas Pemrograman Mobile'), findsNothing);
      expect(find.text('Jadwal UTS'), findsNothing);
    });

    testWidgets('tombol clear muncul saat ada query', (tester) async {
      await tester.pumpWidget(
        buildTestApp(repository: FakeNoteRepository(notes: _sampleNotes)),
      );
      await tester.pumpAndSettle();

      // Belum ada tombol clear
      expect(
        find.byKey(const Key('notes_search_clear_button')),
        findsNothing,
      );

      // Ketik sesuatu
      await tester.enterText(
        find.byKey(const Key('notes_search_field')),
        'uts',
      );
      await tester.pumpAndSettle();

      // Tombol clear muncul
      expect(
        find.byKey(const Key('notes_search_clear_button')),
        findsOneWidget,
      );
    });

    testWidgets('tombol clear mengembalikan semua catatan', (tester) async {
      await tester.pumpWidget(
        buildTestApp(repository: FakeNoteRepository(notes: _sampleNotes)),
      );
      await tester.pumpAndSettle();

      // Ketik query dulu
      await tester.enterText(
        find.byKey(const Key('notes_search_field')),
        'uts',
      );
      await tester.pumpAndSettle();

      // Hanya 1 hasil
      expect(find.text('Jadwal UTS'), findsOneWidget);
      expect(find.text('Catatan Kuliah Algoritma'), findsNothing);

      // Tap tombol clear
      await tester.tap(find.byKey(const Key('notes_search_clear_button')));
      await tester.pumpAndSettle();

      // Semua catatan tampil kembali
      expect(find.text('Catatan Kuliah Algoritma'), findsOneWidget);
      expect(find.text('Tugas Pemrograman Mobile'), findsOneWidget);
      expect(find.text('Jadwal UTS'), findsOneWidget);
    });
  });
}
