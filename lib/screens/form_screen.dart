import 'dart:io';

import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';
import '../services/app_state.dart';
import '../services/report_repository.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/brand_header.dart';
import '../widgets/common.dart';

/// Formulir laporan: jenis sampah, patokan lokasi, privasi, lalu kirim.
class FormScreen extends StatefulWidget {
  const FormScreen({super.key, required this.draft});

  final ReportDraft draft;

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final TextEditingController _landmark = TextEditingController();
  final TextEditingController _name = TextEditingController();

  String? _category;
  bool _anonymous = true;
  bool _sending = false;
  bool _categoryError = false;

  @override
  void dispose() {
    _landmark.dispose();
    _name.dispose();
    super.dispose();
  }

  void _goTab(int i) {
    if (_sending) return;
    store.tab.value = i;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_category == null) {
      setState(() => _categoryError = true);
      toast(context, 'Pilih jenis sampah dulu.', error: true);
      return;
    }
    final d = widget.draft;
    d.category = _category!;
    d.landmark = _landmark.text.trim();
    d.anonymous = _anonymous;
    d.reporterName = _anonymous ? '' : _name.text.trim();
    d.id ??= store.newDraftId();

    setState(() => _sending = true);
    try {
      final report = await store.submit(d);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SuccessScreen(report: report)),
      );
    } on ReportException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      toast(context, e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      toast(
        context,
        'Laporan belum terkirim. Periksa koneksi internet lalu coba lagi.',
        error: true,
        action: SnackBarAction(label: 'COBA LAGI', textColor: Colors.white, onPressed: _submit),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: C.bg,
        body: Column(
          children: [
            const BrandHeader(subtitle: 'Formulir Laporan'),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  BackPill(
                    label: 'Kembali',
                    onTap: () {
                      if (!_sending) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 16),
                  _summary(),
                  const SizedBox(height: 16),
                  _categoryCard(),
                  const SizedBox(height: 16),
                  _landmarkCard(),
                  const SizedBox(height: 16),
                  _privacyCard(),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Kirim Laporan',
                    icon: Icons.send,
                    loading: _sending,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: C.green),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '100% gratis • Pantau statusnya di tab Riwayat',
                          textAlign: TextAlign.center,
                          style: ty(13, 500, color: C.muted, lh: 1.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNav(active: -1, onSelect: _goTab),
      ),
    );
  }

  // ---- ringkasan foto + lokasi

  Widget _summary() {
    final d = widget.draft;
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 76,
              height: 76,
              child: Image.file(File(d.photoPath), fit: BoxFit.cover, cacheWidth: 300),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MiniChip(text: 'Foto & lokasi siap', icon: Icons.check_circle),
                const SizedBox(height: 8),
                Text(d.addressTitle,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: ty(16, 700, lh: 1.25)),
                const SizedBox(height: 2),
                Text(d.addressSub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ty(13.5, 400, color: C.slate, lh: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- 3. jenis sampah

  Widget _categoryCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepTitle(
            number: 3,
            title: 'Jenis Sampah',
            trailing: Text('Pilih satu', style: ty(13.5, 600, color: C.muted)),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trashCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 128,
            ),
            itemBuilder: (context, i) {
              final c = trashCategories[i];
              return _CategoryTile(
                category: c,
                selected: _category == c.name,
                onTap: () => setState(() {
                  _category = c.name;
                  _categoryError = false;
                }),
              );
            },
          ),
          if (_categoryError) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: C.red),
                const SizedBox(width: 6),
                Text('Pilih salah satu jenis sampah', style: ty(13, 600, color: C.red)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---- patokan lokasi

  Widget _landmarkCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Patokan Lokasi', style: ty(18, 700))),
              const MiniChip(text: 'Opsional', bg: C.indigo, fg: C.slate),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _landmark,
            enabled: !_sending,
            maxLength: AppConfig.landmarkMax,
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.done,
            style: ty(15, 500),
            decoration: _fieldDecoration('Contoh: samping pos ronda / dekat tiang listrik'),
          ),
          const SizedBox(height: 4),
          Text('Membantu petugas langsung menemukan titik sampah.',
              style: ty(12.5, 400, color: C.muted)),
        ],
      ),
    );
  }

  // ---- privasi

  Widget _privacyCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Privasi Warga', style: ty(18, 700))),
              const MiniChip(text: 'Aman', icon: Icons.lock),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Laporkan secara anonim', style: ty(16, 700)),
                    const SizedBox(height: 2),
                    Text('Nama dan identitas Anda dirahasiakan.',
                        style: ty(13.5, 400, color: C.slate, lh: 1.3)),
                  ],
                ),
              ),
              Switch(
                value: _anonymous,
                onChanged: _sending ? null : (v) => setState(() => _anonymous = v),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _anonymous
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _name,
                      enabled: !_sending,
                      maxLength: AppConfig.nameMax,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.words,
                      style: ty(15, 500),
                      decoration: _fieldDecoration('Nama pelapor (opsional), mis. Bpk. Bambang'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: ty(14.5, 400, color: C.muted),
      filled: true,
      fillColor: C.indigoSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: C.green, width: 1.8),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.selected, required this.onTap});

  final TrashCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? C.greenLight : C.indigoSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? C.green : Colors.transparent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(category.icon, size: 26, color: selected ? C.green : C.slate),
                  const Spacer(),
                  Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 22,
                    color: selected ? C.green : C.greyIcon,
                  ),
                ],
              ),
              const Spacer(),
              Text(category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ty(15, 700, color: selected ? C.greenDeep : C.ink, lh: 1.2)),
              const SizedBox(height: 2),
              Text(category.sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ty(12, 400, color: selected ? C.greenDark : C.slate, lh: 1.25)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Layar konfirmasi setelah laporan tersimpan.
class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key, required this.report});

  final Report report;

  void _toTab(BuildContext context, int tab) {
    store.tab.value = tab;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toTab(context, 1);
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: C.green,
                      shape: BoxShape.circle,
                      boxShadow: shadowLift,
                    ),
                    child: const Icon(Icons.check_rounded, color: C.white, size: 72),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Laporan Terkirim!', style: ty(28, 700), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  report.pending
                      ? 'Laporan tersimpan di HP dan akan terkirim otomatis begitu internet tersedia. Anda bisa menutup aplikasi.'
                      : 'Terima kasih sudah peduli lingkungan. Laporan Anda tersimpan dan bisa dipantau di tab Riwayat.',
                  textAlign: TextAlign.center,
                  style: ty(15.5, 400, color: C.slate, lh: 1.45),
                ),
                const SizedBox(height: 18),
                MiniChip(
                  text: report.pending
                      ? '${report.code} • Menunggu internet'
                      : '${report.code} • ${report.status.label}',
                  icon: report.pending ? Icons.cloud_upload : Icons.inbox,
                ),
                const Spacer(),
                AppButton(
                  label: 'Lihat Riwayat',
                  icon: Icons.history,
                  onPressed: () => _toTab(context, 1),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Buat Laporan Lagi',
                  icon: Icons.add_a_photo,
                  kind: ButtonKind.tonal,
                  onPressed: () => _toTab(context, 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
