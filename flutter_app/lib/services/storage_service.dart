import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadEnrollmentImage(File file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('User is not signed in.');

    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final path = 'face-images/$uid/enrollments/$timestamp.jpg';
    final ref = _storage.ref(path);

    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return path;
  }

  Future<void> deletePath(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {
      // Biometric template deletion is authoritative on the backend.
    }
  }
}
