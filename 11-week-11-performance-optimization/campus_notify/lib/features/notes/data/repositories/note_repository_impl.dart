import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../models/note_model.dart';

/// Helper pembuka database di layer data
Future<Database> openNotesDb() async {
  final dbPath = await getDatabasesPath();
  return openDatabase(
    join(dbPath, 'notes.db'),
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE notes (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL
        )
      ''');
    },
  );
}

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({required this.openDb});

  final Future<Database> Function() openDb;

  // In-memory cache untuk menerapkan strategi Stale-While-Revalidate
  List<Note>? _cache;

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes({
    bool forceRefresh = false,
  }) async {
    // 1. Tampilkan cache lokal segera jika tersedia (Stale)
    if (!forceRefresh && _cache != null && _cache!.isNotEmpty) {
      _revalidateInMemory();
      return (notes: List<Note>.unmodifiable(_cache!), failure: null);
    }

    try {
      final db = await openDb();
      final rows = await db.query('notes', orderBy: 'updated_at DESC');
      final notes = rows.map((r) => NoteModel.fromMap(r).toEntity()).toList();
      _cache = notes;
      return (notes: notes, failure: null);
    } catch (e) {
      if (_cache != null) {
        return (notes: List<Note>.unmodifiable(_cache!), failure: null);
      }
      return (
        notes: const <Note>[],
        failure: LocalFailure('Gagal membaca catatan: $e'),
      );
    }
  }

  void _revalidateInMemory() {
    openDb().then((db) => db.query('notes', orderBy: 'updated_at DESC')).then((
      rows,
    ) {
      _cache = rows.map((r) => NoteModel.fromMap(r).toEntity()).toList();
    }).catchError((_) {});
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    try {
      final db = await openDb();
      final now = DateTime.now();
      final id = await db.insert(
        'notes',
        NoteModel(
          title: title,
          body: body,
          updatedAt: now,
          dirty: true,
        ).toMap(),
      );
      final newNote = Note(
        id: id,
        title: title,
        body: body,
        updatedAt: now,
        dirty: true,
      );

      // Mutasi cache lokal segera tanpa harus re-query penuh
      if (_cache != null) {
        _cache = [newNote, ..._cache!];
      }

      return (note: newNote, failure: null);
    } catch (e) {
      return (note: null, failure: LocalFailure('Gagal menyimpan catatan: $e'));
    }
  }
}
