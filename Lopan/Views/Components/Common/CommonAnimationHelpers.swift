//
//  CommonAnimationHelpers.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

// MARK: - Animation State Manager

@MainActor
class CommonAnimationState: ObservableObject {
    @Published var headerOffset: CGFloat = 0
    @Published var searchBarScale: CGFloat = 1.0
    @Published var filterChipScale: CGFloat = 1.0
    @Published var listItemOffset: CGFloat = 0
    @Published var contentOpacity: Double = 1.0
    
    private var hasInitialized = false
    
    func animateInitialAppearance() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        // Simplified animation that doesn't interfere with touch response
        // Remove headerOffset animation to prevent touch area conflicts
        withAnimation(.easeOut(duration: 0.4)) {
            searchBarScale = 1.0
            filterChipScale = 1.0
            contentOpacity = 1.0
        }
    }
    
    func resetAnimations() {
        hasInitialized = false
        withAnimation(.none) {
            searchBarScale = 1.0
            filterChipScale = 1.0
            contentOpacity = 1.0
        }
    }
    
    func animateFilterChips() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            filterChipScale = 1.0
        }
    }
}

// MARK: - Common Animation Modifiers

struct CommonEntranceAnimation: ViewModifier {
    let delay: Double
    @State private var offset: CGFloat = 30
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        offset = 0
                        opacity = 1.0
                    }
                }
            }
    }
}

struct CommonScaleAnimation: ViewModifier {
    let delay: Double
    @State private var scale: CGFloat = 1.0
    
    private func validateScale(_ scale: CGFloat) -> CGFloat {
        return max(0.1, min(2.0, scale)) // Ensure scale is always valid
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        scale = validateScale(1.0)
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func commonEntranceAnimation(delay: Double = 0) -> some View {
        self.modifier(CommonEntranceAnimation(delay: delay))
    }
    
    func commonScaleAnimation(delay: Double = 0) -> some View {
        self.modifier(CommonScaleAnimation(delay: delay))
    }
}

// MARK: - Staggered List Animation

struct StaggeredListAnimation: ViewModifier {
    let index: Int
    let totalItems: Int
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .onAppear {
                let delay = min(Double(index) * 0.1, 1.0) // Max 1 second delay
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        hasAppeared = true
                    }
                }
            }
    }
}

extension View {
    func staggeredListAnimation(index: Int, total: Int) -> some View {
        self.modifier(StaggeredListAnimation(index: index, totalItems: total))
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Header")
            .font(.title2)
            .commonEntranceAnimation(delay: 0.1)
        
        Text("Search Bar")
            .commonScaleAnimation(delay: 0.3)
        
        LazyVStack {
            ForEach(0..<5) { index in
                HStack {
                    Text("Item \(index)")
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .staggeredListAnimation(index: index, total: 5)
            }
        }
    }
    .padding()
}