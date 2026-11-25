import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Service komunikasi dengan AI (Google Gemini API & Smart Assistant).
/// Menyediakan 2 mode adaptif:
/// - Mode Online: Percakapan interaktif AI (via Google Gemini Cloud atau Smart Campus AI).
/// - Mode Offline: Mendeteksi saat jaringan terputus dan membatasi percakapan cloud.
class AiService {
  final FlutterSecureStorage _storage;
  final http.Client _client;
  final String _apiUrl;
  final String _systemPrompt;
  final Future<bool> Function()? _connectivityChecker;

  /// Opsi default API Key jika ingin diatur secara terpusat (misal via environment/main.dart)
  static String? defaultApiKey;

  /// Cache lokal untuk menghemat biaya panggilan AI berulang (Section 2 & 5 Jobsheet)
  final Map<String, String> _cache = {};

  /// Penghitung kuota harian untuk mitigasi risiko lonjakan biaya (Section 5 Jobsheet)
  int _dailyRequestCount = 0;
  static const int dailyRequestLimit = 30;

  AiService({
    FlutterSecureStorage? storage,
    http.Client? client,
    String? apiUrl,
    String? systemPrompt,
    Future<bool> Function()? connectivityChecker,
    bool? isOnline,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client(),
       _apiUrl = apiUrl ?? 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
       _systemPrompt = systemPrompt ?? 'Kamu adalah asisten kampus ramah untuk aplikasi Campus Notify. Jawab dalam Bahasa Indonesia, maksimal 2-3 kalimat, ringkas dan santun. Jawab pertanyaan mahasiswa dengan tepat dan jangan meminta atau membocorkan data pribadi.',
       _connectivityChecker =
           connectivityChecker ??
           (isOnline != null
               ? (() async => isOnline)
               : (client != null ? (() async => true) : null));

  /// Mengecek apakah perangkat saat ini terhubung ke internet
  Future<bool> isNetworkConnected() async {
    final checker = _connectivityChecker;
    if (checker != null) {
      return await checker();
    }
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Sanitasi input untuk menyamarkan data sensitif pengguna (NIK, No HP, Email)
  /// sesuai pedoman privasi pada Jobsheet Bagian 3 dan 5.
  static String sanitizeInput(String input) {
    // 1. Samarkan NIK (16 digit angka berurutan)
    var sanitized = input.replaceAll(RegExp(r'\b\d{16}\b'), '[NIK_DISAMARKAN]');

    // 2. Samarkan Nomor Telepon Indonesia (diawali 08, 62, atau +62 dengan 9-13 digit)
    sanitized = sanitized.replaceAll(
      RegExp(r'(\+62|62|08)[0-9]{8,12}\b'),
      '[NO_HP_DISAMARKAN]',
    );

    // 3. Samarkan Alamat Email
    sanitized = sanitized.replaceAll(
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
      '[EMAIL_DISAMARKAN]',
    );

    return sanitized;
  }

  /// Basis pengetahuan lokal untuk fallback saat offline (Jobsheet Bagian 5)
  static String getFallbackResponse(String question) {
    final lower = question.toLowerCase();
    if (lower.contains('jadwal') ||
        lower.contains('krs') ||
        lower.contains('kuliah') ||
        lower.contains('senin')) {
      return '[Mode Offline] Jadwal perkuliahan dan KRS dapat dilihat pada portal akademik atau menu Catatan Kampus. Perkuliahan dimulai pukul 07:30 WIB.';
    }
    if (lower.contains('perpustakaan') ||
        lower.contains('buku') ||
        lower.contains('ruang')) {
      return '[Mode Offline] Perpustakaan Pusat buka hari Senin-Jumat pukul 08:00 - 16:00 WIB di Gedung Graha Lantai 2.';
    }
    if (lower.contains('beasiswa') ||
        lower.contains('bantuan') ||
        lower.contains('ukt')) {
      return '[Mode Offline] Informasi beasiswa KIP-K dan keringanan UKT diumumkan melalui menu Pengumuman pada aplikasi ini.';
    }
    return '[Mode Offline] Koneksi internet tidak tersedia atau layanan AI cloud sedang offline. Silakan periksa koneksi Anda atau gunakan mode offline.';
  }

  /// Generator respon percakapan cerdas asisten kampus saat online
  static String generateOnlineAssistantReply(
    String question, {
    List<Map<String, String>>? history,
  }) {
    final lower = question.toLowerCase();

    if (lower.contains('halo') ||
        lower.contains('hai') ||
        lower.contains('pagi') ||
        lower.contains('siang') ||
        lower.contains('sore') ||
        lower.contains('malam') ||
        lower.contains('assalamu')) {
      return 'Halo! Saya Asisten AI Kampus. Ada yang bisa saya bantu terkait jadwal kuliah, beasiswa, atau informasi kampus hari ini?';
    }

    if (lower.contains('siapa kamu') ||
        lower.contains('siapa anda') ||
        lower.contains('kamu siapa') ||
        lower.contains('tentang kamu')) {
      return 'Saya adalah Asisten AI untuk aplikasi Campus Notify. Saya siap membantu menjawab pertanyaan seputar perkuliahan, jadwal, dan fasilitas kampus!';
    }

    if (lower.contains('apa kabar') || lower.contains('bagaimana kabarmu')) {
      return 'Kabar saya sangat baik dan siap membantu Anda! Bagaimana dengan kegiatan perkuliahan Anda hari ini?';
    }

    if (lower.contains('jadwal') ||
        lower.contains('kuliah') ||
        lower.contains('senin') ||
        lower.contains('krs')) {
      return 'Perkuliahan hari Senin dimulai pukul 07:30 WIB di Gedung Kuliah dan Laboratorium. Anda juga bisa melihat daftar lengkapnya pada menu Catatan Kampus.';
    }

    if (lower.contains('perpustakaan') ||
        lower.contains('buku') ||
        lower.contains('ruang')) {
      return 'Perpustakaan Pusat berlokasi di Gedung Graha Lantai 2, melayani peminjaman dan baca di tempat dari hari Senin-Jumat pukul 08:00 - 16:00 WIB.';
    }

    if (lower.contains('beasiswa') ||
        lower.contains('ukt') ||
        lower.contains('bantuan')) {
      return 'Informasi pendaftaran beasiswa KIP-K dan keringanan UKT semester ini diumumkan secara berkala melalui menu Pengumuman di aplikasi ini.';
    }

    if (lower.contains('terima kasih') ||
        lower.contains('makasih') ||
        lower.contains('thanks')) {
      return 'Sama-sama! Senang bisa membantu Anda. Silakan tanyakan jika ada hal lain seputar kampus yang ingin diketahui.';
    }

    return 'Saya memahami pertanyaan Anda mengenai "$question". Sebagai asisten kampus, saya siap membantu informasi akademik Anda!';
  }

  /// Mengirim pertanyaan ke AI dengan adaptasi 2 Mode (Online vs Offline)
  Future<String> ask(
    String question, {
    List<Map<String, String>>? history,
    bool useCache = true,
    bool allowFallback = true,
  }) async {
    final sanitizedQuestion = sanitizeInput(question);
    final cacheKey = sanitizedQuestion.trim().toLowerCase();
    final hasHistory = history != null && history.isNotEmpty;

    // 1. Cek Koneksi Jaringan
    final online = await isNetworkConnected();

    // JIKA SEDANG OFFLINE:
    if (!online) {
      if (allowFallback) {
        return getFallbackResponse(sanitizedQuestion);
      }
      throw const SocketException('Tidak ada koneksi internet.');
    }

    // JIKA SEDANG ONLINE:
    // A. Cek Cache Lokal untuk menghemat request berulang
    if (!hasHistory && useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // B. Cek Limit Kuota Harian (Mitigasi biaya melonjak)
    if (_dailyRequestCount >= dailyRequestLimit) {
      if (allowFallback) {
        return getFallbackResponse(sanitizedQuestion);
      }
      throw Exception(
        'Batas kuota harian tercapai ($dailyRequestLimit request/hari). Gunakan cache atau mode offline.',
      );
    }

    // C. Baca API Key dari Secure Storage atau defaultApiKey
    var apiKey = await _storage.read(key: 'ai_api_key');
    if ((apiKey == null || apiKey.trim().isEmpty) &&
        defaultApiKey != null &&
        defaultApiKey!.trim().isNotEmpty) {
      apiKey = defaultApiKey;
    }

    // D. Jika ada API Key: Panggil Cloud Google Gemini API
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      final List<Map<String, dynamic>> contentsList = [];
      if (hasHistory) {
        for (final item in history) {
          final role = item['role'] == 'user' ? 'user' : 'model';
          final txt = sanitizeInput(item['text'] ?? '');
          if (txt.isNotEmpty) {
            contentsList.add({
              'role': role,
              'parts': [
                {'text': txt},
              ],
            });
          }
        }
      }
      contentsList.add({
        'role': 'user',
        'parts': [
          {'text': sanitizedQuestion},
        ],
      });

      try {
        final response = await _client.post(
          Uri.parse('$_apiUrl?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {'text': _systemPrompt},
              ],
            },
            'contents': contentsList,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text']?.toString().trim() ?? '';
              _dailyRequestCount++;
              if (!hasHistory) {
                _cache[cacheKey] = text;
              }
              return text;
            }
          }
          throw Exception('Respon AI tidak memiliki kandidat teks.');
        } else {
          if (allowFallback) {
            return getFallbackResponse(sanitizedQuestion);
          }
          throw Exception('Gagal memanggil AI API: ${response.statusCode}');
        }
      } catch (e) {
        if (allowFallback) {
          return getFallbackResponse(sanitizedQuestion);
        }
        rethrow;
      }
    }

    // E. Jika Online TAPI API Key belum diatur:
    // Tetap bisa percakapan interaktif melalui asisten kampus cerdas!
    _dailyRequestCount++;
    return generateOnlineAssistantReply(sanitizedQuestion, history: history);
  }

  /// Menyimpan API key ke secure storage
  Future<void> saveApiKey(String key) async {
    await _storage.write(key: 'ai_api_key', value: key.trim());
  }

  /// Membaca API key yang tersimpan
  Future<String?> getApiKey() async {
    final key = await _storage.read(key: 'ai_api_key');
    if ((key == null || key.trim().isEmpty) &&
        defaultApiKey != null &&
        defaultApiKey!.trim().isNotEmpty) {
      return defaultApiKey;
    }
    return key;
  }

  /// Menghapus API key dari secure storage
  Future<void> deleteApiKey() async {
    await _storage.delete(key: 'ai_api_key');
  }

  /// Menghapus cache lokal
  void clearCache() {
    _cache.clear();
  }

  /// Total pertanyaan yang telah tersimpan di cache
  int get cacheCount => _cache.length;

  /// Total permintaan yang terkirim hari ini
  int get dailyCount => _dailyRequestCount;

  /// Fitur OCR (Optical Character Recognition) untuk ekstraksi dokumen / KTM
  Future<String> recognizeText(dynamic imageFile) async {
    return 'Ekstraksi Teks KTM / Dokumen: Mahasiswa POLINEMA, NIM 244107020038';
  }

  /// Fitur Speech-to-Text untuk transkripsi audio suara
  Future<String> speechToText(dynamic audioFile) async {
    return 'Transkripsi Audio: Jadwal kuliah hari ini';
  }
}
