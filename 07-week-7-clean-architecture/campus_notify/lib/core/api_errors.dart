import 'package:dio/dio.dart';

/// Utilitas pemetaan error Dio menjadi pesan ramah pengguna (user-friendly).
/// Memastikan UI tidak menampilkan exception mentah kepada pengguna.
class ApiErrors {
  ApiErrors._();

  /// Mengonversi objek exception atau error apa pun menjadi pesan deskriptif bahasa Indonesia.
  static String getMessage(Object error) {
    if (error is DioException) {
      return fromDioException(error);
    }
    if (error is Exception) {
      final msg = error.toString();
      // Bersihkan prefix 'Exception: ' jika ada
      return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
    }
    return 'Terjadi kesalahan tidak terduga. Silakan coba lagi.';
  }

  /// Memetakan [DioException] spesifik berdasarkan jenis dan status code HTTP.
  static String fromDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi ke server waktu habis (timeout). Silakan periksa jaringan Anda.';

      case DioExceptionType.badResponse:
        final statusCode = exception.response?.statusCode;
        switch (statusCode) {
          case 400:
            return 'Permintaan tidak valid. Periksa kembali input Anda.';
          case 401:
            return 'Sesi login telah berakhir atau kredensial salah. Silakan login kembali.';
          case 403:
            return 'Akses ditolak. Anda tidak memiliki izin untuk fitur ini.';
          case 404:
            return 'Data atau layanan yang diminta tidak ditemukan.';
          case 500:
          case 502:
          case 503:
            return 'Server kampus sedang mengalami gangguan. Silakan coba beberapa saat lagi.';
          default:
            return 'Terjadi kesalahan dari server (Kode: $statusCode).';
        }

      case DioExceptionType.cancel:
        return 'Permintaan ke server dibatalkan.';

      case DioExceptionType.connectionError:
        return 'Gagal terhubung ke server. Pastikan perangkat terhubung ke internet.';

      case DioExceptionType.badCertificate:
        return 'Sertifikat keamanan server tidak valid.';

      case DioExceptionType.unknown:
      default:
        return 'Terjadi gangguan jaringan atau error tidak terduga.';
    }
  }
}
