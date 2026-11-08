import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models.dart';
import '../services/location_service.dart';
import '../theme.dart';

const Color _blue = Color(0xFF1A73E8);

/// Lapisan dasar peta OpenStreetMap.
Widget osmTiles() => TileLayer(
      urlTemplate: AppConfig.tileUrl,
      userAgentPackageName: AppConfig.appPackage,
    );

/// Atribusi wajib OpenStreetMap.
Widget osmAttribution() => const RichAttributionWidget(
      attributions: const [TextSourceAttribution('OpenStreetMap contributors')],
    );

/// Pin merah penanda titik laporan (ujung bawah pin = titik koordinat).
Widget pinIcon() => const Icon(Icons.location_on, color: C.red, size: 44);

/// Titik biru posisi pengguna.
Widget liveDot() => Container(
      decoration: BoxDecoration(
        color: _blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
      ),
    );

/// Penanda laporan lain di sekitar (oranye = milik orang lain, hijau = milik sendiri).
Widget nearbyDot(NearbyPoint n) => Container(
      decoration: BoxDecoration(
        color: n.mine ? C.green : const Color(0xFFF59E0B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3)],
      ),
      child: const Icon(Icons.delete_outline, size: 14, color: Colors.white),
    );

/// Lingkaran akurasi GPS di sekitar titik biru.
Widget accuracyCircle(LatLng p, double meters) => CircleLayer(
      circles: [
        CircleMarker(
          point: p,
          radius: meters,
          useRadiusInMeter: true,
          color: const Color(0x221A73E8),
          borderColor: const Color(0x551A73E8),
          borderStrokeWidth: 1,
        ),
      ],
    );

/// Pratinjau peta kecil dengan satu pin (tidak bisa digeser).
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.point, this.height = 150});

  final LatLng point;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          key: ValueKey('${point.latitude},${point.longitude}'),
          options: MapOptions(
            initialCenter: point,
            initialZoom: AppConfig.mapZoom,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            osmTiles(),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: pinIcon(),
                ),
              ],
            ),
            osmAttribution(),
          ],
        ),
      ),
    );
  }
}

/// Peta langsung untuk halaman Lapor: titik biru GPS realtime + lingkaran
/// akurasi + pin laporan + laporan di sekitar. Hanya tampilan (tidak digeser)
/// agar halaman tetap mudah digulir; ketuk untuk membuka peta penuh.
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.live,
    required this.point,
    required this.nearby,
    required this.follow,
    required this.onFollowChanged,
    required this.onOpen,
    this.height = 230,
  });

  final LiveLocation live;
  final LatLng? point;
  final List<NearbyPoint> nearby;
  final bool follow;
  final ValueChanged<bool> onFollowChanged;
  final VoidCallback onOpen;
  final double height;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final MapController _controller = MapController();
  bool _ready = false;
  LatLng? _lastMoved;

  @override
  void initState() {
    super.initState();
    widget.live.addListener(_maybeMove);
  }

  @override
  void didUpdateWidget(LiveMap old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeMove();
    });
  }

  @override
  void dispose() {
    widget.live.removeListener(_maybeMove);
    super.dispose();
  }

  void _maybeMove() {
    if (!_ready || !mounted) return;
    final target = widget.follow ? (widget.live.point ?? widget.point) : widget.point;
    if (target == null) return;
    final last = _lastMoved;
    if (last != null && last.latitude == target.latitude && last.longitude == target.longitude) {
      return;
    }
    _lastMoved = target;
    _controller.move(target, AppConfig.mapZoom);
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, {bool active = false}) {
    return Material(
      color: active ? C.green : C.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: active ? C.white : C.ink),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ListenableBuilder(
                listenable: widget.live,
                builder: (context, _) {
                  final lp = widget.live.point;
                  final acc = widget.live.accuracy;
                  return FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: widget.point ?? lp ?? AppConfig.defaultCenter,
                      initialZoom: AppConfig.mapZoom,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      onMapReady: () {
                        _ready = true;
                        _maybeMove();
                      },
                      onTap: (_, __) => widget.onOpen(),
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
                          if (lp != null)
                            Marker(point: lp, width: 22, height: 22, child: liveDot()),
                          if (widget.point != null)
                            Marker(
                              point: widget.point!,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: pinIcon(),
                            ),
                        ],
                      ),
                      osmAttribution(),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: _roundButton(
                widget.follow ? Icons.gps_fixed : Icons.gps_not_fixed,
                () => widget.onFollowChanged(!widget.follow),
                active: widget.follow,
              ),
            ),
            Positioned(
              right: 10,
              top: 58,
              child: _roundButton(Icons.open_in_full, widget.onOpen),
            ),
          ],
        ),
      ),
    );
  }
}
