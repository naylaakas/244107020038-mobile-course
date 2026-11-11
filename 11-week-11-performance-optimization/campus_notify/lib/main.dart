import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';

import 'messaging/push_service.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/announcements/presentation/pages/home_page.dart';
import 'features/announcements/presentation/pages/announcement_page.dart';
import 'features/notes/presentation/pages/notes_page.dart';
import 'features/chat_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'routes.dart';

GoRouter? _rootRouter;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Firebase Core
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase Core: Berhasil diinisialisasi');

    // 2. Daftarkan background message handler (wajib setelah Firebase.initializeApp)
    try {
      registerBackgroundHandler();
      debugPrint('FCM: Background handler terdaftar');
    } catch (e) {
      debugPrint('FCM: Peringatan background handler: $e');
    }

    // 3. Minta izin runtime notifikasi (Android 13+ & iOS)
    try {
      final granted = await requestNotificationPermission();
      debugPrint('FCM: Status izin notifikasi: $granted');
    } catch (e) {
      debugPrint('FCM: Peringatan requestPermission: $e');
    }

    // 4. Inisialisasi plugin notifikasi lokal untuk banner foreground
    try {
      await initLocalNotifications(
        onSelectNotification: (route) {
          _rootRouter?.go(route);
        },
      );
      debugPrint('Local Notifications: Berhasil diinisialisasi');
    } catch (e) {
      debugPrint('Local Notifications: Peringatan inisialisasi: $e');
    }

    // 5. Ambil registration token & pasang listener onTokenRefresh + subscribe topik
    try {
      await initFcmToken(
        onToken: (token) async {
          debugPrint('FCM TOKEN: $token');
        },
      );
      debugPrint('FCM: Token & Topic listener aktif');
    } catch (e) {
      debugPrint('FCM: Peringatan getToken / topic: $e');
    }

    // 6. Setup listener Foreground, Background, dan Terminated
    try {
      setupForegroundAndOpenedAppListeners((route) {
        _rootRouter?.go(route);
      });
      await handleTerminated((route) {
        _rootRouter?.go(route);
      });
      debugPrint('FCM: Router listener siap');
    } catch (e) {
      debugPrint('FCM: Peringatan setup listeners: $e');
    }
  } catch (e) {
    debugPrint('Firebase.initializeApp() Gagal: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

/// Widget root aplikasi — dipisah menjadi ConsumerStatefulWidget
/// agar GoRouter dapat di-dispose dengan benar saat widget dilepas dari tree.
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
    _rootRouter = _router;

    // Eksekusi pending deep link setelah router siap
    if (pendingDeepLink != null) {
      final target = pendingDeepLink!;
      pendingDeepLink = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _router.go(target);
      });
    }
  }

  @override
  void dispose() {
    // Perbaikan Langkah 5: dispose() GoRouter mencegah memory leak
    // stream subscription router (routerDelegate, listener navigasi) dilepas
    _router.dispose();
    _rootRouter = null;
    super.dispose();
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.home,
      redirect: (context, state) {
        final loggedIn = ref.read(authStateProvider).value ?? false;
        final goingLogin = state.matchedLocation == AppRoutes.login;

        if (!loggedIn && !goingLogin) return AppRoutes.login;
        if (loggedIn && goingLogin) return AppRoutes.home;
        return null;
      },
      routes: [
        GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
        GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
        GoRoute(
          path: AppRoutes.announcement,
          builder: (_, state) =>
              AnnouncementPage(id: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(path: AppRoutes.notes, builder: (_, _) => const NotesPage()),
        GoRoute(path: AppRoutes.aiChat, builder: (_, _) => const ChatScreen()),
        GoRoute(
          path: '/announcement/:id',
          redirect: (_, state) =>
              AppRoutes.announcementDetails(state.pathParameters['id'] ?? ''),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pantau perubahan auth state agar redirect berjalan saat login/logout
    ref.listen(authStateProvider, (_, _) => _router.refresh());

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
