# Build Ape Tag for Android

This project includes a GitHub Actions workflow at `.github/workflows/build-android.yml`.
It exports the existing **Android (phone APK)** preset with Godot 4.3 and uploads
`ApeTag.apk` as a workflow artifact.

## Build steps

1. Create a **private or public GitHub repository** and upload the contents of this folder.
2. Open the repository's **Actions** tab.
3. Select **Build Ape Tag Android APK**.
4. Click **Run workflow** and wait for the job to finish.
5. Open the completed run and download the **ApeTag-Android-APK** artifact.
6. Extract the downloaded artifact ZIP; it contains `ApeTag.apk`.

The workflow creates a debug-signed APK for direct installation/testing. It does not
change the game scripts, scene, or Android export preset.
