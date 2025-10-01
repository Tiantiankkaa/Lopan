# Lopan Insights Redesign - Complete Implementation Guide

> **Version:** 1.0.0
> **Date:** 2025-09-30
> **Target:** iOS 17.0+ with iOS 26 optimization
> **Estimated Implementation Time:** 12-14 weeks

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Phase 1: Visual Foundation (Weeks 1-2)](#phase-1-visual-foundation-weeks-1-2)
4. [Phase 2: Navigation Components (Weeks 3-4)](#phase-2-navigation-components-weeks-3-4)
5. [Phase 3: Interactive Charts (Weeks 5-7)](#phase-3-interactive-charts-weeks-5-7)
6. [Phase 4: Advanced Features (Weeks 8-9)](#phase-4-advanced-features-weeks-8-9)
7. [Phase 5: Polish & Optimization (Weeks 10-11)](#phase-5-polish--optimization-weeks-10-11)
8. [Phase 6: Widgets & Extras (Week 12+)](#phase-6-widgets--extras-week-12)
9. [Testing Strategy](#testing-strategy)
10. [Migration Guide](#migration-guide)
11. [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides step-by-step instructions for implementing the complete Lopan Insights redesign, covering:

- **Visual Design System**: Liquid Glass materials, typography, colors
- **Navigation Components**: Time range selector, mode switcher
- **Interactive Charts**: Pie, Bar, Line with full gesture support
- **Advanced Features**: Filters, search, export, AI insights panel
- **Polish**: Microinteractions, animations, accessibility
- **Extras**: Widgets, notifications, performance optimizations

### Design Principles

1. **iOS 26 First, iOS 17 Compatible**: Use latest features with graceful fallbacks
2. **Accessibility Native**: WCAG AA compliance, VoiceOver, Dynamic Type
3. **Performance Critical**: 60fps minimum, memory efficient
4. **Localization Ready**: No hardcoded strings, RTL support
5. **Future Proof**: Architecture ready for AI and collaboration features

---

## Prerequisites

### Development Environment

- Xcode 15.0+ (Xcode 16.0 recommended for iOS 26 features)
- macOS 14.0+ (macOS 15.0 for iOS 26 simulator)
- Swift 5.9+
- iOS Deployment Target: 17.0

### Required Knowledge

- SwiftUI fundamentals
- MVVM architecture
- Async/await concurrency
- Accessibility APIs (VoiceOver, Dynamic Type)
- Core Animation basics

### Existing Codebase

Ensure you have:
- ✅ `EnhancedLiquidGlassManager` (`/DesignSystem/Components/Foundation/EnhancedLiquidGlass.swift`)
- ✅ `LopanColors` and design tokens (`/DesignSystem/Tokens/`)
- ✅ `AdaptiveFluidLayoutManager` (`/DesignSystem/Components/Foundation/AdaptiveFluidLayout.swift`)
- ✅ `CustomerOutOfStockInsightsViewModel` (`/ViewModels/Salesperson/`)

---

## Phase 1: Visual Foundation (Weeks 1-2)

### Goal
Establish the complete visual design system: materials, typography, colors, and responsive layout framework.

### Week 1: Material System & Typography

#### Step 1.1: Extend Liquid Glass Material System

**File:** `/Lopan/DesignSystem/Components/Foundation/EnhancedLiquidGlass.swift`

Add material configurations for Insights components:

```swift
// Add to EnhancedLiquidGlassManager
extension EnhancedLiquidGlassManager {
    /// Creates material for chart containers
    func createChartContainerMaterial() -> some View {
        createGlassMaterial(
            type: .content,
            cornerRadius: 20,
            depth: 2.0,
            isPressed: false,
            isHovered: false,
            customTint: nil
        )
    }

    /// Creates material for time range selector
    func createTimeRangeMaterial() -> some View {
        createGlassMaterial(
            type: .content,
            cornerRadius: 16,
            depth: 1.4,
            isPressed: false,
            isHovered: false,
            customTint: nil
        )
    }

    /// Creates material for mode carousel buttons
    func createModeButtonMaterial(isSelected: Bool, tintColor: Color? = nil) -> some View {
        createGlassMaterial(
            type: .button,
            cornerRadius: 12,
            depth: isSelected ? 1.8 : 1.2,
            isPressed: false,
            isHovered: false,
            customTint: isSelected ? tintColor : nil
        )
    }
}
```

**Testing:**
```swift
#Preview("Chart Container Material") {
    VStack {
        Text("Sample Chart")
            .frame(width: 300, height: 200)
            .background(
                EnhancedLiquidGlassManager.shared.createChartContainerMaterial()
            )
    }
    .padding()
}
```

#### Step 1.2: Create Typography System

**New File:** `/Lopan/DesignSystem/Typography/LopanTypography.swift`

```swift
import SwiftUI

/// Typography system for Lopan Insights
public enum LopanTypography {
    // MARK: - Display Styles

    /// Display text (48pt, Bold, Rounded) - For hero numbers and large KPIs
    public static let display = Font.system(size: 48, weight: .bold, design: .rounded)

    /// Title 1 (28pt, Semibold) - Screen titles, section headers
    public static let title1 = Font.system(size: 28, weight: .semibold, design: .default)

    /// Title 2 (22pt, Semibold) - Card titles, chart headers
    public static let title2 = Font.system(size: 22, weight: .semibold, design: .default)

    /// Title 3 (20pt, Semibold) - Subsection headers
    public static let title3 = Font.system(size: 20, weight: .semibold, design: .default)

    // MARK: - Body Styles

    /// Headline (17pt, Semibold) - Important content
    public static let headline = Font.system(size: 17, weight: .semibold, design: .default)

    /// Body (17pt, Regular) - Standard content
    public static let body = Font.system(size: 17, weight: .regular, design: .default)

    /// Subheadline (15pt, Regular) - Secondary content
    public static let subheadline = Font.system(size: 15, weight: .regular, design: .default)

    // MARK: - Supporting Styles

    /// Footnote (13pt, Regular) - Tertiary content
    public static let footnote = Font.system(size: 13, weight: .regular, design: .default)

    /// Caption 1 (12pt, Regular) - Labels, small text
    public static let caption1 = Font.system(size: 12, weight: .regular, design: .default)

    /// Caption 2 (11pt, Regular) - Smallest readable text
    public static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
}

// MARK: - View Modifiers

extension View {
    /// Applies display text style with monospaced digits
    public func displayStyle() -> some View {
        self
            .font(LopanTypography.display)
            .monospacedDigit()
    }

    /// Applies title 1 style
    public func title1Style() -> some View {
        self.font(LopanTypography.title1)
    }

    /// Applies title 2 style
    public func title2Style() -> some View {
        self.font(LopanTypography.title2)
    }

    /// Applies title 3 style
    public func title3Style() -> some View {
        self.font(LopanTypography.title3)
    }

    /// Applies headline style
    public func headlineStyle() -> some View {
        self.font(LopanTypography.headline)
    }

    /// Applies body style
    public func bodyStyle() -> some View {
        self.font(LopanTypography.body)
    }

    /// Applies subheadline style
    public func subheadlineStyle() -> some View {
        self.font(LopanTypography.subheadline)
    }

    /// Applies footnote style
    public func footnoteStyle() -> some View {
        self.font(LopanTypography.footnote)
    }

    /// Applies caption 1 style
    public func caption1Style() -> some View {
        self.font(LopanTypography.caption1)
    }

    /// Applies caption 2 style
    public func caption2Style() -> some View {
        self.font(LopanTypography.caption2)
    }
}
```

**Testing:**
```swift
#Preview("Typography Scale") {
    VStack(alignment: .leading, spacing: 16) {
        Text("142").displayStyle()
        Text("数据洞察").title1Style()
        Text("区域分析").title2Style()
        Text("上海地区").title3Style()
        Text("重要信息").headlineStyle()
        Text("标准文本").bodyStyle()
        Text("次要信息").subheadlineStyle()
        Text("附注文本").footnoteStyle()
        Text("标签文本").caption1Style()
        Text("最小文本").caption2Style()
    }
    .padding()
}
```

#### Step 1.3: Enhance Color System

**File:** `/Lopan/DesignSystem/Colors/LopanColorsInsights.swift`

```swift
import SwiftUI

/// Color extensions for Insights feature
extension LopanColors {
    // MARK: - Jewel Tones (Mode-specific colors)

    public enum Jewel {
        /// Sapphire - Region mode primary color
        public static let sapphire = Color(red: 0.2, green: 0.4, blue: 0.9)

        /// Emerald - Product mode primary color
        public static let emerald = Color(red: 0.0, green: 0.8, blue: 0.6)

        /// Amethyst - Customer mode primary color
        public static let amethyst = Color(red: 0.6, green: 0.3, blue: 0.9)

        /// Citrine - Supporting accent
        public static let citrine = Color(red: 0.95, green: 0.77, blue: 0.06)

        /// Ruby - Alert/emphasis color
        public static let ruby = Color(red: 0.9, green: 0.2, blue: 0.3)
    }

    // MARK: - Data Visualization Palette (12 colors)

    public static let dataBlue = Color(red: 0.0, green: 0.4, blue: 1.0)
    public static let dataGreen = Color(red: 0.0, green: 0.78, blue: 0.33)
    public static let dataOrange = Color(red: 1.0, green: 0.42, blue: 0.21)
    public static let dataPurple = Color(red: 0.69, green: 0.32, blue: 0.87)
    public static let dataCyan = Color(red: 0.0, green: 0.78, blue: 0.82)
    public static let dataPink = Color(red: 1.0, green: 0.18, blue: 0.58)
    public static let dataYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    public static let dataTeal = Color(red: 0.19, green: 0.74, blue: 0.56)
    public static let dataIndigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    public static let dataRed = Color(red: 1.0, green: 0.27, blue: 0.23)
    public static let dataMint = Color(red: 0.0, green: 0.78, blue: 0.75)
    public static let dataBrown = Color(red: 0.64, green: 0.52, blue: 0.37)

    /// Returns color from data visualization palette by index
    public static func dataColor(at index: Int) -> Color {
        let colors = [
            dataBlue, dataGreen, dataOrange, dataPurple,
            dataCyan, dataPink, dataYellow, dataTeal,
            dataIndigo, dataRed, dataMint, dataBrown
        ]
        return colors[index % colors.count]
    }
}
```

**Testing:**
```swift
#Preview("Data Colors") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) {
        ForEach(0..<12, id: \.self) { index in
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.dataColor(at: index))
                .frame(height: 80)
                .overlay(
                    Text("\(index + 1)")
                        .foregroundStyle(.white)
                        .font(.headline)
                )
        }
    }
    .padding()
}
```

### Week 2: Responsive Layout Framework

#### Step 2.1: Create Grid System

**New File:** `/Lopan/DesignSystem/Layout/LopanGridSystem.swift`

```swift
import SwiftUI

/// 8pt base grid system for consistent spacing
public enum LopanGrid {
    // MARK: - Base Units

    public static let baseUnit: CGFloat = 8.0
    public static let halfUnit: CGFloat = 4.0
    public static let quarterUnit: CGFloat = 2.0

    // MARK: - Multipliers

    public static func space(_ multiplier: CGFloat) -> CGFloat {
        return baseUnit * multiplier
    }

    // MARK: - Common Spacing

    public static let space1 = space(1)   // 8pt
    public static let space2 = space(2)   // 16pt
    public static let space3 = space(3)   // 24pt
    public static let space4 = space(4)   // 32pt
    public static let space5 = space(5)   // 40pt
    public static let space6 = space(6)   // 48pt
    public static let space8 = space(8)   // 64pt

    // MARK: - Gutter System

    public enum Gutters {
        case compact     // 8pt
        case standard    // 12pt
        case comfortable // 16pt
        case spacious    // 20pt

        public var value: CGFloat {
            switch self {
            case .compact: return 8
            case .standard: return 12
            case .comfortable: return 16
            case .spacious: return 20
            }
        }
    }
}

// MARK: - Device Breakpoints

public enum DeviceBreakpoint {
    case phoneSE        // ≤375pt
    case phoneStandard  // 376-420pt
    case phoneProMax    // 421-600pt
    case iPadPortrait   // 601-900pt
    case iPadLandscape  // >900pt

    public init(width: CGFloat) {
        switch width {
        case ...375:
            self = .phoneSE
        case 376...420:
            self = .phoneStandard
        case 421...600:
            self = .phoneProMax
        case 601...900:
            self = .iPadPortrait
        default:
            self = .iPadLandscape
        }
    }

    public var columnCount: Int {
        switch self {
        case .phoneSE: return 1
        case .phoneStandard: return 2
        case .phoneProMax: return 2
        case .iPadPortrait: return 3
        case .iPadLandscape: return 4
        }
    }

    public var horizontalMargin: CGFloat {
        switch self {
        case .phoneSE: return 16
        case .phoneStandard: return 20
        case .phoneProMax: return 24
        case .iPadPortrait: return 32
        case .iPadLandscape: return 40
        }
    }

    public var gutter: CGFloat {
        switch self {
        case .phoneSE: return LopanGrid.Gutters.compact.value
        case .phoneStandard: return LopanGrid.Gutters.standard.value
        case .phoneProMax: return LopanGrid.Gutters.comfortable.value
        case .iPadPortrait: return LopanGrid.Gutters.comfortable.value
        case .iPadLandscape: return LopanGrid.Gutters.spacious.value
        }
    }
}
```

#### Step 2.2: Create Responsive Container

**New File:** `/Lopan/Views/Components/InsightsResponsiveContainer.swift`

```swift
import SwiftUI

/// Responsive container for Insights views
struct InsightsResponsiveContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    let content: (LayoutContext) -> Content

    var body: some View {
        GeometryReader { geometry in
            let context = LayoutContext(
                size: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets,
                horizontalSizeClass: horizontalSizeClass ?? .regular,
                verticalSizeClass: verticalSizeClass ?? .regular,
                dynamicTypeSize: dynamicTypeSize
            )

            ScrollView {
                VStack(spacing: context.sectionSpacing) {
                    content(context)
                }
                .padding(context.contentPadding)
                .frame(maxWidth: context.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Layout context passed to content builder
struct LayoutContext {
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let horizontalSizeClass: UserInterfaceSizeClass
    let verticalSizeClass: UserInterfaceSizeClass
    let dynamicTypeSize: DynamicTypeSize

    var breakpoint: DeviceBreakpoint {
        DeviceBreakpoint(width: size.width)
    }

    var isLargeText: Bool {
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }

    var contentPadding: EdgeInsets {
        let horizontal = breakpoint.horizontalMargin
        let vertical: CGFloat = 16
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    var contentMaxWidth: CGFloat? {
        switch breakpoint {
        case .phoneSE, .phoneStandard:
            return nil
        case .phoneProMax:
            return 400
        case .iPadPortrait:
            return 680
        case .iPadLandscape:
            return 960
        }
    }

    var sectionSpacing: CGFloat {
        let base: CGFloat = 20
        return isLargeText ? base * 1.5 : base
    }

    var columnCount: Int {
        isLargeText ? 1 : breakpoint.columnCount
    }
}
```

**Testing:**
```swift
#Preview("Responsive Container") {
    InsightsResponsiveContainer { context in
        VStack(alignment: .leading, spacing: 16) {
            Text("Breakpoint: \(String(describing: context.breakpoint))")
            Text("Columns: \(context.columnCount)")
            Text("Margin: \(context.breakpoint.horizontalMargin)")
            Text("Max Width: \(context.contentMaxWidth ?? 0)")
        }
    }
}
```

### Deliverables - Phase 1

After Week 2, you should have:
- ✅ Extended Liquid Glass material system
- ✅ Complete typography system with view modifiers
- ✅ Enhanced color palette with data visualization colors
- ✅ Responsive grid system
- ✅ Layout context framework
- ✅ All components tested in Preview

**Validation Checklist:**
- [ ] Materials render correctly in light and dark mode
- [ ] Typography scales properly with Dynamic Type
- [ ] Colors meet WCAG AA contrast requirements
- [ ] Responsive container adapts to all device sizes
- [ ] Code compiles without warnings

---

## Phase 2: Navigation Components (Weeks 3-4)

### Goal
Build the revolutionary Time Range Selector and Analysis Mode Switcher components.

### Week 3: Time Range Selector

#### Step 3.1: Create TimeRange Model Extensions

**File:** `/Lopan/Models/TimeRange.swift` (extend existing)

```swift
extension TimeRange {
    /// Display name for UI
    var localizedDisplayName: LocalizedStringKey {
        switch self {
        case .today: return "insights_time_today"
        case .yesterday: return "insights_time_yesterday"
        case .thisWeek: return "insights_time_this_week"
        case .lastWeek: return "insights_time_last_week"
        case .thisMonth: return "insights_time_this_month"
        case .lastMonth: return "insights_time_last_month"
        case .custom: return "insights_time_custom"
        }
    }

    /// Short label for compact display
    var shortLabel: String {
        switch self {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .thisWeek: return "本周"
        case .lastWeek: return "上周"
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .custom: return "自定义"
        }
    }
}
```

#### Step 3.2: Build Time Range Button Component

**New File:** `/Lopan/Views/Components/TimeRangeButton.swift`

```swift
import SwiftUI

struct TimeRangeButton: View {
    let range: TimeRange
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.enhancedLiquidGlass) private var glassManager

    var body: some View {
        Button(action: handleTap) {
            Text(range.shortLabel)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minWidth: 72, minHeight: 36)
                .background(buttonBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .accessibilityLabel(range.shortLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if isSelected {
            Capsule()
                .fill(glassManager.createGlassMaterial(
                    type: .button,
                    cornerRadius: 18,
                    depth: 1.4,
                    isPressed: isPressed,
                    customTint: LopanColors.primary
                ))
                .shadow(color: LopanColors.primary.opacity(0.2), radius: 8, y: 4)
        } else {
            Capsule()
                .fill(Color.clear)
        }
    }

    private func handleTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isPressed = true
        }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = false
            }
            action()
        }
    }
}
```

#### Step 3.3: Build Complete Time Range Selector

**New File:** `/Lopan/Views/Components/TimeRangeSelector.swift`

```swift
import SwiftUI

struct TimeRangeSelector: View {
    @Binding var selectedRange: TimeRange
    @State private var showingCustomPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimeRange.allCases.filter { $0 != .custom }, id: \.self) { range in
                        TimeRangeButton(
                            range: range,
                            isSelected: selectedRange == range
                        ) {
                            selectedRange = range
                        }
                    }

                    // Custom range button
                    customRangeButton
                }
                .padding(.horizontal, 4)
            }
        }
        .sheet(isPresented: $showingCustomPicker) {
            CustomDateRangePicker(selectedRange: $selectedRange)
        }
    }

    private var sectionHeader: some View {
        HStack {
            Label("时间范围", systemImage: "calendar")
                .font(.headline)

            Spacer()

            if selectedRange == .custom {
                Text("自定义范围")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var customRangeButton: some View {
        Button {
            showingCustomPicker = true
        } label: {
            Label("自定义", systemImage: "calendar.badge.plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minWidth: 72, minHeight: 36)
                .background(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Date Range Picker

struct CustomDateRangePicker: View {
    @Binding var selectedRange: TimeRange
    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Date()
    @State private var endDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("开始日期") {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                Section("结束日期") {
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("自定义时间范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        applyCustomRange()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func applyCustomRange() {
        // TODO: Update TimeRange model to support custom dates
        selectedRange = .custom
        dismiss()
    }
}
```

**Testing:**
```swift
#Preview("Time Range Selector") {
    struct PreviewWrapper: View {
        @State private var selectedRange: TimeRange = .thisWeek

        var body: some View {
            VStack {
                TimeRangeSelector(selectedRange: $selectedRange)

                Spacer()

                Text("Selected: \(selectedRange.shortLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
```

### Week 4: Analysis Mode Switcher

#### Step 4.1: Extend AnalysisMode Model

**File:** `/Lopan/Models/AnalysisMode.swift` (extend existing)

```swift
extension AnalysisMode {
    /// Jewel-tone color for this mode
    var tintColor: Color {
        switch self {
        case .region: return LopanColors.Jewel.sapphire
        case .product: return LopanColors.Jewel.emerald
        case .customer: return LopanColors.Jewel.amethyst
        }
    }

    /// Gradient colors for selected state
    var gradientColors: [Color] {
        switch self {
        case .region: return [LopanColors.Jewel.sapphire, LopanColors.primary]
        case .product: return [LopanColors.Jewel.emerald, LopanColors.success]
        case .customer: return [LopanColors.Jewel.amethyst, LopanColors.secondary]
        }
    }

    /// Localized display name
    var localizedDisplayName: LocalizedStringKey {
        switch self {
        case .region: return "insights_mode_region"
        case .product: return "insights_mode_product"
        case .customer: return "insights_mode_customer"
        }
    }
}
```

#### Step 4.2: Build Mode Segment Button

**New File:** `/Lopan/Views/Components/ModeSegmentButton.swift`

```swift
import SwiftUI

struct ModeSegmentButton: View {
    let mode: AnalysisMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.enhancedLiquidGlass) private var glassManager

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 8) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 15, weight: .semibold))

                Text(mode.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.2)
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .accessibilityLabel("\(mode.displayName)模式")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if isSelected {
            ZStack {
                glassManager.createGlassMaterial(
                    type: .button,
                    cornerRadius: 12,
                    depth: 1.8,
                    isPressed: isPressed,
                    customTint: mode.tintColor
                )

                // Subtle gradient overlay
                LinearGradient(
                    colors: mode.gradientColors.map { $0.opacity(0.15) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)
            }
            .shadow(color: mode.tintColor.opacity(0.3), radius: 8, y: 4)
        } else {
            Color.clear
        }
    }

    private func handleTap() {
        guard !isSelected else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isPressed = true
        }

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = false
            }
            action()
        }
    }
}
```

#### Step 4.3: Build Mode Carousel

**New File:** `/Lopan/Views/Components/AnalysisModeCarousel.swift`

```swift
import SwiftUI

struct AnalysisModeCarousel: View {
    @Binding var selectedMode: AnalysisMode
    @Environment(\.enhancedLiquidGlass) private var glassManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text("分析维度")
                .font(.headline)

            // Mode switcher
            HStack(spacing: 3) {
                ForEach(AnalysisMode.allCases) { mode in
                    ModeSegmentButton(
                        mode: mode,
                        isSelected: selectedMode == mode
                    ) {
                        selectedMode = mode
                    }
                }
            }
            .padding(6)
            .background(carouselBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var carouselBackground: some View {
        glassManager.createGlassMaterial(
            type: .navigation,
            cornerRadius: 16,
            depth: 1.0,
            isPressed: false,
            isHovered: false,
            customTint: nil
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
```

**Testing:**
```swift
#Preview("Mode Carousel") {
    struct PreviewWrapper: View {
        @State private var selectedMode: AnalysisMode = .region

        var body: some View {
            VStack {
                AnalysisModeCarousel(selectedMode: $selectedMode)

                Spacer()

                Text("Selected: \(selectedMode.displayName)")
                    .font(.caption)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
```

### Deliverables - Phase 2

After Week 4, you should have:
- ✅ Complete Time Range Selector with custom date picker
- ✅ Analysis Mode Carousel with jewel-tone styling
- ✅ Smooth animations and haptic feedback
- ✅ Full accessibility support
- ✅ Responsive to Dynamic Type

**Validation Checklist:**
- [ ] Time range selection works for all presets
- [ ] Custom date picker presents and applies correctly
- [ ] Mode switcher animates smoothly
- [ ] Haptic feedback triggers on interactions
- [ ] VoiceOver announces selections correctly
- [ ] Components work on all device sizes

---

## Phase 3: Interactive Charts (Weeks 5-7)

### Goal
Implement interactive Pie, Bar, and Line charts with gesture support, tooltips, and drill-down capabilities.

### Week 5: Interactive Pie Charts

#### Step 5.1: Create Pie Chart Data Models

**New File:** `/Lopan/Models/ChartModels.swift`

```swift
import SwiftUI

// MARK: - Pie Chart Models

struct PieChartSegment: Identifiable {
    let id = UUID()
    let value: Double
    let label: String
    let color: Color

    var percentage: Double = 0 // Calculated
}

struct PieChartData {
    let segments: [PieChartSegment]
    let total: Double

    init(segments: [PieChartSegment]) {
        self.segments = segments.map { segment in
            var updated = segment
            updated.percentage = segments.isEmpty ? 0 : segment.value / segments.reduce(0) { $0 + $1.value }
            return updated
        }
        self.total = segments.reduce(0) { $0 + $1.value }
    }
}

// MARK: - Bar Chart Models

struct BarChartItem: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
    let color: Color
    let subCategory: String?

    init(category: String, value: Double, color: Color, subCategory: String? = nil) {
        self.category = category
        self.value = value
        self.color = color
        self.subCategory = subCategory
    }
}

// MARK: - Line Chart Models

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let label: String
    let category: String?
    let color: Color?
    let date: Date?

    init(x: Double, y: Double, label: String, category: String? = nil, color: Color? = nil, date: Date? = nil) {
        self.x = x
        self.y = y
        self.label = label
        self.category = category
        self.color = color
        self.date = date
    }
}
```

#### Step 5.2: Build Interactive Pie Chart

**New File:** `/Lopan/Views/Components/InteractivePieChart.swift`

```swift
import SwiftUI

struct InteractivePieChart: View {
    let data: [PieChartSegment]
    @State private var selectedSegment: PieChartSegment?
    @State private var animateChart = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let chartSize: CGFloat = 240
    private let lineWidth: CGFloat = 48

    var body: some View {
        ZStack {
            // Chart segments
            ForEach(Array(data.enumerated()), id: \.element.id) { index, segment in
                PieSegmentShape(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .fill(segment.color)
                .scaleEffect(selectedSegment?.id == segment.id ? 1.08 : 1.0)
                .opacity(selectedSegment == nil || selectedSegment?.id == segment.id ? 1.0 : 0.6)
                .onTapGesture {
                    handleSegmentTap(segment)
                }
            }

            // Center hole for donut
            Circle()
                .fill(Color(uiColor: .systemBackground))
                .frame(width: chartSize - (lineWidth * 2))

            // Center label
            if let selected = selectedSegment {
                VStack(spacing: 4) {
                    Text("\(Int(selected.value))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(selected.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: chartSize, height: chartSize)
        .rotationEffect(.degrees(animateChart ? 0 : -90))
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.8)) {
                    animateChart = true
                }
            } else {
                animateChart = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("饼图显示\(data.count)个数据段")
    }

    private func startAngle(for index: Int) -> Angle {
        let previousSum = data.prefix(index).reduce(0.0) { $0 + $1.percentage }
        return .degrees(previousSum * 360)
    }

    private func endAngle(for index: Int) -> Angle {
        let sum = data.prefix(index + 1).reduce(0.0) { $0 + $1.percentage }
        return .degrees(sum * 360)
    }

    private func handleSegmentTap(_ segment: PieChartSegment) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedSegment?.id == segment.id {
                selectedSegment = nil
            } else {
                selectedSegment = segment
            }
        }
    }
}

// MARK: - Pie Segment Shape

struct PieSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}
```

**Testing:**
```swift
#Preview("Interactive Pie Chart") {
    InteractivePieChart(data: [
        PieChartSegment(value: 45, label: "上海", color: LopanColors.dataBlue),
        PieChartSegment(value: 30, label: "北京", color: LopanColors.dataGreen),
        PieChartSegment(value: 25, label: "广州", color: LopanColors.dataOrange)
    ])
    .padding()
}
```

### Week 6: Interactive Bar Charts

#### Step 6.1: Build Bar Chart Component

**New File:** `/Lopan/Views/Components/InteractiveBarChart.swift`

```swift
import SwiftUI

struct InteractiveBarChart: View {
    let data: [BarChartItem]
    let chartHeight: CGFloat

    @State private var selectedBar: BarChartItem?
    @State private var animateBars = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barWidth: CGFloat = 24
    private let barSpacing: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 4) {
                        // Value label
                        if selectedBar?.id == item.id {
                            Text("\(Int(item.value))")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(item.color.opacity(0.2))
                                )
                                .transition(.scale.combined(with: .opacity))
                        }

                        // Bar
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(item.color)
                            .frame(width: barWidth, height: barHeight(for: item, maxValue: maxValue))
                            .scaleEffect(
                                x: 1.0,
                                y: animateBars ? 1.0 : 0.0,
                                anchor: .bottom
                            )
                            .scaleEffect(selectedBar?.id == item.id ? 1.05 : 1.0)
                            .opacity(selectedBar == nil || selectedBar?.id == item.id ? 1.0 : 0.7)
                            .onTapGesture {
                                handleBarTap(item)
                            }

                        // Category label
                        Text(item.category)
                            .font(.caption2)
                            .lineLimit(1)
                            .frame(width: barWidth)
                    }
                    .animation(
                        reduceMotion ? .easeOut : .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(index) * 0.05),
                        value: animateBars
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: chartHeight)
        .onAppear {
            animateBars = true
        }
    }

    private var maxValue: Double {
        data.map(\.value).max() ?? 1.0
    }

    private func barHeight(for item: BarChartItem, maxValue: Double) -> CGFloat {
        let heightRatio = item.value / maxValue
        return chartHeight * 0.7 * heightRatio // 70% of available height
    }

    private func handleBarTap(_ item: BarChartItem) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedBar?.id == item.id {
                selectedBar = nil
            } else {
                selectedBar = item
            }
        }
    }
}
```

**Testing:**
```swift
#Preview("Interactive Bar Chart") {
    InteractiveBarChart(
        data: [
            BarChartItem(category: "产品A", value: 45, color: LopanColors.dataBlue),
            BarChartItem(category: "产品B", value: 30, color: LopanColors.dataGreen),
            BarChartItem(category: "产品C", value: 55, color: LopanColors.dataOrange),
            BarChartItem(category: "产品D", value: 25, color: LopanColors.dataPurple),
            BarChartItem(category: "产品E", value: 40, color: LopanColors.dataCyan)
        ],
        chartHeight: 200
    )
    .padding()
}
```

### Week 7: Chart Integration

#### Step 7.1: Update Insights View

**File:** `/Lopan/Views/Salesperson/CustomerOutOfStockInsightsView.swift`

Replace the chart section with new interactive charts:

```swift
// In CustomerOutOfStockInsightsView

private var chartSection: some View {
    Group {
        switch viewModel.selectedAnalysisMode {
        case .region:
            regionChartView
        case .product:
            productChartView
        case .customer:
            customerChartView
        }
    }
}

private var regionChartView: some View {
    VStack(alignment: .leading, spacing: 16) {
        Text("地区分布")
            .font(.title3)
            .fontWeight(.semibold)

        if let regionData = viewModel.regionAnalytics {
            InteractivePieChart(data: regionData.regionDistribution)
                .frame(height: 280)
        } else {
            loadingPlaceholder
        }
    }
    .padding(20)
    .background(chartContainerBackground)
}

private var productChartView: some View {
    VStack(alignment: .leading, spacing: 16) {
        Text("产品分析")
            .font(.title3)
            .fontWeight(.semibold)

        if let productData = viewModel.productAnalytics {
            InteractiveBarChart(
                data: productData.productDistribution,
                chartHeight: 280
            )
        } else {
            loadingPlaceholder
        }
    }
    .padding(20)
    .background(chartContainerBackground)
}

private var chartContainerBackground: some View {
    EnhancedLiquidGlassManager.shared.createChartContainerMaterial()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
}

private var loadingPlaceholder: some View {
    Rectangle()
        .fill(Color.secondary.opacity(0.1))
        .frame(height: 280)
        .shimmer() // Use existing shimmer modifier
}
```

### Deliverables - Phase 3

After Week 7, you should have:
- ✅ Interactive Pie charts with tap selection
- ✅ Interactive Bar charts with animated entry
- ✅ Chart data models
- ✅ Integration with ViewModel
- ✅ Loading and empty states
- ✅ Smooth animations

**Validation Checklist:**
- [ ] Charts render with correct data
- [ ] Tap interactions select segments/bars
- [ ] Animations play smoothly (60fps)
- [ ] Haptic feedback triggers on tap
- [ ] VoiceOver describes chart data
- [ ] Charts adapt to Dynamic Type
- [ ] Performance is acceptable on iPhone SE

---

## Phase 4: Advanced Features (Weeks 8-9)

### Goal
Add filtering, search, export, and data drill-down capabilities.

### Week 8: Filter & Search

#### Step 8.1: Create Filter Model

**New File:** `/Lopan/Models/InsightsFilter.swift`

```swift
import Foundation

struct InsightsFilter: Identifiable, Codable {
    let id = UUID()
    var type: FilterType
    var isActive: Bool = true

    enum FilterType: Codable {
        case valueRange(min: Double, max: Double)
        case categories(selected: Set<String>)
        case dateRange(start: Date, end: Date)
        case sortOrder(SortOrder)
    }

    enum SortOrder: String, Codable, CaseIterable {
        case valueAscending = "value_asc"
        case valueDescending = "value_desc"
        case nameAscending = "name_asc"
        case nameDescending = "name_desc"

        var displayName: String {
            switch self {
            case .valueAscending: return "数值升序"
            case .valueDescending: return "数值降序"
            case .nameAscending: return "名称A-Z"
            case .nameDescending: return "名称Z-A"
            }
        }
    }
}
```

#### Step 8.2: Build Filter Panel

**New File:** `/Lopan/Views/Components/FilterPanel.swift`

```swift
import SwiftUI

struct FilterPanel: View {
    @Binding var filters: [InsightsFilter]
    @Environment(\.dismiss) private var dismiss

    @State private var minValue: Double = 0
    @State private var maxValue: Double = 100
    @State private var selectedSort: InsightsFilter.SortOrder = .valueDescending

    var body: some View {
        NavigationStack {
            Form {
                Section("数值范围") {
                    HStack {
                        Text("\(Int(minValue))")
                            .monospacedDigit()

                        Slider(value: $minValue, in: 0...100, step: 5)

                        Text("\(Int(maxValue))")
                            .monospacedDigit()
                    }
                }

                Section("排序") {
                    Picker("排序方式", selection: $selectedSort) {
                        ForEach(InsightsFilter.SortOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        applyFilters()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .bottomBar) {
                    Button("清除全部") {
                        resetFilters()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private func applyFilters() {
        // Update filter models
        filters = [
            InsightsFilter(
                type: .valueRange(min: minValue, max: maxValue),
                isActive: true
            ),
            InsightsFilter(
                type: .sortOrder(selectedSort),
                isActive: true
            )
        ]

        let impact = UIImpactFeedbackGenerator(style: .success)
        impact.impactOccurred()

        dismiss()
    }

    private func resetFilters() {
        minValue = 0
        maxValue = 100
        selectedSort = .valueDescending
        filters.removeAll()
    }
}
```

#### Step 8.3: Add Filter Button to Insights View

```swift
// In CustomerOutOfStockInsightsView

@State private var showingFilters = false
@State private var activeFilters: [InsightsFilter] = []

var body: some View {
    NavigationStack {
        InsightsResponsiveContainer { context in
            VStack(spacing: context.sectionSpacing) {
                TimeRangeSelector(selectedRange: $viewModel.selectedTimeRange)
                AnalysisModeCarousel(selectedMode: $viewModel.selectedAnalysisMode)

                // Active filters display
                if !activeFilters.isEmpty {
                    activeFiltersView
                }

                chartSection
            }
        }
        .navigationTitle("数据洞察")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingFilters = true
                } label: {
                    Image(systemName: activeFilters.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(activeFilters.isEmpty ? .secondary : LopanColors.primary)
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            FilterPanel(filters: $activeFilters)
        }
    }
}

private var activeFiltersView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            ForEach(activeFilters) { filter in
                FilterChip(filter: filter) {
                    removeFilter(filter)
                }
            }

            Button("清除全部") {
                activeFilters.removeAll()
            }
            .font(.caption)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 20)
    }
}

private func removeFilter(_ filter: InsightsFilter) {
    activeFilters.removeAll { $0.id == filter.id }
}

struct FilterChip: View {
    let filter: InsightsFilter
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(filterLabel)
                .font(.caption)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(LopanColors.primary.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(LopanColors.primary.opacity(0.3), lineWidth: 1)
        )
    }

    private var filterLabel: String {
        switch filter.type {
        case .valueRange(let min, let max):
            return "\(Int(min))-\(Int(max))"
        case .sortOrder(let order):
            return order.displayName
        default:
            return "筛选"
        }
    }
}
```

### Week 9: Export System

#### Step 9.1: Create Export Service

**New File:** `/Lopan/Services/InsightsExportService.swift`

```swift
import Foundation
import UIKit
import PDFKit

class InsightsExportService {
    enum ExportFormat {
        case csv
        case pdf
        case png
    }

    enum ExportError: Error {
        case dataConversionFailed
        case fileCreationFailed
        case permissionDenied
    }

    // MARK: - CSV Export

    func exportToCSV(data: [BarChartItem]) throws -> URL {
        var csvString = "Category,Value\n"

        for item in data {
            csvString += "\(item.category),\(item.value)\n"
        }

        guard let csvData = csvString.data(using: .utf8) else {
            throw ExportError.dataConversionFailed
        }

        let fileName = "insights_export_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try csvData.write(to: tempURL)

        return tempURL
    }

    // MARK: - PDF Export

    func exportToPDF(title: String, chartImage: UIImage?, data: [BarChartItem]) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "Lopan Insights",
            kCGPDFContextTitle: title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0  // US Letter
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let fileName = "insights_export_\(Date().timeIntervalSince1970).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try renderer.writePDF(to: tempURL) { context in
            context.beginPage()

            let margin: CGFloat = 40
            var yPosition: CGFloat = margin

            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let titleRect = CGRect(x: margin, y: yPosition, width: pageWidth - 2 * margin, height: 40)
            title.draw(in: titleRect, withAttributes: titleAttributes)
            yPosition += 60

            // Chart image
            if let image = chartImage {
                let imageWidth = pageWidth - 2 * margin
                let imageHeight = imageWidth * (image.size.height / image.size.width)
                let imageRect = CGRect(x: margin, y: yPosition, width: imageWidth, height: imageHeight)
                image.draw(in: imageRect)
                yPosition += imageHeight + 40
            }

            // Data table
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let cellAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]

            "Category\tValue".draw(
                at: CGPoint(x: margin, y: yPosition),
                withAttributes: headerAttributes
            )
            yPosition += 30

            for item in data.prefix(20) {  // Limit to 20 items per page
                "\(item.category)\t\(Int(item.value))".draw(
                    at: CGPoint(x: margin, y: yPosition),
                    withAttributes: cellAttributes
                )
                yPosition += 25
            }

            // Footer
            let footerText = "Generated by Lopan Insights - \(Date().formatted(date: .long, time: .shortened))"
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.secondaryLabel
            ]
            footerText.draw(
                at: CGPoint(x: margin, y: pageHeight - margin),
                withAttributes: footerAttributes
            )
        }

        return tempURL
    }

    // MARK: - PNG Export

    @MainActor
    func exportToPNG(view: some View, size: CGSize) throws -> URL {
        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage else {
            throw ExportError.dataConversionFailed
        }

        guard let pngData = uiImage.pngData() else {
            throw ExportError.dataConversionFailed
        }

        let fileName = "insights_chart_\(Date().timeIntervalSince1970).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try pngData.write(to: tempURL)

        return tempURL
    }
}
```

#### Step 9.2: Add Export UI

**New File:** `/Lopan/Views/Components/ExportSheet.swift`

```swift
import SwiftUI

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: InsightsExportService.ExportFormat = .csv
    @State private var includeChart = true
    @State private var includeData = true
    @State private var isExporting = false

    let onExport: (InsightsExportService.ExportFormat, Bool, Bool) async -> URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("格式") {
                    Picker("导出格式", selection: $selectedFormat) {
                        Label("CSV 表格", systemImage: "tablecells").tag(InsightsExportService.ExportFormat.csv)
                        Label("PDF 报告", systemImage: "doc.text").tag(InsightsExportService.ExportFormat.pdf)
                        Label("PNG 图片", systemImage: "photo").tag(InsightsExportService.ExportFormat.png)
                    }
                    .pickerStyle(.inline)
                }

                if selectedFormat == .pdf {
                    Section("选项") {
                        Toggle("包含图表", isOn: $includeChart)
                        Toggle("包含数据表", isOn: $includeData)
                    }
                }

                Section {
                    Button(action: handleExport) {
                        HStack {
                            if isExporting {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text("导出")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("导出数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func handleExport() {
        Task {
            isExporting = true

            if let fileURL = await onExport(selectedFormat, includeChart, includeData) {
                // Present share sheet
                await MainActor.run {
                    presentShareSheet(for: fileURL)
                }
            }

            isExporting = false
            dismiss()
        }
    }

    @MainActor
    private func presentShareSheet(for url: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = window
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            activityVC.popoverPresentationController?.permittedArrowDirections = []
            rootVC.present(activityVC, animated: true)
        }
    }
}
```

#### Step 9.3: Integrate Export

```swift
// In CustomerOutOfStockInsightsView

@State private var showingExportSheet = false
private let exportService = InsightsExportService()

.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button {
                showingFilters = true
            } label: {
                Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
            }

            Button {
                showingExportSheet = true
            } label: {
                Label("导出", systemImage: "square.and.arrow.up")
            }

            Button {
                Task {
                    await viewModel.refreshData()
                }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
.sheet(isPresented: $showingExportSheet) {
    ExportSheet { format, includeChart, includeData in
        await handleExport(format: format, includeChart: includeChart, includeData: includeData)
    }
}

private func handleExport(
    format: InsightsExportService.ExportFormat,
    includeChart: Bool,
    includeData: Bool
) async -> URL? {
    do {
        switch format {
        case .csv:
            guard let data = viewModel.productAnalytics?.productDistribution else { return nil }
            return try exportService.exportToCSV(data: data)

        case .pdf:
            guard let data = viewModel.productAnalytics?.productDistribution else { return nil }
            // TODO: Capture chart as UIImage
            return try exportService.exportToPDF(
                title: "产品分析报告",
                chartImage: nil,
                data: data
            )

        case .png:
            // TODO: Export chart view as PNG
            return nil
        }
    } catch {
        print("Export failed: \(error)")
        return nil
    }
}
```

### Deliverables - Phase 4

After Week 9, you should have:
- ✅ Filter panel with value range and sort options
- ✅ Active filter chips display
- ✅ Export service (CSV, PDF, PNG)
- ✅ Export sheet with options
- ✅ Share sheet integration
- ✅ Error handling

**Validation Checklist:**
- [ ] Filters apply correctly to data
- [ ] Active filters display and can be removed
- [ ] CSV export creates valid file
- [ ] PDF export includes chart and data
- [ ] Share sheet presents correctly
- [ ] Export works on all device sizes

---

## Phase 5: Polish & Optimization (Weeks 10-11)

### Goal
Add microinteractions, optimize performance, and ensure perfect accessibility.

### Week 10: Microinteractions & Animations

#### Step 10.1: Create Animation Helpers

**New File:** `/Lopan/Utils/AnimationHelpers.swift`

```swift
import SwiftUI

extension Animation {
    /// Standard spring for most UI interactions
    static var insightsStandard: Animation {
        .spring(response: 0.4, dampingFraction: 0.75)
    }

    /// Snappy spring for quick feedback
    static var insightsSnappy: Animation {
        .spring(response: 0.3, dampingFraction: 0.8)
    }

    /// Bouncy spring for playful interactions
    static var insightsBouncy: Animation {
        .spring(response: 0.5, dampingFraction: 0.6)
    }

    /// Smooth ease for subtle transitions
    static var insightsSmooth: Animation {
        .easeInOut(duration: 0.3)
    }
}

extension View {
    /// Applies standard insights animation
    func insightsAnimation<V: Equatable>(value: V) -> some View {
        self.animation(.insightsStandard, value: value)
    }
}
```

#### Step 10.2: Add Pull-to-Refresh

```swift
// In CustomerOutOfStockInsightsView

.refreshable {
    await refreshData()
}

private func refreshData() async {
    let impact = UIImpactFeedbackGenerator(style: .light)
    impact.impactOccurred()

    await viewModel.refreshData()

    let success = UINotificationFeedbackGenerator()
    success.notificationOccurred(.success)
}
```

#### Step 10.3: Add Number Count-Up Animation

**New File:** `/Lopan/Views/Components/AnimatedNumber.swift`

```swift
import SwiftUI

struct AnimatedNumber: View {
    let value: Double
    let format: String

    @State private var displayValue: Double = 0

    var body: some View {
        Text(String(format: format, displayValue))
            .monospacedDigit()
            .contentTransition(.numericText(value: displayValue))
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: 0.5)) {
                    displayValue = newValue
                }
            }
    }
}

// Usage
AnimatedNumber(value: 142, format: "%.0f")
    .displayStyle()
```

#### Step 10.4: Add Toast Notifications

**New File:** `/Lopan/Views/Components/ToastView.swift`

```swift
import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String?

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title3)
            }

            Text(message)
                .font(.subheadline)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        )
    }
}

// Toast modifier
extension View {
    func toast(message: String?, icon: String? = nil, isPresented: Binding<Bool>) -> some View {
        self.overlay(alignment: .top) {
            if isPresented.wrappedValue, let message = message {
                ToastView(message: message, icon: icon)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.insightsStandard) {
                                isPresented.wrappedValue = false
                            }
                        }
                    }
            }
        }
        .animation(.insightsStandard, value: isPresented.wrappedValue)
    }
}

// Usage
@State private var showToast = false
@State private var toastMessage = ""

.toast(message: toastMessage, icon: "checkmark.circle.fill", isPresented: $showToast)

// Trigger toast
toastMessage = "数据已刷新"
showToast = true
```

### Week 11: Performance & Accessibility

#### Step 11.1: Performance Optimization

Add profiling markers:

```swift
import os.signpost

extension OSLog {
    static let insights = OSLog(subsystem: "com.lopan.app", category: "Insights")
}

// In ViewModel
func loadData() async {
    let signpostID = OSSignpostID(log: .insights)
    os_signpost(.begin, log: .insights, name: "Load Insights Data", signpostID: signpostID)

    defer {
        os_signpost(.end, log: .insights, name: "Load Insights Data", signpostID: signpostID)
    }

    // Load data...
}
```

Add view optimization:

```swift
// Use drawingGroup for complex charts
InteractivePieChart(data: data)
    .drawingGroup() // Renders to offscreen buffer

// Use LazyVStack for long lists
LazyVStack(spacing: 12) {
    ForEach(items) { item in
        ItemRow(item: item)
    }
}
```

#### Step 11.2: Complete Accessibility Audit

Add missing accessibility labels:

```swift
// Charts
InteractivePieChart(data: data)
    .accessibilityLabel("饼图显示\(data.count)个区域的分布")
    .accessibilityValue(accessibilityChartSummary)
    .accessibilityHint("双击查看详细数据")

private var accessibilityChartSummary: String {
    guard let topSegment = data.max(by: { $0.value < $1.value }) else {
        return "无数据"
    }
    return "\(topSegment.label)占比最高,为\(Int(topSegment.percentage * 100))%"
}

// Add custom actions
.accessibilityAction(named: "按值排序") {
    sortByValue()
}
.accessibilityAction(named: "按名称排序") {
    sortByName()
}
```

Test with VoiceOver:
```swift
#Preview("VoiceOver Test") {
    CustomerOutOfStockInsightsView()
        .environment(\.accessibilityEnabled, true)
}
```

### Deliverables - Phase 5

After Week 11, you should have:
- ✅ Pull-to-refresh with haptics
- ✅ Number count-up animations
- ✅ Toast notification system
- ✅ Performance profiling markers
- ✅ Complete VoiceOver support
- ✅ Optimized rendering

**Validation Checklist:**
- [ ] Animations run at 60fps
- [ ] Pull-to-refresh works smoothly
- [ ] Toast notifications display correctly
- [ ] VoiceOver navigates logically through all elements
- [ ] Dynamic Type works at all sizes
- [ ] Performance is good on iPhone SE

---

## Phase 6: Widgets & Extras (Week 12+)

### Goal
Create home screen widgets and implement remaining polish features.

### Week 12: Widget Implementation

#### Step 12.1: Create Widget Extension

```bash
# In Xcode
File → New → Target → Widget Extension
Name: LopanInsightsWidget
Include Configuration Intent: Yes
```

#### Step 12.2: Implement Widget

**File:** `LopanInsightsWidget/LopanInsightsWidget.swift`

```swift
import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), value: 142, trend: .up)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), value: 142, trend: .up)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline with entries every 15 minutes
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: hourOffset * 15, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, value: 142, trend: .up)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let value: Int
    let trend: TrendDirection

    enum TrendDirection {
        case up, down, stable

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .blue
            }
        }
    }
}

struct LopanInsightsWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("缺货洞察", systemImage: "chart.bar.xaxis")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.value)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Image(systemName: entry.trend.icon)
                    .font(.title3)
                    .foregroundStyle(entry.trend.color)
            }

            Text("待处理")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct MediumWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("缺货洞察", systemImage: "chart.bar.xaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(entry.value)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 4) {
                    Image(systemName: entry.trend.icon)
                    Text("+15%")
                }
                .font(.caption)
                .foregroundStyle(entry.trend.color)
            }

            Spacer()

            // Mini chart (placeholder)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.2))
                .frame(width: 120, height: 80)
                .overlay(
                    Text("图表")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                )
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct LargeWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("缺货洞察", systemImage: "chart.bar.xaxis")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("\(entry.value)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    HStack(spacing: 4) {
                        Image(systemName: entry.trend.icon)
                        Text("+15%")
                    }
                    .font(.subheadline)
                    .foregroundStyle(entry.trend.color)
                }

                Spacer()
            }

            Divider()

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatItem(title: "本周", value: "127")
                StatItem(title: "本月", value: "485")
                StatItem(title: "完成率", value: "85%")
                StatItem(title: "趋势", value: "上升")
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .systemBackground).opacity(0.5))
        )
    }
}

@main
struct LopanInsightsWidget: Widget {
    let kind: String = "LopanInsightsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LopanInsightsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("缺货洞察")
        .description("实时查看缺货数据和趋势")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

### Deliverables - Phase 6

After Week 12, you should have:
- ✅ Small, Medium, Large widgets
- ✅ Widget updates every 15 minutes
- ✅ Tap to open app integration
- ✅ Proper widget configuration

**Validation Checklist:**
- [ ] Widgets display on home screen
- [ ] Data updates periodically
- [ ] Tapping widget opens Insights view
- [ ] Widgets work in light and dark mode
- [ ] Widget placeholder renders correctly

---

## Testing Strategy

### Unit Testing

Create tests for:
- Data models
- Filter logic
- Export service
- Chart calculations

```swift
// Example test
import XCTest
@testable import Lopan

final class InsightsFilterTests: XCTestCase {
    func testValueRangeFilter() {
        let filter = InsightsFilter(type: .valueRange(min: 10, max: 50), isActive: true)
        let data = [
            BarChartItem(category: "A", value: 5, color: .blue),
            BarChartItem(category: "B", value: 25, color: .blue),
            BarChartItem(category: "C", value: 75, color: .blue)
        ]

        let filtered = data.filter { item in
            if case .valueRange(let min, let max) = filter.type {
                return item.value >= min && item.value <= max
            }
            return true
        }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.category, "B")
    }
}
```

### UI Testing

Test critical flows:

```swift
import XCTest

final class InsightsUITests: XCTestCase {
    func testTimeRangeSelection() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Insights
        app.buttons["数据洞察"].tap()

        // Select time range
        app.buttons["本周"].tap()

        // Verify selection
        XCTAssertTrue(app.buttons["本周"].isSelected)
    }

    func testChartInteraction() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["数据洞察"].tap()

        // Tap chart segment
        app.otherElements["饼图"].tap()

        // Verify tooltip appears
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '上海'")).element.exists)
    }
}
```

### Accessibility Testing

Test with VoiceOver:

```swift
func testVoiceOverNavigation() throws {
    let app = XCUIApplication()
    app.launch()

    app.buttons["数据洞察"].tap()

    // Navigate with VoiceOver
    let chartElement = app.otherElements["饼图显示3个区域的分布"]
    XCTAssertTrue(chartElement.exists)
    XCTAssertEqual(chartElement.accessibilityTraits, [.button])
}
```

### Performance Testing

Measure performance:

```swift
func testChartRenderPerformance() throws {
    measure {
        // Render chart 10 times
        for _ in 0..<10 {
            let chart = InteractivePieChart(data: sampleData)
            _ = chart.body
        }
    }
}
```

---

## Migration Guide

### From Current Implementation

**Step 1: Back up current code**
```bash
git checkout -b backup/pre-redesign
git commit -am "Backup before redesign"
git checkout main
git checkout -b feature/insights-redesign
```

**Step 2: Gradually replace components**

Instead of replacing everything at once, use feature flags:

```swift
enum InsightsVersion {
    case legacy
    case redesigned

    static var current: InsightsVersion {
        #if DEBUG
        return .redesigned
        #else
        return .legacy
        #endif
    }
}

// In view
var body: some View {
    switch InsightsVersion.current {
    case .legacy:
        LegacyInsightsView()
    case .redesigned:
        NewInsightsView()
    }
}
```

**Step 3: Migrate data models**

Existing models should work with minimal changes. Add extensions:

```swift
// Existing: TimeRange, AnalysisMode
// Add: Computed properties for new UI
extension TimeRange {
    var displayIcon: String {
        // Add icons
    }
}
```

**Step 4: Test in parallel**

Run both versions in TestFlight:
- Group A: Legacy version
- Group B: Redesigned version
- Compare metrics

**Step 5: Gradual rollout**

```swift
// Remote config
let rolloutPercentage = RemoteConfig.shared.getDouble("insights_redesign_rollout")
let shouldUseRedesign = Double.random(in: 0...100) < rolloutPercentage

InsightsVersion.current = shouldUseRedesign ? .redesigned : .legacy
```

---

## Troubleshooting

### Common Issues

#### Charts not rendering
```swift
// Check data is valid
guard !data.isEmpty else {
    return EmptyStateView()
}

// Check percentages sum to 1.0
let total = data.reduce(0.0) { $0 + $1.percentage }
assert(abs(total - 1.0) < 0.01, "Percentages must sum to 1.0")
```

#### Animations stuttering
```swift
// Use drawingGroup for complex views
ComplexChart()
    .drawingGroup()

// Profile with Instruments
// Xcode → Product → Profile → Time Profiler
```

#### Memory warnings
```swift
// Release resources on disappear
.onDisappear {
    viewModel.cancelTasks()
    chartRenderer.cleanup()
}

// Use weak references
viewModel.onUpdate = { [weak self] in
    self?.update()
}
```

#### VoiceOver not working
```swift
// Check accessibility tree
// Xcode → Debug → View Debugging → Show Accessibility Inspector

// Add labels
.accessibilityLabel("明确的描述")
.accessibilityHint("双击执行操作")
```

#### Dark mode issues
```swift
// Use semantic colors
.foregroundStyle(.primary) // Not .black
.background(.regularMaterial) // Not Color.white

// Test in both modes
#Preview("Light") {
    View()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    View()
        .preferredColorScheme(.dark)
}
```

### Getting Help

- **Design Questions**: Refer to design sprint documentation
- **Implementation Issues**: Check code examples in this guide
- **Performance Problems**: Profile with Instruments
- **Accessibility**: Test with VoiceOver, refer to Apple HIG

---

## Appendix

### Localization Strings

Add to `Localizable.strings`:

```
/* Time Range */
"insights_time_today" = "今天";
"insights_time_yesterday" = "昨天";
"insights_time_this_week" = "本周";
"insights_time_last_week" = "上周";
"insights_time_this_month" = "本月";
"insights_time_last_month" = "上月";
"insights_time_custom" = "自定义";

/* Analysis Modes */
"insights_mode_region" = "区域分析";
"insights_mode_product" = "产品分析";
"insights_mode_customer" = "客户分析";

/* Actions */
"insights_action_filter" = "筛选";
"insights_action_export" = "导出";
"insights_action_refresh" = "刷新";

/* States */
"insights_loading" = "正在加载...";
"insights_error" = "加载失败";
"insights_empty" = "暂无数据";
```

### Performance Benchmarks

Target metrics:
- Initial load: < 1s
- Chart render: < 200ms
- Animation: 60fps minimum
- Memory: < 100MB
- Battery: < 2% per 30min session

### File Structure

```
Lopan/
├── DesignSystem/
│   ├── Typography/
│   │   └── LopanTypography.swift
│   ├── Colors/
│   │   └── LopanColorsInsights.swift
│   ├── Layout/
│   │   └── LopanGridSystem.swift
│   └── Components/
│       └── Foundation/
│           └── EnhancedLiquidGlass.swift (existing)
├── Views/
│   ├── Components/
│   │   ├── TimeRangeSelector.swift
│   │   ├── AnalysisModeCarousel.swift
│   │   ├── InteractivePieChart.swift
│   │   ├── InteractiveBarChart.swift
│   │   ├── FilterPanel.swift
│   │   ├── ExportSheet.swift
│   │   ├── AnimatedNumber.swift
│   │   ├── ToastView.swift
│   │   └── InsightsResponsiveContainer.swift
│   └── Salesperson/
│       └── CustomerOutOfStockInsightsView.swift (updated)
├── Models/
│   ├── ChartModels.swift
│   └── InsightsFilter.swift
├── Services/
│   └── InsightsExportService.swift
└── Utils/
    └── AnimationHelpers.swift

LopanInsightsWidget/ (new target)
└── LopanInsightsWidget.swift
```

---

## Conclusion

This implementation guide provides a complete roadmap for transforming the Lopan Insights interface into a world-class analytics experience. Follow the phases sequentially, validate each deliverable, and maintain the quality standards throughout.

**Key Success Factors:**
- ✅ Incremental implementation
- ✅ Continuous testing
- ✅ Performance monitoring
- ✅ Accessibility validation
- ✅ User feedback integration

**Estimated Total Time:** 12-14 weeks for complete implementation

**Questions or Issues?** Refer to the troubleshooting section or consult the design sprint documentation for detailed specifications.

Good luck with the implementation! 🚀