// File generated for Firebase configuration
// This file is required for Firebase initialization across platforms

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCRsbLjjXYDpf8spqqK6M21IVdsKkmwwkc',
    appId: '1:542457497074:web:a16d48099255920f1e576b',
    messagingSenderId: '542457497074',
    projectId: 'freezme-844cc',
    authDomain: 'freezme-844cc.firebaseapp.com',
    storageBucket: 'freezme-844cc.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCRsbLjjXYDpf8spqqK6M21IVdsKkmwwkc',
    appId: '1:542457497074:android:a16d48099255920f1e576b',
    messagingSenderId: '542457497074',
    projectId: 'freezme-844cc',
    storageBucket: 'freezme-844cc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCRsbLjjXYDpf8spqqK6M21IVdsKkmwwkc',
    appId: '1:542457497074:ios:a16d48099255920f1e576b',
    messagingSenderId: '542457497074',
    projectId: 'freezme-844cc',
    storageBucket: 'freezme-844cc.firebasestorage.app',
    iosBundleId: 'com.freezme.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCRsbLjjXYDpf8spqqK6M21IVdsKkmwwkc',
    appId: '1:542457497074:ios:a16d48099255920f1e576b',
    messagingSenderId: '542457497074',
    projectId: 'freezme-844cc',
    storageBucket: 'freezme-844cc.firebasestorage.app',
    iosBundleId: 'com.freezme.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCRsbLjjXYDpf8spqqK6M21IVdsKkmwwkc',
    appId: '1:542457497074:web:a16d48099255920f1e576b',
    messagingSenderId: '542457497074',
    projectId: 'freezme-844cc',
    authDomain: 'freezme-844cc.firebaseapp.com',
    storageBucket: 'freezme-844cc.firebasestorage.app',
  );
}
