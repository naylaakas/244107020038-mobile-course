|  | Pemrograman Mobile |
|--|--|
| **NIM** | 244107020038 |
| **Nama** | Nayla Akas Oktavia |
| **Kelas** | TI - 3H |

# WEEK 13
## Otomasi CI/CD & Build Pipeline Flutter

---

### Langkah 3 — Membuat Workflow CI Flutter

#### 1. File Workflow GitHub Actions
Workflow CI Flutter dibuat pada `.github/workflows/flutter-ci.yml`. Pipeline ini dipicu saat ada event `push` dan `pull_request` ke branch `main`, serta mendukung eksekusi manual via `workflow_dispatch`.

```yaml
name: Flutter CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test-and-build:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: 13-week-13-ci-cd-automation/campus_notify

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze --fatal-infos
      - run: flutter test --coverage
```

#### 2. Pemeriksaan Lokal
Sebelum mendorong perubahan ke repository remote, seluruh langkah pemeriksaan dijalankan secara lokal di folder project `campus_notify`:
- Format kode: `dart format --output=none --set-exit-if-changed .`
- Analisis kode: `flutter analyze --fatal-infos`
- Pengujian unit & widget: `flutter test --coverage`

![Pemeriksaan Lokal](screenshots/local-checks.png)

---

### Langkah 4 — Membangun dan Menyimpan APK/AAB

Setelah tahap validasi dan pengujian lulus, pipeline CI melanjutkan proses build release secara otomatis:

```yaml
      - run: flutter build apk --release
      - run: flutter build appbundle --release
      - uses: actions/upload-artifact@v4
        with:
          name: android-builds
          path: |
            13-week-13-ci-cd-automation/campus_notify/build/app/outputs/flutter-apk/app-release.apk
            13-week-13-ci-cd-automation/campus_notify/build/app/outputs/bundle/release/app-release.aab
            **/build/app/outputs/flutter-apk/app-release.apk
            **/build/app/outputs/bundle/release/app-release.aab
          if-no-files-found: error
          retention-days: 7
```

- **APK (`app-release.apk`)**: Format paket aplikasi yang siap dipasang langsung (sideloading) untuk kebutuhan testing internal atau tim QA.
- **AAB (`app-release.aab`)**: Android App Bundle sebagai format distribusi resmi ke Google Play Store yang memungkinkan dynamic delivery ukuran aplikasi lebih efisien.
- **Upload Artifact**: Kedua file artefak biner disimpan di GitHub Actions selama 7 hari dan dapat diunduh langsung dari tab Actions.

---

### Langkah 5 — Versi, Secrets, dan Keamanan

#### 1. Versioning
Pada file `pubspec.yaml`, versi aplikasi dinaikkan mengikuti Semantic Versioning:
```yaml
version: 1.1.0+2
```
- `1.1.0`: Menandakan versi rilis fitur baru (penambahan pipeline CI/CD otomatisasi).
- `+2`: Build number inkremental untuk membedakan rilis biner dari versi sebelumnya (`1.0.0+1`).
- Tag rilis yang disarankan: `v1.1.0` yang dipasangkan pada commit yang telah lulus pipeline CI.

#### 2. Rahasia dan Konfigurasi
- **GitHub Secrets**: Token API eksternal (misalnya Gemini AI Key) dan keystore signing disimpan pada GitHub Actions Secrets (`Settings > Secrets and variables > Actions`), bukan di-hardcode ke file source code repository.
- **Dart Define**: Nilai konfigurasi disuntikkan saat build waktu kompilasi menggunakan argumen `--dart-define` atau Secret environment.
- **Keamanan Keystore**: Kunci signing produksi tidak disertakan pada pull request dari kontributor publik untuk mencegah kebocoran sertifikat rilis aplikasi.

---

### Langkah 6 — Menjalankan dan Mengevaluasi Pipeline

#### 1. Menjalankan Workflow
File workflow dan perubahan di-commit kemudian di-push ke GitHub:
```bash
git add .
git commit -m "feat(ci): setup Flutter CI workflow with build and artifact upload"
git push origin main
```

#### 2. Hasil Eksekusi Pipeline


---

## Tugas dan Refleksi

### Tugas

1. **Workflow CI Terpasang:**
   - File `.github/workflows/flutter-ci.yml` telah dikonfigurasi untuk memeriksa integritas kode secara otomatis:
     - `dart format --output=none --set-exit-if-changed .`
     - `flutter analyze --fatal-infos`
     - `flutter test --coverage`

2. **Build APK dan AAB Disimpan sebagai Artefak:**
   - Pipeline otomatis memproduksi `app-release.apk` dan `app-release.aab` pada job yang sama.
   - Menggunakan action `actions/upload-artifact@v4` dengan nama artefak `android-builds` dan retensi 7 hari.

3. **Eksekusi Workflow & Bukti Commit:**
   - Pipeline dijalankan melalui push ke branch `main`.
   - Bukti eksekusi sukses (centang hijau) dan daftar artefak build tersimpan di tab Actions repository.

4. **Dokumentasi Versi Berikutnya, Pemeriksaan, dan Risiko Keamanan:**
   - **Versi Berikutnya:** Direncanakan `v1.2.0+3` jika ada penambahan fitur modul baru, atau `v1.1.1+3` untuk patch/bug fixing.
   - **Pemeriksaan Tambahan:** Dapat ditambahkan integrasi *coverage report upload* (misalnya Codecov) dan integrasi test otomatis pada emulator.
   - **Risiko Keamanan yang Perlu Ditangani:**
     - Penanganan Android Release Signing: Mengganti debug keystore dengan keystore resmi yang dienkripsi menggunakan Base64 di GitHub Secrets.
     - Proteksi API Keys: Menjaga API keys agar tidak terekspos di log console GitHub Actions.

---

### Refleksi

1. **Masalah apa yang ditemukan otomatis sebelum perubahan di-merge?**
   Pelanggaran format kode (`dart format`), ketidaksesuaian linting/warning (`flutter analyze --fatal-infos`), serta potensi regresi logika pada use case dan widget (`flutter test`) langsung terdeteksi dan menggagalkan pipeline sebelum kode masuk ke branch utama.

2. **Informasi apa yang Anda butuhkan untuk menyelidiki build yang gagal?**
   Log output terperinci dari langkah yang gagal di tab Actions, pesan error compiler/Gradle, stack trace kegagalan test, serta ringkasan perbedaan commit (*diff*) yang memicu eksekusi pipeline tersebut.

3. **Bagian mana yang masih perlu persetujuan atau pemeriksaan manual sebelum rilis?**
   Pemeriksaan manual UX/UI pada perangkat pengguna nyata (sanity check), pengujian performa transisi, persetujuan QA (*sign-off*), dan otorisasi perilisan biner produksi ke Google Play Console menggunakan deployment environment berizin khusus.
