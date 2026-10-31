import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/app_map.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/brand_header.dart';
import '../widgets/common.dart';

/// Detail satu laporan: foto bukti (sebelum/sesudah), perjalanan status,
/// lokasi, dan aksi. Mengikuti perubahan realtime dari admin.
class DetailScreen extends StatefulWidget {
  const DetailScreen(
      {super.key, required this.reportId, required this.initial});

  final String reportId;
  final Report initial;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _showAfter = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => store.markSeen(widget.reportId));
  }

  void _goTab(int i) {
    store.tab.value = i;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmDelete(Report r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.white,
        title: Text('Hapus laporan?', style: ty(20, 700)),
        content: Text(
          'Laporan ${r.code} akan dihapus permanen dan tidak bisa dikembalikan.',
          style: ty(15, 400, color: C.slate, lh: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal', style: ty(15, 700, color: C.slate)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Hapus', style: ty(15, 700, color: C.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await store.deleteReport(r);
      if (!mounted) return;
      toast(context, 'Laporan ${r.code} dihapus.');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      toast(
        context,
        'Laporan tidak bisa dihapus. Mungkin sudah ditangani petugas atau koneksi bermasalah.',
        error: true,
      );
    }
  }

  Report _current() {
    for (final r in store.reports) {
      if (r.id == widget.reportId) return r;
    }
    return widget.initial;
  }

  String _mapsUrl(Report r) =>
      'https://www.google.com/maps/search/?api=1&query=${r.lat},${r.lng}';

  String _shareText(Report r) {
    final b = StringBuffer()
      ..writeln('Laporan sampah ${r.code}')
      ..writeln('Status: ${r.status.label}')
      ..writeln('Jenis: ${r.category}')
      ..writeln('Lokasi: ${r.addressTitle}, ${r.addressSub}');
    if (r.landmark.isNotEmpty) b.writeln('Patokan: ${r.landmark}');
    b
      ..writeln('Peta: ${_mapsUrl(r)}')
      ..writeln()
      ..write('Dikirim lewat aplikasi CleanReport');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final r = _current();
        return Scaffold(
          backgroundColor: C.bg,
          body: Column(
            children: [
              const BrandHeader(subtitle: 'Detail Laporan'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    BackPill(
                      label: 'Kembali ke Riwayat',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 16),
                    _headerCard(r),
                    const SizedBox(height: 16),
                    _photoCard(r),
                    const SizedBox(height: 16),
                    _journeyCard(r),
                    const SizedBox(height: 16),
                    _infoCard(r),
                    const SizedBox(height: 16),
                    _locationCard(r),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Bagikan ke WhatsApp',
                      icon: Icons.share,
                      onPressed: () => openUrl(
                        context,
                        'https://wa.me/?text=${Uri.encodeComponent(_shareText(r))}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label:
                          'Masih ada sampah? Hubungi Petugas (${AppConfig.helpNumber})',
                      icon: Icons.call,
                      kind: ButtonKind.outline,
                      onPressed: () =>
                          openUrl(context, 'tel:${AppConfig.helpNumber}'),
                    ),
                    // Pelapor bisa menghapus selama laporan belum ditangani petugas atau sudah ditolak.
                    if (r.status == ReportStatus.received ||
                        r.status == ReportStatus.rejected) ...[
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Hapus Laporan Ini',
                        icon: Icons.delete_outline,
                        kind: ButtonKind.danger,
                        loading: _deleting,
                        onPressed: () => _confirmDelete(r),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNav(
            active: -1,
            riwayatBadge: store.updatedIds.length,
            onSelect: _goTab,
          ),
        );
      },
    );
  }

  // ---- kepala laporan

  Widget _headerCard(Report r) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: C.green, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text('Laporan ${r.code}', style: ty(22, 700))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                icon: r.status.icon,
                bg: r.status.pillBg,
                fg: r.status.pillFg,
                iconColor: r.status.iconColor,
                label: r.pillLabel,
              ),
              if (r.pending)
                const MiniChip(
                  text: 'Menunggu internet',
                  icon: Icons.cloud_upload,
                  bg: C.indigo,
                  fg: C.slate,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, color: C.slate, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${r.addressTitle}, ${r.addressSub}',
                  style: ty(15, 500, color: C.slate, lh: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- foto bukti (sebelum / sesudah)

  Widget _photoCard(Report r) {
    final hasAfter = r.photoAfter.isNotEmpty;
    final after = hasAfter && _showAfter;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: C.green, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text('Foto Bukti', style: ty(19, 700))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasAfter
                ? 'Bandingkan kondisi sampah sebelum dan sesudah dibersihkan.'
                : 'Foto kondisi sampah yang Anda laporkan.',
            style: ty(14, 400, color: C.slate, lh: 1.4),
          ),
          if (hasAfter) ...[
            const SizedBox(height: 14),
            _toggle(),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ReportImage(after ? r.photoAfter : r.photo),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: MiniChip(
                      text: after
                          ? 'Setelah dibersihkan'
                          : '${fmtDateTime(r.createdAt)} • Foto Laporan',
                      icon: after ? Icons.auto_awesome : Icons.schedule,
                      bg: C.white,
                      fg: C.greenDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle() {
    Widget item(
        String label, IconData icon, bool selected, VoidCallback onTap) {
      return Expanded(
        child: Material(
          color: selected ? C.green : C.indigo,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: selected ? C.white : C.ink),
                  const SizedBox(width: 6),
                  Text(label,
                      style: ty(14, 700, color: selected ? C.white : C.ink)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item('Setelah (Bersih)', Icons.verified, _showAfter,
            () => setState(() => _showAfter = true)),
        const SizedBox(width: 8),
        item('Sebelum Lapor', Icons.warning_amber, !_showAfter,
            () => setState(() => _showAfter = false)),
      ],
    );
  }

  // ---- perjalanan laporan

  Widget _journeyCard(Report r) {
    return SectionCard(
      child: FutureBuilder<List<StatusEntry>>(
        // Dimuat ulang saat status berubah (admin memperbarui).
        key: ValueKey('${r.id}-${r.status.name}'),
        future: store.historyOf(r),
        initialData: r.history,
        builder: (context, snap) {
          final history = snap.data ?? r.history;
          StatusEntry? entryOf(ReportStatus s) {
            for (final h in history) {
              if (h.status == s) return h;
            }
            return null;
          }

          // Laporan ditolak: tampilkan alasan dari admin, bukan langkah penanganan.
          if (r.status == ReportStatus.rejected) {
            final rej = entryOf(ReportStatus.rejected);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timeline, color: C.green, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('Perjalanan Laporan Anda',
                            style: ty(19, 700, lh: 1.2))),
                  ],
                ),
                const SizedBox(height: 18),
                _TimelineStep(
                  data: const _StepData(
                    status: ReportStatus.received,
                    title: 'Laporan Diterima',
                    desc:
                        'Laporan Anda masuk dan tersimpan di sistem CleanReport.',
                    icon: Icons.check,
                  ),
                  number: 1,
                  reached: true,
                  nextReached: true,
                  isLast: false,
                  entry: entryOf(ReportStatus.received),
                ),
                _RejectedStep(reason: rej?.note.trim() ?? '', at: rej?.at),
              ],
            );
          }

          final steps = <_StepData>[
            const _StepData(
              status: ReportStatus.received,
              title: 'Laporan Diterima',
              desc: 'Laporan Anda masuk dan tersimpan di sistem CleanReport.',
              icon: Icons.check,
            ),
            const _StepData(
              status: ReportStatus.inProgress,
              title: 'Regu Ditugaskan',
              desc: 'Petugas menuju titik lokasi laporan.',
              icon: Icons.local_shipping,
            ),
            const _StepData(
              status: ReportStatus.done,
              title: 'Sampah Diangkut Tuntas',
              desc: 'Sampah sudah diangkut dan lokasi kembali bersih.',
              icon: Icons.check,
            ),
          ];

          final reachedIndex = r.status.index;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timeline, color: C.green, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Perjalanan Laporan Anda',
                          style: ty(19, 700, lh: 1.2))),
                ],
              ),
              const SizedBox(height: 18),
              for (int i = 0; i < steps.length; i++)
                _TimelineStep(
                  data: steps[i],
                  number: i + 1,
                  reached: i <= reachedIndex,
                  nextReached: i + 1 <= reachedIndex,
                  isLast: i == steps.length - 1,
                  entry: entryOf(steps[i].status),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---- rincian

  Widget _infoCard(Report r) {
    Widget row(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: C.green),
            const SizedBox(width: 12),
            SizedBox(
                width: 96,
                child: Text(label, style: ty(14, 500, color: C.slate))),
            Expanded(child: Text(value, style: ty(15, 700, lh: 1.3))),
          ],
        ),
      );
    }

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        children: [
          row(Icons.delete_outline, 'Jenis',
              r.category.isEmpty ? '-' : r.category),
          const Divider(height: 1, color: C.indigo),
          row(Icons.flag_outlined, 'Patokan',
              r.landmark.isEmpty ? '-' : r.landmark),
          const Divider(height: 1, color: C.indigo),
          row(Icons.person_outline, 'Pelapor', r.reporterLabel),
        ],
      ),
    );
  }

  // ---- lokasi

  Widget _locationCard(Report r) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: C.green, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text('Titik Lokasi', style: ty(19, 700))),
            ],
          ),
          const SizedBox(height: 14),
          MapPreview(point: LatLng(r.lat, r.lng), height: 170),
          const SizedBox(height: 10),
          Text(r.addressTitle, style: ty(16, 700, lh: 1.3)),
          const SizedBox(height: 2),
          Text(r.addressSub, style: ty(14, 400, color: C.slate, lh: 1.35)),
          const SizedBox(height: 4),
          Text('Koordinat: ${fmtCoord(r.lat, r.lng)}',
              style: ty(12.5, 500, color: C.muted)),
          const SizedBox(height: 14),
          AppButton(
            label: 'Buka di Google Maps',
            icon: Icons.map_outlined,
            kind: ButtonKind.tonal,
            height: 48,
            onPressed: () => openUrl(context, _mapsUrl(r)),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  const _StepData({
    required this.status,
    required this.title,
    required this.desc,
    required this.icon,
  });

  final ReportStatus status;
  final String title;
  final String desc;
  final IconData icon;
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.data,
    required this.number,
    required this.reached,
    required this.nextReached,
    required this.isLast,
    required this.entry,
  });

  final _StepData data;
  final int number;
  final bool reached;
  final bool nextReached;
  final bool isLast;
  final StatusEntry? entry;

  @override
  Widget build(BuildContext context) {
    final done = data.status == ReportStatus.done;
    final circleBg = reached ? (done ? C.greenLight : C.green) : C.indigo;
    final circleFg = reached ? (done ? C.green : C.white) : C.muted;
    final note = entry?.note.trim() ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                RoundIcon(
                    icon: data.icon,
                    bg: circleBg,
                    fg: circleFg,
                    size: 40,
                    iconSize: 20),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: nextReached ? C.green : C.indigo,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. ${data.title}',
                    style: ty(17, 700,
                        color: reached ? (done ? C.green : C.ink) : C.muted,
                        lh: 1.25),
                  ),
                  const SizedBox(height: 6),
                  if (reached && entry != null)
                    MiniChip(
                        text: fmtDateTime(entry!.at), bg: C.indigo, fg: C.slate)
                  else if (!reached)
                    const MiniChip(
                        text: 'Menunggu', bg: C.indigoSoft, fg: C.muted),
                  const SizedBox(height: 6),
                  Text(
                    reached
                        ? data.desc
                        : 'Akan diperbarui setelah petugas menindaklanjuti.',
                    style: ty(14, 400,
                        color: reached ? C.slate : C.muted, lh: 1.4),
                  ),
                  if (reached && note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.indigoSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 16, color: C.slate),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Catatan petugas: $note',
                              style: ty(13.5, 500, color: C.ink, lh: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectedStep extends StatelessWidget {
  const _RejectedStep({required this.reason, required this.at});

  final String reason;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RoundIcon(
          icon: Icons.block,
          bg: Color(0xFFFFE3E0),
          fg: C.red,
          size: 40,
          iconSize: 20,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('2. Laporan Ditolak',
                  style: ty(17, 700, color: C.red, lh: 1.25)),
              const SizedBox(height: 6),
              if (at != null)
                MiniChip(text: fmtDateTime(at!), bg: C.indigo, fg: C.slate),
              const SizedBox(height: 6),
              Text(
                'Laporan ini tidak dapat diproses oleh petugas.',
                style: ty(14, 400, color: C.slate, lh: 1.4),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: C.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason.isEmpty
                            ? 'Alasan tidak dicantumkan.'
                            : 'Alasan: $reason',
                        style: ty(13.5, 500, color: C.ink, lh: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Anda dapat menghapus laporan ini lalu membuat laporan baru bila perlu.',
                style: ty(13, 500, color: C.muted, lh: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
