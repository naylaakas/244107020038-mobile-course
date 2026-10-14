import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../routes.dart';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

/// Menyimpan rute tertunda saat notifikasi diklik sebelum router siap.
String? pendingDeepLink;

/// Token FCM yang tersimpan saat ini (dalam memori)
String? lastFcmToken;

/// Background message handler wajib berupa fungsi top-level
/// dan ditandai dengan @pragma('vm:entry-point') agar tidak di-tree-shake oleh compiler.
///
/// PERINGATAN PENTING:
/// 1. Dijalankan pada isolate Dart terpisah saat aplikasi di background / terminated.
/// 2. DILARANG mengakses BuildContext atau State Management (seperti Riverpod) di sini.
/// 3. Navigasi UI TIDAK boleh dilakukan di sini; navigasi dilakukan saat banner diklik.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Hanya lakukan logging atau penyimpanan lokal ringan jika diperlukan.
  if (kDebugMode) {
    debugPrint('Background message ID: ${message.messageId}');
  }
}

/// Mendaftarkan background message handler ke Firebase Messaging.
void registerBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

/// Meminta izin notifikasi runtime.
/// - Pada Android 13+ (API 33+), ini memicu prompt runtime permission POST_NOTIFICATIONS.
/// - Pada Android 12 ke bawah, permission diberikan saat instalasi aplikasi.
/// - Pada iOS, ini meminta izin alert, badge, dan suara ke Apple Push Notification service (APNs).
Future<bool> requestNotificationPermission() async {
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: false,
    carPlay: false,
    criticalAlert: false,
  );

  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

/// Inisialisasi plugin notifikasi lokal (flutter_local_notifications).
Future<void> initLocalNotifications({
  void Function(String route)? onSelectNotification,
}) async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();

  await _local.initialize(
    settings: const InitializationSettings(
      android: android,
      iOS: ios,
    ),
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        pendingDeepLink = payload;
        if (onSelectNotification != null) {
          onSelectNotification(payload);
        }
      }
    },
  );

  // Buat Notification Channel untuk Android (wajib Android 8.0+)
  const channel = AndroidNotificationChannel(
    'campus_notify',
    'Campus Notify',
    description: 'Notifikasi Pengumuman Kampus',
    importance: Importance.high,
  );

  final androidPlugin = _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(channel);
}

/// Mengambil registration token FCM dan memantau perubahannya (token lifecycle).
/// Listener [onTokenRefresh] WAJIB ada agar saat token kadaluwarsa/berubah
/// (misal reinstall atau rotasi keamanan), backend menerima token terbaru.
Future<void> initFcmToken({
  required Future<void> Function(String token) onToken,
}) async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    lastFcmToken = token;
    // Log aman (token terpotong) untuk mencegah kebocoran kredensial di log
    if (kDebugMode) {
      debugPrint('FCM Token didapat: ${maskToken(token)}');
    }
    await onToken(token);
  }

  // Wajib pantau perubahan token
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    lastFcmToken = newToken;
    if (kDebugMode) {
      debugPrint('FCM Token diperbarui: ${maskToken(newToken)}');
    }
    await onToken(newToken);
  });

  // Langganan topik default pengumuman kampus
  await subscribeTopic('pengumuman-kampus');
}

/// Menangani notifikasi saat aplikasi berada di Foreground dan Background (diklik).
void setupForegroundAndOpenedAppListeners(void Function(String route) go) {
  // 1. STATE FOREGROUND:
  // Sistem operasi TIDAK menampilkan banner notifikasi secara otomatis saat app terbuka.
  // Karena itu, kita tampilkan secara manual menggunakan flutter_local_notifications.
  FirebaseMessaging.onMessage.listen((message) async {
    if (kDebugMode) {
      debugPrint('Foreground message diterima: ${message.messageId}');
    }

    final route = routeFromMessage(message.data);
    final notification = message.notification;

    await _local.show(
      id: message.hashCode,
      title: notification?.title ?? 'Pengumuman Baru',
      body: notification?.body ?? 'Ada pengumuman baru untuk Anda.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'campus_notify',
          'Campus Notify',
          channelDescription: 'Notifikasi Pengumuman Kampus',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: route,
    );
  });

  // 2. STATE BACKGROUND (banner sistem diklik pengguna):
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    final route = routeFromMessage(message.data);
    go(route);
  });
}

/// Menangani STATE TERMINATED: saat aplikasi dimatikan penuh lalu dibuka dari klik banner.
Future<void> handleTerminated(void Function(String route) go) async {
  // Cek apakah aplikasi diluncurkan dari notifikasi Firebase
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    final route = routeFromMessage(initial.data);
    go(route);
    return;
  }

  // Cek jika ada notifikasi lokal tertunda
  if (pendingDeepLink != null) {
    final route = pendingDeepLink!;
    pendingDeepLink = null;
    go(route);
  }
}

/// Berlangganan ke topik broadcast kampus.
Future<void> subscribeTopic(String topic) async {
  await FirebaseMessaging.instance.subscribeToTopic(topic);
}

/// Berhenti berlangganan dari topik broadcast kampus.
Future<void> unsubscribeTopic(String topic) async {
  await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}

/// Helper untuk menyamarkan (masking) token FCM agar aman ditampilkan pada UI & log.
/// Menampilkan 12 karakter pertama diikuti elipsis '...'.
String maskToken(String token) {
  if (token.length <= 12) return token;
  return '${token.substring(0, 12)}...';
}
