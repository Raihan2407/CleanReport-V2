import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Kartu putih standar (radius 12 + bayangan desain).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: C.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadowCard,
      ),
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: body),
            ),
    );
  }
}

/// Lingkaran ikon kecil.
class RoundIcon extends StatelessWidget {
  const RoundIcon({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
    this.size = 40,
    this.iconSize = 18,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: fg, size: iconSize),
    );
  }
}

/// Judul bagian bernomor ("1  Foto Sampah  [chip]").
class StepTitle extends StatelessWidget {
  const StepTitle({super.key, required this.number, required this.title, this.trailing});

  final int number;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$number', style: ty(14, 700, color: C.white)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: ty(18, 700))),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Chip kecil berisi ikon opsional + teks.
class MiniChip extends StatelessWidget {
  const MiniChip({
    super.key,
    required this.text,
    this.icon,
    this.bg = C.greenLight,
    this.fg = C.greenDark,
  });

  final String text;
  final IconData? icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(text, style: ty(12.5, 700, color: fg), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Pill status pada kartu laporan.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final Color? iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor ?? fg, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: ty(13.5, 700, color: fg), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Empat tanda sudut pada area bidik foto.
class CornerBrackets extends StatelessWidget {
  const CornerBrackets({super.key, this.color = C.green, this.length = 16});

  final Color color;
  final double length;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BracketsPainter(color, length), size: Size.infinite);
}

class _BracketsPainter extends CustomPainter {
  _BracketsPainter(this.color, this.length);

  final Color color;
  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const d = 14.0;
    final w = size.width;
    final h = size.height;
    final r = length;
    final p = Path()
      ..moveTo(d, d + r)
      ..lineTo(d, d)
      ..lineTo(d + r, d)
      ..moveTo(w - d - r, d)
      ..lineTo(w - d, d)
      ..lineTo(w - d, d + r)
      ..moveTo(d, h - d - r)
      ..lineTo(d, h - d)
      ..lineTo(d + r, h - d)
      ..moveTo(w - d - r, h - d)
      ..lineTo(w - d, h - d)
      ..lineTo(w - d, h - d - r);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_BracketsPainter old) => old.color != color || old.length != length;
}

enum ButtonKind { primary, tonal, outline }

/// Tombol standar CleanReport (tinggi nyaman untuk jempol, ada keadaan loading).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ButtonKind.primary,
    this.loading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonKind kind;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = switch (kind) {
      ButtonKind.primary => C.submit,
      ButtonKind.tonal => C.indigo,
      ButtonKind.outline => C.white,
    };
    final fg = switch (kind) {
      ButtonKind.primary => C.white,
      ButtonKind.tonal => C.ink,
      ButtonKind.outline => C.green,
    };
    final content = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: loading
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed?.call();
              },
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: ty(15.5, 700, ls: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: kind == ButtonKind.outline
                ? const BorderSide(color: C.green, width: 1.5)
                : BorderSide.none,
          ),
        ),
        child: content,
      ),
    );
  }
}

/// Tombol "Kembali" berbentuk pil di bawah header.
class BackPill extends StatelessWidget {
  const BackPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: C.indigo,
        borderRadius: BorderRadius.circular(9999),
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, size: 20, color: C.ink),
                const SizedBox(width: 8),
                Text(label, style: ty(15, 700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto laporan: otomatis memilih jaringan (URL), base64 (Firestore) atau berkas lokal.
class ReportImage extends StatelessWidget {
  const ReportImage(this.path, {super.key, this.fit = BoxFit.cover, this.cacheWidth});

  final String path;
  final BoxFit fit;
  final int? cacheWidth;

  // Cache kecil agar foto base64 tidak didekode ulang setiap kali daftar digulir.
  static final Map<String, Uint8List> _memory = <String, Uint8List>{};

  Widget _placeholder() => Container(
        color: C.indigoPlaceholder,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: C.muted),
      );

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return _placeholder();

    if (path.startsWith('b64:')) {
      try {
        if (_memory.length > 40) _memory.clear();
        final bytes = _memory.putIfAbsent(path, () => base64Decode(path.substring(4)));
        return Image.memory(
          bytes,
          fit: fit,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      } catch (_) {
        return _placeholder();
      }
    }

    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: fit,
        cacheWidth: cacheWidth,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                color: C.indigoPlaceholder,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: C.green),
                ),
              ),
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }
}

/// Pesan singkat (snackbar) yang konsisten dengan desain.
void toast(BuildContext context, String message, {bool error = false, SnackBarAction? action}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? C.red : C.greenDeep,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
      action: action,
      content: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: ty(14, 600, color: Colors.white, lh: 1.3))),
        ],
      ),
    ),
  );
}

/// Membuka tautan di aplikasi lain (telepon, WhatsApp, Google Maps).
Future<bool> openUrl(BuildContext context, String url) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    toast(context, 'Tidak dapat membuka tautan di perangkat ini.', error: true);
  }
  return ok;
}
