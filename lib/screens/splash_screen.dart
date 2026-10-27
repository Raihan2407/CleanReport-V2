import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'home_shell.dart';

/// Layar pembuka CleanReport.
///
/// Satu [AnimationController] mengatur seluruh urutan (staggered animation):
///   1. riak air melebar dari tengah layar
///   2. lencana putih muncul dengan efek memantul (elastic)
///   3. cincin hijau tergambar melingkar
///   4. daun tumbuh sambil berputar
///   5. tanda centang tergambar (simbol "sudah bersih")
///   6. percikan bintang meledak di sekeliling lencana
///   7. tulisan "CleanReport" muncul huruf demi huruf, lalu tagline
///   8. isi memudar halus, lalu masuk ke [HomeShell]
///
/// Semua digambar dengan kode (tanpa gambar/paket tambahan) sehingga tajam
/// di semua ukuran layar. Ketuk layar untuk melewati animasi.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _word = 'CleanReport';

  late final AnimationController _c;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goHome();
      });
    _c.forward();

    // Hormati pengaturan "kurangi animasi" milik sistem.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) _goHome();
    });
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const HomeShell(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: C.greenDeep,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _goHome,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              final exit = _seg(v, 0.90, 1.0, Curves.easeIn);
              return Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [C.greenDeep, C.green],
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: _RipplePainter(_seg(v, 0.0, 0.50, Curves.easeOutCubic)),
                  ),
                  Opacity(
                    opacity: 1 - exit,
                    child: Transform.scale(
                      scale: 1 + 0.12 * exit,
                      child: _content(v),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(double v) {
    final tagline = _seg(v, 0.72, 0.88, Curves.easeOut);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: CustomPaint(
              painter: _BadgePainter(
                badge: _seg(v, 0.05, 0.42, Curves.elasticOut),
                ring: _seg(v, 0.28, 0.56, Curves.easeInOutCubic),
                leaf: _seg(v, 0.40, 0.62, Curves.easeOutBack),
                check: _seg(v, 0.54, 0.72, Curves.easeOutCubic),
                spark: _seg(v, 0.60, 0.84, Curves.easeOut),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < _word.length; i++)
                _letter(
                  _word[i],
                  _seg(v, 0.58 + i * 0.012, 0.58 + i * 0.012 + 0.15,
                      Curves.easeOutBack),
                  i < 5 ? C.white : C.greenLight,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: _cl(tagline),
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - tagline)),
              child: Text(
                'Lapor sampah, kota bersih',
                style: ty(18, 500, color: C.greenLight, ls: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _letter(String ch, double t, Color color) {
    return Opacity(
      opacity: _cl(t),
      child: Transform.translate(
        offset: Offset(0, 26 * (1 - t)),
        child: Text(ch, style: ty(40, 700, color: color, ls: 0.4, lh: 1.1)),
      ),
    );
  }
}

/// Mengubah nilai controller [v] (0..1) menjadi progres lokal pada rentang
/// [begin]..[end], lalu menerapkan [curve].
double _seg(double v, double begin, double end, [Curve curve = Curves.linear]) {
  final t = _cl((v - begin) / (end - begin));
  return curve.transform(t);
}

double _cl(double x, [double lo = 0.0, double hi = 1.0]) =>
    x < lo ? lo : (x > hi ? hi : x);

Color _alpha(Color c, double o) => c.withAlpha((_cl(o) * 255).round());

/// Riak air: tiga lingkaran lembut melebar dari tengah layar.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.p);
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0) return;
    final center = size.center(Offset.zero);
    final maxR = size.longestSide * 0.85;
    for (int i = 0; i < 3; i++) {
      final t = _cl((p - i * 0.16) / 0.68);
      if (t <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _alpha(C.greenLight, (1 - t) * 0.16);
      canvas.drawCircle(center, t * maxR, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.p != p;
}

/// Lencana logo: lingkaran putih + cincin + daun + centang + percikan.
/// Koordinat dibuat relatif pada kanvas 280x280 dengan titik tengah (0,0).
class _BadgePainter extends CustomPainter {
  _BadgePainter({
    required this.badge,
    required this.ring,
    required this.leaf,
    required this.check,
    required this.spark,
  });

  final double badge; // skala lencana (boleh > 1 karena efek memantul)
  final double ring; // 0..1 panjang cincin tergambar
  final double leaf; // skala daun
  final double check; // 0..1 panjang centang tergambar
  final double spark; // 0..1 percikan

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final unit = size.width / 280;
    canvas.scale(unit);

    _paintSparkles(canvas);

    final s = badge < 0 ? 0.0 : badge;
    if (s > 0) {
      canvas.save();
      canvas.scale(s);
      _paintBadge(canvas);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintBadge(Canvas canvas) {
    const r = 70.0;

    // Bayangan lembut di bawah lencana.
    canvas.drawCircle(
      const Offset(0, 8),
      r,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Latar putih.
    canvas.drawCircle(Offset.zero, r, Paint()..color = C.white);

    // Cincin hijau yang tergambar melingkar dari atas.
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 59),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = C.green,
      );
    }

    // Daun tumbuh sambil berputar sedikit.
    if (leaf > 0) {
      final ls = leaf < 0 ? 0.0 : leaf;
      canvas.save();
      canvas.rotate((1 - _cl(leaf)) * -0.7);
      canvas.scale(ls * 1.3);
      final leafPath = Path()
        ..moveTo(-27, 29)
        ..quadraticBezierTo(-36, -22, 25, -31)
        ..quadraticBezierTo(35, 27, -27, 29)
        ..close();
      canvas.drawPath(leafPath, Paint()..color = C.green);
      canvas.restore();
    }

    // Centang putih yang tergambar di atas daun.
    if (check > 0) {
      final checkPath = Path()
        ..moveTo(-14, 2)
        ..lineTo(-4, 13)
        ..lineTo(16, -12);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = C.white;
      canvas.save();
      canvas.scale(1.3);
      for (final m in checkPath.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * _cl(check)), paint);
      }
      canvas.restore();
    }
  }

  void _paintSparkles(Canvas canvas) {
    if (spark <= 0 || spark >= 1) return;
    // sudut (rad), jarak akhir, ukuran
    const items = <List<double>>[
      [-0.9, 112, 13],
      [-0.2, 120, 9],
      [0.7, 114, 12],
      [2.1, 116, 10],
      [2.9, 110, 13],
      [4.0, 118, 9],
    ];
    final pulse = math.sin(spark * math.pi); // naik lalu turun
    final paint = Paint()..color = _alpha(C.greenLight, pulse);
    for (final it in items) {
      final dist = 70 + (it[1] - 70) * spark;
      final center = Offset(math.cos(it[0]) * dist, math.sin(it[0]) * dist);
      _star(canvas, center, it[2] * pulse, paint);
    }
  }

  /// Bintang empat sudut (mirip ikon percikan di desain).
  void _star(Canvas canvas, Offset c, double s, Paint paint) {
    final p = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.badge != badge ||
      old.ring != ring ||
      old.leaf != leaf ||
      old.check != check ||
      old.spark != spark;
}
