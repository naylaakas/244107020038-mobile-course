# AI Engineering & Verification Log: Integrasi Fitur AI (Chat Assistant)

| Identitas | Detail |
|---|---|
| **NIM** | 244107020038 |
| **Nama** | Nayla Akas Oktavia |
| **Kelas** | TI - 3H |
| **Mata Kuliah** | Pemrograman Mobile |
| **Topik** | Week 10 — Integrasi Fitur AI (Mobile AI Feature Integration) |

---

## 1. Prompt Design untuk Mobile (Jobsheet Bagian 2 & 3)

Perancangan prompt pada aplikasi mobile memerlukan formulasi yang singkat, terarah, dan memiliki batasan tegas guna menghemat token LLM serta menjaga privasi data mahasiswa:

| Komponen | Contoh Implementasi | Tujuan & Fungsi |
|---|---|---|
| **System Prompt** | `"Kamu adalah asisten kampus ramah untuk aplikasi Campus Notify. Jawab dalam Bahasa Indonesia, maksimal 2 kalimat, ringkas dan sopan. Jangan meminta atau membocorkan data pribadi pengguna."` | Menetapkan persona asisten, batasan panjang respon (maksimal 2 kalimat), dan rambu-rambu privasi. |
| **User Prompt** | `"Jadwal kampus hari Senin jam berapa?"` | Pertanyaan spesifik dari pengguna/mahasiswa. |
| **Konteks** | Basis data pengumuman kampus, kalender akademik, dan lokasi fasilitas kampus (Perpustakaan, Gedung Kuliah). | Memberikan informasi yang akurat dan relevan dengan lingkungan kampus. |
| **Batas (Guardrails)** | Dilarang mengirim NIK, nomor telepon, atau data identitas sensitif ke cloud API. | Menjamin kepatuhan terhadap standar keamanan dan privasi data. |

---

## 2. Formula 5 Slot Prompting

Berikut formulasi prompt yang digunakan saat mengembangkan modul integrasi AI:

```text
[Peran]
Bertindaklah sebagai Senior Mobile AI Engineer dan Flutter Specialist.

[Konteks]
Aplikasi Flutter "Campus Notify" membutuhkan integrasi layanan AI Cloud (Google Gemini API) untuk fitur asisten tanya jawab seputar kampus.
Arsitektur aplikasi menggunakan Flutter Riverpod v3 (NotifierProvider), flutter_secure_storage, dan http package.

[Tugas]
1. Buatkan AiService di lib/ai/ai_service.dart yang berkomunikasi dengan Gemini REST API secara secure.
2. Buatkan ChatScreen di lib/features/chat_screen.dart dengan indikator loading, quick suggestions, dan banner privasi.
3. Terapkan sanitasi input otomatis (masking NIK 16-digit, No HP Indonesia, dan Email).
4. Sediakan local cache untuk pertanyaan berulang guna mencegah biaya melonjak.
5. Sediakan mekanisme graceful fallback offline jika API down atau offline.
6. Buatkan unit test dan widget test komprehensif di test/ai_feature_test.dart.

[Batas]
- Kunci API dilarang keras ditulis di kode sumber (hardcoded). Wajib disimpan di FlutterSecureStorage.
- Riverpod state management wajib menggunakan Notifier dan NotifierProvider (Riverpod 3 kompatibel).
- Setiap fungsi/method UI berukuran ringkas (<40 baris).

[Output]
Kode lengkap AiService, ChatScreen, routes wiring, dan berkas automated test.
```

---

## 3. Catatan Prompt Mentah & Output Awal AI

### A. Draf Awal Kode yang Dihasilkan AI
Pada draf awal generator AI, dihasilkan service komunikasi sederhana:

```dart
// Draf Awal dari AI (Belum optimal)
class AiService {
  final _storage = const FlutterSecureStorage();
  final _apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  Future<String> ask(String question) async {
    final apiKey = await _storage.read(key: 'ai_api_key');
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key tidak tersedia. Silakan atur di pengaturan.');
    }

    final response = await http.post(
      Uri.parse('$_apiUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{'parts': [{'text': question}]}]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception('Gagal memanggil AI API: ${response.statusCode}');
    }
  }
}
```

### B. Temuan Masalah & Keterbatasan Draf Awal
1. **Tidak Ada Sanitasi Data Pribadi:** Pertanyaan yang mengandung NIK atau nomor telepon langsung dikirim mentah ke server Google Cloud, berpotensi memicu pelanggaran privasi data mahasiswa.
2. **Ketergantungan Kuat Tanpa Dependency Injection:** `_storage` dan `http.Client` dibuat secara `const` dan privat tanpa parameter konstruktor, sehingga tidak memungkinkan unit testing menggunakan mock/fake client.
3. **Pemborosan Biaya (Tidak Ada Cache):** Setiap pengulangan pertanyaan identik (misal: "jam buka perpustakaan") selalu memicu request HTTP baru yang menguras kuota harian dan biaya API.
4. **Crash Saat Jaringan Terputus (Ketiadaan Fallback):** Jika koneksi internet mati atau kuota API habis, aplikasi langsung melempar unhandled `Exception` yang membingungkan pengguna.
5. **Halusinasi API Riverpod di UI:** Draf awal widget chat mengusulkan `StateProvider<bool>` dan `StateNotifierProvider`, yang memicu error kompilasi pada versi `flutter_riverpod: ^3.4.3`.

---

## 4. Refactoring & Solusi Teknikal

Berdasarkan temuan di atas, dilakukan serangkaian refactoring terukur:

1. **Implementasi `sanitizeInput` Berbasis Regex:**
   ```dart
   static String sanitizeInput(String input) {
     var sanitized = input.replaceAll(RegExp(r'\b\d{16}\b'), '[NIK_DISAMARKAN]');
     sanitized = sanitized.replaceAll(RegExp(r'(\+62|62|08)[0-9]{8,12}\b'), '[NO_HP_DISAMARKAN]');
     sanitized = sanitized.replaceAll(RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'), '[EMAIL_DISAMARKAN]');
     return sanitized;
   }
   ```
2. **Dependency Injection untuk Testability:**
   Konstruktor `AiService` menerima parameter opsional `storage`, `client`, dan `apiUrl`, sehingga pengujian unit dapat menginjeksi `FakeSecureStorage` dan `MockClient`.
3. **In-Memory Caching & Rate Limiter:**
   Menerapkan cache map `_cache` berdasarkan normalized query, serta pembatasan kuota `dailyRequestLimit = 30` untuk mencegah tagihan membengkak.
4. **Graceful Offline Fallback (`getFallbackResponse`):**
   Saat API offline, down (HTTP 500), atau kunci belum disetel, aplikasi secara cerdas mengembalikan jawaban dari basis pengetahuan lokal kampus dengan label `[Mode Offline]`.
5. **Migrasi ke Riverpod 3 `Notifier` dan `NotifierProvider`:**
   Menggunakan `AiLoadingNotifier` dan `ChatMessagesNotifier` yang mengimplementasikan class `Notifier<T>` modern.

---

## 5. Bukti Verifikasi Mesin Hijau

### A. Static Analysis (`flutter analyze`)
```text
Analyzing campus_notify...
No issues found! (ran in 12.1s)
```

### B. Formatting Standard (`dart format`)
```text
Formatted 33 files (0 changed) in 0.28 seconds.
```

### C. Automated Testing Suite (`flutter test`)
```text
00:00 +0: test/ai_feature_test.dart: Sanitasi Data Pribadi: menyamarkan NIK, No HP, dan Email
00:00 +1: test/ai_feature_test.dart: Panggilan Berhasil: membaca API key dan parse respon JSON Gemini
00:00 +2: test/ai_feature_test.dart: Cache Lokal: pertanyaan berulang tidak memicu HTTP request kedua
00:00 +3: test/ai_feature_test.dart: Fallback Offline: kembalikan jawaban lokal saat API key belum diatur
00:00 +4: test/ai_feature_test.dart: Fallback Error 500: beralih ke mode offline saat API cloud gangguan
00:00 +5: test/ai_feature_test.dart: Manajemen Kunci API: simpan, baca, dan hapus API key secara aman
00:00 +6: test/ai_feature_test.dart: Fitur Pendukung: OCR dan Speech-to-Text helper methods
00:00 +7: test/ai_feature_test.dart: ChatScreen Widget Tests Menampilkan UI awal chat dengan pesan sambutan asisten
00:02 +8: test/ai_feature_test.dart: ChatScreen Widget Tests Interaksi kirim pesan dan respon fallback offline
00:03 +9: test/ai_feature_test.dart: ChatScreen Widget Tests Buka dialog konfigurasi API key dan simpan kunci
00:03 +10: test/ai_feature_test.dart: ChatScreen Widget Tests Tombol bersihkan riwayat mengosongkan obrolan chat
...
00:18 +42: All tests passed!
```
Semua 42 pengujian unit dan widget (termasuk modul auth, notes, push notification, dan ai-chat) berhasil lolos 100%.
