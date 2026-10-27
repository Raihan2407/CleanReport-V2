import 'package:latlong2/latlong.dart';

/// Pengaturan yang mudah diubah tanpa menyentuh logika aplikasi.
class AppConfig {
  AppConfig._();

  /// Nomor telepon bantuan pada tombol "Hubungi Petugas".
  /// Catatan: "311" hanya contoh dari mockup dan BUKAN kerja sama resmi dengan
  /// instansi. Ganti dengan nomor layanan kebersihan setempat bila sudah ada.
  static const String helpNumber = '311';

  /// Titik awal peta bila GPS belum tersedia (Tanjung Pinang).
  static const LatLng defaultCenter = LatLng(0.9167, 104.4500);

  /// Zoom peta untuk menunjuk titik sampah.
  static const double mapZoom = 17;

  /// Peta dasar OpenStreetMap (gratis). Untuk pemakaian berat, ganti dengan
  /// penyedia tile sendiri (lihat kebijakan tile OpenStreetMap).
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Dipakai sebagai identitas aplikasi pada permintaan tile peta.
  static const String appPackage = 'id.ac.umrah.cleanreport.v2';

  /// Batas panjang teks isian.
  static const int landmarkMax = 100;
  static const int nameMax = 40;

  /// Radius (meter) pencarian laporan di sekitar untuk peringatan laporan ganda.
  static const double nearbyMeters = 150;

  /// Batas jumlah laporan per perangkat dalam 24 jam (anti-spam sederhana).
  static const int dailyLimit = 10;

  /// Batas ukuran foto (byte). Satu dokumen Firestore maks. 1 MiB dan memuat foto
  /// sebelum + foto sesudah dari admin, masing-masing membengkak ~33% (base64),
  /// jadi tiap foto dibatasi 350 KB.
  static const int photoMaxBytes = 350 * 1024;
}
