|  | Pemrograman Mobile |
|--|--|
| NIM |  244107020038|
| Nama |  Nayla Akas Oktavia |
| Kelas | TI - 3H |
| Repository | [link] () |

# WEEK 2
## Declarative UI & Responsive Design

### Demo

1. Jalankan aplikasi hasil akhir pada emulator ukuran ponsel (misal 5"), lalu tablet (misal 10"); bandingkan jumlah kolomnya.

- 5" = 800 x 480 

![screenshot](screenshots/5inch.png)

- 10" = 1920 x 1200

![screenshot](screenshots/10inch.png)

2. Aktifkan dark mode pada emulator/perangkat dan amati perubahan tema secara otomatis.

- tambah kode:

![screenshot](screenshots/kode-dark.png)

- hasil:

![screenshot](screenshots/darkmode.png)

3. Perhatikan pola declarative: UI tidak diubah satu per satu, hanya state yang diperbarui dan Flutter membangun ulang tampilan.

### Praktikum: layout sederhana (warm-up)

- tampilan kartu profil:

![screenshot](screenshots/card.png)

- Hapus expanded di baris nama

![screenshot](screenshots/hapus-expanded.png)

- Ganti mainAxisSize MainAxisSize.min menjadi nilai default 

![screenshot](screenshots/Ganti%20mainAxisSize.png)

- tambahkan satu baris data (email):

![screenshot](screenshots/tambah-email.png)

![screenshot](screenshots/card-email.png)

### Praktikum: dashboard responsif

- Create project

![screenshot](screenshots/create.png)

- Tampilan di HP

![screenshot](screenshots/tampilan-hp.jpeg)

- Buat aplikasi profil sederhana

![screenshot](screenshots/dashboard-resp.jpeg)

- Menambahkan interaksi: StatefulWidget dan Cupertino

![screenshot](screenshots/700.png)

- Eksperimen layout

1. Ubah breakpoint dari 700 menjadi nilai lain dan amati perubahan jumlah kolom (diubah menjadi 300)

![screenshot](screenshots/300.png)

2. Ubah themeMode menjadi ThemeMode.dark, lalu kembalikan ke ThemeMode.system.

- tetap bertema gelap walau tidak sedang di mode gelap
![screenshot](screenshots/dark.png)

- tema mengikuti tema system/perangkat (tema perangkat saya  dark)

![screenshot](screenshots/dark.png)

3. Uji aplikasi dengan ukuran layar emulator yang berbeda.

![screenshot](screenshots/ubah-ukuran.png)

4. Tambahkan Semantics atau label yang bermakna pada elemen yang penting bagi screen reader.

![screenshot](screenshots/semantics.png)

### Tugas dan AI design exploration

Kembangkan dashboard menjadi halaman Academic Overview dengan ketentuan:

- Memiliki header profil dan minimal empat kartu informasi
- Menggunakan Row, Column, Expanded, dan Container
- Menampilkan satu kolom pada layar sempit dan dua kolom pada layar lebar
- Menyediakan light theme dan dark theme yang tetap terbaca, dengan toggle tema (misal CupertinoSwitch atau Switch.adaptive)
- Memiliki label aksesibilitas untuk informasi atau tombol penting
- Menyertakan screenshot layar sempit dan lebar pada folder screenshots/

hasil:

![screenshot](screenshots/narrow.png)

![screenshot](screenshots/wide.png)

- AI Prompt Challenge

1. Prompt desain. Ajukan prompt ini (atau variasinya): "Bandingkan dua tata letak dashboard akademik untuk Flutter: versi GridView dan versi LayoutBuilder + Column. Jelaskan trade-off responsif dan aksesibilitasnya."

![screenshot](screenshots/1.png)

2. Prompt penguatan konsep. "Jelaskan kapan penggunaan Expanded justru menyebabkan overflow di dalam Row, beri contoh kode yang gagal dan perbaikannya."

![screenshot](screenshots/2.png)

3. Verification prompt. Minta AI mengaudit hasilnya sendiri: "Periksa kembali rekomendasi layout di atas: apakah tetap responsif di bawah 600px, apakah mengurangi aksesibilitas, dan apakah ada widget yang tidak tersedia di Flutter stabil saat ini?"

4. Dokumentasikan. Simpan prompt, output penting, keputusan yang dipilih, alasan teknis, dan bukti verifikasi (test/screenshots) di README tugas minggu ini.

![screenshot](screenshots/3.1.png)

![screenshot](screenshots/3.2.png)

![screenshot](screenshots/3.3.png)

- Refactoring challenge

1. Ekstrak kartu informasi menjadi widget reusable (misal InfoCard) yang menerima title dan value, sehingga tidak ada duplikasi widget.

![screenshot](screenshots/InfoCard.png)

2. Ganti warna dan ukuran yang di-hardcode dengan Theme.of(context) agar mengikuti tema terang/gelap secara otomatis.

![screenshot](screenshots/Theme.of(context).png)

3. Pindahkan breakpoint ke satu konstanta bernama (misal const kWideBreakpoint = 700;) agar hanya didefinisikan satu kali.

![screenshot](screenshots/BreakPoint.png)

4. Jalankan flutter analyze dan pastikan tidak ada error maupun warning baru.

![screenshot](screenshots/analyze.png)

- Testing Dasar

![screenshot](screenshots/test.png)

### Refleksi

1. Apa perbedaan cara berpikir imperative dan declarative saat membangun UI?
    
    Imperative: Mengatur tahapan perubahan UI satu per satu secara manual. Declarative: Menggambarkan wujud akhir UI berdasarkan kondisi status saat itu

2. Kapan Expanded membantu dan kapan penggunaannya justru menghasilkan layout error?
    
    Membantu untuk mengisi sisa ruang kosong dan mencegah overflow di dalam row atau column. Error jika dipakai di dalam kontainer tanpa batas ukuran

3. Bagaimana breakpoint dan theme memengaruhi pengalaman pengguna?
    
    Breakpoint menjaga tata letak tetap profesional dan mudah dipakai di berbagai ukuran layar. Theme menjamin konsistensi visual serta kenyamanan mata lewat mode terang/gelap

4. Apa yang Anda verifikasi dari rekomendasi AI setelah tugas inti selesai?

    - memastikan layout tetap 1 kolom di layar sempit dan 2 kolom di layar lebar
    - memastikan light dan dark theme tetap terbaca, termasuk warna teks dan background
    - menjalankan aplikasi pada ukuran layar berbeda untuk memastikan hasil rekomendasi AI benar-benar sesuai