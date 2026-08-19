# Face Name — Production Source

Face Name is a Flutter + Firebase + Python face-recognition application.

## Included

- Flutter Android/iOS app source
- Google, email/password, and anonymous authentication
- Firestore user profile persistence
- Camera capture and multi-image gallery selection
- Multi-face recognition in one photo
- Tagging/enrollment of unknown faces
- Per-user private face database
- Firebase Storage archival of enrollment images
- FastAPI backend using `face_recognition`
- Firebase ID-token verification
- Firestore and Storage security rules
- Docker / Render deployment
- GitHub Actions Android APK workflow
- Flutter Android/iOS scaffold bootstrap script

## Firebase credentials are intentionally not included

A real Firebase project is required before authentication, Storage, Firestore, and Google Sign-In can work. Never commit a Firebase Admin service-account private key.

## Architecture

1. The user signs in through Firebase Authentication.
2. Flutter sends a Firebase ID token to the API as a Bearer token.
3. Recognition images are sent over HTTPS directly to the backend.
4. The backend creates 128D face encodings using `face_recognition`.
5. Private encodings are stored under `users/{uid}/faces/{faceId}` in Firestore.
6. Client Firestore rules deny access to those encodings.
7. Enrollment images are archived in `face-images/{uid}/...` in Firebase Storage.
8. All matching is scoped to the signed-in user's database.

## Quick start

### Flutter scaffold

Install Flutter, then:

```bash
cd flutter_app
bash ../scripts/bootstrap_flutter.sh
flutter pub get
```

Android package and iOS bundle ID:

```text
com.farooq77.facename
```

### Firebase

Enable:
- Google Authentication
- Email/Password Authentication
- Anonymous Authentication
- Firestore
- Storage

Add native files after bootstrapping:
- `google-services.json` -> `flutter_app/android/app/google-services.json`
- `GoogleService-Info.plist` -> `flutter_app/ios/Runner/GoogleService-Info.plist`

Deploy rules from the `firebase` folder.

### Backend

See `backend/README.md`.

### Runtime client configuration

Run/build with:

```bash
flutter run   --dart-define=FACE_NAME_API_BASE_URL=https://YOUR-API.example.com   --dart-define=FIREBASE_API_KEY=...   --dart-define=FIREBASE_PROJECT_ID=...   --dart-define=FIREBASE_MESSAGING_SENDER_ID=...   --dart-define=FIREBASE_STORAGE_BUCKET=...   --dart-define=FIREBASE_ANDROID_APP_ID=...   --dart-define=FIREBASE_IOS_APP_ID=...   --dart-define=FIREBASE_IOS_BUNDLE_ID=com.farooq77.facename   --dart-define=GOOGLE_SERVER_CLIENT_ID=...   --dart-define=GOOGLE_IOS_CLIENT_ID=...
```

If Firebase values are absent, the app still compiles and opens a setup screen instead of crashing.

## Privacy

Face templates are biometric identifiers. Before public distribution, add a privacy policy, explicit consent, retention/deletion policy, and jurisdiction-specific legal review.

## Production checklist

- [ ] Connect your Firebase project
- [ ] Enable required authentication providers
- [ ] Add Android SHA-1/SHA-256 for Google Sign-In
- [ ] Deploy Firestore/Storage rules
- [ ] Deploy backend behind HTTPS
- [ ] Store Firebase Admin credentials only as backend secrets
- [ ] Test on physical Android and iOS devices
- [ ] Add privacy/biometric consent UX
- [ ] Configure Play Store / App Store signing
