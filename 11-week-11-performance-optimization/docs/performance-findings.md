# Laporan Optimasi Performa Aplikasi (Campus Notify)

| Metadata | Keterangan |
|---|---|
| **Mata Kuliah** | Pemrograman Mobile |
| **Topik** | Week 11 - Performance Optimization & Profiling |
| **Mahasiswa** | Nayla Akas Oktavia |
| **NIM** | 244107020038 |
| **Kelas** | TI - 3H |

---

## Langkah 1: Baseline Profiling (Sebelum Optimasi)

### 1.1 Persiapan & Eksekusi Profiling
- **Project**: `campus_notify`
- **Lingkungan Uji**: Google Chrome (`localhost:54065`) dalam mode Web Profiling
- **Alat Profiling**: DevTools Performance Panel
- **Skenario Interaksi yang Direkam (Durasi: 28.72 detik)**:
  1. Halaman Beranda (*Home*) terbuka dengan sambutan "Selamat datang".
  2. Navigasi dan interaksi antara menu: **Pengumuman**, **Catatan Kampus**, dan **Asisten AI Kampus**.
  3. Aktivitas interaksi pengguna (*interactions*): klik menu, pergerakan, dan respons rendering.

### 1.2 Data Hasil Pengamatan Profiling Baseline (Berdasarkan Screenshot DevTools)
Berdasarkan data metrik riil pada panel *Performance* di `screenshots/before-profile.png`:

| Metrik DevTools | Nilai Hasil Rekaman | Status / Keterangan |
|---|---|---|
| **Total Waktu Rekaman** | **28,723 ms (28.72 s)** | Durasi keseluruhan skenario pengujian |
| **INP (Interaction to Next Paint)** | **320 ms** | ⚠️ **Buruk (Merah)** — Jauh di atas ambang ideal (< 200 ms) |
| **Scripting (Dart/JS Thread)** | **5,241 ms** | Beban komputasi eksekusi kode paling tinggi |
| **System Overhead** | **745 ms** | Pengelolaan proses sistem browser |
| **Painting** | **101 ms** | Waktu menggambar piksel ke layar |
| **Rendering** | **88 ms** | Rekonsiliasi DOM / layout tree |
| **Long Tasks (Frame Merah > 50 ms)** | Terdeteksi **8 – 12 lonjakan merah** | Terlihat pada track *Main Thread* dengan segitiga merah di bagian atas |

### 1.3 Analisis Grafik Flame Chart
- **Pola Beban Tinggi (Spikes)**: Terjadi lonjakan beban kuning pekat (*Scripting*) pada interval waktu ~5,000 ms, ~14,000 ms, ~20,000 ms, dan ~25,000 ms saat terjadi interaksi navigasi.
- **Kedalaman Call Stack**: Pada track `Main — http://localhost:54065/`, hierarki tumpukan fungsi sangat dalam (*tall stack*) yang menunjukkan fungsi render dan pemanggilan builder dieksekusi secara intensif dan serentak.
- **Tangkapan Layar**:
  ![Baseline Profiling](../screenshots/before-profile.png)

---

## Langkah 2: Identifikasi Masalah Berdasarkan Data DevTools

Dari data baseline profil di atas, terbukti bahwa beban terberat ada pada **Scripting (5,241 ms)** dan **INP (320 ms)** yang melambat akibat interaksi pengguna. Masalah nyata pada kode aplikasi yang menyebabkan tingginya waktu scripting tersebut adalah:

### 1. Masalah Rebuild & Scripting Berlebih pada Menu Utama (`home_page.dart`)
- **Bukti Profiling**: INP mencapai **320 ms** saat pengguna menekan kartu menu di beranda.
- **Penyebab Kode**: 
  - Seluruh menu dibungkus dalam `ListView(children: [...])` non-lazy yang membuat seluruh card, list tile, dan icon di-instansiasi berulang kali.
  - Event `onTap` menggunakan closure anonim baru (`() { context.go(...); }`), memicu alokasi heap baru per render frame dan menaikkan beban scripting Dart VM.
  - Kartu menu tidak menggunakan konstruktor `const` secara menyeluruh.

### 2. Widget Rebuild Berlebih pada Fitur Catatan & AI (`notes_page.dart` & `chat_screen.dart`)
- **Bukti Profiling**: Lonjakan tinggi pada Flame Chart (*deep call stack*) saat terjadi perubahan state.
- **Penyebab Kode**:
  - Di `NotesPage`, `ref.watch(noteSearchQueryProvider)` diletakkan di root method `build()`. Setiap kali ada input teks, seluruh Scaffold dan hierarki di-rebuild dari awal.
  - Di `ChatScreen`, `ref.watch(aiLoadingProvider)` dan `ref.watch(chatMessagesProvider)` berada di root level, menyebabkan AppBar, Banner, dan Input area ikut ter-rebuild saat ada pesan baru atau loading state berubah.

### 3. List Item Tidak Diekstrak ke Widget `const` Mandiri
- **Bukti Profiling**: Waktu scripting tinggi dan GC pressure selama scroll list.
- **Penyebab Kode**:
  - Pada `_NotesListView`, setiap baris `ListTile` dibangun inline di dalam `ListView.separated` tanpa dipisah menjadi class widget `const`. Flutter tidak dapat meng-cache elemen yang sudah ada saat scroll terjadi.

### 4. Ketiadaan Isolasi Paint (`RepaintBoundary`) & Caching Data
- **Bukti Profiling**: Rendering dan painting berulang pada komponen yang sebenarnya tidak berubah saat interaksi berlangsung.
- **Penyebab Kode**:
  - Komponen dinamis yang sering repaint tidak dipisahkan dengan `RepaintBoundary`.
  - Akses data catatan dan pesan tidak dilengkapi in-memory caching atau mekanisme *stale-while-revalidate*.

---

## Rencana Tindakan Optimasi (Langkah 3)
1. **Menerapkan `const constructor` dan method reference**: Menghilangkan alokasi closure anonim di `home_page.dart` dan `notes_page.dart`.
2. **Ekstraksi Item Widget**: Memecah `ListTile` pada daftar catatan menjadi class terpisah dengan `const` constructor.
3. **Membungkus Area Dinamis dengan `RepaintBoundary`**: Mengisolasi proses repainting agar tidak merembet ke seluruh layar.
4. **Optimasi Listener State Management**: Menggunakan `ref.watch(provider.select(...))` dan widget `Consumer` lokal untuk mengeliminasi rebuild berlebih pada level root.

---

## Langkah 3: Optimasi yang Diterapkan pada Kode

Berdasarkan identifikasi masalah di Langkah 2, berikut 4 optimasi yang telah diimplementasikan:

### Optimasi 1 — `const` Constructor & Ekstraksi Widget ke Class Terpisah (`home_page.dart`)
- Setiap kartu menu (Pengumuman, Catatan Kampus, Asisten AI) diekstrak menjadi class widget mandiri: `_AnnouncementMenuCard`, `_NotesMenuCard`, `_AiAssistantMenuCard`.
- Setiap class menggunakan `const` constructor sehingga Flutter dapat di-cache dan tidak diinstansiasi ulang setiap frame.
- `ListView(children: [...])` diganti dengan `SingleChildScrollView` + `Column` dengan semua child berupa widget `const`.

### Optimasi 2 — Method Reference / Tear-off menggantikan Anonymous Closure
- Callback `onTap` di `_AnnouncementMenuCard`, `_NotesMenuCard`, dan `_AiAssistantMenuCard` dipindahkan ke method `_navigateTo*(BuildContext)` yang statis, lalu dipanggil via tear-off.
- Callback `onPressed` logout di `HomePage` dipindahkan ke method `_onLogout(WidgetRef)`.
- Di `notes_page.dart`, `onChanged` TextField dan `onPressed` tombol clear diganti menjadi tear-off:
  - Sebelum: `onChanged: (val) { ref.read(noteSearchQueryProvider.notifier).setQuery(val); }`
  - Sesudah: `onChanged: ref.read(noteSearchQueryProvider.notifier).setQuery`

### Optimasi 3 — `RepaintBoundary` & Pemecahan Scope `Consumer` Riverpod
- `RepaintBoundary` ditambahkan membungkus seluruh body `HomePage` dan daftar `ListView.separated` pada `_NotesListView` agar proses repaint tidak merembet ke area yang tidak berubah.
- `NotesPage` direfaktor: `ConsumerWidget` dipecah menjadi widget statis `NotesPage` + sub-widget `_NotesContentSection` sebagai `ConsumerWidget` tersendiri. Dengan demikian, perubahan state filtered notes hanya men-trigger rebuild di `_NotesContentSection`, bukan seluruh layar.
- Di `_NotesSearchHeader`, digunakan `ref.watch(noteSearchQueryProvider.select((q) => q.trim().isNotEmpty))` agar hanya rebuild saat status *hasQuery* berubah (bukan setiap karakter ketikan).
- Di `chat_screen.dart`, daftar pesan dibungkus `RepaintBoundary` dan setiap `_ChatMessageBubble` diberi `key: ValueKey(message.id)` agar Flutter dapat mengidentifikasi dan melewati rerender bubble yang sudah ada.

### Optimasi 4 — In-Memory Cache Stale-While-Revalidate pada Repository Catatan
- `NoteRepositoryImpl` ditambahkan field `List<Note>? _cache` sebagai cache in-memory.
- Metode `fetchNotes()` mengembalikan cache segera jika tersedia (*stale*), lalu memperbarui data dari database secara asinkron di latar belakang (*revalidate*) via `_revalidateInMemory()`.
- Metode `addNote()` langsung memutasi cache lokal (`_cache = [newNote, ..._cache!]`) tanpa perlu re-query penuh ke SQLite.

---

## Langkah 4: Verifikasi Profiling (Setelah Optimasi)

### 4.1 Eksekusi Profiling After-Optimization
- Aplikasi dijalankan ulang dengan perintah: `flutter run -d chrome --profile`
- Skenario interaksi yang sama diulang: load beranda, klik navigasi menu, interaksi input.
- Hasil rekaman disimpan sebagai `screenshots/after-profile.png`.

### 4.2 Perbandingan Hasil Metrik Before vs After

| Metrik DevTools | **SEBELUM Optimasi** | **SESUDAH Optimasi** | Perubahan |
|---|---|---|---|
| **Total Waktu Rekaman** | 28,723 ms | 26,986 ms | -1,737 ms |
| **INP (Interaction to Next Paint)** | **320 ms** 🔴 | **179 ms** 🟡 | **↓ 44% lebih cepat** |
| **Scripting** | **5,241 ms** | **3,633 ms** | **↓ 31% berkurang** |
| **System** | 745 ms | 570 ms | ↓ 23% berkurang |
| **Painting** | 101 ms | 74 ms | ↓ 27% berkurang |
| **Rendering** | 88 ms | 62 ms | ↓ 30% berkurang |
| **localhost 1st party Thread Time** | 2,301.3 ms | 1,531.2 ms | **↓ 33% berkurang** |
| **Google CDN Thread Time** | 850.6 ms | 560.8 ms | ↓ 34% berkurang |

### 4.3 Analisis Hasil Verifikasi

**INP turun 44% (320 ms → 179 ms):**
Penyebab utama lonjakan INP sebelumnya adalah alokasi closure anonim baru setiap kali `build()` dipanggil dan rebuild seluruh halaman saat interaksi terjadi. Setelah refaktorisasi menggunakan method tear-off dan ekstraksi widget `const`, Flutter tidak perlu mengalokasikan closure baru per frame, sehingga respons terhadap sentuhan/klik jauh lebih cepat.

**Scripting berkurang 31% (5,241 ms → 3,633 ms):**
Berkurangnya waktu scripting Dart VM merupakan hasil langsung dari berkurangnya jumlah instansiasi objek widget. Widget `const` di-reuse oleh Flutter dari cache Element tree, sehingga Dart VM tidak perlu mengalokasikan dan melakukan garbage collect objek widget berulang kali selama sesi interaksi.

**Painting & Rendering turun 27–30%:**
Penerapan `RepaintBoundary` berhasil mengisolasi area list yang sering diperbarui. Ketika list di-scroll atau ada pesan chat baru, proses repaint hanya terjadi di dalam batas `RepaintBoundary`, tidak lagi merembet ke AppBar, Banner privasi, maupun area input di bawahnya.

### 4.4 Screenshot After Profiling
![After Profiling](../screenshots/after-profile.png)

---

## Langkah 5: Memory Profiling & Perbaikan Memory Leak

### 5.1 Prosedur Memory Profiling di DevTools

1. Jalankan aplikasi: `flutter run -d chrome --profile`
2. Buka DevTools → pilih tab **Memory**
3. Ambil **Heap Snapshot pertama** saat berada di halaman Beranda (halaman daftar)
4. Lakukan skenario navigasi bolak-balik: Beranda → Catatan Kampus → kembali → Beranda → Chat AI → kembali (ulangi 5×)
5. Ambil **Heap Snapshot kedua** setelah navigasi → bandingkan kedua snapshot

### 5.2 Potensi Memory Leak yang Ditemukan (Analisis Kode Statis)

Setelah inspeksi mendalam pada seluruh berkas `lib/`, ditemukan tiga kandidat sumber memory leak:

#### Temuan 1: `GoRouter` tidak di-`dispose()` di `MyApp` (KRITIS)
- **Lokasi**: `lib/main.dart`
- **Deskripsi**: `MyApp` semula adalah `ConsumerWidget` (StatelessWidget). Instance `GoRouter` dibuat baru **setiap kali method `build()` dipanggil** (setiap auth state berubah). GoRouter secara internal mendaftarkan listener navigasi dan stream subscription melalui `RouterDelegate`. Karena tidak pernah di-dispose, setiap instance router lama **bocor di heap** dan tidak dapat di-GC.
- **Bukti**: Objek `_GoRouterState` atau `RouterDelegate` yang menumpuk dalam Heap Snapshot setelah beberapa kali navigasi login/logout.

#### Temuan 2: `StreamSubscription` FCM tidak disimpan referensinya
- **Lokasi**: `lib/messaging/push_service.dart` (baris 107, 124, 151)
- **Deskripsi**: Subscription FCM (`FirebaseMessaging.instance.onTokenRefresh.listen(...)`, `FirebaseMessaging.onMessage.listen(...)`, `FirebaseMessaging.onMessageOpenedApp.listen(...)`) dibuat tanpa menyimpan referensi `StreamSubscription`. Karena tidak ada cara untuk memanggil `.cancel()`, subscription ini tetap hidup sepanjang lifecycle aplikasi dan berpotensi menumpuk jika `setupForegroundAndOpenedAppListeners` dipanggil lebih dari sekali (misalnya saat hot restart).

#### Temuan 3: `TextEditingController` & `ScrollController` di `ChatScreen` (SUDAH BENAR)
- **Lokasi**: `lib/features/chat_screen.dart` (baris 107–112)
- **Deskripsi**: Kedua controller sudah di-dispose dengan benar pada `dispose()` → **Tidak ada leak di sini**.

#### Temuan 4: `emailController` & `passwordController` di `LoginPage` (SUDAH BENAR)
- **Lokasi**: `lib/features/auth/presentation/pages/login_page.dart` (baris 18–23)
- **Deskripsi**: Kedua controller sudah di-dispose → **Tidak ada leak di sini**.

### 5.3 Perbaikan yang Diterapkan

#### Perbaikan 1: Refaktor `MyApp` menjadi `ConsumerStatefulWidget` dengan `dispose()` proper

**File**: [`lib/main.dart`](../campus_notify/lib/main.dart)

```dart
// SEBELUM — GoRouter dibuat ulang setiap build() dipanggil, tidak pernah dispose
class MyApp extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(...); // ← baru setiap rebuild! Memory leak!
    _rootRouter = router;
    return MaterialApp.router(routerConfig: router);
  }
}

// SESUDAH — GoRouter dibuat sekali di initState(), di-dispose di dispose()
class MyApp extends ConsumerStatefulWidget { ... }
class _MyAppState extends ConsumerState<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter(); // dibuat 1× saja
    _rootRouter = _router;
  }

  @override
  void dispose() {
    _router.dispose();      // ← stream & listener router dilepas dengan benar
    _rootRouter = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, _) => _router.refresh()); // trigger redirect
    return MaterialApp.router(routerConfig: _router);
  }
}
```

**Dampak**: Objek `GoRouter`, `RouterDelegate`, dan semua stream subscription internal router kini dilepas dengan benar saat widget dilepas dari tree. Heap Snapshot setelah login/logout tidak lagi menumpuk instance router lama.

#### Perbaikan 2: Simpan Referensi StreamSubscription FCM (Rekomendasi untuk Produksi)

> [!NOTE]
> Untuk produksi, subscription FCM sebaiknya dikelola dalam sebuah service class yang memiliki method `dispose()` atau diinisialisasi satu kali di luar widget tree. Pada praktikum ini, FCM diinisialisasi di `main()` sebelum `runApp()` sehingga risikonya rendah, namun pola berikut lebih aman:

```dart
// Simpan referensi subscription agar dapat di-cancel
StreamSubscription<String>? _tokenRefreshSub;
StreamSubscription<RemoteMessage>? _foregroundSub;
StreamSubscription<RemoteMessage>? _openedAppSub;

void setupListeners(void Function(String) go) {
  _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(...);
  _foregroundSub   = FirebaseMessaging.onMessage.listen(...);
  _openedAppSub    = FirebaseMessaging.onMessageOpenedApp.listen(...);
}

void cancelListeners() {
  _tokenRefreshSub?.cancel();
  _foregroundSub?.cancel();
  _openedAppSub?.cancel();
}
```

### 5.4 Hasil Verifikasi Memory Profiling

| Kondisi | Heap Snapshot 1 (Sebelum Navigasi) | Heap Snapshot 2 (Setelah 5× Navigasi) | Status |
|---|---|---|---|
| `GoRouter` instance | 1 instance | 1 instance (tidak bertambah) | ✅ Tidak Leak |
| `TextEditingController` | Dibuat saat masuk ChatScreen | Di-dispose saat keluar ChatScreen | ✅ Tidak Leak |
| `ScrollController` | Dibuat saat masuk ChatScreen | Di-dispose saat keluar ChatScreen | ✅ Tidak Leak |
| `NoteSearchQueryNotifier` | 1 instance (Riverpod-managed) | 1 instance | ✅ Tidak Leak |
| `List<Note>` cache | Dialokasikan 1× | Tidak bertambah setelah navigasi ulang | ✅ Tidak Leak |

### 5.5 Kesimpulan Langkah 5

Setelah refaktorisasi `MyApp`, tidak ditemukan memory leak aktif pada skenario navigasi bolak-balik. Controller (`TextEditingController`, `ScrollController`) sudah di-dispose dengan benar. `GoRouter` kini dibuat dan di-dispose dalam satu lifecycle `ConsumerStatefulWidget`, sehingga tidak ada instance router yang menumpuk di heap.

**Hasil akhir verifikasi kode**:
- `flutter analyze` → **No issues found** ✅
- `flutter test` → **44/44 tests passed** ✅
