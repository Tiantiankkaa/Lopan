//
//  LopanCornerRadius.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Corner radius system for Lopan production management app
/// Provides consistent border radius tokens for unified component appearance
struct LopanCornerRadius {
    
    // MARK: - Radius Scale
    static let none: CGFloat = 0
    static let xs: CGFloat = 2
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    
    // MARK: - Semantic Radius
    static let button = md              // 8pt
    static let card = lg                // 12pt
    static let input = sm               // 4pt
    static let badge = xl               // 16pt (pill shape)
    static let modal = lg               // 12pt
    static let image = md               // 8pt
    static let container = lg           // 12pt
    
    // MARK: - Special Cases
    static let pill: CGFloat = 999      // Creates pill shape
    static let circle: CGFloat = 999    // Creates circle (with equal width/height)
}

// MARK: - View Extensions for Corner Radius
extension View {
    /// Applies corner radius using Lopan tokens
    func lopanCornerRadius(_ radius: CGFloat) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius))
    }
    
    /// Applies button corner radius
    func buttonCornerRadius() -> some View {
        self.lopanCornerRadius(LopanCornerRadius.button)
    }
    
    /// Applies card corner radius
    func cardCornerRadius() -> some View {
        self.lopanCornerRadius(LopanCornerRadius.card)
    }
    
    /// Applies input corner radius
    func inputCornerRadius() -> some View {
        self.lopanCornerRadius(LopanCornerRadius.input)
    }
    
    /// Applies badge corner radius (pill shape)
    func badgeCornerRadius() -> some View {
        self.lopanCornerRadius(LopanCornerRadius.badge)
    }
    
    /// Applies modal corner radius
    func modalCornerRadius() -> some View {
        self.lopanCornerRadius(LopanCornerRadius.modal)
    }
    
    /// Applies image corner radius
    func imageCornerRadius() -> some View {
        self.lopanCornerRadius(LopanCornerRadius.image)
    }
    
    /// Applies container corner radius
    func containerCornerRadius() -> some View {
        self.lopanCornerRadius(LopanCornerRadius.container)
    }
    
    /// Creates pill shape
    func pillShape() -> some View {
        self.lopanCornerRadius(LopanCornerRadius.pill)
    }
    
    /// Creates circular shape
    func circularShape() -> some View {
        self.clipShape(Circle())
    }
}