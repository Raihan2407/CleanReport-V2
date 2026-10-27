import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../format.dart';
import '../geo.dart';
import '../models.dart';
import '../services/app_state.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/brand_header.dart';
import '../widgets/common.dart';
import 'form_screen.dart';
import 'pick_location_screen.dart';

/// Halaman Lapor: ambil foto, pastikan lokasi (GPS realtime + peta), lalu lanjut ke formulir.
class LaporScreen extends StatefulWidget {
  const LaporScreen({super.key});

  @override
  State<LaporScreen> createState() => _LaporScreenState();
}

class _LaporScreenState extends State<LaporScreen> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final LiveLocation _live = LiveLocation();

  String? _photoPath;
  DateTime? _photoTime;

  LatLng? _point;
  double? _accuracy;
  AddressInfo? _address;

  /// true = titik laporan mengikuti GPS realtime; false = dipilih manual.
  bool _auto = true;

  /// true = peta ikut bergerak mengikuti posisi pengguna.
  bool _follow = true;
  bool _started = false;

  LatLng? _geocodedAt;
  Timer? _geoTimer;
  int _geoToken = 0;

  LatLng? _nearbyAt;
  List<NearbyPoint> _nearby = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _live.addListener(_onLive);
    store.resetTick.addListener(_reset);
    store.tab.addListener(_onTab);
    // Minta lokasi setelah layar tampil, supaya dialog izin muncul di waktu yang wajar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLive();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live.removeListener(_onLive);
    store.resetTick.removeListener(_reset);
    store.tab.removeListener(_onTab);
    _geoTimer?.cancel();
    _live.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hemat baterai: hentikan pelacakan saat aplikasi di latar belakang.
    if (state == AppLifecycleState.resumed) {
      if (store.tab.value == 0) _startLive();
    } else if (state == AppLifecycleState.paused) {
      _live.stop();
    }
  }

  void _onTab() {
    if (store.tab.value == 0) {
      _startLive();
    } else {
      _live.stop();
    }
  }

  Future<void> _startLive() async {
    if (mounted) setState(() => _started = true);
    await _live.start();
  }

  /// Dipanggil setelah laporan terkirim: kosongkan foto.
  void _reset() {
    if (!mounted) return;
    setState(() {
      _photoPath = null;
      _photoTime = null;
    });
  }

  // ---------------------------------------------------------------- lokasi

  void _onLive() {
    if (!mounted) return;
    final p = _live.point;
    if (_auto && p != null) {
      _point = p;
      _accuracy = _live.accuracy;
      _maybeGeocode(p);
      _maybeNearby(p);
    }
    setState(() {});
  }

  /// Alamat diperbarui hanya bila posisi bergeser cukup jauh (hemat permintaan).
  void _maybeGeocode(LatLng p) {
    final at = _geocodedAt;
    if (at != null && distanceMeters(at.latitude, at.longitude, p.latitude, p.longitude) < 10) {
      return;
    }
    _geoTimer?.cancel();
    final token = ++_geoToken;
    _geoTimer = Timer(Duration(milliseconds: _address == null ? 0 : 1200), () async {
      final a = await LocationService.address(p);
      if (!mounted || token != _geoToken || !_auto) return;
      setState(() {
        _address = a;
        _geocodedAt = p;
      });
    });
  }

  Future<void> _maybeNearby(LatLng p) async {
    final at = _nearbyAt;
    if (at != null && distanceMeters(at.latitude, at.longitude, p.latitude, p.longitude) < 40) {
      return;
    }
    _nearbyAt = p;
    final list = await store.nearby(p);
    if (mounted) setState(() => _nearby = list);
  }

  /// Kembali memakai posisi GPS realtime sebagai titik laporan.
  void _useGps() {
    setState(() {
      _auto = true;
      _follow = true;
      _geocodedAt = null;
      _nearbyAt = null;
    });
    final p = _live.point;
    if (p != null) {
      _point = p;
      _accuracy = _live.accuracy;
      _maybeGeocode(p);
      _maybeNearby(p);
      setState(() {});
    } else {
      _startLive();
    }
  }

  Future<void> _editPoint() async {
    final res = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => PickLocationScreen(
          initial: _point ?? _live.point ?? AppConfig.defaultCenter,
          live: _live,
          nearby: _nearby,
        ),
      ),
    );
    if (res == null || !mounted) return;
    setState(() {
      _auto = false;
      _follow = false;
      _point = res.point;
      _address = res.address;
      _accuracy = null;
    });
    _nearbyAt = res.point;
    final list = await store.nearby(res.point);
    if (mounted) setState(() => _nearby = list);
  }

  // ------------------------------------------------------------------ foto

  Future<void> _pick(ImageSource source) async {
    try {
      // Foto dikecilkan agar muat di Firestore (gratis) dan cepat terkirim.
      final x = await _picker.pickImage(source: source, maxWidth: 900, imageQuality: 60);
      if (!mounted) return;
      if (x == null) {
        // Dibatalkan: aplikasi tetap stabil.
        if (_photoPath == null) toast(context, 'Foto diperlukan untuk membuat laporan.');
        return;
      }
      setState(() {
        _photoPath = x.path;
        _photoTime = DateTime.now();
      });
    } catch (_) {
      if (mounted) {
        toast(context, 'Kamera atau galeri tidak bisa dibuka. Cek izin aplikasi.', error: true);
      }
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const RoundIcon(icon: Icons.photo_camera, bg: C.greenLight, fg: C.green),
                title: Text('Ambil foto dengan kamera', style: ty(16, 600)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const RoundIcon(icon: Icons.photo_library, bg: C.indigo, fg: C.ink),
                title: Text('Pilih dari galeri', style: ty(16, 600)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pick(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- lanjut

  void _next() {
    if (_photoPath == null) {
      toast(context, 'Ambil atau pilih foto sampah dulu.', error: true);
      return;
    }
    final point = _point;
    if (point == null) {
      toast(context, 'Lokasi belum ada. Izinkan GPS atau pilih titik di peta.', error: true);
      return;
    }
    final addr = _address ??
        AddressInfo('Lokasi terpilih', fmtCoord(point.latitude, point.longitude));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FormScreen(
          draft: ReportDraft(
            photoPath: _photoPath!,
            lat: point.latitude,
            lng: point.longitude,
            addressTitle: addr.title,
            addressSub: addr.sub,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- tampilan

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandHeader(subtitle: 'Foto & Lapor'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              _intro(),
              const SizedBox(height: 20),
              _photoCard(),
              const SizedBox(height: 16),
              _locationCard(),
              if (_nearby.isNotEmpty) ...[
                const SizedBox(height: 16),
                _nearbyCard(),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: 'Lanjut ke Formulir',
                icon: Icons.arrow_forward,
                onPressed: _next,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 16, color: C.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Gratis, tanpa login, dan nama Anda bisa dirahasiakan.',
                      textAlign: TextAlign.center,
                      style: ty(13, 500, color: C.muted, lh: 1.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _intro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MiniChip(text: 'Tanpa login • GPS realtime', icon: Icons.verified),
        const SizedBox(height: 12),
        Text('Lapor Sampah Cepat', style: ty(28, 700, lh: 1.15)),
        const SizedBox(height: 6),
        Text(
          'Ambil foto tumpukan sampah. Lokasi terisi otomatis dari GPS agar petugas mudah menemukannya.',
          style: ty(15, 400, color: C.slate, lh: 1.45),
        ),
      ],
    );
  }

  // ---- 1. foto

  Widget _photoCard() {
    final has = _photoPath != null;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(
            number: 1,
            title: 'Foto Sampah',
            trailing: has
                ? const MiniChip(text: 'Siap kirim', icon: Icons.check_circle)
                : const MiniChip(text: 'Wajib', bg: C.indigo, fg: C.slate),
          ),
          const SizedBox(height: 14),
          if (!has) ...[
            _viewfinder(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Ambil Foto',
                    icon: Icons.photo_camera,
                    height: 50,
                    onPressed: () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Galeri',
                    icon: Icons.photo_library,
                    kind: ButtonKind.tonal,
                    height: 50,
                    onPressed: () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(_photoPath!), fit: BoxFit.cover, cacheWidth: 900),
                    const Positioned(
                      left: 10,
                      top: 10,
                      child: MiniChip(
                        text: 'Foto terlampir',
                        icon: Icons.check_circle,
                        bg: C.white,
                        fg: C.green,
                      ),
                    ),
                    if (_photoTime != null)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: MiniChip(
                          text: 'Pukul ${fmtTime(_photoTime!)}',
                          bg: C.white,
                          fg: C.slate,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Ganti Foto',
              icon: Icons.cameraswitch,
              kind: ButtonKind.tonal,
              height: 50,
              onPressed: _chooseSource,
            ),
          ],
        ],
      ),
    );
  }

  Widget _viewfinder() {
    return GestureDetector(
      onTap: _chooseSource,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: C.indigoSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: CornerBrackets()),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RoundIcon(
                      icon: Icons.add_a_photo,
                      bg: C.greenLight,
                      fg: C.green,
                      size: 60,
                      iconSize: 28,
                    ),
                    const SizedBox(height: 12),
                    Text('Ketuk untuk memotret', style: ty(16, 700)),
                    const SizedBox(height: 2),
                    Text(
                      'Arahkan kamera ke tumpukan sampah',
                      style: ty(13.5, 400, color: C.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 2. lokasi

  Widget _locationCard() {
    final MiniChip chip;
    if (_point != null) {
      if (!_auto) {
        chip = const MiniChip(text: 'Titik manual', icon: Icons.edit_location_alt);
      } else {
        final acc = _accuracy;
        final weak = acc != null && acc > 30;
        chip = MiniChip(
          text: acc == null ? 'GPS aktif' : 'GPS • ±${acc.round()} m',
          icon: Icons.gps_fixed,
          bg: weak ? const Color(0xFFFFF4D6) : C.greenLight,
          fg: weak ? const Color(0xFF8A5A00) : C.greenDark,
        );
      }
    } else if (_live.starting || !_started) {
      chip = const MiniChip(text: 'Mencari…', bg: C.indigo, fg: C.slate);
    } else {
      chip = const MiniChip(text: 'Belum ada', bg: C.indigo, fg: C.slate);
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(number: 2, title: 'Lokasi Penjemputan', trailing: chip),
          const SizedBox(height: 14),
          if (_point != null)
            _locationReady()
          else if (_live.starting || !_started)
            _locationLoading()
          else
            _locationIssue(),
        ],
      ),
    );
  }

  Widget _locationLoading() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.indigoSoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: C.green),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text('Mencari sinyal GPS…', style: ty(15, 600, color: C.slate))),
        ],
      ),
    );
  }

  Widget _locationReady() {
    final p = _point!;
    final a = _address;
    final acc = _accuracy;
    final weak = _auto && acc != null && acc > 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RoundIcon(icon: Icons.place, bg: C.greenLight, fg: C.green),
            const SizedBox(width: 12),
            Expanded(
              child: a == null
                  ? Text('Mencari alamat…', style: ty(15, 500, color: C.muted))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: ty(17, 700, lh: 1.25)),
                        const SizedBox(height: 2),
                        Text(a.sub, style: ty(14, 400, color: C.slate, lh: 1.35)),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LiveMap(
          live: _live,
          point: p,
          nearby: _nearby,
          follow: _follow,
          onFollowChanged: (v) => setState(() => _follow = v),
          onOpen: _editPoint,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.circle, size: 10, color: Color(0xFF1A73E8)),
            const SizedBox(width: 6),
            Text('Posisi Anda', style: ty(12, 500, color: C.muted)),
            const SizedBox(width: 14),
            const Icon(Icons.location_on, size: 14, color: C.red),
            const SizedBox(width: 2),
            Text('Titik laporan', style: ty(12, 500, color: C.muted)),
            const Spacer(),
            Text('Ketuk peta untuk memperbesar', style: ty(12, 500, color: C.muted)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Koordinat: ${fmtCoord(p.latitude, p.longitude)}',
          style: ty(12.5, 500, color: C.muted),
        ),
        if (weak) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFF8A5A00)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Akurasi GPS masih rendah (±${acc!.round()} m). Pindah ke tempat terbuka dan tunggu beberapa detik, atau geser pin lewat "Ubah Titik".',
                    style: ty(13, 500, color: const Color(0xFF8A5A00), lh: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_live.issue != null && _auto) ...[
          const SizedBox(height: 10),
          Text(
            'Sinyal GPS terputus. Nyalakan lokasi atau pilih titik di peta.',
            style: ty(13, 600, color: C.red, lh: 1.35),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: _auto ? 'GPS Realtime' : 'Pakai GPS',
                icon: Icons.my_location,
                kind: _auto ? ButtonKind.primary : ButtonKind.tonal,
                height: 48,
                onPressed: _useGps,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Ubah Titik',
                icon: Icons.edit_location_alt,
                kind: ButtonKind.tonal,
                height: 48,
                onPressed: _editPoint,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _locationIssue() {
    final String msg;
    final String actionLabel;
    final VoidCallback action;
    switch (_live.issue) {
      case LocationIssue.serviceOff:
        msg = 'GPS di HP Anda sedang mati. Nyalakan lokasi agar laporan terisi otomatis.';
        actionLabel = 'Buka Pengaturan GPS';
        action = LocationService.openLocationSettings;
      case LocationIssue.deniedForever:
        msg = 'Izin lokasi diblokir. Aktifkan lewat Pengaturan aplikasi, atau pilih titik di peta.';
        actionLabel = 'Buka Pengaturan Aplikasi';
        action = LocationService.openAppSettings;
      case LocationIssue.denied:
        msg = 'Izin lokasi belum diberikan. Anda tetap bisa menentukan titik secara manual di peta.';
        actionLabel = 'Coba Lagi';
        action = _startLive;
      case LocationIssue.failed:
      case null:
        msg = 'Lokasi belum terdeteksi. Pastikan GPS aktif dan Anda tidak sedang di dalam ruangan tertutup.';
        actionLabel = 'Coba Lagi';
        action = _startLive;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_off, color: C.red, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(msg, style: ty(14, 500, color: C.ink, lh: 1.4))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: actionLabel,
          icon: Icons.my_location,
          kind: ButtonKind.tonal,
          height: 48,
          onPressed: action,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Pilih Titik di Peta',
          icon: Icons.map,
          kind: ButtonKind.outline,
          height: 48,
          onPressed: _editPoint,
        ),
      ],
    );
  }

  // ---- laporan ganda di sekitar

  Widget _nearbyCard() {
    final mine = _nearby.where((n) => n.mine).length;
    final others = _nearby.length - mine;
    final shown = _nearby.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF8A5A00), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ada ${_nearby.length} laporan lain di dekat sini',
                  style: ty(16, 700, color: const Color(0xFF5C3B00), lh: 1.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (others > 0)
                'Warga lain sudah melapor $others titik dalam ${AppConfig.nearbyMeters.round()} m. Jika sampahnya sama, tidak perlu melapor lagi.',
              if (mine > 0) 'Anda sendiri sudah melapor $mine kali di sekitar sini.',
            ].join(' '),
            style: ty(13.5, 400, color: const Color(0xFF5C3B00), lh: 1.4),
          ),
          const SizedBox(height: 10),
          for (final n in shown)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    n.mine ? Icons.person : Icons.groups,
                    size: 18,
                    color: const Color(0xFF8A5A00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${n.category.isEmpty ? 'Laporan' : n.category} • ${n.status.label}${n.mine ? ' (Anda)' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ty(13.5, 600, color: const Color(0xFF5C3B00)),
                    ),
                  ),
                  Text('${n.distance.round()} m',
                      style: ty(13, 600, color: const Color(0xFF8A5A00))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
