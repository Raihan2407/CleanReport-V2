import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

enum _Filter { all, processing, done, rejected }

/// Halaman Riwayat: daftar laporan milik pengguna + filter status.
class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.reports;
        final processing = all
            .where((r) =>
                r.status == ReportStatus.received ||
                r.status == ReportStatus.inProgress)
            .toList();
        final done = all.where((r) => r.status == ReportStatus.done).toList();
        final rejected =
            all.where((r) => r.status == ReportStatus.rejected).toList();
        final shown = switch (_filter) {
          _Filter.all => all,
          _Filter.processing => processing,
          _Filter.done => done,
          _Filter.rejected => rejected,
        };

        return Column(
          children: [
            const BrandHeader(subtitle: 'Riwayat'),
            Expanded(
              child: RefreshIndicator(
                color: C.green,
                onRefresh: store.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    _title(all.length),
                    const SizedBox(height: 16),
                    _filters(all.length, processing.length, done.length,
                        rejected.length),
                    const SizedBox(height: 16),
                    if (store.loading && all.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                            child: CircularProgressIndicator(color: C.green)),
                      )
                    else if (store.error != null && all.isEmpty)
                      _errorState()
                    else if (shown.isEmpty)
                      _emptyState(all.isEmpty)
                    else
                      for (final r in shown) ...[
                        _ReportCard(report: r),
                        const SizedBox(height: 14),
                      ],
                    if (shown.isNotEmpty) _hint(),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Buat Laporan Baru',
                      icon: Icons.add_a_photo,
                      onPressed: () => store.tab.value = 0,
                    ),
                    if (!store.isCloud && !store.loading) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Mode lokal: laporan tersimpan di HP ini. Hubungkan Firebase agar tersimpan di cloud.',
                        textAlign: TextAlign.center,
                        style: ty(12.5, 400, color: C.muted, lh: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _title(int count) {
    return Row(
      children: [
        Expanded(child: Text('Laporan Saya', style: ty(26, 700, lh: 1.15))),
        MiniChip(text: '$count Laporan Terkirim'),
      ],
    );
  }

  Widget _filters(int all, int processing, int done, int rejected) {
    Widget chip(_Filter f, String label, int n) {
      final selected = _filter == f;
      return Expanded(
        child: Material(
          color: selected ? C.green : C.indigo,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _filter = f),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '$label ($n)',
                textAlign: TextAlign.center,
                maxLines: 2,
                style:
                    ty(13.5, 700, color: selected ? C.white : C.ink, lh: 1.2),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_Filter.all, 'Semua', all),
        const SizedBox(width: 8),
        chip(_Filter.processing, 'Sedang Diproses', processing),
        const SizedBox(width: 8),
        chip(_Filter.done, 'Sudah Bersih', done),
        if (rejected > 0) ...[
          const SizedBox(width: 8),
          chip(_Filter.rejected, 'Ditolak', rejected),
        ],
      ],
    );
  }

  Widget _emptyState(bool noReportsAtAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          const RoundIcon(
            icon: Icons.eco_outlined,
            bg: C.greenLight,
            fg: C.green,
            size: 84,
            iconSize: 42,
          ),
          const SizedBox(height: 18),
          Text(
            noReportsAtAll
                ? 'Belum ada laporan'
                : 'Tidak ada laporan di kategori ini',
            textAlign: TextAlign.center,
            style: ty(19, 700),
          ),
          const SizedBox(height: 6),
          Text(
            noReportsAtAll
                ? 'Temukan tumpukan sampah liar? Laporkan dalam hitungan detik, lalu pantau di sini.'
                : 'Coba pilih filter lain untuk melihat laporan Anda.',
            textAlign: TextAlign.center,
            style: ty(14.5, 400, color: C.slate, lh: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          const RoundIcon(
            icon: Icons.cloud_off,
            bg: C.indigo,
            fg: C.slate,
            size: 84,
            iconSize: 40,
          ),
          const SizedBox(height: 18),
          Text('Riwayat belum bisa dimuat',
              style: ty(19, 700), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(store.error ?? '',
              textAlign: TextAlign.center,
              style: ty(14.5, 400, color: C.slate, lh: 1.4)),
          const SizedBox(height: 16),
          AppButton(
            label: 'Coba Lagi',
            icon: Icons.refresh,
            kind: ButtonKind.tonal,
            height: 48,
            onPressed: store.refresh,
          ),
        ],
      ),
    );
  }

  Widget _hint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.indigo, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: C.slate),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sentuh kartu mana saja untuk melihat foto bukti, lokasi, dan perjalanan laporan.',
              style: ty(13.5, 500, color: C.slate, lh: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return SectionCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => DetailScreen(reportId: r.id, initial: r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: StatusPill(
                  icon: r.status.icon,
                  bg: r.status.pillBg,
                  fg: r.status.pillFg,
                  iconColor: r.status.iconColor,
                  label: r.pillLabel,
                ),
              ),
              const SizedBox(width: 8),
              Text(r.code, style: ty(13, 600, color: C.muted)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: ReportImage(r.photo, cacheWidth: 300),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.addressTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ty(17, 700, lh: 1.25)),
                    const SizedBox(height: 3),
                    Text(reportedAgo(r.createdAt),
                        style: ty(13.5, 400, color: C.slate)),
                    const SizedBox(height: 6),
                    Text(
                        r.pending
                            ? 'Tersimpan di HP, menunggu internet.'
                            : r.status.message,
                        style:
                            ty(13.5, 600, color: r.status.descColor, lh: 1.3)),
                    if (r.pending || store.updatedIds.contains(r.id)) ...[
                      const SizedBox(height: 8),
                      if (store.updatedIds.contains(r.id))
                        const MiniChip(
                          text: 'Pembaruan baru',
                          icon: Icons.notifications_active,
                          bg: C.green,
                          fg: C.white,
                        )
                      else
                        const MiniChip(
                          text: 'Menunggu internet',
                          icon: Icons.cloud_upload,
                          bg: C.indigo,
                          fg: C.slate,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: C.indigo),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(r.categoryInfo.icon, size: 18, color: C.slate),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.category.isEmpty ? 'Jenis sampah' : r.category,
                  style: ty(13.5, 600, color: C.slate),
                ),
              ),
              const Icon(Icons.chevron_right, color: C.green),
            ],
          ),
        ],
      ),
    );
  }
}
