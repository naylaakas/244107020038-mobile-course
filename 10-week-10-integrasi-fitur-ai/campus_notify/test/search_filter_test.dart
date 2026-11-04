import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_notify/features/notes/domain/entities/note.dart';
import 'package:campus_notify/features/notes/domain/usecases/search_notes.dart';
import 'package:campus_notify/features/notes/presentation/pages/notes_page.dart';
import 'package:campus_notify/features/notes/presentation/providers/notes_providers.dart';

void main() {
  group('Refactoring & Testing: Search Filter Pure Use Case Tests', () {
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

  group(
    'Refactoring & Testing: Widget Tests untuk Empty State & Interaksi',
    () {
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

      testWidgets(
        '1 widget test untuk empty state saat pencarian tidak cocok',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                notesProvider.overrideWith((ref) => Future.value(mockNotes)),
              ],
              child: const MaterialApp(home: NotesPage()),
            ),
          );
          await tester.pumpAndSettle();

          // Masukkan query tidak cocok
          final searchField = find.byKey(const Key('notes_search_field'));
          await tester.enterText(searchField, 'zzz-tak-ada');
          await tester.pumpAndSettle();

          // Verifikasi empty state tampil
          expect(
            find.text('Tidak ada catatan yang cocok dengan "zzz-tak-ada".'),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.search_off), findsOneWidget);
        },
      );

      testWidgets(
        'widget test untuk empty state saat belum ada catatan sama sekali',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                notesProvider.overrideWith((ref) => Future.value(<Note>[])),
              ],
              child: const MaterialApp(home: NotesPage()),
            ),
          );
          await tester.pumpAndSettle();

          // Verifikasi pesan empty state ketika list kosong tanpa query
          expect(find.text('Belum ada catatan.'), findsOneWidget);
          expect(find.byIcon(Icons.notes_outlined), findsOneWidget);
        },
      );

      testWidgets(
        'uji manual simulasi 3 query (kosong, cocok, tak cocok) + clear',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                notesProvider.overrideWith((ref) => Future.value(mockNotes)),
              ],
              child: const MaterialApp(home: NotesPage()),
            ),
          );
          await tester.pumpAndSettle();

          final searchField = find.byKey(const Key('notes_search_field'));

          // 1. Query kosong: tampil semua catatan (2 item)
          expect(find.text('Belanja Bulanan'), findsOneWidget);
          expect(find.text('Kuliah Pemrograman Mobile'), findsOneWidget);

          // 2. Query cocok ('belanja'): tampil 1 item
          await tester.enterText(searchField, 'belanja');
          await tester.pumpAndSettle();
          expect(find.text('Belanja Bulanan'), findsOneWidget);
          expect(find.text('Kuliah Pemrograman Mobile'), findsNothing);

          // 3. Query tak cocok ('tidak-ada'): tampil empty state
          await tester.enterText(searchField, 'tidak-ada');
          await tester.pumpAndSettle();
          expect(
            find.text('Tidak ada catatan yang cocok dengan "tidak-ada".'),
            findsOneWidget,
          );

          // 4. Reset lewat tombol clear
          final clearButton = find.byKey(
            const Key('notes_search_clear_button'),
          );
          await tester.tap(clearButton);
          await tester.pumpAndSettle();
          expect(find.text('Belanja Bulanan'), findsOneWidget);
          expect(find.text('Kuliah Pemrograman Mobile'), findsOneWidget);
        },
      );
    },
  );
}
