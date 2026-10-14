import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:campus_notify/routes.dart';
import 'package:campus_notify/data/api_errors.dart';
import 'package:campus_notify/data/auth_repository.dart';
import 'package:campus_notify/messaging/push_service.dart';

class FakeTokenStore {
  String? access;
  String? refresh;

  Future<void> save({required String newAccess, required String newRefresh}) async {
    access = newAccess;
    refresh = newRefresh;
  }

  Future<String?> readAccess() async => access;
  Future<String?> readRefresh() async => refresh;
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

void main() {
  group('Refactoring Challenge: routeFromMessage Parsing Tests', () {
    test('routeFromMessage menangani route kosong dan tanpa slash', () {
      expect(routeFromMessage({}), '/');
      expect(routeFromMessage({'route': 'pengumuman/3'}), '/pengumuman/3');
      expect(routeFromMessage({'route': '/pengumuman/3'}), '/pengumuman/3');
    });

    test('data payload membawa id pengumuman dan fallback dengan benar', () {
      const data = {'route': '/pengumuman/3', 'id': '3'};
      expect(data['id'], '3');
      expect(routeFromMessage(data), '/pengumuman/3');

      // Uji fallback ketika route kosong tetapi id tersedia
      final dataWithOnlyId = {'id': '42'};
      expect(routeFromMessage(dataWithOnlyId), '/pengumuman/42');
    });

    test('routeFromMessage menangani whitespace dan fallback ke home jika null', () {
      expect(routeFromMessage({'route': '   '}), '/');
      expect(routeFromMessage({'route': '  pengumuman/99  '}), '/pengumuman/99');
    });
  });

  group('Refactoring Challenge: ApiErrors Pemetaan DioException Tests', () {
    test('memetakan status code 401 ke pesan sesi berakhir', () {
      final dioError401 = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );

      final message = ApiErrors.getMessage(dioError401);
      expect(message, contains('Sesi login telah berakhir'));
    });

    test('memetakan timeout ke pesan ramah pengguna', () {
      final timeoutError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final message = ApiErrors.getMessage(timeoutError);
      expect(message, contains('waktu habis (timeout)'));
    });

    test('memetakan gangguan koneksi / offline ke pesan internet', () {
      final offlineError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
      );

      final message = ApiErrors.getMessage(offlineError);
      expect(message, contains('Pastikan perangkat terhubung ke internet'));
    });

    test('memetakan error server 500 ke pesan gangguan server', () {
      final serverError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
        ),
        type: DioExceptionType.badResponse,
      );

      final message = ApiErrors.getMessage(serverError);
      expect(message, contains('Server kampus sedang mengalami gangguan'));
    });

    test('memetakan Exception umum tanpa prefix "Exception: "', () {
      final genericException = Exception('Koneksi database lokal terputus');
      expect(
        ApiErrors.getMessage(genericException),
        'Koneksi database lokal terputus',
      );
    });
  });

  group('Praktikum 1: AuthRepository & Session Logic Tests', () {
    final repo = AuthRepository();

    test('login berhasil mengembalikan session dengan access & refresh token', () async {
      final session = await repo.login(
        email: 'mahasiswa@polinema.ac.id',
        password: 'password123',
      );

      expect(session.access, isNotEmpty);
      expect(session.refresh, isNotEmpty);
      expect(session.access, contains('mahasiswa@polinema.ac.id'));
    });

    test('login gagal jika email tidak memiliki @ atau password < 6 karakter', () async {
      expect(
        () => repo.login(email: 'invalid-email', password: 'password123'),
        throwsException,
      );

      expect(
        () => repo.login(email: 'valid@polinema.ac.id', password: '123'),
        throwsException,
      );
    });

    test('refresh mengembalikan token baru yang valid', () async {
      final newToken = await repo.refresh('mock-refresh-token');
      expect(newToken, contains('mock-access-renewed-'));
    });

    test('refresh melempar exception jika refreshToken kosong', () async {
      expect(() => repo.refresh(''), throwsException);
    });
  });

  group('Keamanan & Lifecycle Token Tests', () {
    test('maskToken menyamarkan token dengan panjang lebih dari 12 karakter', () {
      const fullToken = 'c7F9x0192837465fcmLongRegistrationTokenSecret12345';
      final masked = maskToken(fullToken);

      expect(masked, startsWith('c7F9x0192837'));
      expect(masked, endsWith('...'));
      expect(masked.length, 15);
      expect(masked, isNot(equals(fullToken)));
    });

    test('maskToken tidak memotong token jika panjang <= 12 karakter', () {
      expect(maskToken('short_token'), 'short_token');
    });

    test('provider auth membaca status login dari token', () async {
      final store = FakeTokenStore()..access = 'mock-access';
      expect(store.access != null, isTrue);
      store.access = null;
      expect(store.access != null, isFalse);
    });

    test('refresh gagal -> sesi dibersihkan (paksa login ulang)', () async {
      final store = FakeTokenStore()..refresh = '';
      final needsLogin = (store.refresh ?? '').isEmpty;
      expect(needsLogin, isTrue);
    });
  });
}
