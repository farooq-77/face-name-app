$ErrorActionPreference = "Stop"

function Replace-Text {
    param(
        [string]$Path,
        [string]$Old,
        [string]$New
    )
    $content = Get-Content -Raw -LiteralPath $Path
    if (-not $content.Contains($Old)) {
        throw "Expected text not found in $Path"
    }
    $content = $content.Replace($Old, $New)
    Set-Content -LiteralPath $Path -Value $content -Encoding utf8
}

Write-Host "Applying Face Name no-Storage patch..." -ForegroundColor Cyan

# 1) pubspec: remove Firebase Storage package
Replace-Text "flutter_app/pubspec.yaml" "  firebase_storage: ^13.4.5`n" ""

# 2) AppConfig: Storage bucket is no longer required
Replace-Text "flutter_app/lib/config/app_config.dart" @'
  static const firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
'@ ""

Replace-Text "flutter_app/lib/config/app_config.dart" @'
        firebaseMessagingSenderId.isNotEmpty &&
        firebaseStorageBucket.isNotEmpty &&
        appId.isNotEmpty;
'@ @'
        firebaseMessagingSenderId.isNotEmpty &&
        appId.isNotEmpty;
'@

# 3) FirebaseOptions: remove storageBucket assignment
Replace-Text "flutter_app/lib/config/firebase_options.dart" "        storageBucket: AppConfig.firebaseStorageBucket,`n" ""

# 4) API: make imagePath optional and only send if present
Replace-Text "flutter_app/lib/services/api_service.dart" @'
    required String imagePath,
'@ @'
    String? imagePath,
'@

Replace-Text "flutter_app/lib/services/api_service.dart" @'
    request.fields['image_path'] = imagePath;
'@ @'
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      request.fields['image_path'] = imagePath.trim();
    }
'@

# 5) Home screen: remove StorageService use
Replace-Text "flutter_app/lib/screens/home/home_screen.dart" "import '../../services/storage_service.dart';`n" ""
Replace-Text "flutter_app/lib/screens/home/home_screen.dart" "  final _storage = StorageService();`n" ""
Replace-Text "flutter_app/lib/screens/home/home_screen.dart" "    String? uploadedPath;`n`n" ""

Replace-Text "flutter_app/lib/screens/home/home_screen.dart" @'
                uploadedPath ??= await _storage.uploadEnrollmentImage(file);
                final saved = await _api.enroll(
                  image: file,
                  faceIndex: face.index,
                  name: name,
                  imagePath: uploadedPath!,
                );
'@ @'
                final saved = await _api.enroll(
                  image: file,
                  faceIndex: face.index,
                  name: name,
                );
'@

Replace-Text "flutter_app/lib/screens/home/home_screen.dart" @'
                  'Face templates are compared only against the signed-in user’s private database.',
'@ @'
                  'Photos are processed for recognition and are not permanently stored. Only the private face template and tag are retained.',
'@

# 6) Saved faces screen: remove Storage deletion
Replace-Text "flutter_app/lib/screens/faces/my_faces_screen.dart" "import '../../services/storage_service.dart';`n" ""
Replace-Text "flutter_app/lib/screens/faces/my_faces_screen.dart" "  final _storage = StorageService();`n" ""
Replace-Text "flutter_app/lib/screens/faces/my_faces_screen.dart" @'
      if (face.imagePath != null && face.imagePath!.isNotEmpty) {
        await _storage.deletePath(face.imagePath!);
      }
'@ ""

# 7) Firebase deploy config: Firestore only
@'
{
  "firestore": {
    "rules": "firestore.rules"
  }
}
'@ | Set-Content -LiteralPath "firebase/firebase.json" -Encoding utf8

# 8) Android build script: remove Storage secret
Replace-Text "scripts/build_android.sh" "  FIREBASE_STORAGE_BUCKET`n" ""
Replace-Text "scripts/build_android.sh" "  --dart-define=`"FIREBASE_STORAGE_BUCKET=`$FIREBASE_STORAGE_BUCKET`" \`n" ""

# 9) GitHub Actions: remove Storage secret
Replace-Text ".github/workflows/android.yml" "          FIREBASE_STORAGE_BUCKET: `${{ secrets.FIREBASE_STORAGE_BUCKET }}`n" ""

# 10) Delete obsolete Storage files
if (Test-Path "flutter_app/lib/services/storage_service.dart") {
    Remove-Item "flutter_app/lib/services/storage_service.dart"
}
if (Test-Path "firebase/storage.rules") {
    Remove-Item "firebase/storage.rules"
}

# 11) Add an update note
@'
# No-Storage Initial Release

Firebase Storage is intentionally disabled for the initial Face Name release.

Recognition/enrollment images are sent to the authenticated backend over HTTPS and processed in memory. The app does not archive the source image. Only the private face template and user-supplied tag are persisted in Firestore by the backend.

This avoids requiring Firebase Blaze billing for the first release and reduces retained biometric/photo data.
'@ | Set-Content -LiteralPath "NO_STORAGE_MODE.md" -Encoding utf8

Write-Host ""
Write-Host "Patch applied successfully." -ForegroundColor Green
Write-Host "Next run:" -ForegroundColor Yellow
Write-Host "  git status"
Write-Host "  git add -A"
Write-Host '  git commit -m "Remove Firebase Storage for free initial release"'
Write-Host "  git push"
