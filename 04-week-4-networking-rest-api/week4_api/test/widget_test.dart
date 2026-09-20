import 'package:flutter_test/flutter_test.dart';
import 'package:week4_api/data/comment_feature.dart';

void main() {
  group('Comment Model Tests', () {
    // Verifikasi fromJson aman ketika field bernilai null atau hilang
    test('fromJson aman ketika field bernilai null atau hilang sama sekali', () {
      final Map<String, dynamic> jsonRusak = {
        'postId': null,
        // 'id' dihilangkan sama sekali dari map
        'name': null,
        // 'email' dihilangkan sama sekali dari map
        'body': null,
      };

      final comment = Comment.fromJson(jsonRusak);

      expect(comment.postId, 0);
      expect(comment.id, 0);
      expect(comment.name, '');
      expect(comment.email, '');
      expect(comment.body, '');
    });

    // EDGE CASE SENDIRI: Menguji tipe data angka yang dikirim API berupa format double/desimal
    // Kasus nyata: parser backend kadang mengirim ID angka sebagai format float/double 
    test('Edge case: fromJson aman menerima angka bertipe double tanpa crash', () {
      final Map<String, dynamic> jsonDouble = {
        'postId': 42.0,
        'id': 105.0,
        'name': 'Budi Santoso',
        'email': 'budi@example.com',
        'body': 'Komentar pengujian edge case',
      };

      final comment = Comment.fromJson(jsonDouble);

      // Verifikasi konversi num?.toInt() berhasil tanpa melempar TypeError
      expect(comment.postId, 42);
      expect(comment.id, 105);
      expect(comment.name, 'Budi Santoso');
    });
  });
}