# AI Review vs Keputusan Final

## 1. AI Prompt
Review PR Flutter ini sebagai senior Flutter dev.
Konteks: feature-first Clean Architecture (presentation -> domain <- data), Riverpod, GoRouter, SQLite + Dio.
Fokus: kebenaran, arsitektur, dan test. Abaikan style.
Berikan 5 temuan teratas + level (blocker/saran) + alasan + usulan potongan kode perbaikan.

## 2. Output Awal AI (Ringkasan 5 Temuan)
1. **[Blocker] State Management & Exception Leak**: Provider melempar `DioException` langsung ke layer Presentation tanpa di-catch.
2. **[Saran] Layer Dependency Rule**: Class pada layer Domain mengimpor file dari layer Data/SQLite.
3. **[Blocker] Error Path / Unhandled Null**: Fungsi `validateTitle` tidak menangani nilai `null` pada parameter input.
4. **[Saran] Unused Import & Code Style**: Ada import yang tidak dipakai dan spasi kurang rapi pada widget form.
5. **[Saran] Lack of Unit Test**: Belum ada unit test untuk skenario kegagalan saat memasukkan judul kosong.

## 3. Tabel Verifikasi & Keputusan Final

| No | Temuan AI | Level | Bukti / Verifikasi | Status | Alasan & Keputusan Final |
|---|---|---|---|---|---|
| 1 | Exception Leak (DioException) | Blocker | Terbukti lewat `flutter test` yang crash saat error HTTP | **Diterima** | Diterapkan perbaikan try-catch mapping ke Failure domain. |
| 2 | Impor SQLite di Domain | Saran | Diperiksa via `grep` import, tidak ditemukan import SQLite di domain | **Ditolak** | Halusinasi AI; layer domain sudah murni tanpa dependensi luar. |
| 3 | Unhandled Null pada `validateTitle` | Blocker | Terbukti saat dipanggil dengan parameter null menghasilkan `NoSuchMethodError` | **Diterima** | Ditambahkan periksa null sebelum diproses. |
| 4 | Formatting & Unused Import | Saran | Dijalankan `flutter analyze` & `dart format` | **Ditolak** | Hal seperti formatting diabaikan karena sudah ditangani otomatis oleh CI. |
| 5 | Kurangnya Unit Test Skenario Gagal | Saran | Diuji via `flutter test` | **Diterima** | Ditambahkan file unit test baru di layer test. |

## 4. Bukti Eksekusi (Test / Analyze)
- `flutter analyze` : Clean (No issues found)
- `flutter test` : Passed (All tests green)