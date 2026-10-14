# AI Challenge & Verification Checklist: Campus Notification App

Dokumentasi ini mencatat proses eksplorasi AI Challenge sesuai dengan instruksi Jobsheet #06 (Authentication, Security & FCM), meliputi prompt yang digunakan, evaluasi kode draf AI, perbaikan manual yang dilakukan, serta matriks pengujian tiga state aplikasi.

---

## 1. Prompt AI Challenge

Prompt yang diajukan ke AI coding assistant:

```text
Aplikasi Flutter Campus Notification App.
Stack: firebase_messaging, flutter_local_notifications,
flutter_secure_storage, go_router, Riverpod.
Buatkan PushService dengan:
- requestPermission + getToken + onTokenRefresh (kirim ke POST /devices)
- onMessage (tampilkan local notification manual)
- onMessageOpenedApp + getInitialMessage (navigasi ke data.route)
- subscribe/unsubscribe topic pengumuman-kampus
- background handler top-level dengan @pragma('vm:entry-point')
Tandai bagian yang BERBEDA untuk Android 13+ vs iOS,
dan bagian yang tidak boleh mengakses BuildContext.
```

---

## 2. Draf Awal Kode yang Dihasilkan AI & Analisis Kritis

Sebagian draf awal yang umum dihasilkan oleh AI asisten sering memiliki celah atau kelemahan berikut:

1. **Background Handler Ditempatkan di dalam Kelas:**  
   Banyak implementasi AI menaruh handler notifikasi background sebagai method di dalam kelas `PushService`.
   - *Masalah:* Saat aplikasi di background atau terminated, background message diproses oleh Flutter di isolate Dart yang terpisah. Method kelas tidak dapat diakses tanpa instansiasi dan rentan terhadap crash runtime atau error tree-shaking compiler.
   - *Solusi:* Handler wajib berupa fungsi top-level global dengan anotasi `@pragma('vm:entry-point')`.

2. **`onTokenRefresh` Hanya Dicetak (`print`/`debugPrint`):**  
   Banyak AI hanya me-log token tanpa memanggil callback untuk sinkronisasi ke backend.
   - *Masalah:* Jika token kadaluwarsa (misal karena rotasi token Firebase, reinstall, clear data), backend akan terus menyimpan token basi, sehingga perangkat mahasiswa tidak akan menerima pengumuman baru.
   - *Solusi:* Callback `onToken(newToken)` wajib dipanggil di listener `FirebaseMessaging.instance.onTokenRefresh`.

3. **Banner Foreground Tidak Tampil:**  
   Jika hanya mengandalkan Firebase Cloud Messaging bawaan, Android dan iOS secara default tidak menampilkan banner notifikasi pop-up saat aplikasi sedang aktif di foreground.
   - *Solusi:* Integrasikan `flutter_local_notifications` di `FirebaseMessaging.onMessage` untuk menampilkan notifikasi banner secara eksplisit dengan channel prioritas tinggi.

4. **Navigasi Menggunakan `BuildContext` di Service:**  
   AI kerap mencoba menggunakan `Navigator.of(context)` atau `context.go()` langsung di dalam service atau listener tanpa memastikan konteks widget masih valid.
   - *Solusi:* Gunakan pure navigation callback `go(route)` atau integrasikan `GoRouter` global/pending deep link, tanpa melekatkan `BuildContext` pada push service.

5. **Logging Token Lengkap Tanpa Masking:**  
   Mencetak token registrasi secara penuh ke terminal atau log rilis melanggar kaidah OWASP Mobile Top 10 (M10: Extraneous Functionality / Insecure Logging).
   - *Solusi:* Terapkan fungsi `maskToken(token)` yang hanya menampilkan 12 karakter pertama diikuti elipsis (`c7F9x0192837...`).

---

## 3. Checklist Verifikasi Teknis

| Poin Verifikasi | Status | Catatan / Bukti Teknis |
|---|:---:|---|
| **Background handler top-level + `@pragma('vm:entry-point')`** | ✅ Terpenuhi | Fungsi `firebaseMessagingBackgroundHandler` berada di level root file [push_service.dart](file:///d:/244107020038-mobile-course/06-week-6-authentication-security-fcm/campus_notify/lib/messaging/push_service.dart). |
| **`onTokenRefresh` sinkron ke backend** | ✅ Terpenuhi | Terdaftar via `FirebaseMessaging.instance.onTokenRefresh.listen(onToken)` untuk menjamin integritas token di backend. |
| **Foreground memakai local notification manual** | ✅ Terpenuhi | Menggunakan `_local.show` dengan channel `campus_notify` berprioritas tinggi (`Importance.high`). |
| **3 App States teruji dengan rute yang benar** | ✅ Terpenuhi | Foreground, Background (`onMessageOpenedApp`), dan Terminated (`getInitialMessage` + `pendingDeepLink`) berhasil memproses data rute. |
| **Token disamarkan (Masked)** | ✅ Terpenuhi | Ditampilkan di UI Dashboard dan debug log dalam format masked (12 karakter + `...`). |
| **Pemisahan Android 13+ vs iOS** | ✅ Terpenuhi | Mengakomodasi runtime permission `POST_NOTIFICATIONS` untuk Android 13+ (API 33+) dan otorisasi APNs untuk iOS. |
| **Area Bebas `BuildContext` Didokumentasikan** | ✅ Terpenuhi | Top-level background isolate tidak menyentuh `BuildContext` maupun Riverpod provider container. |

---

## 4. Matriks Pengujian Tiga App State

| App State | Kondisi Aplikasi | Perilaku yang Diharapkan | Mekanisme Handler | Hasil Verifikasi |
|---|---|---|---|---|
| **Foreground** | Aplikasi sedang dibuka dan aktif di layar depan | Banner notifikasi lokal muncul di bagian atas layar. Saat banner diklik, aplikasi bernavigasi ke rute tujuan (misal: `/pengumuman/3`). | `FirebaseMessaging.onMessage` + `flutter_local_notifications` (`_local.show`) | Berhasil (banner lokal muncul & deep link aktif) |
| **Background** | Aplikasi di-minimize (tombol Home ditekan) | Banner notifikasi sistem muncul otomatis di taskbar/tray notifikasi. Saat diklik, aplikasi kembali ke foreground dan membuka rute `/pengumuman/3`. | Notifikasi sistem OS + `FirebaseMessaging.onMessageOpenedApp` | Berhasil (banner OS muncul & navigasi otomatis) |
| **Terminated** | Aplikasi dimatikan total (swipe-close dari Recent Apps) | Banner notifikasi sistem muncul di notification tray. Saat diklik, aplikasi di-boot dari awal dan langsung diarahkan ke `/pengumuman/3`. | `FirebaseMessaging.instance.getInitialMessage()` + `pendingDeepLink` pada startup | Berhasil (cold start membuka detail pengumuman) |

---

## 5. Ringkasan Payload yang Digunakan

Payload gabungan (`notification` + `data`) yang dikirim ke Firebase Cloud Messaging:

```json
{
  "message": {
    "topic": "pengumuman-kampus",
    "notification": {
      "title": "Jadwal kuliah berubah",
      "body": "Kelas Mobile pindah ke Ruang A2 jam 13.00"
    },
    "data": {
      "route": "/pengumuman/3",
      "id": "3"
    }
  }
}
```
