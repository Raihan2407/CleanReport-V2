import 'package:flutter/material.dart';

/// Palet warna yang diambil langsung dari desain Figma "PPB".
class C {
  C._();

  static const Color bg = Color(0xFFFAF8FF); // latar utama
  static const Color ink = Color(0xFF131B2E); // teks utama (gelap)
  static const Color slate = Color(0xFF3F493F); // teks sekunder
  static const Color muted = Color(0xFF6F7A6E); // placeholder / hint
  static const Color green = Color(0xFF00652C); // aksen utama
  static const Color greenLight = Color(0xFFB1F2BE); // pill / highlight
  static const Color greenMid = Color(0xFF2E6A41); // teks status proses
  static const Color olive = Color(0xFF415D4D); // teks status diterima
  static const Color greenDark = Color(0xFF347047); // teks di atas hijau muda
  static const Color greenDeep = Color(0xFF12512C); // status selesai
  static const Color indigo = Color(0xFFE2E7FF); // tab / chip non-aktif
  static const Color indigoSoft = Color(0xFFF2F3FF); // panel lembut
  static const Color indigoPlaceholder = Color(0xFFEAEDFF); // placeholder foto
  static const Color white = Color(0xFFFFFFFF);
  static const Color greyIcon = Color(0xFFBECABC); // radio kosong
  static const Color red = Color(0xFFBA1A1A); // pin peta
  static const Color submit = Color(0xFF15803D); // tombol kirim
  static const Color mint = Color(0xFFD3FFD5); // teks tombol kirim
  static const Color chipBg = Color(0xFFCAEAD6);
  static const Color chipFg = Color(0xFF314D3E);
  static const Color camDark = Color(0xFF283044); // overlay kamera
  static const Color camText = Color(0xFFEEF0FF);
}

/// Membuat TextStyle dengan font variabel Atkinson Hyperlegible Next.
/// [wght] adalah berat variabel (400/500/600/700...), [lh] faktor baris
/// (tinggi baris px dibagi ukuran font), [ls] letter-spacing px.
TextStyle ty(double size, double wght,
        {Color? color, double? lh, double? ls}) =>
    TextStyle(
      fontFamily: 'AtkinsonHyperlegibleNext',
      fontSize: size,
      height: lh,
      letterSpacing: ls,
      color: color ?? C.ink,
      fontVariations: [FontVariation('wght', wght)],
    );

const List<BoxShadow> shadowCard = [
  // #131B2E 6% blur 16 off (0,4)
  BoxShadow(color: Color(0x14131B2E), blurRadius: 16, offset: Offset(0, 4)),
];

const List<BoxShadow> shadowSmall = [
  // hitam 5% blur 2 off (0,1)
  BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
];

const List<BoxShadow> shadowHeader = [
  // #131B2E 6% blur 12 off (0,2)
  BoxShadow(color: Color(0x0F131B2E), blurRadius: 12, offset: Offset(0, 2)),
];

const List<BoxShadow> shadowNav = [
  // #131B2E 8% blur 16 off (0,-4)
  BoxShadow(color: Color(0x14131B2E), blurRadius: 16, offset: Offset(0, -4)),
];

const List<BoxShadow> shadowLift = [
  // bayangan tegas untuk elemen mengambang
  BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10)),
];

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: C.bg,
    fontFamily: 'AtkinsonHyperlegibleNext',
    colorScheme: const ColorScheme.light(primary: C.green, surface: C.bg),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: C.green),
  );
}