$ErrorActionPreference = "Stop"

function Read-Utf8 {
    param([string]$Path)
    return [System.IO.File]::ReadAllText((Resolve-Path $Path))
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Resolve-Path $Path), $Content, $utf8NoBom)
}

function Replace-Regex {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Replacement
    )
    $content = Read-Utf8 $Path
    $updated = [System.Text.RegularExpressions.Regex]::Replace(
        $content,
        $Pattern,
        $Replacement,
        [System.Text.RegularExpressions.RegexOptions]::Multiline
    )
    if ($updated -eq $content) {
        Write-Host "No change needed: $Path" -ForegroundColor DarkGray
        return
    }
    Write-Utf8 $Path $updated
    Write-Host "Updated: $Path" -ForegroundColor Green
}

Write-Host "Applying Face Name no-Storage patch (Windows-safe)..." -ForegroundColor Cyan

# Remove firebase_storage dependency
Replace-Regex "flutter_app/pubspec.yaml" '^\s*firebase_storage:\s*\^[^\r\n]+\r?\n' ''

# Remove Storage bucket configuration
Replace-Regex "flutter_app/lib/config/app_config.dart" '(?ms)^\s*static const firebaseStorageBucket\s*=\s*String\.fromEnvironment\(\s*''FIREBASE_STORAGE_BUCKET'',\s*defaultValue:\s*''''\s*\);\s*\r?\n' ''
Replace-Regex "flutter_app/lib/config/app_config.dart" '^\s*firebaseStorageBucket\.isNotEmpty\s*&&\s*\r?\n' ''

Replace-Regex "flutter_app/lib/config/firebase_options.dart" '^\s*storageBucket:\s*AppConfig\.firebaseStorageBucket,\s*\r?\n' ''

# Make API image_path optional
Replace-Regex "flutter_app/lib/services/api_service.dart" 'required String imagePath,' 'String? imagePath,'
Replace-Regex "flutter_app/lib/services/api_service.dart" "^\s*request\.fields\['image_path'\]\s*=\s*imagePath;\s*$" @'
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      request.fields['image_path'] = imagePath.trim();
    }
'@

# Remove StorageService usage from Home
Replace-Regex "flutter_app/lib/screens/home/home_screen.dart" "^import '../../services/storage_service\.dart';\r?\n" ''
Replace-Regex "flutter_app/lib/screens/home/home_screen.dart" '^\s*final _storage = StorageService\(\);\r?\n' ''
Replace-Regex "flutter_app/lib/screens/home/home_screen.dart" '^\s*String\? uploadedPath;\r?\n\r?\n' ''
Replace-Regex "flutter_app/lib/screens/home/home_screen.dart" '(?ms)^\s*uploadedPath \?\?= await _storage\.uploadEnrollmentImage\(file\);\s*\r?\n\s*final saved = await _api\.enroll\(\s*\r?\n\s*image: file,\s*\r?\n\s*faceIndex: face\.index,\s*\r?\n\s*name: name,\s*\r?\n\s*imagePath: uploadedPath!,\s*\r?\n\s*\);' @'
                final saved = await _api.enroll(
                  image: file,
                  faceIndex: face.index,
                  name: name,
                );
'@
Replace-Regex "flutter_app/lib/screens/home/home_screen.dart" 'Face templates are compared only against the signed-in user’s private database\.' 'Photos are processed for recognition and are not permanently stored. Only the private face template and tag are retained.'

# Remove StorageService usage from My Faces
Replace-Regex "flutter_app/lib/screens/faces/my_faces_screen.dart" "^import '../../services/storage_service\.dart';\r?\n" ''
Replace-Regex "flutter_app/lib/screens/faces/my_faces_screen.dart" '^\s*final _storage = StorageService\(\);\r?\n' ''
Replace-Regex "flutter_app/lib/screens/faces/my_faces_screen.dart" '(?ms)^\s*if \(face\.imagePath != null && face\.imagePath!\.isNotEmpty\) \{\s*\r?\n\s*await _storage\.deletePath\(face\.imagePath!\);\s*\r?\n\s*\}\s*\r?\n' ''

# Firebase deploy config -> Firestore only
$firebaseJson = @'
{
  "firestore": {
    "rules": "firestore.rules"
  }
}
'@
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Resolve-Path "firebase/firebase.json"), $firebaseJson, $utf8NoBom)
Write-Host "Updated: firebase/firebase.json" -ForegroundColor Green

# Remove Storage secret from Android build script
Replace-Regex "scripts/build_android.sh" '^\s*FIREBASE_STORAGE_BUCKET\r?\n' ''
Replace-Regex "scripts/build_android.sh" '^\s*--dart-define="FIREBASE_STORAGE_BUCKET=\$FIREBASE_STORAGE_BUCKET"\s*\\\r?\n' ''

# Remove Storage secret from workflow
Replace-Regex ".github/workflows/android.yml" '^\s*FIREBASE_STORAGE_BUCKET:\s*\$\{\{\s*secrets\.FIREBASE_STORAGE_BUCKET\s*\}\}\r?\n' ''

# Delete obsolete Storage files
if (Test-Path "flutter_app/lib/services/storage_service.dart") {
    Remove-Item "flutter_app/lib/services/storage_service.dart"
    Write-Host "Deleted: flutter_app/lib/services/storage_service.dart" -ForegroundColor Yellow
}
if (Test-Path "firebase/storage.rules") {
    Remove-Item "firebase/storage.rules"
    Write-Host "Deleted: firebase/storage.rules" -ForegroundColor Yellow
}

# Add documentation note
$note = @'
# No-Storage Initial Release

Firebase Storage is intentionally disabled for the initial Face Name release.

Recognition/enrollment images are sent to the authenticated backend over HTTPS and processed in memory. The app does not archive the source image. Only the private face template and user-supplied tag are persisted in Firestore by the backend.

This avoids requiring Firebase Blaze billing for the first release and reduces retained biometric/photo data.
'@
[System.IO.File]::WriteAllText(
    (Join-Path (Get-Location) "NO_STORAGE_MODE.md"),
    $note,
    $utf8NoBom
)
Write-Host "Created/updated: NO_STORAGE_MODE.md" -ForegroundColor Green

Write-Host ""
Write-Host "Patch finished successfully." -ForegroundColor Cyan
Write-Host "Now run: git status" -ForegroundColor Yellow
