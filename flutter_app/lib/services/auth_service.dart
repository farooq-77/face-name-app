import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import 'user_service.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    UserService? userService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _userService = userService ?? UserService();

  final FirebaseAuth _auth;
  final UserService _userService;
  bool _googleInitialized = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInGuest() async {
    final credential = await _auth.signInAnonymously();
    await _userService.ensureUserProfile(credential.user!, 'guest');
    return credential;
  }

  Future<UserCredential> signInEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _userService.ensureUserProfile(credential.user!, 'email');
    return credential;
  }

  Future<UserCredential> registerEmail(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName.trim().isNotEmpty) {
      await credential.user!.updateDisplayName(displayName.trim());
      await credential.user!.reload();
    }
    await _userService.ensureUserProfile(_auth.currentUser!, 'email');
    return credential;
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> signInGoogle() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS && AppConfig.googleIosClientId.isNotEmpty
            ? AppConfig.googleIosClientId
            : null,
        serverClientId: AppConfig.googleServerClientId.isNotEmpty
            ? AppConfig.googleServerClientId
            : null,
      );
      _googleInitialized = true;
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    await _userService.ensureUserProfile(result.user!, 'google');
    return result;
  }

  Future<void> signOut() async {
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } finally {
      await _auth.signOut();
    }
  }
}
