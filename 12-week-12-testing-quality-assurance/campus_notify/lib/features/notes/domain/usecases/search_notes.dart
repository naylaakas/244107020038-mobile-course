import '../entities/note.dart';

/// Pure domain use case untuk memfilter daftar [Note] berdasarkan query judul.
/// Bebas dari ketergantungan Flutter, Riverpod, Dio, maupun SQLite.
class SearchNotes {
  const SearchNotes();

  /// Menyaring [notes] berdasarkan [query].
  /// Mengabaikan perbedaan huruf besar/kecil (case-insensitive) dan spasi awal/akhir.
  List<Note> call(List<Note> notes, String query) {
    final sanitizedQuery = query.trim().toLowerCase();
    if (sanitizedQuery.isEmpty) {
      return notes;
    }

    return notes.where((note) {
      return note.title.toLowerCase().contains(sanitizedQuery);
    }).toList();
  }
}
