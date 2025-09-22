# Accessibility Validation Checklist (Phase 1)

Use this checklist before exiting Phase 1 to ensure each refreshed flow meets the iOS 26 accessibility baseline.

## Global Requirements
- [ ] Dynamic Type: Verify `.large`, `.extraExtraLarge`, and `.accessibilityExtraLarge` in light/dark, zh-Hans/en.
- [ ] VoiceOver: Confirm focus order matches visual hierarchy and every composite view uses `accessibilityElement(children: .ignore)` with `Label/Value/Hint`.
- [ ] Reduce Motion: Disable non-essential animations when `accessibilityReduceMotion` is true; fall back to `.transaction` updates only.
- [ ] Reduce Transparency: Provide solid-colour fallbacks for glass/blur surfaces.
- [ ] Contrast: 4.5:1 minimum for text/icons; document exceptions in `KnownHIGDeviations.md`.

## Batch Workflows
- [x] `BatchProcessingView`: Header collapse animation respects Reduce Motion; machine selection cards expose merged accessibility labels/hints.
- [ ] `BatchCreationView`: Machine pagination buttons have descriptive `accessibilityLabel`s; cache debug overlay is hidden behind an accessibility toggle.
- [x] `BatchManagementView`: Review sheets expose confirmation dialogs and custom actions via `accessibilityAction` when supporting gestures.

## Warehouse Workbench
- [x] Tab bar icons include labels/hints for counts; quick actions use localized identifiers and announce role (e.g., “Warehouse Keeper”).
- [ ] Quick action menu supports VoiceOver rotor navigation (LazyVStack) without trapping focus in the sheet.
- [x] Search/quick action buttons skip haptics when `Reduce Motion` or `isOtherAudioPlaying` is active (handled in `HapticFeedback`).

## Documentation & Reporting
- [ ] Capture screen recordings of VoiceOver passes for `CustomerOutOfStockDashboard`, `BatchProcessingView`, and `WarehouseKeeperTabView`.
- [ ] Update `docs/uiux/phase1_audit.md` with any residual gaps and planned fixes.
- [ ] File tracking tasks for haptic/contrast work that cannot ship in Phase 1.

Keep this checklist in version control and reference it during PR reviews to maintain parity with the Phase 1 goals.
