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
    @Published var headerOffset: CGFloat = -50
    @Published var searchBarScale: CGFloat = 0.9
    @Published var filterChipScale: CGFloat = 0.8
    @Published var listItemOffset: CGFloat = 20
    @Published var contentOpacity: Double = 0
    
    func animateInitialAppearance() {
        // Staggered entrance animations
        withAnimation(.easeOut(duration: 0.6)) {
            headerOffset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.searchBarScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.filterChipScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.4)) {
                self.listItemOffset = 0
                self.contentOpacity = 1.0
            }
        }
    }
    
    func resetAnimations() {
        withAnimation(.none) {
            headerOffset = 0
            searchBarScale = 1.0
            filterChipScale = 1.0
            listItemOffset = 0
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
    @State private var scale: CGFloat = 0.8
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        scale = 1.0
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