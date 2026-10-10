# Putting Kernel Panic on your phone

The project is already set up for mobile: landscape orientation, touch controls
(floating joystick, tap cards, pinch-zoom research tree), notch-safe UI,
Android back button support, and an automatic Performance Mode on phones.
Export presets for Android and iOS are included in `export_presets.cfg`.

## Try the touch controls on PC first
Hold the left mouse button anywhere in a run and drag: that's the same joystick
you get on a phone. The research tree also works with click + drag + scroll.

## Android (APK)
1. In Godot: Editor > Manage Export Templates > Download and Install.
2. Install the Android SDK + a JDK (Godot 4.5 docs: "Exporting for Android" lists
   the exact versions), then set their paths in Editor > Editor Settings > Export > Android.
   Godot can generate a debug keystore for you there.
3. Project > Export > choose the "Android" preset > Export Project.
   Or plug in your phone with USB debugging on and press the Android "remote deploy" button
   in the top-right of the editor to install and run it directly.
4. Change `package/unique_name` (com.kernelpanic.game) to your own before publishing.

## iOS
Requires a Mac with Xcode and an Apple developer account.
Fill in your Team ID in the "iOS" preset, export, then build/run the generated Xcode project.

## Notes
- Options > Performance Mode reduces glows, particles and the enemy cap.
  It's on by default on phones; turn it off on a strong device.
- The CRT filter is off by default on phones (it costs a full-screen pass).
