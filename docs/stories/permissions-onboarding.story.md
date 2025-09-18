# Story: Permissions Onboarding UX (Brownfield)

## Status: Approved

## Story

As a user,
I want the app to clearly explain and request the necessary permissions,
so that I can understand why permissions are needed and use features smoothly.

## Context Source

- Source Document: `docs/features/permissions-ux.md`
- Enhancement Type: UX improvement for permissions onboarding & in-context gating
- Existing System Impact: Affects app launch flow, local playback, SMB browsing, notifications prompts

## Acceptance Criteria

1. On launch, if Storage/Photos or Local Network (iOS) is missing, show Permission Explainer with per-permission cards, status, and CTA "Cấp quyền".
2. Tap "Cấp quyền" shows native prompt for that permission and updates status instantly after result.
3. Tap "Bỏ qua, vào app" continues; features requiring missing permissions are soft-blocked with clear message and CTA to request again or open Settings when suppressed.
4. On subsequent launches, still-missing mandatory permissions re-trigger the Explainer screen until granted.
5. Android "Don’t ask again" and iOS Photos Limited states are detected; CTAs route to Settings/deeplink accordingly.
6. Copy is Vietnamese and consistent across Android & iOS.

## Dev Technical Guidance

- Mandatory permissions: Storage/Photos, Local Network (iOS).
- Optional: Notifications banner post-onboarding.
- State flags: `hasStorageOrPhotosPermission`, `hasLocalNetworkPermission` (iOS), `hasNotificationsPermission`.
- Launch routing: Show `PermissionExplainerScreen` when mandatory not satisfied.
- In-context gating: Overlay soft-block with CTA when entering features without required permission.
- Suppression handling: Android → open App Settings; iOS Limited Photos → `app-settings:` deeplink.

## Tasks / Subtasks

- [x] Implement `PermissionExplainerScreen` (3 cards, statuses, CTAs; skip button)
  - [x] Read current permission states and render badges
  - [x] Wire "Cấp quyền" to platform-specific prompts per permission
  - [x] Update UI status immediately after the result
- [ ] Implement feature-level soft-block overlays
  - [ ] Local playback soft-block when Storage/Photos missing
  - [ ] SMB browser soft-block when Local Network missing (iOS)
  - [ ] Route to Settings when suppressed/limited
- [x] Add launch routing logic
  - [x] If mandatory not satisfied → show explainer on app start
  - [x] Otherwise proceed; show optional notifications banner
- [ ] Telemetry
  - [ ] Events: `perm_explainer_shown`, `perm_request_clicked`, `perm_request_result`, `soft_block_shown`, `open_settings_clicked`
- [ ] Copy
  - [ ] Use VI strings from spec for titles/subtitles/overlays

## Risks & Mitigations

- Platform differences (Android scoped media, iOS limited photos) → test on multiple OS versions.
- Over-prompting annoyance → keep prompts behind explicit CTAs, not automatic.
- Discovery requires extra permissions on some devices → revisit only if proven necessary.

## Definition of Done

- [ ] All ACs pass on both Android and iOS emulators/devices
- [ ] Telemetry events fire as designed
- [ ] Strings localized in VI (future-proof for i18n)
- [ ] Code follows repo standards and passes CI
