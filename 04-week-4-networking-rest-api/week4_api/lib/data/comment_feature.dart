import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

// ==========================================
// 1. MODEL COMMENT
// ==========================================
class Comment {
  const Comment({
    required this.postId,
    required this.id,
    required this.name,
    required this.email,
    required this.body,
  });

  final int postId;
  final int id;
  final String name;
  final String email;
  final String body;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      postId: (json['postId'] as num?)?.toInt() ?? 0,
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'id': id,
        'name': name,
        'email': email,
        'body': body,
      };
}

// ==========================================
// 2. REPOSITORY
// ==========================================
class CommentRepository {
  CommentRepository(this._dio);
  final Dio _dio;

  Future<List<Comment>> fetchComments(int postId) async {
    final response = await _dio.get<List<dynamic>>(
      '/comments',
      queryParameters: {'postId': postId},
    );

    final data = response.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();
  }
}

// ==========================================
// 3. PROVIDER (Memakai FutureProvider.family)
// ==========================================
// Ini otomatis menghasilkan AsyncValue (AsyncLoading, AsyncData, AsyncError)
// tanpa masalah class notifier
final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(ref.watch(dioProvider)),
);

final commentListProvider =
    FutureProvider.autoDispose.family<List<Comment>, int>((ref, postId) async {
  final repository = ref.watch(commentRepositoryProvider);
  return repository.fetchComments(postId);
});

// ==========================================
// 4. PESAN ERROR RAMAH PENGGUNA
// ==========================================
String friendlyCommentErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi lambat atau waktu tunggu habis (timeout). Silakan periksa jaringan dan coba lagi.';
      case DioExceptionType.connectionError:
        return 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 404) return 'Komentar tidak ditemukan (404).';
        if (code == 500) {
          return 'Terjadi gangguan pada server internal (500). Silakan coba lagi nanti.';
        }
        return 'Server bermasalah ($code). Coba lagi nanti.';
      default:
        return 'Terjadi masalah pada jaringan. Silakan coba lagi.';
    }
  }
  return 'Terjadi kesalahan: $error';
}