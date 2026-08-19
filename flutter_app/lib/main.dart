import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'config/firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/setup_required_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.firebaseConfigured) {
    await Firebase.initializeApp(options: AppFirebaseOptions.currentPlatform);
  }

  runApp(const FaceNameApp());
}

class FaceNameApp extends StatelessWidget {
  const FaceNameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Name',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AppConfig.firebaseConfigured
          ? const AuthGate()
          : const SetupRequiredScreen(),
    );
  }
}
