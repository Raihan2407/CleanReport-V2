import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';
import '../geo.dart';
import '../models.dart';
import 'report_repository.dart';

/// Implementasi Firebase paket GRATIS (Spark), tanpa Cloud Storage:
///   identitas        : Firebase Authentication anonim
///   reports/{id}     : dokumen laporan (foto dikompres, disimpan sebagai teks base64)
///   reports/{id}/statusHistory/{hid} : riwayat status (subkoleksi)
///   public_points/{id}: titik publik tanpa foto & nama, untuk peringatan laporan ganda
///
/// Offline: Firestore menyimpan penulisan di HP dan mengirimnya otomatis saat
/// internet kembali (laporan tampil dengan penanda "menunggu").
class CloudReportRepository implements ReportRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  bool get isCloud => true;

  @override
  String newId() => _db.collection('reports').doc().id;

  Future<String>? _signingIn;

  /// Memastikan pengguna anonim sudah masuk. Aman dipanggil bersamaan dari
  /// beberapa tempat: hanya satu proses login yang berjalan (satu akun anonim).
  Future<String> _uid() {
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    if (current != null) return Future<String>.value(current.uid);
    return _signingIn ??= auth
        .signInAnonymously()
        .timeout(const Duration(seconds: 15))
        .then((cred) => cred.user!.uid)
        .whenComplete(() => _signingIn = null);
  }

  DateTime _ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

  String _photo(Map<String, dynamic> m, String key) {
    final b64 = (m[key] as String?) ?? '';
    return b64.isEmpty ? '' : 'b64:$b64';
  }

  Report _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final created = _ts(m['createdAt']);
    final status = statusFromName(m['status'] as String?);
    final updated = _ts(m['updatedAt']);
    return Report(
      id: d.id,
      userId: (m['userId'] as String?) ?? '',
      category: (m['kategori'] as String?) ?? '',
      landmark: (m['patokanLokasi'] as String?) ?? '',
      reporterName: (m['namaPelapor'] as String?) ?? '',
      anonymous: (m['anonim'] as bool?) ?? true,
      lat: (m['latitude'] as num?)?.toDouble() ?? 0,
      lng: (m['longitude'] as num?)?.toDouble() ?? 0,
      addressTitle: (m['alamatTeks'] as String?) ?? '',
      addressSub: (m['alamatDetail'] as String?) ?? '',
      photo: _photo(m, 'fotoSebelumB64'),
      photoAfter: _photo(m, 'fotoSesudahB64'),
      status: status,
      createdAt: created,
      pending: d.metadata.hasPendingWrites,
      history: [
        StatusEntry(status: ReportStatus.received, at: created),
        if (status != ReportStatus.received)
          StatusEntry(status: status, at: updated),
      ],
    );
  }

  @override
  Future<List<Report>> load() async {
    final uid = await _uid();
    final snap = await _db
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .get()
        .timeout(const Duration(seconds: 20));
    final list = snap.docs.map(_fromDoc).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Aliran realtime: perubahan dari admin langsung muncul di aplikasi.
  @override
  Stream<List<Report>> watch() async* {
    final uid = await _uid();
    yield* _db
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<Report> submit(ReportDraft draft) async {
    final uid = await _uid();
    final id = draft.id ?? newId();
    draft.id = id;

    // Foto disimpan sebagai teks base64 di Firestore (gratis, tanpa Storage).
    final bytes = await File(draft.photoPath).readAsBytes();
    if (bytes.length > AppConfig.photoMaxBytes) {
      throw const ReportException(
          'Foto terlalu besar. Ambil ulang foto atau pilih foto yang lebih kecil.');
    }
    final b64 = base64Encode(bytes);

    final now = DateTime.now();
    final ts = Timestamp.fromDate(now);
    final doc = _db.collection('reports').doc(id);
    final batch = _db.batch();
    batch.set(doc, {
      'userId': uid,
      'kategori': draft.category,
      'patokanLokasi': draft.landmark,
      'namaPelapor': draft.anonymous ? '' : draft.reporterName,
      'anonim': draft.anonymous,
      'latitude': draft.lat,
      'longitude': draft.lng,
      'alamatTeks': draft.addressTitle,
      'alamatDetail': draft.addressSub,
      'fotoSebelumB64': b64,
      'status': ReportStatus.received.name,
      'createdAt': ts,
      'updatedAt': ts,
    });
    batch.set(doc.collection('statusHistory').doc('received'), {
      'status': ReportStatus.received.name,
      'changedAt': ts,
      'catatan': '',
    });
    batch.set(_db.collection('public_points').doc(id), {
      'userId': uid,
      'lat': draft.lat,
      'lng': draft.lng,
      'kategori': draft.category,
      'status': ReportStatus.received.name,
      'createdAt': ts,
    });

    // Bila internet lambat/mati, penulisan tetap tersimpan di HP dan terkirim
    // otomatis nanti; laporan ditandai "menunggu".
    var queued = false;
    try {
      await batch.commit().timeout(const Duration(seconds: 6));
    } on TimeoutException {
      queued = true;
    }

    return Report(
      id: id,
      userId: uid,
      category: draft.category,
      landmark: draft.landmark,
      reporterName: draft.anonymous ? '' : draft.reporterName,
      anonymous: draft.anonymous,
      lat: draft.lat,
      lng: draft.lng,
      addressTitle: draft.addressTitle,
      addressSub: draft.addressSub,
      photo: 'b64:$b64',
      createdAt: now,
      pending: queued,
      history: [StatusEntry(status: ReportStatus.received, at: now)],
    );
  }

  @override
  Future<List<StatusEntry>> loadHistory(Report report) async {
    final snap = await _db
        .collection('reports')
        .doc(report.id)
        .collection('statusHistory')
        .get()
        .timeout(const Duration(seconds: 15));
    final list = snap.docs.map((d) {
      final m = d.data();
      return StatusEntry(
        status: statusFromName(m['status'] as String?),
        at: _ts(m['changedAt']),
        note: (m['catatan'] as String?) ?? '',
      );
    }).toList();
    list.sort((a, b) => a.at.compareTo(b.at));
    return list.isEmpty ? report.history : list;
  }

  /// Hapus laporan + riwayat status + titik publik + catat log, dalam satu batch.
  /// Aturan Firestore: pelapor hanya boleh menghapus saat status "received" atau "rejected";
  /// admin boleh menghapus apa pun. Offline: penghapusan diantre dan terkirim nanti.
  @override
  Future<void> delete(Report report) async {
    final uid = await _uid();
    final doc = _db.collection('reports').doc(report.id);
    final batch = _db.batch();
    for (final s in const ['received', 'inProgress', 'done', 'rejected']) {
      batch.delete(doc.collection('statusHistory').doc(s));
    }
    batch.delete(_db.collection('public_points').doc(report.id));
    batch.delete(doc);
    // Log penghapusan (hanya id, kode, status, waktu; tanpa isi laporan).
    batch.set(_db.collection('audit_log').doc(), {
      'laporanId': report.id,
      'kode': report.code,
      'aksi': 'hapus',
      'peran': 'pelapor',
      'uid': uid,
      'email': '',
      'status': report.status.name,
      'waktu': Timestamp.now(),
      'alasan': '',
    });
    try {
      await batch.commit().timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // Tersimpan di HP dan akan dihapus di server saat internet kembali.
    }
  }

  @override
  Future<List<NearbyPoint>> nearby(
      double lat, double lng, double meters) async {
    final uid = await _uid();
    final dLat = meters / 111320.0;
    final snap = await _db
        .collection('public_points')
        .where('lat', isGreaterThanOrEqualTo: lat - dLat)
        .where('lat', isLessThanOrEqualTo: lat + dLat)
        .limit(100)
        .get()
        .timeout(const Duration(seconds: 10));
    final out = <NearbyPoint>[];
    for (final d in snap.docs) {
      final m = d.data();
      final status = statusFromName(m['status'] as String?);
      if (status == ReportStatus.done || status == ReportStatus.rejected)
        continue;
      final plat = (m['lat'] as num?)?.toDouble() ?? 0;
      final plng = (m['lng'] as num?)?.toDouble() ?? 0;
      final dist = distanceMeters(lat, lng, plat, plng);
      if (dist > meters) continue;
      out.add(NearbyPoint(
        id: d.id,
        lat: plat,
        lng: plng,
        category: (m['kategori'] as String?) ?? '',
        status: status,
        createdAt: _ts(m['createdAt']),
        mine: (m['userId'] as String?) == uid,
        distance: dist,
      ));
    }
    out.sort((a, b) => a.distance.compareTo(b.distance));
    return out;
  }
}
