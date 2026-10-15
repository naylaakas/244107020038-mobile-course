/// Fungsi murni untuk memformat tanggal dan parsing rute
class AppFormatters {
  AppFormatters._();

  /// Memformat DateTime menjadi string ringkas YYYY-MM-DD
  static String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Mem-parsing rute dari payload notifikasi
  static String parseRoute(Map<String, dynamic> data) {
    final route = data['route']?.toString().trim();
    if (route != null && route.isNotEmpty) {
      return route.startsWith('/') ? route : '/$route';
    }
    final id = data['id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      return '/pengumuman/$id';
    }
    return '/';
  }
}