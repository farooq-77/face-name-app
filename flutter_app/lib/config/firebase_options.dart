import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

import 'app_config.dart';

class AppFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isIOS) {
      return FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        appId: AppConfig.firebaseIosAppId,
        messagingSenderId: AppConfig.firebaseMessagingSenderId,
        projectId: AppConfig.firebaseProjectId,
        iosBundleId: AppConfig.firebaseIosBundleId,
      );
    }

    return FirebaseOptions(
      apiKey: AppConfig.firebaseApiKey,
      appId: AppConfig.firebaseAndroidAppId,
      messagingSenderId: AppConfig.firebaseMessagingSenderId,
      projectId: AppConfig.firebaseProjectId,
    );
  }
}
