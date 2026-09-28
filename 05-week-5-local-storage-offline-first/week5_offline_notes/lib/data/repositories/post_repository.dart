import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../local/db.dart';

class Post {
  final int id;
  final String title;
  final String body;

  Post({required this.id, required this.title, required this.body});

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
}

class PostRepository {
  final Dio _dio = Dio();

  // Membaca data cache dari tabel cached_posts
  Future<List<Post>> readCachedPosts() async {
    final db = await openNotesDb();
    final rows = await db.query('cached_posts');
    return rows.map((row) {
      final payload = jsonDecode(row['payload'] as String);
      return Post.fromJson(payload);
    }).toList();
  }

  // Ambil data baru dari API & simpan ke SQLite di background
  Future<void> refreshPostsInBackground() async {
    try {
      final response = await _dio.get('https://jsonplaceholder.typicode.com/posts');
      if (response.statusCode == 200) {
        final List data = response.data;
        final db = await openNotesDb();
        final batch = db.batch();
        for (var item in data) {
          batch.insert(
            'cached_posts',
            {
              'id': item['id'],
              'payload': jsonEncode(item),
              'cached_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    } catch (_) {
      // Jika offline, abaikan error agar aplikasi tetap pakai data cache
    }
  }

  // --- KODE UTAMA JOBSHEET ---
  Future<List<Post>> loadPostsCacheFirst() async {
    final cached = await readCachedPosts(); // 1. Ambil cache lokal seketika
    refreshPostsInBackground();              // 2. Fetch Dio di background
    return cached;                           // 3. Kembalikan cache agar UI tidak blank
  }
}