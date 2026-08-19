# Face Name Production Package Manifest

## Flutter
- Google / email-password / anonymous authentication
- Firestore user profile storage
- Camera
- Multi-image gallery
- Multi-face recognition
- Unknown-face tagging
- Saved-face list and deletion
- Firebase Storage enrollment archive
- Authenticated API calls
- Safe setup screen when Firebase is absent

## Backend
- FastAPI
- Firebase Admin token validation
- `face_recognition` HOG detection
- 128D embeddings
- Per-user Firestore storage
- Configurable match tolerance
- Duplicate enrollment prevention
- Image upload safeguards
- Docker + Render files

## Security
- No committed service-account key
- Client Firestore rules deny biometric embeddings
- Per-user Storage rules
- Firebase ID-token verification
- No wildcard CORS by default

## Build
- Flutter bootstrap script
- Android build script
- GitHub Actions APK workflow

## Still required for real deployment
- Your Firebase client credentials
- Backend Firebase Admin secret
- Live backend URL
- Store signing credentials
- Privacy policy / biometric consent
