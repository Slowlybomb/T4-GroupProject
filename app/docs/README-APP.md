# Flutter setup and emulator guide

This guide explains how to install Flutter and run an emulator for this app on macOS, Linux, or Windows.

## 1) Install Flutter SDK (all OS)

1. Download the Flutter SDK for your OS and extract it.
2. Add the Flutter SDK `bin` directory to your PATH.
3. Verify the installation with `flutter doctor`.

References:
- Flutter manual install (all OS). citeturn0search0
- Add Flutter to PATH (Windows/macOS/Linux). citeturn0search2
- `flutter doctor` verification. citeturn6view0

## 2) OS-specific prerequisites

### macOS
- Install Xcode command-line tools:
  ```bash
  xcode-select --install
  ```
- Xcode is required for iOS Simulator and macOS desktop development.

References: citeturn0search0turn2search0

### Linux
- Install required packages (Debian/Ubuntu example):
  ```bash
  sudo apt-get update -y && sudo apt-get upgrade -y
  sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa
  ```
- For Linux desktop builds, install tooling like `clang`, `cmake`, `ninja-build`, and `pkg-config`.

References: citeturn0search0turn0search5

### Windows
- Install Git for Windows before installing Flutter.
- Ensure Flutter SDK `bin` is added to your Windows Path environment variable.

References: citeturn0search0turn0search2

## 3) Set up an emulator

### Android Emulator (macOS/Linux/Windows)
1. Install Android Studio and open **Device Manager**.
2. Click **Create Device**, pick hardware, select a system image, and finish.
3. Start the emulator from the Device Manager.

References: citeturn1search0turn1search4

### iOS Simulator (macOS only)
1. Install and update Xcode.
2. Start the Simulator:
  ```bash
  open -a Simulator
  ```

References: citeturn2search0turn2search1

## 4) Run this app on the emulator

From the Flutter app directory, run:
```bash
cd app/flutter_app
flutter pub get
flutter run
```
If multiple devices are available, select the emulator when prompted by Flutter or your IDE.

Reference: citeturn6view0
