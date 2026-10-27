import 'package:flutter_test/flutter_test.dart';

import 'package:cleanreport/main.dart';

void main() {
  testWidgets('Splash lalu Home menampilkan tab Lapor & Riwayat', (tester) async {
    await tester.pumpWidget(const CleanReportApp());

    // Splash tampil dulu; tunggu animasi selesai lalu masuk ke Home.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Lapor'), findsWidgets);
    expect(find.text('Riwayat'), findsWidgets);
  });
}
