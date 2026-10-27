// Konfigurasi Firebase untuk CleanReport.
//
// FILE INI BERISI NILAI CONTOH ("ISI_...") sehingga aplikasi berjalan dalam
// mode lokal (data tersimpan di HP). Untuk menyalakan Firebase sesuai proposal,
// jalankan perintah berikut dari folder project (lihat PANDUAN.md):
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --platforms=android --android-package-name=id.ac.umrah.cleanreport.v2
//
// Perintah itu akan MENIMPA file ini dengan nilai proyek Firebase Anda.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC_o0enebomQWJomUJbn_3cVbVzHOt4XLc',
    appId: '1:834726284889:android:36f94716331642f373ab48',
    messagingSenderId: '834726284889',
    projectId: 'cleanreport-v2',
    storageBucket: 'cleanreport-v2.firebasestorage.app',
  );
}
