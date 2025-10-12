//
//  LopanSpacing.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Consistent spacing system for Lopan production management app
/// Based on 4pt grid system for precise layout control
public struct LopanSpacing {
    
    // MARK: - Base Unit (4pt grid system)
    private static let baseUnit: CGFloat = 4
    
    // MARK: - Spacing Scale
    public static let xxxs: CGFloat = baseUnit * 0.5    // 2pt
    public static let xxs: CGFloat = baseUnit * 1       // 4pt
    public static let xs: CGFloat = baseUnit * 2        // 8pt
    public static let sm: CGFloat = baseUnit * 3        // 12pt
    public static let md: CGFloat = baseUnit * 4        // 16pt
    public static let lg: CGFloat = baseUnit * 5        // 20pt
    public static let xl: CGFloat = baseUnit * 6        // 24pt
    public static let xxl: CGFloat = baseUnit * 8       // 32pt
    public static let xxxl: CGFloat = baseUnit * 12     // 48pt
    public static let xxxxl: CGFloat = baseUnit * 16    // 64pt
    
    // MARK: - Semantic Spacing
    public static let componentPadding = md             // 16pt
    public static let cardPadding = md                  // 16pt
    public static let screenPadding = lg                // 20pt
    public static let sectionSpacing = xl               // 24pt
    public static let itemSpacing = sm                  // 12pt
    public static let buttonPadding = md                // 16pt
    public static let listItemPadding = md              // 16pt
    
    // MARK: - Layout Spacing
    public static let headerSpacing = xxl               // 32pt
    public static let contentSpacing = lg               // 20pt
    public static let footerSpacing = xl                // 24pt
    
    // MARK: - Interactive Element Spacing
    public static let minTouchTarget: CGFloat = 44      // iOS minimum touch target
    public static let buttonHeight: CGFloat = 48        // Standard button height
    public static let inputHeight: CGFloat = 44         // Standard input height
    
    // MARK: - Grid Spacing
    public static let gridSpacing = md                  // 16pt
    public static let columnSpacing = md                // 16pt
    public static let rowSpacing = sm                   // 12pt
    
    // MARK: - Filter & Chip Spacing
    public static let filterChipHorizontalPadding = sm  // 12pt
    public static let filterChipVerticalPadding: CGFloat = 6
    public static let filterChipSpacing = xs            // 8pt
    public static let drawerWidth: CGFloat = 320        // Fixed drawer width
    public static let drawerPadding = xl                // 24pt
}

// MARK: - Spacing View Extensions
extension View {
    /// Adds padding using Lopan spacing tokens
    func lopanPadding(_ spacing: CGFloat = LopanSpacing.md) -> some View {
        self.padding(spacing)
    }
    
    /// Adds horizontal padding using Lopan spacing tokens
    func lopanPaddingHorizontal(_ spacing: CGFloat = LopanSpacing.md) -> some View {
        self.padding(.horizontal, spacing)
    }
    
    /// Adds vertical padding using Lopan spacing tokens
    func lopanPaddingVertical(_ spacing: CGFloat = LopanSpacing.md) -> some View {
        self.padding(.vertical, spacing)
    }
    
    /// Adds screen-level padding
    func screenPadding() -> some View {
        self.padding(LopanSpacing.screenPadding)
    }
    
    /// Adds component-level padding
    func componentPadding() -> some View {
        self.padding(LopanSpacing.componentPadding)
    }
    
    /// Adds card-level padding
    func cardPadding() -> some View {
        self.padding(LopanSpacing.cardPadding)
    }
}