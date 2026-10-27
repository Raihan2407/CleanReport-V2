import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../widgets/bottom_nav.dart';
import 'lapor_screen.dart';
import 'riwayat_screen.dart';

/// Kerangka utama aplikasi: 2 tab (Lapor & Riwayat) + navigasi bawah.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: store.tab,
      builder: (context, index, _) {
        return PopScope(
          // Tombol kembali di tab Riwayat membawa ke tab Lapor dulu.
          canPop: index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) store.tab.value = 0;
          },
          child: Scaffold(
            body: IndexedStack(
              index: index,
              children: const [LaporScreen(), RiwayatScreen()],
            ),
            bottomNavigationBar: ListenableBuilder(
              listenable: store,
              builder: (context, _) => BottomNav(
                active: index,
                riwayatBadge: store.updatedIds.length,
                onSelect: (i) => store.tab.value = i,
              ),
            ),
          ),
        );
      },
    );
  }
}
