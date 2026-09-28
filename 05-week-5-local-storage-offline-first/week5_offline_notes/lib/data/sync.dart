import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import 'local/db.dart';
import 'local/post.dart';
import 'repositories/note_repository.dart';

final Dio _dio = Dio(
  BaseOptions(
    baseUrl: 'https://jsonplaceholder.typicode.com',
  ),
);

Future<List<Post>> readCachedPosts() async {
  final db = await openNotesDb();

  final rows = await db.query(
    'cached_posts',
    orderBy: 'cached_at DESC',
  );

  return rows.map((row) {
    final payload = jsonDecode(row['payload'] as String);

    return Post.fromJson(
      Map<String, dynamic>.from(payload as Map),
    );
  }).toList();
}

Future<void> savePostsToCache(List<Post> posts) async {
  final db = await openNotesDb();
  final batch = db.batch();

  for (final post in posts) {
    batch.insert(
      'cached_posts',
      {
        'id': post.id,
        'payload': jsonEncode(post.toJson()),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  await batch.commit(noResult: true);
}

Future<List<Post>> loadPostsCacheFirst({
  bool forceOffline = false,
}) async {
  final cached = await readCachedPosts();

  if (!forceOffline) {
    refreshPostsInBackground();
  }

  return cached;
}

Future<void> refreshPostsInBackground() async {
  try {
    final response = await _dio.get('/posts');

    if (response.data is! List) {
      return;
    }

    final posts = (response.data as List)
        .map(
          (item) => Post.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    await savePostsToCache(posts);
  } catch (_) {}
}

Future<int> syncNotes(NoteRepository repo) async {
  final dirtyCount = await repo.countDirty();

  if (dirtyCount == 0) {
    return 0;
  }

  await Future.delayed(
    const Duration(seconds: 1),
  );

  await repo.markAllSynced();

  return dirtyCount;
}