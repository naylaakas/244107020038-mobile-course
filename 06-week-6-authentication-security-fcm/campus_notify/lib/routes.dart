/// Definisi rute terpusat untuk Campus Notification App.
/// Menyatukan konfigurasi rute GoRouter dan deep link FCM.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String home = '/';
  static const String announcement = '/pengumuman/:id';

  /// Helper untuk membangun rute detail pengumuman dengan parameter id
  static String announcementDetails(String id) => '/pengumuman/$id';
}

/// Fungsi murni untuk mem-parsing payload data notifikasi menjadi rute navigasi.
/// Dapat di-unit-test secara independen tanpa ketergantungan pada SDK Firebase.
String routeFromMessage(Map<String, dynamic> data) {
  // Ambil route langsung dari data jika tersedia
  var route = data['route']?.toString().trim();

  // Jika route kosong tetapi id tersedia, arahkan ke rute detail pengumuman
  if ((route == null || route.isEmpty) && data.containsKey('id')) {
    final id = data['id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      return AppRoutes.announcementDetails(id);
    }
  }

  // Jika tetap kosong, default ke beranda
  if (route == null || route.isEmpty) {
    return AppRoutes.home;
  }

  // Pastikan selalu diawali dengan '/'
  if (!route.startsWith('/')) {
    route = '/$route';
  }

  return route;
}
