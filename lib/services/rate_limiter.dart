import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Pembatas laporan per perangkat dalam 24 jam (anti-spam sederhana).
/// Catatan: bersifat di sisi aplikasi, bukan pengaman mutlak.
class RateLimiter {
  RateLimiter._();

  static const String _key = 'cleanreport.sentAt.v1';
  static const int _windowMs = 24 * 60 * 60 * 1000;

  static List<int> _recent(SharedPreferences p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (p.getStringList(_key) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .where((t) => now - t < _windowMs)
        .toList();
  }

  static Future<bool> canSend() async {
    try {
      final p = await SharedPreferences.getInstance();
      return _recent(p).length < AppConfig.dailyLimit;
    } catch (_) {
      return true;
    }
  }

  static Future<void> record() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = _recent(p)..add(DateTime.now().millisecondsSinceEpoch);
      await p.setStringList(_key, list.map((e) => '$e').toList());
    } catch (_) {}
  }
}
