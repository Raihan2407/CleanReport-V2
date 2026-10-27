import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/common.dart';

/// Hasil pemilihan titik manual.
class PickedLocation {
  const PickedLocation(this.point, this.address);

  final LatLng point;
  final AddressInfo address;
}

/// Peta layar penuh: geser/zoom peta, pin di tengah menunjuk titik sampah.
/// Titik biru = posisi GPS Anda (realtime). Dipakai untuk "Ubah Titik" dan
/// saat izin lokasi ditolak.
class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({
    super.key,
    required this.initial,
    required this.live,
    this.nearby = const [],
  });

  final LatLng initial;
  final LiveLocation live;
  final List<NearbyPoint> nearby;

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  final MapController _map = MapController();
  late LatLng _center = widget.initial;
  AddressInfo? _address;
  bool _resolving = true;
  bool _ready = false;
  Timer? _debounce;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    widget.live.start();
    _resolve();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    final t = ++_token;
    final a = await LocationService.address(_center);
    if (!mounted || t != _token) return;
    setState(() {
      _address = a;
      _resolving = false;
    });
  }

  void _onMoved(LatLng c) {
    _center = c;
    _debounce?.cancel();
    if (!_resolving) setState(() => _resolving = true);
    _debounce = Timer(const Duration(milliseconds: 700), _resolve);
  }

  void _goToMe() {
    final p = widget.live.point;
    if (p != null && _ready) {
      _map.move(p, AppConfig.mapZoom);
      _onMoved(p); // perbarui titik & alamat (pergerakan program tidak dihitung sebagai geseran)
    } else {
      widget.live.start();
      toast(context, 'Posisi GPS belum tersedia. Tunggu sebentar atau geser peta manual.',
          error: true);
    }
  }

  void _confirm() {
    final a = _address;
    if (a == null || _resolving) return;
    Navigator.of(context).pop(PickedLocation(_center, a));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: widget.live,
            builder: (context, _) {
              final lp = widget.live.point;
              final acc = widget.live.accuracy;
              return FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: widget.initial,
                  initialZoom: AppConfig.mapZoom,
                  interactionOptions:
                      InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onMapReady: () => _ready = true,
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) _onMoved(camera.center);
                  },
                ),
                children: [
                  osmTiles(),
                  if (lp != null && acc != null) accuracyCircle(lp, acc),
                  MarkerLayer(
                    markers: [
                      for (final n in widget.nearby)
                        Marker(
                          point: LatLng(n.lat, n.lng),
                          width: 26,
                          height: 26,
                          child: nearbyDot(n),
                        ),
                      if (lp != null) Marker(point: lp, width: 22, height: 22, child: liveDot()),
                    ],
                  ),
                  osmAttribution(),
                ],
              );
            },
          ),
          // Pin tetap di tengah; ujung bawah pin tepat di titik pusat peta.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(Icons.location_on, size: 48, color: C.red),
              ),
            ),
          ),
          Positioned(
            top: top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Material(
                  color: C.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_back, color: C.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: C.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: shadowCard,
                    ),
                    child: Text(
                      'Geser peta sampai pin tepat di titik sampah',
                      style: ty(14, 600, color: C.slate, lh: 1.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                  child: Material(
                    color: C.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _goToMe,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(Icons.my_location, color: C.green),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
                  decoration: const BoxDecoration(
                    color: C.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: shadowNav,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const RoundIcon(icon: Icons.place, bg: C.greenLight, fg: C.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _resolving || _address == null
                                ? Text('Mencari alamat…', style: ty(15, 500, color: C.muted))
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_address!.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: ty(17, 700, lh: 1.25)),
                                      const SizedBox(height: 2),
                                      Text(_address!.sub,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: ty(14, 400, color: C.slate, lh: 1.3)),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Koordinat: ${fmtCoord(_center.latitude, _center.longitude)}',
                        style: ty(12.5, 500, color: C.muted),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Gunakan Lokasi Ini',
                        icon: Icons.check,
                        onPressed: _confirm,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
