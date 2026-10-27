import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../firebase_options.dart';
import '../models.dart';
import 'cloud_report_repository.dart';
import 'notify_service.dart';
import 'rate_limiter.dart';
import 'report_repository.dart';

/// Status global aplikasi: daftar laporan (realtime bila memakai Firebase),
/// tab aktif, penanda pembaruan, dan pilihan backend.
class ReportStore extends ChangeNotifier {
  static const String _kSeen = 'cleanreport.seenStatus.v1';

  ReportRepository? _repo;
  Future<void>? _ready;
  StreamSubscription<List<Report>>? _sub;

  List<Report> reports = const [];
  bool loading = true;
  String? error;

  /// Id laporan yang statusnya berubah dan belum dilihat pengguna.
  final Set<String> updatedIds = <String>{};

  /// Tab aktif pada HomeShell (0 = Lapor, 1 = Riwayat).
  final ValueNotifier<int> tab = ValueNotifier<int>(0);

  /// Dinaikkan setiap laporan terkirim agar layar Lapor mengosongkan form.
  final ValueNotifier<int> resetTick = ValueNotifier<int>(0);

  bool get isCloud => _repo?.isCloud ?? false;

  /// Aman dipanggil berulang kali.
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    unawaited(NotifyService.init());
    try {
      _repo = await _tryCloud();
    } catch (_) {
      _repo = null;
    }
    _repo ??= LocalReportRepository();
    await _start();
  }

  /// Memakai Firebase hanya bila firebase_options.dart sudah diisi.
  Future<ReportRepository?> _tryCloud() async {
    try {
      final o = DefaultFirebaseOptions.currentPlatform;
      if (o.apiKey.isEmpty || o.apiKey.startsWith('ISI_')) return null;
      await Firebase.initializeApp(options: o).timeout(const Duration(seconds: 10));
      return CloudReportRepository();
    } catch (_) {
      return null;
    }
  }

  Future<void> _start() async {
    final repo = _repo;
    if (repo == null) return;
    await _sub?.cancel();
    _sub = null;

    final stream = repo.watch();
    if (stream == null) {
      await _loadOnce(repo);
      return;
    }
    loading = reports.isEmpty;
    error = null;
    notifyListeners();
    _sub = stream.listen(
      _onReports,
      onError: (Object _) {
        error =
            'Riwayat belum bisa dimuat. Periksa koneksi internet lalu tarik layar ke bawah untuk mencoba lagi.';
        loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _loadOnce(ReportRepository repo) async {
    loading = reports.isEmpty;
    error = null;
    notifyListeners();
    try {
      reports = await repo.load();
    } catch (_) {
      error =
          'Riwayat belum bisa dimuat. Periksa koneksi internet lalu tarik layar ke bawah untuk mencoba lagi.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refresh() => _ready == null ? init() : _start();

  void _onReports(List<Report> list) {
    reports = list;
    loading = false;
    error = null;
    notifyListeners();
    unawaited(_detectChanges(list));
  }

  /// Membandingkan status terakhir yang diketahui dengan data terbaru; bila
  /// berubah (mis. admin mengubah status) -> notifikasi + penanda "baru".
  Future<void> _detectChanges(List<Report> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSeen);
      final seeded = raw != null;
      final seen = <String, String>{};
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) => seen['$k'] = '$v');
        }
      }
      var dirty = false;
      var uiChanged = false;
      for (final r in list) {
        final prev = seen[r.id];
        final now = r.status.name;
        if (prev == now) continue;
        seen[r.id] = now;
        dirty = true;
        if (seeded && prev != null && r.status != ReportStatus.received) {
          updatedIds.add(r.id);
          uiChanged = true;
          unawaited(NotifyService.show(
            'CleanReport ${r.code}',
            r.status == ReportStatus.done
                ? 'Sampah sudah dibersihkan. Buka untuk melihat hasilnya.'
                : 'Petugas sedang menuju lokasi laporan Anda.',
          ));
        }
      }
      if (dirty) await prefs.setString(_kSeen, jsonEncode(seen));
      if (uiChanged) notifyListeners();
    } catch (_) {}
  }

  Future<void> _rememberStatus(Report r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSeen);
      final seen = <String, String>{};
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) => seen['$k'] = '$v');
        }
      }
      seen[r.id] = r.status.name;
      await prefs.setString(_kSeen, jsonEncode(seen));
    } catch (_) {}
  }

  /// Dipanggil saat pengguna membuka detail laporan.
  void markSeen(String id) {
    if (updatedIds.remove(id)) notifyListeners();
  }

  String newDraftId() =>
      _repo?.newId() ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  /// Menyimpan laporan. Melempar error bila gagal agar UI bisa menawarkan "Coba lagi".
  Future<Report> submit(ReportDraft draft) async {
    await init();
    final repo = _repo!;
    if (!await RateLimiter.canSend()) {
      throw const ReportException(
          'Batas ${AppConfig.dailyLimit} laporan per 24 jam sudah tercapai. Coba lagi besok.');
    }
    draft.id ??= repo.newId();
    final report = await repo.submit(draft);
    await RateLimiter.record();
    await _rememberStatus(report);

    reports = [report, ...reports.where((r) => r.id != report.id)];
    error = null;
    loading = false;
    notifyListeners();
    resetTick.value++;
    unawaited(NotifyService.requestPermission());
    return report;
  }

  Future<List<StatusEntry>> historyOf(Report r) async {
    try {
      return await _repo!.loadHistory(r);
    } catch (_) {
      return r.history;
    }
  }

  Future<List<NearbyPoint>> nearby(LatLng c) async {
    try {
      await init();
      return await _repo!.nearby(c.latitude, c.longitude, AppConfig.nearbyMeters);
    } catch (_) {
      return const [];
    }
  }
}

/// Instans tunggal yang dipakai seluruh layar.
final ReportStore store = ReportStore();
