import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../local/db.dart';
import '../local/post.dart';

class PostRepository {
  PostRepository({
    Future<Database> Function()? openDb,
    Dio? dio,
  })  : _openDb = openDb ?? openNotesDb,
        _dio = dio ?? Dio();

  final Future<Database> Function() _openDb;
  final Dio _dio;

  Future<List<Post>> readCachedPosts() async {
    final db = await _openDb();
    final rows = await db.query('cached_posts');
    return rows.map((row) {
      final payload = row['payload'] as String;
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return Post.fromMap(map);
    }).toList();
  }

  Future<void> savePostsToCache(List<Post> posts) async {
    final db = await _openDb();
    final batch = db.batch();
    batch.delete('cached_posts');
    for (final post in posts) {
      batch.insert('cached_posts', {
        'id': post.id,
        'payload': jsonEncode({'id': post.id, 'title': post.title, 'body': post.body}),
        'cached_at': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Post>> loadPostsCacheFirst({
    Function()? onRefreshed,
    bool forceOffline = false,
  }) async {
    final cached = await readCachedPosts();
    if (forceOffline) {
      return cached;
    }
    
    _dio.get('https://jsonplaceholder.typicode.com/posts').then((response) async {
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final posts = data.map((json) => Post.fromMap(json as Map<String, dynamic>)).toList();
        await savePostsToCache(posts);
        if (onRefreshed != null) onRefreshed();
      }
    }).catchError((_) {
  });

    return cached;
  }
}