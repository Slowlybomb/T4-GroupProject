# Flutter setup (Android-only) and emulator guide

This guide is for beginners who want to run the Flutter app on an Android emulator
on macOS, Linux, or Windows.

## What you need
- Flutter SDK installed: https://flutter.dev/docs/get-started/install
- Android Studio installed (emulator + SDK tools): https://developer.android.com/studio

## 1) Install Flutter (macOS/Linux/Windows)
1. Download the Flutter SDK for your OS:
   - macOS: https://flutter.dev/docs/get-started/install/macos
   - Linux: https://flutter.dev/docs/get-started/install/linux
   - Windows: https://flutter.dev/docs/get-started/install/windows
2. Extract it and add the `flutter/bin` folder to your PATH:
   - https://flutter.dev/docs/get-started/install#update-your-path
3. Verify the install:
   ```bash
   flutter doctor
   ```

## 2) Install Android Studio and create an emulator
1. Install Android Studio: https://developer.android.com/studio
2. Open Android Studio → **Device Manager**.
3. Click **Create Device**, pick a phone, choose a system image, and finish.
4. Start the emulator from Device Manager.

## 3) Run the app
From the repo root:
```bash
cd app/flutter_app
flutter pub get
flutter run
```

## Troubleshooting

### “No pubspec.yaml file found”
This means `app/flutter_app` is not a Flutter project yet.
Create the project in-place, then try again:
```bash
cd app/flutter_app
flutter create .
flutter pub get
flutter run
```
