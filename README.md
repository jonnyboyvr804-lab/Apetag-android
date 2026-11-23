# Ape Tag (Godot 4.3+)

Open this folder in Godot 4.3+ and press F5.

## Controls (touch)
- Left side: floating stick = walk
- Right side drag = look
- L / R: reach and push off the ground; alternate L, R, L, R quickly for a speed combo
- Hold L or R next to a wall to climb it (release at the top to hop over)
- J: jump

## ID login
Tap ID, enter your ID, Login. Each ID opens its own panel:
- Owner panel: fly, speed boost, tag all, ban, respawn all, reset score
- Admin panel: fly, speed boost, tag all
- Moderator panel: ban players / cheaters

The game only stores salted SHA-256 hashes of the IDs (see ID_HASHES in main.gd), not the IDs.
After 5 wrong tries the dialog locks for 30 seconds.
Note: a client-side check can still be edited out by someone who modifies the game files.
For real security the check has to run on a server.

## Building the APK (phone) - one time setup
1. Install Godot 4.3+ and download Export Templates (Editor > Manage Export Templates).
2. Install JDK 17 and the Android SDK (Android Studio's "SDK Manager" works).
   Editor > Editor Settings > Export > Android: set Java SDK Path, Android SDK Path and a debug keystore.
   Make a debug keystore if you have none:
   keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
3. Project > Export > preset "Android (phone APK)" > Export Project. Copy build/scary-baboon.apk to the phone and install it.

## Building the VR APK (Meta Quest)
1. Enable Developer Mode on the Quest (Meta Horizon phone app).
2. In Godot: AssetLib > install "Godot OpenXR Vendors" (version for Godot 4.3).
3. Project > Install Android Build Template. Project > Project Settings > Plugins: enable the OpenXR Vendors plugin.
4. Project > Export > preset "Quest (VR APK)": confirm Use Gradle Build is on, XR Mode = OpenXR, and tick Quest support in the Meta options.
5. Export, then: adb install build/scary-baboon-quest.apk
VR controls: swing your arms while a hand touches the ground, a wall or a tree to push yourself (Gorilla Tag style).
A or B button = jump. Owner/Admin/Moderator panels and the wardrobe are touch-screen menus and are not shown in the headset yet.
