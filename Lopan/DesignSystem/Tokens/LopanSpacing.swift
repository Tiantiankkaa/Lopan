//
//  LopanSpacing.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Consistent spacing system for Lopan production management app
/// Based on 4pt grid system for precise layout control
struct LopanSpacing {
    
    // MARK: - Base Unit (4pt grid system)
    private static let baseUnit: CGFloat = 4
    
    // MARK: - Spacing Scale
    static let xxxs: CGFloat = baseUnit * 0.5    // 2pt
    static let xxs: CGFloat = baseUnit * 1       // 4pt
    static let xs: CGFloat = baseUnit * 2        // 8pt
    static let sm: CGFloat = baseUnit * 3        // 12pt
    static let md: CGFloat = baseUnit * 4        // 16pt
    static let lg: CGFloat = baseUnit * 5        // 20pt
    static let xl: CGFloat = baseUnit * 6        // 24pt
    static let xxl: CGFloat = baseUnit * 8       // 32pt
    static let xxxl: CGFloat = baseUnit * 12     // 48pt
    static let xxxxl: CGFloat = baseUnit * 16    // 64pt
    
    // MARK: - Semantic Spacing
    static let componentPadding = md             // 16pt
    static let cardPadding = md                  // 16pt
    static let screenPadding = lg                // 20pt
    static let sectionSpacing = xl               // 24pt
    static let itemSpacing = sm                  // 12pt
    static let buttonPadding = md                // 16pt
    static let listItemPadding = md              // 16pt
    
    // MARK: - Layout Spacing
    static let headerSpacing = xxl               // 32pt
    static let contentSpacing = lg               // 20pt
    static let footerSpacing = xl                // 24pt
    
    // MARK: - Interactive Element Spacing
    static let minTouchTarget: CGFloat = 44      // iOS minimum touch target
    static let buttonHeight: CGFloat = 48        // Standard button height
    static let inputHeight: CGFloat = 44         // Standard input height
    
    // MARK: - Grid Spacing
    static let gridSpacing = md                  // 16pt
    static let columnSpacing = md                // 16pt
    static let rowSpacing = sm                   // 12pt
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