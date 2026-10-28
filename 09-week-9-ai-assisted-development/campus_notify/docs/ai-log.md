# AI Engineering & Verification Log: Fitur Search Notes

Dokumen log ini mencatat seluruh rangkaian proses *AI-Assisted Development* untuk penambahan fitur pencarian catatan (*search notes*) pada aplikasi **Campus Notify** (Clean Architecture: Presentation, Domain, Data dengan Flutter Riverpod).

---

## 1. Praktikum 1: Prompt dan Context Engineering

### A. Formula 5 Slot Prompting
Berikut adalah formulasi prompt 5 slot yang dirancang secara spesifik, terukur, dan kontekstual:

```text
[Peran]
Bertindaklah sebagai Senior Flutter Developer dan Clean Architecture Specialist.

[Konteks]
Saya sedang mengembangkan aplikasi Flutter "Campus Notify" dengan arsitektur feature-first (Clean Architecture: presentation -> domain <- data), state management Flutter Riverpod (v3.x), penyimpanan lokal SQLite, dan networking Dio.
Struktur file fitur notes saat ini:
- Domain Entity: lib/features/notes/domain/entities/note.dart (Note: id, title, body, updatedAt, dirty)
- Repository Contract: lib/features/notes/domain/repositories/note_repository.dart
- Use Cases: lib/features/notes/domain/usecases/get_notes.dart, add_notes.dart
- Riverpod Providers: lib/features/notes/presentation/providers/notes_providers.dart
- Presentation UI: lib/features/notes/presentation/pages/notes_page.dart

[Tugas]
Buatkan fitur pencarian catatan berdasarkan judul (`title`) lengkap dengan tampilan state kosong (*empty state* untuk kondisi belum ada catatan dan kondisi kata kunci tidak ditemukan).

[Batas]
1. Jangan mengubah arsitektur presentation -> domain <- data yang sudah ada.
2. Dilarang memanggil database/SQLite atau Dio langsung dari dalam widget.
3. Layer domain harus murni Dart (bebas impor Flutter, Riverpod, Dio, atau SQLite).
4. Setiap method/fungsi widget maksimal 40 baris kode.

[Output]
1. Use case murni `SearchNotes` di layer domain.
2. Notifier & Provider Riverpod untuk mengelola query dan hasil filter catatan.
3. UI `NotesPage` dengan TextField pencarian dan Empty State.
4. Minimal 3 unit & widget test case beserta petunjuk pengujiannya.
```

### B. Analisis Buruk vs Baik
| Tipe Prompt | Contoh Teks Prompt | Analisis Kelemahan / Keunggulan |
|---|---|---|
| **Buruk** | *"Buatkan search notes yang keren dong."* | **Sangat Kabur:** AI tidak mengetahui arsitektur proyek, menaruh query database langsung di dalam `build()` widget, menggunakan regex lambat, tidak menyertakan handling case-insensitive, dan tidak menyediakan automated test. Kode sulit diuji dan melanggar prinsip modularitas. |
| **Baik** | *"Tambah search judul notes. Arsitektur: presentation->domain<-data. Jangan panggil SQLite dari widget. Sertakan empty state + 1 widget test."* | **Jelas & Berbatas:** AI memahami batasan pemisahan layer, menempatkan aturan filter di layer domain/use case, menjaga widget tetap murni sebagai UI, serta menghasilkan kode yang dapat diverifikasi dengan test otomatis. |

### C. Prinsip Context vs Secret
- **Konteks yang Disertakan:** Cuplikan entitas `Note`, kontrak interface `NoteRepository`, struktur hierarki folder fitur `notes`, serta versi dependensi dari `pubspec.yaml` (khususnya `flutter_riverpod: ^3.4.3`).
- **Data Rahasia yang Disaring:** Token FCM, payload JWT auth, credential database, dan API private key disaring atau diganti dengan placeholder seperti `TOKEN_PLACEHOLDER` dan `API_KEY_PLACEHOLDER`.

---

## 2. Praktikum 2: Generate dan Verifikasi Search

### A. Prompt Mentah yang Diberikan ke AI
```text
Peran: senior Flutter dev
Konteks: feature-first (Clean Architecture: presentation->domain<-data), Riverpod, SQLite + Dio
Tugas: buatkan use case filter catatan dan widget search notes dengan empty state
Batas: jangan ubah arsitektur, domain bebas Flutter/SQLite, fungsi maks 40 baris
Output: kode search_notes.dart, provider, UI notes_page.dart, dan unit test
```

### B. Output Awal yang Dihasilkan AI (Raw AI Draft)
```dart
// lib/features/notes/domain/usecases/search_notes.dart
import 'package:flutter/material.dart'; // DRAFT AI: Import Framework di Domain!
import '../entities/note.dart';

class SearchNotes {
  List<Note> filterNotes(List<Note> notes, String query) {
    // DRAFT AI: Menggunakan contains case-sensitive langsung!
    return notes.where((n) => n.title.contains(query)).toList();
  }
}

// lib/features/notes/presentation/providers/notes_providers.dart
final noteSearchQueryProvider = StateProvider<String>((ref) => ''); // DRAFT AI: Menggunakan StateProvider usang di Riverpod 3
```

### C. Pelaksanaan 6 Langkah Verifikasi
1. **Baca Baris demi Baris:** Ditemukan bahwa AI mengimpor `package:flutter/material.dart` di dalam file domain use case, dan menggunakan method `contains(query)` tanpa konversi huruf kecil (*case-sensitive*).
2. **Cek Import Domain:** Terdeteksi pelanggaran arsitektur Clean Architecture: layer domain mengimpor package framework Flutter.
3. **Cek API & Versi Library:** AI menggunakan `StateProvider<String>` yang sudah dihilangkan/usang pada dependensi proyek `flutter_riverpod: ^3.4.3`. Solusi yang benar adalah menggunakan `NotifierProvider` dan class `Notifier<String>`.
4. **Jalankan Static Analysis (`flutter analyze`):** Terdeteksi error kompilasi:
   `Error: Method not found: 'StateProvider'.`
5. **Uji Test Otomatis (1 Sukses & 1 Gagal):**
   - Test sukses: Query string identik cocok.
   - Test gagal (Merah): Query huruf kecil `'belanja'` gagal menemukan judul `'Belanja Bulanan'` dan `'Daftar BELANJA Lab'`.
6. **Uji Manual UI State:**
   - Query kosong: menampilkan seluruh catatan.
   - Query cocok: menampilkan daftar yang difilter.
   - Query tak cocok: menampilkan widget `_NotesEmptyState` dengan pesan *"Tidak ada catatan yang cocok..."*.

### D. Bukti Wajib: Temuan Bug & Halusinasi AI
1. **Halusinasi Import Framework di Layer Domain:**
   - *Bukti Pemeriksaan (Grep):*
     ```bash
     grep -rn "package:flutter" lib/features/notes/domain/
     ```
     Menemukan `import 'package:flutter/material.dart';` pada draf usecase `search_notes.dart`. Ini membuktikan halusinasi AI yang menganggap usecase memerlukan utilitas Flutter.
2. **Bug Fungsional: Case-Sensitivity Flaw:**
   - *Bukti Test Gagal (Red Test):*
     ```dart
     test('filter abaikan huruf besar/kecil', () {
       expect(filterNotes(list, 'belanja'), hasLength(2));
     });
     ```
     Eksekusi test menghasilkan kegagalan: `Expected: 2, Actual: 0`. AI berasumsi bahwa method `contains()` pada Dart String sudah case-insensitive secara otomatis.

---

## 3. Praktikum 3: Debug dan Refactor

### A. Debug Siklus Test Merah (Red-Green-Refactor)
1. **Reproduksi:** Memasukkan kata kunci dengan variasi huruf (`'belanja'`, `'BELANJA'`, atau spasi `'  belanja  '`) pada catatan berjudul `'Belanja Bulanan'` dan `'Daftar BELANJA Lab'`. Hasilnya list kosong.
2. **Isolasi Masalah:** Memisahkan algoritma pencarian dari layer UI/State ke use case murni `SearchNotes.call(List<Note> notes, String query)` di `lib/features/notes/domain/usecases/search_notes.dart`.
3. **Test Merah:** Dibuat pengujian unit di `test/search_filter_test.dart`:
   ```dart
   test('filter abaikan huruf besar/kecil', () {
     final result = searchNotes(sampleNotes, 'belanja');
     expect(result, hasLength(2));
   });
   ```
4. **Perbaikan Kecil (Green):**
   Menerapkan sanitasi query dengan `.trim().toLowerCase()` dan mencocokkan dengan `note.title.toLowerCase().contains(...)`:
   ```dart
   class SearchNotes {
     const SearchNotes();

     List<Note> call(List<Note> notes, String query) {
       final sanitizedQuery = query.trim().toLowerCase();
       if (sanitizedQuery.isEmpty) return notes;
       return notes.where((note) {
         return note.title.toLowerCase().contains(sanitizedQuery);
       }).toList();
     }
   }
   ```
5. **Catatan Akar Masalah:** String comparison bawaan Dart bersifat ordinal/case-sensitive. Tanpa normalisasi lowercase dan penanganan spasi berlebih (*trim*), input user di UI mobile akan sering gagal menemukan data yang sebenarnya ada.

### B. Refactor ke Layer yang Benar
Pemisahan tanggung jawab arsitektural diimplementasikan secara teratur:
```text
Widget (NotesPage UI saja)
  └── Notifier (NoteSearchQueryNotifier: hanya state string query)
        └── Use Case (SearchNotes: aturan filter murni di layer Domain)
              └── Repository (NoteRepositoryImpl / SQLite: data provider)
```

- **Pengecekan Panjang Fungsi:**
  - `NotesPage.build`: 25 baris
  - `_NotesSearchHeader.build`: 27 baris
  - `_NotesListView.build`: 19 baris
  - `_NotesEmptyState.build`: 28 baris
  - `_NotesErrorView.build`: 12 baris
  *(Seluruh fungsi dan class berada di bawah batas 40 baris).*
- **Larangan Panggilan Database:** Tidak ada pemanggilan SQLite, helper database, maupun Dio di dalam file widget `notes_page.dart`.

### C. Verifikasi Akhir
- `flutter analyze` : **No issues found! (ran in 9.6s)**
- `dart format --set-exit-if-changed .` : **Clean (Formatted 29 files, 0 changed)**
- `flutter test` : **All 24 tests passed! (100% Green)**

---

## 4. AI Challenge

### A. Prompt AI Challenge
```text
Review kode search Flutter ini sebagai senior dev.
Konteks: feature-first (presentation->domain<-data), Riverpod, SQLite + Dio.
Fokus: kebenaran, arsitektur, test. Abaikan style.
Beri 3 temuan + level blocker/saran + alasan.
```

### B. Output Review Awal dari Senior Dev AI
1. **Temuan 1 [Blocker]: State Query Mutation Direct vs Notifier Method**
   - *Detail:* AI mencatat bahwa perubahan state pencarian dari event `TextField.onChanged` tidak boleh memutasi state secara ad-hoc, melainkan harus melalui method eksplisit pada Riverpod `Notifier` (`setQuery` dan `clear`) agar mematuhi unidirectional data flow.
2. **Temuan 2 [Saran]: Async Database Search Query via SQLite `LIKE %query%`**
   - *Detail:* AI menyarankan memindahkan filter judul ke database query SQLite (`SELECT * FROM notes WHERE title LIKE ?`) dengan alasan efisiensi memori pada dataset skala jutaan baris.
3. **Temuan 3 [Saran]: Dekomposisi Widget Search & Empty State**
   - *Detail:* AI menyarankan agar TextField dan Empty State dipecah menjadi private widgets terpisah agar widget tree modular, mencegah re-render yang tidak perlu, dan fungsi `build` tetap di bawah 40 baris.

### C. Tabel Usulan AI vs Keputusan Final

| No | Temuan / Usulan AI | Level | Bukti / Verifikasi Teknis | Keputusan | Alasan Teknis & Trade-off |
|---|---|---|---|:---:|---|
| 1 | Penggunaan method Notifier (`setQuery` & `clear`) alih-alih mutasi state langsung | Blocker | Terbukti di Riverpod 3.4 bahwa mutasi `state = val` dari UI tanpa notifier class melanggar kaidah enkapsulasi state | **DITERIMA** | Dibuat class `NoteSearchQueryNotifier extends Notifier<String>` dengan method `setQuery(val)` dan `clear()`. |
| 2 | Mengubah pencarian menjadi query SQLite `LIKE %query%` via repository | Saran | Benchmark in-memory filter vs SQLite I/O query pada data catatan lokal mahasiswa | **DITOLAK** | Data catatan lokal berukuran puluhan hingga ratusan item sudah berada di Riverpod cache (`notesProvider`). Melakukan query SQL asynchronous pada setiap ketukan keyboard (*keystroke*) memicu disk I/O berlebih, disk-lock SQLite, dan lag UI, sedangkan in-memory filtering pada Pure Use Case berjalan sinkron (<1ms), snappy, dan andal secara offline. |
| 3 | Dekomposisi widget menjadi `_NotesSearchHeader`, `_NotesListView`, dan `_NotesEmptyState` | Saran | Pengukuran baris kode `NotesPage.build` dan analisis visual rendering | **DITERIMA** | Memecah komponen UI menjaga `build()` tetap ringkas (<30 baris), mudah dipelihara, dan widget empty state dapat diuji secara independen. |

### D. Keputusan Tiap File
1. `lib/features/notes/domain/usecases/search_notes.dart`: **Terima + Refactor** (Mengadopsi use case murni, menghapus import Flutter, menambahkan sanitasi lowercase dan whitespace trimming).
2. `lib/features/notes/presentation/providers/notes_providers.dart`: **Terima + Refactor** (Mengganti StateProvider usang dengan Riverpod 3 `NotifierProvider<NoteSearchQueryNotifier, String>` dan memoized `filteredNotesProvider`).
3. `lib/features/notes/presentation/pages/notes_page.dart`: **Terima + Refactor** (Memecah komponen ke private widgets terpisah, menghubungkan event onChanged ke notifier, menambahkan tombol clear).
4. `test/search_filter_test.dart`: **Tulis Manual** (Menulis pengujian unit dan widget teruji mencakup case-insensitivity, whitespace, empty state, dan interaksi interaktif widget).

---

## 5. Refactoring, Testing, dan Penanganan Error Umum

### A. Eksekusi Uji Terfokus
```bash
flutter test test/search_filter_test.dart
```
Output:
```text
00:00 +0: Refactoring & Testing: Search Filter Pure Use Case Tests filter abaikan huruf besar/kecil
00:00 +1: Refactoring & Testing: Search Filter Pure Use Case Tests query tak cocok kembalikan kosong
00:00 +2: Refactoring & Testing: Search Filter Pure Use Case Tests query kosong atau spasi mengembalikan seluruh catatan
00:00 +3: Refactoring & Testing: Search Filter Pure Use Case Tests query dengan whitespace di awal dan akhir ditrim dengan benar
00:00 +4: Refactoring & Testing: Widget Tests untuk Empty State & Interaksi 1 widget test untuk empty state saat pencarian tidak cocok
00:02 +5: Refactoring & Testing: Widget Tests untuk Empty State & Interaksi widget test untuk empty state saat belum ada catatan sama sekali
00:02 +6: Refactoring & Testing: Widget Tests untuk Empty State & Interaksi uji manual simulasi 3 query (kosong, cocok, tak cocok) + clear
00:02 +7: All tests passed!
```

### B. Matriks Penanganan Error Umum
1. **Method Tidak Ada (Halusinasi API):**  
   - Terjadi saat AI mengusulkan `StateProvider<String>`. Solusi: cek pubspec.yaml dan rilis pub.dev (`flutter_riverpod: ^3.4.3`) lalu migrasi ke Riverpod 3 `Notifier`.
2. **Import Lintas Layer (Konteks Kurang):**  
   - Terjadi saat AI mengimpor `flutter/material.dart` di domain. Solusi: tegaskan batasan domain murni Dart pada prompt dan lakukan grep audit.
3. **Semua Test Merah (Prompt Terlalu Besar):**  
   - Solusi: batasi lingkup tugas menjadi 1 usecase kecil dengan 1 test case fokus.
4. **Prompt Diulang Terus Tanpa Kemajuan:**  
   - Solusi: tulis langkah reproduksi konkret disertai unit test pembukti bug (test merah).
5. **Tak Bisa Menjelaskan Kode (Terima Mentah):**  
   - Solusi: baca baris demi baris, sederhanakan kode, dan dekomposisi fungsi ke ukuran < 30 baris.
