const List<String> _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "24 Okt"
String fmtDate(DateTime d) => '${d.day} ${_bulan[d.month - 1]}';

/// "09:30"
String fmtTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "24 Okt, 09:30"
String fmtDateTime(DateTime d) => '${fmtDate(d)}, ${fmtTime(d)}';

/// "Dilaporkan hari ini, 09:30" / "kemarin" / "3 hari lalu" / "24 Okt".
String reportedAgo(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Dilaporkan hari ini, ${fmtTime(d)}';
  if (diff == 1) return 'Dilaporkan kemarin, ${fmtTime(d)}';
  if (diff < 7) return 'Dilaporkan $diff hari lalu';
  return 'Dilaporkan ${fmtDate(d)}';
}

/// "0.91670, 104.45000"
String fmtCoord(double lat, double lng) =>
    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
