import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_notify/features/notes/domain/entities/note.dart';
import 'package:campus_notify/features/notes/domain/usecases/search_notes.dart';
import 'package:campus_notify/features/notes/presentation/pages/notes_page.dart';
import 'package:campus_notify/features/notes/presentation/providers/notes_providers.dart';

void main() {
  group('Praktikum 2 & 3: SearchNotes Domain Use Case Tests', () {
    final sampleNotes = [
      Note(
        id: 1,
        title: 'Belanja Bulanan',
        body: 'Beli ATK dan modul kuliah',
        updatedAt: DateTime(2026, 10, 1),
      ),
      Note(
        id: 2,
        title: 'Daftar BELANJA Lab',
        body: 'Kabel LAN, switch, dan connector RJ45',
        updatedAt: DateTime(2026, 10, 2),
      ),
      Note(
        id: 3,
        title: 'Tugas Mobile Week 9',
        body: 'Selesaikan AI-assisted development dan prompt engineering',
        updatedAt: DateTime(2026, 10, 3),
      ),
    ];

    const searchNotes = SearchNotes();

    test('filter abaikan huruf besar/kecil', () {
      final result = searchNotes(sampleNotes, 'belanja');
      expect(result, hasLength(2));
      expect(result.map((n) => n.id), containsAll([1, 2]));
    });

    test('query tak cocok kembalikan kosong', () {
      final result = searchNotes(sampleNotes, 'zzz-tak-ada');
      expect(result, isEmpty);
    });

    test('query kosong atau spasi mengembalikan seluruh catatan', () {
      final resultEmpty = searchNotes(sampleNotes, '');
      expect(resultEmpty, hasLength(3));

      final resultSpaces = searchNotes(sampleNotes, '   ');
      expect(resultSpaces, hasLength(3));
    });

    test('query dengan whitespace di awal dan akhir ditrim dengan benar', () {
      final result = searchNotes(sampleNotes, '  mobile  ');
      expect(result, hasLength(1));
      expect(result.first.title, 'Tugas Mobile Week 9');
    });
  });

  group('Praktikum 3: Riverpod State Wiring & Widget Tests', () {
    final mockNotes = [
      Note(
        id: 1,
        title: 'Belanja Bulanan',
        body: 'Beli ATK',
        updatedAt: DateTime(2026, 10, 1),
      ),
      Note(
        id: 2,
        title: 'Kuliah Pemrograman Mobile',
        body: 'Materi AI Development',
        updatedAt: DateTime(2026, 10, 2),
      ),
    ];

    testWidgets('menampilkan search bar dan hasil filter secara responsif', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesProvider.overrideWith((ref) => Future.value(mockNotes)),
          ],
          child: const MaterialApp(home: NotesPage()),
        ),
      );

      // Selesaikan future loading
      await tester.pumpAndSettle();

      // Pastikan kedua catatan tampil di awal
      expect(find.text('Belanja Bulanan'), findsOneWidget);
      expect(find.text('Kuliah Pemrograman Mobile'), findsOneWidget);

      // Masukkan teks ke search field
      final searchField = find.byKey(const Key('notes_search_field'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'belanja');
      await tester.pumpAndSettle();

      // Hanya 'Belanja Bulanan' yang tampil
      expect(find.text('Belanja Bulanan'), findsOneWidget);
      expect(find.text('Kuliah Pemrograman Mobile'), findsNothing);

      // Cari query yang tidak ada -> empty state
      await tester.enterText(searchField, 'zzz-tidak-ditemukan');
      await tester.pumpAndSettle();

      expect(
        find.text('Tidak ada catatan yang cocok dengan "zzz-tidak-ditemukan".'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.search_off), findsOneWidget);

      // Klik tombol clear
      final clearButton = find.byKey(const Key('notes_search_clear_button'));
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Catatan kembali lengkap
      expect(find.text('Belanja Bulanan'), findsOneWidget);
      expect(find.text('Kuliah Pemrograman Mobile'), findsOneWidget);
    });
  });
}
