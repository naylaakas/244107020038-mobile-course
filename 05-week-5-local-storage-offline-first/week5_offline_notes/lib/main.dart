import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pages/note_detail_page.dart';
import 'pages/notes_page.dart';
import 'pages/post_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkModeAsync = ref.watch(darkModeProvider);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return const NotesPage();
          },
        ),
        GoRoute(
          path: '/note/:id',
          builder: (context, state) {
            final id = int.parse(
              state.pathParameters['id']!,
            );

            return NoteDetailPage(id: id);
          },
        ),
        GoRoute(
          path: '/posts',
          builder: (context, state) {
            return const PostsPage();
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) {
            return const SettingsPage();
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Offline Notes',
      routerConfig: router,
      themeMode: darkModeAsync.maybeWhen(
        data: (isDark) =>
            isDark ? ThemeMode.dark : ThemeMode.light,
        orElse: () => ThemeMode.light,
      ),
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
    );
  }
}