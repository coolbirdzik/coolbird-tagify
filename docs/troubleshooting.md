# Troubleshooting

## Build Issues

- Run `flutter clean && flutter pub get`
- Ensure correct platform SDK versions

## Android

- Check `local.properties` sdk.dir
- Run Gradle sync in Android Studio

## iOS

- Run `pod install` in `ios/`
- Open `.xcworkspace`

## Desktop

- Ensure platform requirements (CMake, toolchains)

## Common Runtime Problems

- Permissions: verify Android/iOS entitlements
- Network: check SMB/streaming configs

## Logging

- Use `flutter run -v` for verbose logs
- Add temporary logs in services/blocs when isolating issues
