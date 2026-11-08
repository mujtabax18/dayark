// import 'dart:async';
// import 'package:flutter/foundation.dart';
// // import 'package:google_sign_in/google_sign_in.dart';
//
// // plus your GetX imports, models, etc.
//
// bool googleInitialized = false;
//
// Future<void> ensureGoogleInitialized() async {
//   if (googleInitialized) return;
//
//   // You can wire these via --dart-define if you want:
//   // --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx
//   // --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx
//   const webIdFromEnv = String.fromEnvironment(
//     'GOOGLE_WEB_CLIENT_ID',
//     defaultValue: '',
//   );
//   const serverId = String.fromEnvironment(
//     'GOOGLE_SERVER_CLIENT_ID',
//     defaultValue: '',
//   );
//
//   // Fallback to your existing web client ID if env is empty.
//   final webId = webIdFromEnv.isNotEmpty
//       ? webIdFromEnv
//       : (kIsWeb
//           ? '1078897962612-gi25eummqh39an2radj6c6ilnuj3nf5o.apps.googleusercontent.com'
//           : '');
//
//   await GoogleSignIn.instance.initialize(
//     clientId: webId.isEmpty ? null : webId,
//     serverClientId: serverId.isEmpty ? null : serverId,
//   );
//
//   // Silent / lightweight auth; if it works, you'll get a SignIn event.
//   unawaited(GoogleSignIn.instance.attemptLightweightAuthentication());
//   googleInitialized = true;
// }
