import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';
import 'common.dart';

/// Lembar bantuan: cara melapor + tombol telepon.
void showHelpSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.white,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cara melapor', style: ty(22, 700)),
          const SizedBox(height: 4),
          Text('Cukup 3 langkah, tanpa login.', style: ty(15, 400, color: C.slate)),
          const SizedBox(height: 18),
          _step(1, 'Foto sampahnya', 'Ambil foto langsung atau pilih dari galeri.'),
          _step(2, 'Cek lokasinya', 'Lokasi terisi otomatis dari GPS. Geser titik bila kurang pas.'),
          _step(3, 'Isi & kirim', 'Pilih jenis sampah, lalu kirim. Pantau di tab Riwayat.'),
          const SizedBox(height: 8),
          AppButton(
            label: 'Telepon Petugas (${AppConfig.helpNumber})',
            icon: Icons.call,
            onPressed: () {
              Navigator.of(ctx).pop();
              openUrl(context, 'tel:${AppConfig.helpNumber}');
            },
          ),
        ],
      ),
    ),
  );
}

Widget _step(int n, String title, String desc) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: C.greenLight, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$n', style: ty(15, 700, color: C.greenDeep)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ty(16, 700)),
              const SizedBox(height: 2),
              Text(desc, style: ty(14, 400, color: C.slate, lh: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}
