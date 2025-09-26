//
//  ShimmerEffect.swift
//  Lopan
//
//  Created by Claude Code on 2025/1/20.
//

import SwiftUI

// MARK: - Shimmer Effect Modifier
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                LopanColors.clear,
                                LopanColors.textPrimary.opacity(0.4),
                                LopanColors.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .clipped()
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 300
                }
            }
    }
}

// MARK: - View Extension
extension View {
    func shimmering() -> some View {
        modifier(ShimmerEffect())
    }
}