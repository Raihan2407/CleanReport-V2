import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../geo.dart';
import '../models.dart';

/// Kesalahan yang pesannya aman ditampilkan langsung ke pengguna.
class ReportException implements Exception {
  const ReportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data laporan. Ada dua implementasi:
///  - [LocalReportRepository]  : tersimpan di HP (dipakai bila Firebase belum
///                               dikonfigurasi, sehingga aplikasi tetap bisa
///                               dipakai/di-demo).
///  - CloudReportRepository    : Firebase Auth anonim + Firestore (paket gratis
///                               Spark, tanpa Cloud Storage).
abstract class ReportRepository {
  bool get isCloud;

  /// Id baru untuk draft laporan.
  String newId();

  /// Pemuatan sekali.
  Future<List<Report>> load();

  /// Aliran realtime daftar laporan; null bila repositori tidak mendukung.
  Stream<List<Report>>? watch();

  /// Menyimpan laporan beserta foto. Melempar error bila gagal, dan tidak
  /// boleh meninggalkan data setengah tersimpan.
  Future<Report> submit(ReportDraft draft);

  /// Riwayat status satu laporan (untuk linimasa pada halaman Detail).
  Future<List<StatusEntry>> loadHistory(Report report);

  /// Laporan lain (yang belum selesai) dalam radius [meters] dari titik.
  Future<List<NearbyPoint>> nearby(double lat, double lng, double meters);

  /// Menghapus laporan beserta riwayat status dan titik publiknya.
  Future<void> delete(Report report);
}

class LocalReportRepository implements ReportRepository {
  static const String _kReports = 'cleanreport.reports.v1';
  static const String _kUser = 'cleanreport.localUser';

  @override
  bool get isCloud => false;

  @override
  Stream<List<Report>>? watch() => null;

  @override
  String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<String> _userId(SharedPreferences prefs) async {
    var id = prefs.getString(_kUser);
    if (id == null || id.isEmpty) {
      id = 'local-${newId()}';
      await prefs.setString(_kUser, id);
    }
    return id;
  }

  @override
  Future<List<Report>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kReports);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Report.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Report> submit(ReportDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final id = draft.id ?? newId();
    draft.id = id;

    // Salin foto ke penyimpanan aplikasi supaya tidak hilang saat cache dibersihkan.
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/reports');
    if (!await folder.exists()) await folder.create(recursive: true);
    final dest = '${folder.path}/$id.jpg';
    await File(draft.photoPath).copy(dest);

    final now = DateTime.now();
    final report = Report(
      id: id,
      userId: await _userId(prefs),
      category: draft.category,
      landmark: draft.landmark,
      reporterName: draft.reporterName,
      anonymous: draft.anonymous,
      lat: draft.lat,
      lng: draft.lng,
      addressTitle: draft.addressTitle,
      addressSub: draft.addressSub,
      photo: dest,
      status: ReportStatus.received,
      createdAt: now,
      history: [StatusEntry(status: ReportStatus.received, at: now)],
    );

    final all = await load();
    all.removeWhere((r) => r.id == id);
    all.insert(0, report);
    await prefs.setString(
        _kReports, jsonEncode(all.map((r) => r.toJson()).toList()));
    return report;
  }

  @override
  Future<List<StatusEntry>> loadHistory(Report report) async => report.history;

  @override
  Future<void> delete(Report report) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await load();
    all.removeWhere((r) => r.id == report.id);
    await prefs.setString(
        _kReports, jsonEncode(all.map((r) => r.toJson()).toList()));
    // Hapus juga berkas foto di HP.
    try {
      if (report.photo.isNotEmpty &&
          !report.photo.startsWith('b64:') &&
          !report.photo.startsWith('http')) {
        final f = File(report.photo);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  @override
  Future<List<NearbyPoint>> nearby(
      double lat, double lng, double meters) async {
    final all = await load();
    final out = <NearbyPoint>[];
    for (final r in all) {
      if (r.status == ReportStatus.done || r.status == ReportStatus.rejected)
        continue;
      final d = distanceMeters(lat, lng, r.lat, r.lng);
      if (d <= meters) {
        out.add(NearbyPoint(
          id: r.id,
          lat: r.lat,
          lng: r.lng,
          category: r.category,
          status: r.status,
          createdAt: r.createdAt,
          mine: true,
          distance: d,
        ));
      }
    }
    out.sort((a, b) => a.distance.compareTo(b.distance));
    return out;
  }
}
