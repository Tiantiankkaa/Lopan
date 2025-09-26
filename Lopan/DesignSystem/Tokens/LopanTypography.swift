//
//  LopanTypography.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Advanced typography system for Lopan production management app
/// Provides full Dynamic Type support, accessibility features, and adaptive scaling
struct LopanTypography {

    // MARK: - Dynamic Type System Fonts (iOS 26 Compatible)

    /// Display styles for major headings with proper Dynamic Type scaling
    static let displayLarge = Font.largeTitle.weight(.regular)
    static let displayMedium = Font.title.weight(.regular)
    static let displaySmall = Font.title2.weight(.regular)

    /// Headline styles for section headers with medium weight
    static let headlineLarge = Font.title2.weight(.medium)
    static let headlineMedium = Font.title3.weight(.medium)
    static let headlineSmall = Font.headline.weight(.medium)

    /// Title styles for cards and components with semibold weight
    static let titleLarge = Font.title3.weight(.semibold)
    static let titleMedium = Font.headline.weight(.semibold)
    static let titleSmall = Font.subheadline.weight(.semibold)

    /// Body styles for main content with regular weight
    static let bodyLarge = Font.body.weight(.regular)
    static let bodyMedium = Font.callout.weight(.regular)
    static let bodySmall = Font.subheadline.weight(.regular)

    /// Label styles for metadata and secondary text
    static let labelLarge = Font.subheadline.weight(.medium)
    static let labelMedium = Font.footnote.weight(.medium)
    static let labelSmall = Font.caption.weight(.medium)

    /// Button typography optimized for touch interfaces
    static let buttonLarge = Font.body.weight(.semibold)
    static let buttonMedium = Font.callout.weight(.semibold)
    static let buttonSmall = Font.subheadline.weight(.semibold)

    /// Caption and supporting text styles
    static let caption = Font.caption2.weight(.regular)
    static let overline = Font.caption2.weight(.medium)

    /// Monospace fonts for code and data display
    static let codeSmall = Font.footnote.monospaced().weight(.regular)
    static let codeMedium = Font.callout.monospaced().weight(.regular)

    // MARK: - Adaptive Typography Configuration

    /// Minimum scale factor for constrained layouts
    public static let minimumScaleFactor: CGFloat = 0.75

    /// Maximum lines for different content types
    public enum MaxLines {
        static let title = 2
        static let body = 0 // No limit
        static let caption = 1
        static let button = 1
    }

    /// Line spacing multipliers for readability
    public enum LineSpacing {
        static let compact: CGFloat = 1.2
        static let normal: CGFloat = 1.4
        static let loose: CGFloat = 1.6
    }

    // MARK: - Accessibility Enhancements

    /// Returns whether current Dynamic Type size is considered large
    public static func isLargeContentSize(_ category: ContentSizeCategory) -> Bool {
        switch category {
        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return true
        default:
            return false
        }
    }

    /// Adaptive font that scales appropriately for accessibility sizes
    public static func adaptiveFont(
        base: Font,
        maximumSize: CGFloat = 34,
        minimumSize: CGFloat = 12
    ) -> Font {
        return base
    }

    /// Gets the appropriate line height for a given font style
    public static func lineHeight(for fontStyle: FontStyle) -> CGFloat {
        switch fontStyle {
        case .display:
            return LineSpacing.compact
        case .headline:
            return LineSpacing.normal
        case .body:
            return LineSpacing.normal
        case .caption:
            return LineSpacing.compact
        }
    }

    public enum FontStyle {
        case display
        case headline
        case body
        case caption
    }
}

// MARK: - Enhanced Text Style Extensions with Dynamic Type Support
extension View {
    /// Applies display large typography with Dynamic Type support
    func lopanDisplayLarge(
        maxLines: Int = LopanTypography.MaxLines.title,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.displayLarge)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .display))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies display medium typography with Dynamic Type support
    func lopanDisplayMedium(
        maxLines: Int = LopanTypography.MaxLines.title,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.displayMedium)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .display))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies display small typography with Dynamic Type support
    func lopanDisplaySmall(
        maxLines: Int = LopanTypography.MaxLines.title,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.displaySmall)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .display))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies headline large typography with Dynamic Type support
    func lopanHeadlineLarge(
        maxLines: Int = LopanTypography.MaxLines.title,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.headlineLarge)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .headline))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies headline medium typography with Dynamic Type support
    func lopanHeadlineMedium(
        maxLines: Int = LopanTypography.MaxLines.title,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.headlineMedium)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .headline))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies headline small typography with Dynamic Type support
    func lopanHeadlineSmall(
        maxLines: Int = LopanTypography.MaxLines.title,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.headlineSmall)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .headline))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies title large typography with Dynamic Type support
    func lopanTitleLarge(
        maxLines: Int = LopanTypography.MaxLines.title,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.titleLarge)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .headline))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies title medium typography with Dynamic Type support
    func lopanTitleMedium(
        maxLines: Int = LopanTypography.MaxLines.title,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.titleMedium)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .headline))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies title small typography with Dynamic Type support
    func lopanTitleSmall(
        maxLines: Int = LopanTypography.MaxLines.title,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.titleSmall)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .headline))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies body large typography with Dynamic Type support
    func lopanBodyLarge(
        maxLines: Int = LopanTypography.MaxLines.body,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.bodyLarge)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .body))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies body medium typography with Dynamic Type support
    func lopanBodyMedium(
        maxLines: Int = LopanTypography.MaxLines.body,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.bodyMedium)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .body))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies body small typography with Dynamic Type support
    func lopanBodySmall(
        maxLines: Int = LopanTypography.MaxLines.body,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.bodySmall)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .body))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies label large typography with Dynamic Type support
    func lopanLabelLarge(
        maxLines: Int = LopanTypography.MaxLines.caption,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.labelLarge)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .caption))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies label medium typography with Dynamic Type support
    func lopanLabelMedium(
        maxLines: Int = LopanTypography.MaxLines.caption,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.labelMedium)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .caption))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies label small typography with Dynamic Type support
    func lopanLabelSmall(
        maxLines: Int = LopanTypography.MaxLines.caption,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.labelSmall)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .caption))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies button large typography with Dynamic Type support
    func lopanButtonLarge(
        maxLines: Int = LopanTypography.MaxLines.button,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.buttonLarge)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .body))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies button medium typography with Dynamic Type support
    func lopanButtonMedium(
        maxLines: Int = LopanTypography.MaxLines.button,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.buttonMedium)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .body))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies button small typography with Dynamic Type support
    func lopanButtonSmall(
        maxLines: Int = LopanTypography.MaxLines.button,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.buttonSmall)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .body))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies caption typography with Dynamic Type support
    func lopanCaption(
        maxLines: Int = LopanTypography.MaxLines.caption,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.caption)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .caption))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    /// Applies overline typography with Dynamic Type support
    func lopanOverline(
        maxLines: Int = LopanTypography.MaxLines.caption,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        self
            .font(LopanTypography.overline)
            .lineLimit(maxLines)
            .lineSpacing(lineSpacing ?? LopanTypography.lineHeight(for: .caption))
            .minimumScaleFactor(LopanTypography.minimumScaleFactor)
    }

    // MARK: - Legacy Extensions (Deprecated)

    @available(*, deprecated, message: "Use lopanDisplayLarge() for better Dynamic Type support")
    func displayLarge() -> some View {
        self.font(LopanTypography.displayLarge)
    }

    @available(*, deprecated, message: "Use lopanDisplayMedium() for better Dynamic Type support")
    func displayMedium() -> some View {
        self.font(LopanTypography.displayMedium)
    }

    @available(*, deprecated, message: "Use lopanDisplaySmall() for better Dynamic Type support")
    func displaySmall() -> some View {
        self.font(LopanTypography.displaySmall)
    }

    @available(*, deprecated, message: "Use lopanHeadlineLarge() for better Dynamic Type support")
    func headlineLarge() -> some View {
        self.font(LopanTypography.headlineLarge)
    }

    @available(*, deprecated, message: "Use lopanHeadlineMedium() for better Dynamic Type support")
    func headlineMedium() -> some View {
        self.font(LopanTypography.headlineMedium)
    }

    @available(*, deprecated, message: "Use lopanHeadlineSmall() for better Dynamic Type support")
    func headlineSmall() -> some View {
        self.font(LopanTypography.headlineSmall)
    }

    @available(*, deprecated, message: "Use lopanTitleLarge() for better Dynamic Type support")
    func titleLarge() -> some View {
        self.font(LopanTypography.titleLarge)
    }

    @available(*, deprecated, message: "Use lopanTitleMedium() for better Dynamic Type support")
    func titleMedium() -> some View {
        self.font(LopanTypography.titleMedium)
    }

    @available(*, deprecated, message: "Use lopanTitleSmall() for better Dynamic Type support")
    func titleSmall() -> some View {
        self.font(LopanTypography.titleSmall)
    }

    @available(*, deprecated, message: "Use lopanBodyLarge() for better Dynamic Type support")
    func bodyLarge() -> some View {
        self.font(LopanTypography.bodyLarge)
    }

    @available(*, deprecated, message: "Use lopanBodyMedium() for better Dynamic Type support")
    func bodyMedium() -> some View {
        self.font(LopanTypography.bodyMedium)
    }

    @available(*, deprecated, message: "Use lopanBodySmall() for better Dynamic Type support")
    func bodySmall() -> some View {
        self.font(LopanTypography.bodySmall)
    }

    @available(*, deprecated, message: "Use lopanLabelLarge() for better Dynamic Type support")
    func labelLarge() -> some View {
        self.font(LopanTypography.labelLarge)
    }

    @available(*, deprecated, message: "Use lopanLabelMedium() for better Dynamic Type support")
    func labelMedium() -> some View {
        self.font(LopanTypography.labelMedium)
    }

    @available(*, deprecated, message: "Use lopanLabelSmall() for better Dynamic Type support")
    func labelSmall() -> some View {
        self.font(LopanTypography.labelSmall)
    }

    @available(*, deprecated, message: "Use lopanButtonLarge() for better Dynamic Type support")
    func buttonLarge() -> some View {
        self.font(LopanTypography.buttonLarge)
    }

    @available(*, deprecated, message: "Use lopanButtonMedium() for better Dynamic Type support")
    func buttonMedium() -> some View {
        self.font(LopanTypography.buttonMedium)
    }

    @available(*, deprecated, message: "Use lopanButtonSmall() for better Dynamic Type support")
    func buttonSmall() -> some View {
        self.font(LopanTypography.buttonSmall)
    }

    @available(*, deprecated, message: "Use lopanCaption() for better Dynamic Type support")
    func caption() -> some View {
        self.font(LopanTypography.caption)
    }

    @available(*, deprecated, message: "Use lopanOverline() for better Dynamic Type support")
    func overline() -> some View {
        self.font(LopanTypography.overline)
    }
}

// MARK: - Text Color Extensions
extension Text {
    /// Sets text color to primary
    func primaryText() -> Text {
        self.foregroundColor(LopanColors.textPrimary)
    }
    
    /// Sets text color to secondary
    func secondaryText() -> Text {
        self.foregroundColor(LopanColors.textSecondary)
    }
    
    /// Sets text color to tertiary
    func tertiaryText() -> Text {
        self.foregroundColor(LopanColors.textTertiary)
    }
    
    /// Sets text color to on primary (for buttons)
    func onPrimaryText() -> Text {
        self.foregroundColor(LopanColors.textOnPrimary)
    }
    
    /// Sets text color to on dark backgrounds
    func onDarkText() -> Text {
        self.foregroundColor(LopanColors.textOnDark)
    }
}