import 'package:flutter/material.dart';

import 'format.dart';
import 'theme.dart';

/// Status sebuah laporan sampah.
/// Catatan proposal (2.11): hanya [received] yang diberikan sistem saat
/// laporan tersimpan. [inProgress] dan [done] disiapkan untuk pengembangan
/// lanjutan (pembaruan oleh petugas).
enum ReportStatus { received, inProgress, done }

ReportStatus statusFromName(String? name) => ReportStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => ReportStatus.received,
    );

extension ReportStatusX on ReportStatus {
  String get label => switch (this) {
        ReportStatus.received => 'Laporan Diterima',
        ReportStatus.inProgress => 'Petugas Meluncur',
        ReportStatus.done => 'Sudah Bersih',
      };

  String get message => switch (this) {
        ReportStatus.received => 'Laporan tersimpan, menunggu ditinjau.',
        ReportStatus.inProgress => 'Petugas sedang menuju lokasi.',
        ReportStatus.done => 'Sampah sudah dibersihkan.',
      };

  IconData get icon => switch (this) {
        ReportStatus.done => Icons.check,
        ReportStatus.inProgress => Icons.local_shipping,
        ReportStatus.received => Icons.inbox,
      };

  Color get pillBg => this == ReportStatus.done ? C.greenLight : C.indigo;
  Color get pillFg => this == ReportStatus.done ? C.greenDeep : C.ink;
  Color get iconColor => this == ReportStatus.done ? C.greenDeep : C.green;

  Color get descColor => switch (this) {
        ReportStatus.done => C.green,
        ReportStatus.inProgress => C.greenMid,
        ReportStatus.received => C.olive,
      };
}

/// Satu baris riwayat perubahan status (ERD: REPORT_STATUS_HISTORY).
class StatusEntry {
  const StatusEntry({required this.status, required this.at, this.note = ''});

  final ReportStatus status;
  final DateTime at;
  final String note;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'at': at.millisecondsSinceEpoch,
        'note': note,
      };

  factory StatusEntry.fromJson(Map<String, dynamic> j) => StatusEntry(
        status: statusFromName(j['status'] as String?),
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
        note: (j['note'] as String?) ?? '',
      );
}

/// Laporan yang sudah tersimpan (ERD: REPORTS).
class Report {
  const Report({
    required this.id,
    required this.userId,
    required this.category,
    required this.lat,
    required this.lng,
    required this.addressTitle,
    required this.photo,
    required this.createdAt,
    this.landmark = '',
    this.reporterName = '',
    this.anonymous = true,
    this.addressSub = '',
    this.status = ReportStatus.received,
    this.history = const [],
    this.photoAfter = '',
    this.pending = false,
  });

  final String id;
  final String userId;
  final String category;
  final String landmark;
  final String reporterName;
  final bool anonymous;
  final double lat;
  final double lng;
  final String addressTitle;
  final String addressSub;

  /// URL (https://...) bila tersimpan di cloud, atau path berkas lokal.
  final String photo;
  final ReportStatus status;
  final DateTime createdAt;
  final List<StatusEntry> history;

  /// Foto "sesudah" yang diunggah admin setelah lokasi dibersihkan (boleh kosong).
  final String photoAfter;

  /// true bila laporan baru tersimpan di HP dan menunggu internet untuk terkirim.
  final bool pending;

  /// Kode pendek yang mudah dibaca, mis. "#CR-8X2KQ".
  String get code {
    final s = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    return '#CR-${s.length > 5 ? s.substring(s.length - 5) : s}';
  }

  TrashCategory get categoryInfo => trashCategories.firstWhere(
        (c) => c.name == category,
        orElse: () => trashCategories.first,
      );

  String get reporterLabel =>
      (anonymous || reporterName.trim().isEmpty) ? 'Anonim' : reporterName.trim();

  /// Teks pada pill status, mis. "Sudah Bersih • 24 Okt".
  String get pillLabel {
    if (status != ReportStatus.done) return status.label;
    final when = history.isEmpty ? createdAt : history.last.at;
    return '${status.label} • ${fmtDate(when)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'category': category,
        'landmark': landmark,
        'reporterName': reporterName,
        'anonymous': anonymous,
        'lat': lat,
        'lng': lng,
        'addressTitle': addressTitle,
        'addressSub': addressSub,
        'photo': photo,
        'photoAfter': photoAfter,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'history': history.map((h) => h.toJson()).toList(),
      };

  factory Report.fromJson(Map<String, dynamic> j) {
    final created =
        DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num?)?.toInt() ?? 0);
    final rawHistory = (j['history'] as List?) ?? const [];
    final history = rawHistory
        .whereType<Map>()
        .map((e) => StatusEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return Report(
      id: (j['id'] as String?) ?? '',
      userId: (j['userId'] as String?) ?? '',
      category: (j['category'] as String?) ?? '',
      landmark: (j['landmark'] as String?) ?? '',
      reporterName: (j['reporterName'] as String?) ?? '',
      anonymous: (j['anonymous'] as bool?) ?? true,
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0,
      addressTitle: (j['addressTitle'] as String?) ?? '',
      addressSub: (j['addressSub'] as String?) ?? '',
      photo: (j['photo'] as String?) ?? '',
      photoAfter: (j['photoAfter'] as String?) ?? '',
      status: statusFromName(j['status'] as String?),
      createdAt: created,
      history: history.isEmpty
          ? [StatusEntry(status: ReportStatus.received, at: created)]
          : history,
    );
  }
}

/// Titik laporan lain di sekitar (tanpa foto & tanpa nama), untuk peringatan
/// laporan ganda dan penanda di peta.
class NearbyPoint {
  const NearbyPoint({
    required this.id,
    required this.lat,
    required this.lng,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.mine,
    required this.distance,
  });

  final String id;
  final double lat;
  final double lng;
  final String category;
  final ReportStatus status;
  final DateTime createdAt;

  /// true bila laporan ini milik pengguna sendiri.
  final bool mine;

  /// Jarak dari titik acuan, dalam meter.
  final double distance;
}

/// Data laporan yang sedang disusun pengguna, sebelum dikirim.
class ReportDraft {
  ReportDraft({
    required this.photoPath,
    required this.lat,
    required this.lng,
    required this.addressTitle,
    required this.addressSub,
  });

  final String photoPath;
  final double lat;
  final double lng;
  final String addressTitle;
  final String addressSub;

  String category = '';
  String landmark = '';
  bool anonymous = true;
  String reporterName = '';

  /// Dibuat sekali per draft supaya percobaan ulang tidak menggandakan data.
  String? id;
}

/// Opsi jenis sampah pada formulir (empat kategori sesuai proposal).
class TrashCategory {
  const TrashCategory({required this.name, required this.sub, required this.icon});

  final String name;
  final String sub;
  final IconData icon;
}

const List<TrashCategory> trashCategories = [
  TrashCategory(name: 'Plastik & Liar', sub: 'Sampah kantong / bungkus', icon: Icons.shopping_bag),
  TrashCategory(name: 'Kasur & Perabot', sub: 'Barang bekas besar', icon: Icons.chair),
  TrashCategory(name: 'Ranting & Puing', sub: 'Sisa pohon / semen', icon: Icons.park),
  TrashCategory(name: 'Berbau / Bangkai', sub: 'Perlu angkut segera', icon: Icons.warning_amber),
];
