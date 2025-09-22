# Lopan Design System (Phase 1 Foundation)

This directory holds the shared tokens, themes, and components that drive the iOS 26 UX refresh. During Phase 1 the focus is on standardising the primitives so that every view can adopt the same spacing, typography, colour, motion, and haptic rules.

## Token Hierarchy

| Area | Source | Usage Notes |
| --- | --- | --- |
| Colours (`Tokens/ColorTokens.swift`) | `LopanColors` | Map brand palette to semantic roles (`textPrimary`, `backgroundCard`, role accent colours). Reference these via environment or the helper extensions rather than hard-coded `Color(...)` values. Document new shades in this README before adding them. |
| Typography (`Tokens/TypographyTokens.swift`) | `LopanTypography` | Wraps Dynamic Type styles with four-space indentation/weight presets (`titleMedium`, `bodySmall`). Use these in SwiftUI via `.font(LopanTypography.bodyLarge)` so Dynamic Type and accessibility caps are respected. |
| Spacing (`Tokens/SpacingTokens.swift`) | `LopanSpacing` | 8-pt grid helpers (`xxxs` → `xxl`). When adding layout padding/margins, pick from these constants to keep vertical rhythm consistent. |
| Corners & Elevation (`Tokens/CornerRadiusTokens.swift`, `Tokens/ShadowTokens.swift`) | `LopanCornerRadius`, `LopanShadow` | Corner radii align with card/list patterns; use `.continuous` where specified. Shadows adopt Apple’s Material defaults for light/dark. |
| Motion & Haptics (`Tokens/MotionTokens.swift`, `Tokens/HapticTokens.swift`) | `LopanAnimation`, `HapticFeedback` | Animations default to `withAnimation(.spring(response: 0.4, dampingFraction: 0.8))`. Haptic helpers wrap `sensoryFeedback`/`UIImpactFeedbackGenerator` and must honour `ReduceMotion`/`AVAudioSession`. |

## Components & Themes

- `Components/`: Reusable view modifiers and shells (e.g. LiquidGlass, analytics surfaces). Keep these presentation-only; business logic belongs in ViewModels/UseCases.
- `Theme/`: Defines platform-wide theming (liquid glass materials, accent gradients). Extend here before touching view-level styles.

## Phase 1 Checklist

- [x] Document token usage (this README).
- [ ] Audit existing components for hard-coded colours/spacing and migrate to tokens.
- [ ] Centralise haptic usage so all entry points call `HapticFeedback` with accessibility checks.
- [ ] Add design tokens for elevation overlays (glass backgrounds) once palette is signed off.

Please keep this README updated as new tokens/components are introduced. Every addition should include:

1. A short description of the token/component and its intended use.
2. Any accessibility or localisation considerations.
3. Links to preview files or test cases (if applicable).

