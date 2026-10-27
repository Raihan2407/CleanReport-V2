import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'services/app_state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Data & backend disiapkan di latar selama animasi splash berjalan.
  store.init();
  runApp(const CleanReportApp());
}

class CleanReportApp extends StatelessWidget {
  const CleanReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CleanReport',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        // Ikon status bar gelap di atas latar terang (splash menimpa jadi terang).
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: C.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}
