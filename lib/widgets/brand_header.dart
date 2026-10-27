import 'package:flutter/material.dart';

import '../theme.dart';
import 'help_sheet.dart';

/// Header brand CleanReport (logo + nama + subjudul + tombol Bantuan).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 8, 20, 10),
      decoration: const BoxDecoration(color: C.bg, boxShadow: shadowHeader),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 36, height: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CleanReport', style: ty(21, 700, color: C.green, lh: 1.15)),
                Text(subtitle, style: ty(14, 500, color: C.slate, lh: 1.2)),
              ],
            ),
          ),
          Material(
            color: C.greenLight,
            borderRadius: BorderRadius.circular(9999),
            child: InkWell(
              borderRadius: BorderRadius.circular(9999),
              onTap: () => showHelpSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.support_agent, color: C.greenDark, size: 18),
                    const SizedBox(width: 6),
                    Text('Bantuan', style: ty(14, 700, color: C.greenDark)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
