//
//  LopanShadows.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Elevation and shadow system for Lopan production management app
/// Provides consistent depth and hierarchy through shadow levels
struct LopanShadows {
    
    // MARK: - Shadow Levels
    static let none = ShadowStyle(
        color: .clear,
        radius: 0,
        x: 0,
        y: 0
    )
    
    static let xs = ShadowStyle(
        color: Color.black.opacity(0.05),
        radius: 1,
        x: 0,
        y: 1
    )
    
    static let sm = ShadowStyle(
        color: Color.black.opacity(0.08),
        radius: 2,
        x: 0,
        y: 1
    )
    
    static let md = ShadowStyle(
        color: Color.black.opacity(0.1),
        radius: 4,
        x: 0,
        y: 2
    )
    
    static let lg = ShadowStyle(
        color: Color.black.opacity(0.12),
        radius: 8,
        x: 0,
        y: 4
    )
    
    static let xl = ShadowStyle(
        color: Color.black.opacity(0.15),
        radius: 16,
        x: 0,
        y: 8
    )
    
    static let xxl = ShadowStyle(
        color: Color.black.opacity(0.2),
        radius: 24,
        x: 0,
        y: 12
    )
    
    // MARK: - Semantic Shadows
    static let card = md
    static let button = sm
    static let modal = xl
    static let dropdown = lg
    static let tooltip = sm
    static let floatingActionButton = lg
    
    // MARK: - Interactive Shadows
    static let buttonPressed = xs
    static let cardHover = lg
    static let cardPressed = sm
}

// MARK: - Shadow Style Structure
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions for Shadows
extension View {
    /// Applies a shadow style to the view
    func lopanShadow(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
    
    /// Applies card shadow
    func cardShadow() -> some View {
        self.lopanShadow(LopanShadows.card)
    }
    
    /// Applies button shadow
    func buttonShadow() -> some View {
        self.lopanShadow(LopanShadows.button)
    }
    
    /// Applies modal shadow
    func modalShadow() -> some View {
        self.lopanShadow(LopanShadows.modal)
    }
    
    /// Applies dropdown shadow
    func dropdownShadow() -> some View {
        self.lopanShadow(LopanShadows.dropdown)
    }
    
    /// Applies floating action button shadow
    func fabShadow() -> some View {
        self.lopanShadow(LopanShadows.floatingActionButton)
    }
}