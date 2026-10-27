import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifikasi lokal (gratis, tanpa server) saat status laporan berubah.
/// Muncul selama aplikasi masih hidup (terbuka atau baru saja ditinggalkan);
/// bila aplikasi benar-benar ditutup, pemberitahuan baru muncul saat dibuka lagi
/// (lewat penanda "Pembaruan baru" di Riwayat).
class NotifyService {
  NotifyService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Android 13+ meminta izin notifikasi. Dipanggil setelah laporan pertama terkirim.
  static Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> show(String title, String body) async {
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'status_laporan',
          'Status laporan',
          channelDescription: 'Pemberitahuan saat status laporan sampah Anda berubah',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      final id = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000000;
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }
}
