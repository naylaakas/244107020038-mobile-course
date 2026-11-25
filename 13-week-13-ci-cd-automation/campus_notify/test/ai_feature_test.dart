import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:campus_notify/ai/ai_service.dart';
import 'package:campus_notify/features/chat_screen.dart';

/// Fake In-Memory Secure Storage untuk keperluan pengujian unit dan widget
class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _data = {};

  FakeSecureStorage([Map<String, String>? initial]) {
    if (initial != null) _data.addAll(initial);
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  group('Praktikum 2 & 5: AI Service Unit Tests', () {
    test('Sanitasi Data Pribadi: menyamarkan NIK, No HP, dan Email', () {
      const rawPrompt =
          'Halo nama saya Budi, NIK 3507123456780001, No HP 081234567890, email budi@kampus.ac.id mohon info jadwal.';
      final sanitized = AiService.sanitizeInput(rawPrompt);

      expect(sanitized, isNot(contains('3507123456780001')));
      expect(sanitized, isNot(contains('081234567890')));
      expect(sanitized, isNot(contains('budi@kampus.ac.id')));
      expect(sanitized, contains('[NIK_DISAMARKAN]'));
      expect(sanitized, contains('[NO_HP_DISAMARKAN]'));
      expect(sanitized, contains('[EMAIL_DISAMARKAN]'));
      expect(sanitized, contains('mohon info jadwal.'));
    });

    test('Panggilan Berhasil: membaca API key dan parse respon JSON Gemini saat Online', () async {
      final fakeStorage = FakeSecureStorage({'ai_api_key': 'test-secret-key'});
      int callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        expect(request.url.queryParameters['key'], 'test-secret-key');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body);
        expect(body['contents'], isNotEmpty);

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': 'Perkuliahan hari Senin dimulai pukul 07:30 WIB di Gedung Sipil.',
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = AiService(
        storage: fakeStorage,
        client: mockClient,
        isOnline: true,
      );
      final reply = await service.ask('Jadwal hari Senin?');

      expect(callCount, 1);
      expect(
        reply,
        'Perkuliahan hari Senin dimulai pukul 07:30 WIB di Gedung Sipil.',
      );
      expect(service.cacheCount, 1);
      expect(service.dailyCount, 1);
    });

    test(
      'Percakapan Online Tanpa API Key: asisten cerdas menjawab interaktif',
      () async {
        final fakeStorage = FakeSecureStorage(); // Tanpa API Key
        final service = AiService(storage: fakeStorage, isOnline: true);

        final reply = await service.ask('Halo apa kabar?');
        expect(reply, isNot(contains('[Mode Offline]')));
        expect(reply, contains('Halo'));
      },
    );

    test(
      'Cache Lokal: pertanyaan berulang tidak memicu HTTP request kedua',
      () async {
        final fakeStorage = FakeSecureStorage({'ai_api_key': 'key-123'});
        int httpCalls = 0;

        final mockClient = MockClient((request) async {
          httpCalls++;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Perpustakaan buka pukul 08:00 WIB.'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final service = AiService(
          storage: fakeStorage,
          client: mockClient,
          isOnline: true,
        );

        // Panggilan pertama (hit API)
        final res1 = await service.ask('Jam buka perpustakaan?');
        expect(httpCalls, 1);
        expect(res1, 'Perpustakaan buka pukul 08:00 WIB.');

        // Panggilan kedua pertanyaan sama persis (hit Cache)
        final res2 = await service.ask('Jam buka perpustakaan?');
        expect(httpCalls, 1); // tetap 1!
        expect(res2, 'Perpustakaan buka pukul 08:00 WIB.');
        expect(service.dailyCount, 1);
      },
    );

    test(
      'Fallback Offline: kembalikan jawaban lokal saat internet mati',
      () async {
        final fakeStorage = FakeSecureStorage();
        final service = AiService(storage: fakeStorage, isOnline: false);

        // Dengan allowFallback = true
        final fallbackReply = await service.ask(
          'Berapa jam buka perpustakaan pusat?',
          allowFallback: true,
        );
        expect(fallbackReply, contains('[Mode Offline]'));
        expect(fallbackReply, contains('Perpustakaan Pusat'));

        // Dengan allowFallback = false -> wajib lempar Exception
        expect(
          () => service.ask('Jadwal kuliah', allowFallback: false),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'Fallback Error 500: beralih ke mode offline saat API cloud gangguan',
      () async {
        final fakeStorage = FakeSecureStorage({'ai_api_key': 'key-abc'});
        final errorClient = MockClient((_) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = AiService(
          storage: fakeStorage,
          client: errorClient,
          isOnline: true,
        );

        final reply = await service.ask(
          'Info beasiswa kampus semester ini',
          allowFallback: true,
        );
        expect(reply, contains('[Mode Offline]'));
        expect(reply, contains('beasiswa'));
      },
    );

    test(
      'Manajemen Kunci API: simpan, baca, dan hapus API key secara aman',
      () async {
        final fakeStorage = FakeSecureStorage();
        final service = AiService(storage: fakeStorage, isOnline: true);

        expect(await service.getApiKey(), isNull);

        await service.saveApiKey('AIzaSyNewKey123');
        expect(await service.getApiKey(), 'AIzaSyNewKey123');

        await service.deleteApiKey();
        expect(await service.getApiKey(), isNull);
      },
    );

    test('Fitur Pendukung: OCR dan Speech-to-Text helper methods', () async {
      final service = AiService();

      final ocrResult = await service.recognizeText('ktm_card.jpg');
      expect(ocrResult, contains('NIM 244107020038'));

      final sttResult = await service.speechToText('audio_voice.m4a');
      expect(sttResult, contains('Transkripsi Audio'));
    });
  });

  group('Praktikum 3: ChatScreen Widget Tests', () {
    testWidgets('Menampilkan UI awal chat dengan pesan sambutan asisten', (
      tester,
    ) async {
      final fakeService = AiService(isOnline: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiServiceProvider.overrideWithValue(fakeService)],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );

      // Cek judul AppBar dan banner privasi
      expect(find.text('Asisten AI Kampus'), findsOneWidget);
      expect(
        find.textContaining('Privasi Terjaga: NIK, nomor telepon, dan email'),
        findsOneWidget,
      );

      // Cek pesan sambutan awal
      expect(
        find.textContaining('Halo! Saya Asisten AI Kampus'),
        findsOneWidget,
      );

      // Cek chip pertanyaan cepat
      expect(find.text('Jadwal kampus hari Senin?'), findsOneWidget);
      expect(find.text('Lokasi perpustakaan pusat?'), findsOneWidget);
      expect(find.text('Info beasiswa kampus?'), findsOneWidget);

      // Cek input field dan tombol kirim
      expect(
        find.widgetWithText(TextField, 'Tanyakan sesuatu ke asisten kampus...'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Percakapan Berfungsi saat Online', (tester) async {
      final fakeStorage = FakeSecureStorage();
      final fakeService = AiService(storage: fakeStorage, isOnline: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiServiceProvider.overrideWithValue(fakeService)],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );

      // Ketik pertanyaan jadwal saat online
      await tester.enterText(
        find.byType(TextField),
        'Jadwal kuliah hari Senin jam berapa?',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Pastikan pesan user muncul
      expect(find.text('Jadwal kuliah hari Senin jam berapa?'), findsOneWidget);

      // Pastikan asisten membalas percakapan secara online
      expect(
        find.textContaining('Perkuliahan hari Senin dimulai'),
        findsOneWidget,
      );
      expect(find.text('Asisten AI'), findsNWidgets(2));
    });

    testWidgets('Deteksi Offline Memunculkan Dialog dan Opsi Jawaban Offline', (
      tester,
    ) async {
      final fakeStorage = FakeSecureStorage();
      final fakeService = AiService(storage: fakeStorage, isOnline: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiServiceProvider.overrideWithValue(fakeService)],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );

      // Ketik pertanyaan saat offline
      await tester.enterText(
        find.byType(TextField),
        'Tanya jadwal kuliah hari Senin',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Muncul dialog peringatan offline
      expect(find.text('Perangkat Offline'), findsOneWidget);

      // Klik gunakan jawaban offline
      await tester.tap(find.text('Gunakan Jawaban Offline'));
      await tester.pumpAndSettle();

      // Jawaban offline masuk ke chat
      expect(find.textContaining('[Mode Offline]'), findsOneWidget);
      expect(find.text('Offline Fallback'), findsOneWidget);
    });

    testWidgets('Buka dialog konfigurasi API key dan simpan kunci', (
      tester,
    ) async {
      final fakeStorage = FakeSecureStorage();
      final fakeService = AiService(storage: fakeStorage, isOnline: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiServiceProvider.overrideWithValue(fakeService)],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );

      // Tekan tombol ikon kunci di AppBar
      await tester.tap(find.byIcon(Icons.key));
      await tester.pumpAndSettle();

      // Cek dialog muncul
      expect(find.text('Pengaturan API Key'), findsOneWidget);
      expect(
        find.textContaining('Masukkan Google Gemini API Key'),
        findsOneWidget,
      );

      // Masukkan API key baru
      await tester.enterText(
        find.widgetWithText(TextField, 'AIzaSy...'),
        'AIzaSyTestApiKey999',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      // Cek API key tersimpan di storage
      expect(await fakeService.getApiKey(), 'AIzaSyTestApiKey999');
    });

    testWidgets('Tombol bersihkan riwayat mengosongkan obrolan chat', (
      tester,
    ) async {
      final fakeService = AiService(isOnline: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiServiceProvider.overrideWithValue(fakeService)],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );

      // Tekan tombol hapus riwayat
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Percakapan telah dibersihkan'),
        findsOneWidget,
      );
    });
  });
}
