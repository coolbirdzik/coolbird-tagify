# Mobile Permissions UX Spec (Android & iOS)

## Overview

Goal: Deliver a clear, repeatable permissions experience with a pre-permission explainer, feature-level soft-blocks, and reliable re-prompt logic.

Scope: Storage/Photos and Local Network are mandatory; Notifications is optional. Location is excluded unless later proven necessary by platform constraints.

## Platforms & Permissions

- Mandatory
  - Storage/Photos
    - Android: Read media categories (scoped, API-level appropriate)
    - iOS: Photos access (consider Limited vs Full)
  - Local Network (for SMB discovery/streaming)
    - iOS: Local Network permission
    - Android: Only if strictly required by discovery mechanism
- Optional
  - Notifications (progress, status)

## UX Principles

- Explain before asking: Display an explainer card per permission with purpose and affected features.
- Ask at the right time: Tap "Cấp quyền" triggers the native prompt; avoid surprise prompts.
- Soft-block, not hard-block: Allow entering the app, but gate features that require missing permissions with clear guidance.
- Repeat when still missing mandatory permissions on next launch.

## Screens & Flows

### 1) Permission Explainer Screen (On Launch If Missing Mandatory)

- Header: "Quyền cần để app hoạt động đúng"
- Cards (grouped by context):
  - Phát file nội bộ → Storage/Photos (Bắt buộc)
    - Subtitle: "Để quét, phát và quản lý file/video trong máy."
  - Duyệt mạng nội bộ (SMB) → Local Network (Bắt buộc)
    - Subtitle: "Để duyệt thiết bị trong mạng nội bộ và phát nội dung từ đó."
  - Tiện ích → Notifications (Tùy chọn)
    - Subtitle: "Để nhận báo tiến trình và thông tin quan trọng."
- Each card shows current status: Đã cấp / Chưa cấp
- Primary CTA per card: "Cấp quyền" → triggers native prompt for that permission
- Secondary global CTA: "Bỏ qua, vào app" → continue with soft-blocks in place
- Auto-show condition on launch: if any mandatory permission remains missing

Wireframe (textual):

- AppBar: none
- Body: Section title + list of cards
  - Card: [Icon] [Title] [Subtitle] [Status Badge] [Button: Cấp quyền]
- Footer: [TextButton: Bỏ qua, vào app]

### 2) In-Context Soft-Block Overlay

- Trigger: User taps into a feature requiring a missing permission
- Content: Short reason, affected feature, CTA
  - Title: "Cần quyền {X}"
  - Body: 1–2 câu giải thích
  - Primary CTA: "Cấp quyền" (prompt or open Settings if suppressed)
  - Secondary CTA: "Để sau" (dismiss)

### 3) Settings Redirect States

- Android ("Don’t ask again")
  - After denial with suppression, "Cấp quyền" opens App Settings → highlight required permission
- iOS Photos Limited
  - Show "Nâng quyền trong Cài đặt"; deep link `app-settings:` if supported

## Copy (VI)

- Storage/Photos: "Để quét, phát và quản lý file/video trong máy."
- Local Network: "Để duyệt thiết bị trong mạng nội bộ và phát nội dung từ đó."
- Notifications: "Để nhận báo tiến trình và thông tin quan trọng."
- Soft-block title: "Cần quyền {Tên quyền}"
- Soft-block body (example Storage): "Bạn cần cấp quyền Ảnh/Tệp để xem và phát file nội bộ."
- Settings hint: "Mở Cài đặt để cấp quyền."

## State & Logic

State flags (persisted):

- `hasStorageOrPhotosPermission: boolean`
- `hasLocalNetworkPermission: boolean` (iOS; Android only if applicable)
- `hasNotificationsPermission: boolean`
- Derived: `isOnboardingPermissionsResolved = hasStorageOrPhotosPermission && hasLocalNetworkPermission`

Launch routing:

- If `!isOnboardingPermissionsResolved` → show Permission Explainer
- Else → proceed to Home; if notifications missing → show dismissible banner

Card status update:

- After native prompt result, refresh status immediately (optimistic update followed by verification if needed)

In-context gating:

- Check required permission before entering feature; if missing → show soft-block overlay

Suppression handling:

- Android: if user selects "Don’t ask again" → future CTAs open Settings
- iOS Limited Photos: if feature needs full access → CTA opens Settings to upgrade

Repeat policy:

- Explainer reappears on next launch until all mandatory permissions are granted
- Do not include a "don’t show again" switch

## Acceptance Criteria

1. On launch, if any mandatory permission is missing, show the Permission Explainer Screen with cards, correct statuses, and functioning CTAs.
2. Tapping "Cấp quyền" invokes the correct native prompt for that permission; status updates immediately after user action.
3. Tapping "Bỏ qua, vào app" allows entry; features requiring missing permissions are soft-blocked with clear messaging and CTAs.
4. On subsequent launches, the explainer reappears until all mandatory permissions are granted.
5. Android "Don’t ask again" and iOS Photos Limited are correctly detected; subsequent CTAs route to Settings/deeplink.
6. Copy is Vietnamese, consistent across Android and iOS.

## Test Scenarios

- Onboarding
  - Missing both mandatory → explainer shows 2 mandatory cards + optional notifications
  - Grant Storage then back to screen shows updated status; still missing Local Network keeps screen visible
  - Skip → home loads; accessing SMB browser triggers soft-block
- In-Context
  - Enter local playback without Storage/Photos → soft-block, CTA prompts for permission
  - Enter SMB without Local Network (iOS) → soft-block, CTA prompts or Settings if suppressed
- Suppression
  - Android deny with "Don’t ask again" → subsequent CTA opens App Settings
  - iOS Photos Limited → attempting to access full library shows upgrade CTA to Settings
- Repeat Launch
  - After granting all mandatory permissions → explainer no longer appears; banner suggests notifications

## Analytics & Telemetry

Events:

- `perm_explainer_shown` { missing: [storage|local_network|notifications] }
- `perm_request_clicked` { type: storage|local_network|notifications }
- `perm_request_result` { type, result: granted|denied|suppressed|limited }
- `soft_block_shown` { feature: smb|local_playback, missing: type }
- `open_settings_clicked` { type }
- `notifications_banner_shown` {}
- `notifications_grant_clicked` {}

KPIs:

- Opt-in rate per permission (explainer vs in-context)
- CTR on "Cấp quyền" and "Mở Cài đặt"
- # of sessions until mandatory permissions complete

## Implementation Notes (Non-binding)

- Flutter: maintain a small permission service wrapping platform checks; centralize permission state; emit streams for UI updates
- Respect platform nuances (scoped media on Android, Limited Photos on iOS)
- Avoid requesting Location unless later required by discovery approach
