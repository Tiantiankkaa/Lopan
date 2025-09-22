# iOS 26 UI/UX Implementation Plan

## Apple Design Foundations
- Follow the 2024 Human Interface Guidelines for iOS: clarity-first designs, depth via subtle materials, and deference to content.
- Use the platform navigation stack, toolbars, tab bars, and sheets; avoid rebuilding standard navigation controls.
- Interactions must feel immediate: primary tasks are accessible within one tap, secondary actions live in menus.
- Build from a design system (colors, typography, spacing, motion, haptics) mapped to Apple’s tokens.
- Animations reinforce action (0.2–0.4 s springs) and obey `Reduce Motion`; materials degrade gracefully when `Reduce Transparency` is enabled.

## iOS 26 Development Rules
- **Navigation**: one back button per screen; rely on `NavigationStack` and `ToolbarItem`. Remove redundant chevrons.
- **Hierarchy**: push flows with `NavigationStack`, short tasks with `sheet`, immersive flows with `fullScreenCover`.
- **Adaptive Layout**: 8pt grid, Dynamic Type friendly layouts, support compact/regular widths; use `NavigationSplitView` for iPad/macOS Catalyst.
- **Typography**: Dynamic Type (`.headline`, `.title3`, `.body`, `.footnote`, etc.) everywhere; minimum line-height 120%.
- **Colors & Contrast**: Use asset catalog palette, ensure 4.5:1 contrast, support light/dark, don’t rely on color alone.
- **Controls**: Prefer system controls; custom control must behave like a SwiftUI `Control`. Touch targets ≥44×44 pt.
- **Icons**: Prefer SF Symbols matched to text weight. Provide multicolor variants only when needed.
- **Motion**: Use matched geometry sparingly; call `withAnimation(.spring(response: 0.4, dampingFraction: 0.8)`); respect motion/accessibility settings.
- **Accessibility**: Each composite view uses `accessibilityElement(children: .ignore)` with label/value/hints and explicit actions. Test with VoiceOver, Switch Control, Dynamic Type XL, Reduce Motion.
- **Haptics**: Centralize haptic calls (iOS 17+ `sensoryFeedback`, fallback to generators). Respect `Reduce Motion`.

## Localization & Internationalization
- Base locale `zh-Hans`; localize strings with `LocalizedStringKey` and `.stringsdict`. Provide English + other locales as needed.
- Use system formatters (`Date.FormatStyle`, `MeasurementFormatter`). For Chinese: `yyyy年M月d日 EEEE`.
- Support right-to-left by testing with `.environment(\.layoutDirection, .rightToLeft)`.
- Allow multi-line labels, use `minimumScaleFactor` where truncation is unavoidable.
- Validate localizations in CI (`xcodebuild test`) for `zh-Hans`, `en`, `ar`, `fr`.

## Cutting-Edge Yet Simple Concepts
1. **Glassmorphism Lite** using `Material`/LiquidGlass components with fallbacks before iOS 17.
2. **Contextual Floating Filters** with `Menu` + `ControlGroup`.
3. **Live Metrics** using numeric `contentTransition`.
4. **Thumb-Friendly Layouts**: quick stats at top, list center, primary CTA bottom.
5. **Predictive Preloading** via `ViewPreloadManager` to warm heavy flows.

## Implementation Roadmap (targeting iOS 26)

### Phase 1 – Foundation (Weeks 1–2)
- Audit current screens vs HIG checklist (navigation, typography, contrast, accessibility).
- Consolidate design tokens into `DesignSystem` (colors, type, spacing, motion, haptics).
- Validate localization pipeline; ensure base strings and `.stringsdict` coverage.

### Phase 2 – Component Hardening (Weeks 3–4)
- Refactor shared components (`StatusNavigationBar`, `AdaptiveDateNavigationBar`, `QuickStatCard`, `OutOfStockCardView`, sheets).
- Add accessibility modifiers with merged elements.
- Ensure Dynamic Type scaling in previews (light/dark, zh/en, XL).
- Implement centralized haptic helper.

### Phase 3 – Screen Compliance (Weeks 5–6)
- Update each screen (customer out-of-stock, analytics, batch management). Remove custom nav bars, align headers, apply tokens.
- Validate skeleton states, filter transitions, responsiveness under Reduce Motion.
- Add UI tests to confirm single back button per screen.
- Conduct manual VoiceOver & Switch Control passes.

### Phase 4 – QA & Automation (Weeks 7–8)
- Add snapshot tests (light/dark, Dynamic Type XL, zh/en).
- Extend UI tests for quick stats, filters, creation flows.
- Introduce lint step for accessibility + localization checks.
- Run pseudo-localization to catch truncation.

### Phase 5 – Continuous Enforcement
- Document `DesignReview.md` with checklist; require screenshots + localization proof for every PR.
- Maintain “Known HIG Deviations” log with rationale and revisit each release.
- Schedule quarterly design audits (update tokens for future iOS releases).

## Compliance Notes for iOS 26
- Liquid Glass components require iOS 17+; wrap in `if #available(iOS 17.0, *)` with fallback backgrounds.
- `sensoryFeedback` and numeric `contentTransition` require iOS 17; guard with availability.
- Use `NavigationStack`/`ToolbarItem` APIs introduced in iOS 16+, confirmed compatible with iOS 26.
- Ensure features tie into `VisionOS` patterns where possible (shared tokens, blur semantics).
