import 'dart:math' as math;

double _rad(double d) => d * math.pi / 180;

/// Jarak antara dua koordinat dalam meter (rumus haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final sLat = math.sin(dLat / 2);
  final sLng = math.sin(dLng / 2);
  final a = sLat * sLat + math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * sLng * sLng;
  return 2 * r * math.asin(math.sqrt(a));
}
