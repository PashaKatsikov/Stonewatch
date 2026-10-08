import 'package:firebase_core/firebase_core.dart';

import '../secure/values.dart';

// ============================================================
// FIREBASE BOOT — manual initialisation from the Rust vault
// ============================================================
// The Firebase config is NOT shipped as a bundled google-services.json
// (which would bake the apiKey / appId / sender id into the APK as
// greppable resource strings). Instead the fields live masked in
// native/stonewatch_core/src/vault.rs and are revealed here to build
// FirebaseOptions for an explicit Firebase.initializeApp(options:).
//
// messagingSenderId is the FCM sender id, which equals the Firebase
// project number already sealed as V_PROJECT_NUMBER.
// ============================================================

/// Assembles [FirebaseOptions] from the vault, or null when the config is not
/// sealed (any required field empty) — callers then stay on the native game.
FirebaseOptions? vaultFirebaseOptions() {
  final String apiKey = revealFbApiKey();
  final String appId = revealFbAppId();
  final String senderId = revealProjectNumber();
  final String projectId = revealFbProjectId();
  if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty || projectId.isEmpty) {
    return null;
  }
  final String bucket = revealFbStorageBucket();
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    storageBucket: bucket.isEmpty ? null : bucket,
  );
}

/// Ensures the default Firebase app is up, initialising it from the vault on
/// first call. Returns the app, or null when the config is not sealed. May
/// throw if the native layer rejects the options; callers guard accordingly.
Future<FirebaseApp?> ensureFirebase() async {
  if (Firebase.apps.isNotEmpty) return Firebase.app();
  final FirebaseOptions? options = vaultFirebaseOptions();
  if (options == null) return null;
  return Firebase.initializeApp(options: options);
}
