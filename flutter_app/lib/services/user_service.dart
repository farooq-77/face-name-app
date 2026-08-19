import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> ensureUserProfile(User user, String loginType) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snapshot = await ref.get();

    final data = <String, Object?>{
      'uid': user.uid,
      'displayName': user.displayName ?? (user.isAnonymous ? 'Guest' : ''),
      'email': user.email ?? '',
      'isAnonymous': user.isAnonymous,
      'loginType': loginType,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(data, SetOptions(merge: true));
  }
}
