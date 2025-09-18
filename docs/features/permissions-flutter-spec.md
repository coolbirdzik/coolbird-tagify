# Flutter Component Spec — Permissions UX

## Purpose

Define concrete Flutter implementation: widgets, routes, services, state, and telemetry for the permissions explainer + in-context soft-blocks.

Source UX: `docs/features/permissions-ux.md`

## Architecture Overview

- Presentation
  - `PermissionExplainerScreen` (route)
  - `PermissionCard` (widget)
  - `PermissionSoftBlock` (bottom sheet/overlay)
  - Optional `NotificationsBanner` (home banner)
- Domain/Service
  - `PermissionService` (check/request/openSettings)
  - `PermissionState` (ValueNotifier/Bloc)
- Telemetry
  - `Analytics` (event methods)

## Routes

- `routes.permissionExplainer` → `PermissionExplainerScreen`
- Launch guard: if mandatory permissions missing → navigate to explainer before home

## State Model

```dart
class PermissionState {
  final bool hasStorageOrPhotos;
  final bool hasLocalNetwork; // iOS only, Android when applicable
  final bool hasNotifications;
  bool get onboardingResolved => hasStorageOrPhotos && hasLocalNetwork;
}
```

State management options (choose one):

- ValueNotifier<PermissionState> exposed by `PermissionService`
- Or Bloc (`PermissionsCubit`) with states and events

## PermissionService (Facade)

```dart
abstract class PermissionService {
  Future<PermissionState> readCurrent();
  Future<bool> requestStorageOrPhotos();
  Future<bool> requestLocalNetwork(); // iOS only
  Future<bool> requestNotifications();
  Future<void> openAppSettings();
  Stream<PermissionState> changes(); // emit on any update
}
```

- Android: use `permission_handler` with media permissions scoped by API level
- iOS: handle Photos (limited/full) and Local Network (info.plist keys present)

## Analytics API

```dart
abstract class Analytics {
  void permExplainerShown({required List<String> missing});
  void permRequestClicked(String type);
  void permRequestResult(String type, String result); // granted|denied|suppressed|limited
  void softBlockShown(String feature, String missingType);
  void openSettingsClicked(String type);
  void notificationsBannerShown();
  void notificationsGrantClicked();
}
```

## Widgets

### PermissionExplainerScreen

- Props: `PermissionState initialState`
- Subscribes to `PermissionService.changes()`
- Layout: list of `PermissionCard` for Storage/Photos, Local Network (iOS), Notifications (optional)
- Footer: TextButton "Bỏ qua, vào app"
- Actions:
  - Tap card CTA → call `PermissionService.requestX()`, emit analytics
  - After request → refresh UI from stream
  - Skip → Navigator.pop or pushReplacement to Home

### PermissionCard

- Props: `icon, title, subtitle, status, onRequest`
- Status badge: Đã cấp / Chưa cấp

### PermissionSoftBlock (BottomSheet)

- Props: `missingType, title, body, onRequest, onOpenSettings`
- Behavior: if suppressed/limited, hide request CTA and show Open Settings

### NotificationsBanner

- Visible on Home when notifications not granted
- CTA: request notifications, with analytics

## Copy (VI)

Reuse strings from `permissions-ux.md`:

- Titles/subtitles for each permission
- Soft-block title/body templates
- Settings hint

Prefer `intl` ready keys for future i18n.

## Launch Integration

- At app start:
  - `final s = await permissionService.readCurrent();`
  - If `!s.onboardingResolved` → `Navigator.pushReplacementNamed(routes.permissionExplainer)`
- After returning from explainer, always re-check state

## Feature Guards (In-Context)

- Before entering local playback: ensure `hasStorageOrPhotos`; otherwise show `PermissionSoftBlock`
- Before entering SMB browser (iOS): ensure `hasLocalNetwork`; otherwise soft-block
- Guard helper:

```dart
Future<bool> guardPermission({required bool condition,
  required BuildContext context,
  required String missingType,
  required Future<bool> Function() request,
}) async {
  if (condition) return true;
  // show bottom sheet with CTA
  // return true after success, false otherwise
}
```

## Edge Cases

- Android Don’t ask again → `requestX()` returns denied with `suppressed=true` → subsequent CTAs open settings
- iOS Photos Limited → when feature needs full access, route to settings
- Rapid taps → debounce request calls; disable CTA while awaiting

## Telemetry Placement

- Explainer `initState` → `permExplainerShown(missing)`
- Card CTA tap → `permRequestClicked(type)`
- After prompt result → `permRequestResult(type, result)`
- Soft-block shown → `softBlockShown(feature, missingType)`
- Open settings → `openSettingsClicked(type)`
- Banner shown / CTA → respective events

## Validation Checklist

- [ ] Explainer appears only when mandatory missing
- [ ] Status updates immediately after prompt result
- [ ] Soft-blocks appear at feature entry points
- [ ] Suppressed/limited routes to Settings
- [ ] Analytics events fire per spec
- [ ] Strings centralized for i18n

## Files To Create/Modify (suggested)

- `lib/services/permission_service.dart`
- `lib/services/permission_service_impl.dart`
- `lib/ui/permissions/permission_explainer_screen.dart`
- `lib/ui/permissions/permission_card.dart`
- `lib/ui/permissions/permission_soft_block.dart`
- `lib/ui/home/notifications_banner.dart`
- `lib/routes.dart` (add route)
- `lib/analytics/analytics.dart` (interface)

## Info.plist / AndroidManifest

- iOS: NSPhotoLibraryUsageDescription, NSLocalNetworkUsageDescription (+ Bonjour services if needed)
- Android: ensure required permissions mapped to SDK levels; handle media scoped APIs
