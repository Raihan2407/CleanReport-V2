import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Navigasi bawah: tab Lapor & Riwayat.
/// [active] = 0 (Lapor), 1 (Riwayat), atau -1 (tidak ada yang aktif, dipakai
/// layar Formulir & Detail). Menekan tab selalu memanggil [onSelect].
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    this.active = -1,
    required this.onSelect,
    this.riwayatBadge = 0,
  });

  /// Jumlah laporan yang statusnya berubah dan belum dilihat (titik merah di Riwayat).
  final int riwayatBadge;
  final int active;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottom),
      decoration: const BoxDecoration(color: C.white, boxShadow: shadowNav),
      child: Row(
        children: [
          _item(0, 'Lapor', Icons.add_a_photo_outlined, Icons.add_a_photo),
          _item(1, 'Riwayat', Icons.history, Icons.history, badge: riwayatBadge),
        ],
      ),
    );
  }

  Widget _item(int index, String label, IconData icon, IconData activeIcon, {int badge = 0}) {
    final isActive = active == index;
    final color = isActive ? C.green : C.slate;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onSelect(index);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? C.greenLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  child: Icon(isActive ? activeIcon : icon, color: color, size: 26),
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: ty(13.5, isActive ? 700 : 600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
