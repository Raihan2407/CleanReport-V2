import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../format.dart';

/// Alasan lokasi gagal didapat (untuk pesan yang jelas bagi pengguna).
enum LocationIssue { serviceOff, denied, deniedForever, failed }

class LocationFix {
  const LocationFix.ok(this.point, this.accuracy) : issue = null;
  const LocationFix.fail(this.issue)
      : point = null,
        accuracy = null;

  final LatLng? point;

  /// Perkiraan akurasi dalam meter.
  final double? accuracy;
  final LocationIssue? issue;

  bool get ok => point != null;
}

class AddressInfo {
  const AddressInfo(this.title, this.sub);

  final String title;
  final String sub;
}

class LocationService {
  LocationService._();

  /// Memeriksa GPS & izin. Mengembalikan null bila semuanya siap.
  static Future<LocationIssue?> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocationIssue.serviceOff;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) return LocationIssue.denied;
      if (perm == LocationPermission.deniedForever) return LocationIssue.deniedForever;
      return null;
    } catch (_) {
      return LocationIssue.failed;
    }
  }

  /// Mengambil posisi sekali. Tidak pernah melempar error.
  static Future<LocationFix> current() async {
    final problem = await ensurePermission();
    if (problem != null) return LocationFix.fail(problem);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationFix.ok(LatLng(pos.latitude, pos.longitude), pos.accuracy);
    } on TimeoutException {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LocationFix.ok(LatLng(last.latitude, last.longitude), last.accuracy);
        }
      } catch (_) {}
      return const LocationFix.fail(LocationIssue.failed);
    } catch (_) {
      return const LocationFix.fail(LocationIssue.failed);
    }
  }

  static Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
  }

  // Kode plus Google (mis. "FPQ8+XY") tidak ramah dibaca; dibuang.
  static final RegExp _plusCode = RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,}');

  static String _clean(String? s) {
    final t = (s ?? '').trim();
    return (t.isEmpty || _plusCode.hasMatch(t)) ? '' : t;
  }

  /// Mengubah koordinat menjadi alamat yang mudah dibaca. Bila gagal
  /// (offline, dll) dikembalikan teks netral + koordinat.
  static Future<AddressInfo> address(LatLng p) async {
    final coords = fmtCoord(p.latitude, p.longitude);
    try {
      final list = await placemarkFromCoordinates(p.latitude, p.longitude)
          .timeout(const Duration(seconds: 8));
      if (list.isEmpty) return AddressInfo('Lokasi terpilih', coords);
      final m = list.first;

      var title = _clean(m.street);
      if (title.isEmpty) title = _clean(m.thoroughfare);
      if (title.isEmpty) title = _clean(m.name);

      final subs = <String>[];
      for (final s in [m.subLocality, m.locality, m.subAdministrativeArea]) {
        final t = _clean(s);
        if (t.isNotEmpty && t != title && !subs.contains(t)) subs.add(t);
      }
      if (title.isEmpty) {
        title = subs.isNotEmpty ? subs.removeAt(0) : 'Lokasi terpilih';
      }
      return AddressInfo(title, subs.isEmpty ? coords : subs.join(', '));
    } catch (_) {
      return AddressInfo('Lokasi terpilih', coords);
    }
  }
}

/// Posisi GPS realtime (aliran data lokasi). Dipakai peta untuk titik biru
/// yang bergerak. Berhenti otomatis lewat [stop] agar hemat baterai.
class LiveLocation extends ChangeNotifier {
  StreamSubscription<Position>? _sub;
  bool _starting = false;
  bool _disposed = false;

  LatLng? point;

  /// Akurasi dalam meter (makin kecil makin teliti).
  double? accuracy;
  LocationIssue? issue;

  bool get active => _sub != null;
  bool get starting => _starting;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_sub != null || _starting) return;
    _starting = true;
    issue = null;
    _notify();

    final problem = await LocationService.ensurePermission();
    if (problem != null) {
      issue = problem;
      _starting = false;
      _notify();
      return;
    }
    try {
      // Pembacaan cepat pertama, agar titik tidak menunggu pergerakan.
      unawaited(LocationService.current().then((fix) {
        if (fix.ok && point == null) {
          point = fix.point;
          accuracy = fix.accuracy;
          _notify();
        }
      }));
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2,
        ),
      ).listen(
        (p) {
          point = LatLng(p.latitude, p.longitude);
          accuracy = p.accuracy;
          issue = null;
          _notify();
        },
        onError: (Object _) {
          issue = LocationIssue.failed;
          _notify();
        },
      );
    } catch (_) {
      issue = LocationIssue.failed;
    }
    _starting = false;
    _notify();
  }

  Future<void> stop() async {
    final s = _sub;
    _sub = null;
    await s?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
