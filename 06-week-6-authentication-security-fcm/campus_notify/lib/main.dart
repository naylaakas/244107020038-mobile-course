import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';

import 'messaging/push_service.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/announcement_page.dart';
import 'providers/auth_provider.dart';
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
    final authState = ref.watch(authStateProvider);
    final loggedIn = authState.value ?? false;

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      redirect: (context, state) {
        final goingLogin = state.matchedLocation == AppRoutes.login;

        if (!loggedIn && !goingLogin) {
          return AppRoutes.login;
        }

        if (loggedIn && goingLogin) {
          return AppRoutes.home;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const HomePage(),
        ),
        GoRoute(
          path: AppRoutes.announcement,
          builder: (_, state) => AnnouncementPage(
            id: state.pathParameters['id'] ?? '',
          ),
        ),
        // Rute alternatif untuk kompatibilitas tautan bahasa Inggris
        GoRoute(
          path: '/announcement/:id',
          redirect: (_, state) =>
              AppRoutes.announcementDetails(state.pathParameters['id'] ?? ''),
        ),
      ],
    );

    _rootRouter = router;

    // Jika ada pending deep link saat boot, eksekusi navigasi
    if (pendingDeepLink != null) {
      final target = pendingDeepLink!;
      pendingDeepLink = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.go(target);
      });
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}