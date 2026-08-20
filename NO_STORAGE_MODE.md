# No-Storage Initial Release

Firebase Storage is intentionally disabled for the initial Face Name release.

Recognition/enrollment images are sent to the authenticated backend over HTTPS and processed in memory. The app does not archive the source image. Only the private face template and user-supplied tag are persisted in Firestore by the backend.

This avoids requiring Firebase Blaze billing for the first release and reduces retained biometric/photo data.