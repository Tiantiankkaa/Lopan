//
//  CustomerFilterAccessoryView.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/17.
//

import SwiftUI
import UIKit

/// Bottom accessory view for customer filters (iOS 26 Native TabView Match)
/// Button controls with exact iOS 26 TabView touch dynamics
struct CustomerFilterAccessoryView: View {
    @Binding var selectedFilter: CustomerFilterTab
    @State private var pressedFilter: CustomerFilterTab? = nil
    @State private var animatingFilter: CustomerFilterTab? = nil

    var body: some View {
        HStack(spacing: 12) {
            ForEach(CustomerFilterTab.allCases, id: \.self) { filter in
                Button {
                    // Haptic feedback on tap (matching native tab bar)
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()

                    // Trigger bounce animation for selection
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                        animatingFilter = filter
                    }

                    // Reset bounce after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation {
                            animatingFilter = nil
                        }
                    }

                    selectedFilter = filter
                    print("📊 Filter selected: \(filter.rawValue)")
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 13, weight: selectedFilter == filter ? .semibold : .medium))
                        .foregroundStyle(selectedFilter == filter ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            if selectedFilter == filter {
                                // Selected state with enhanced liquid glass effect
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.blue)

                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.4)

                                    // Subtle shadow for depth
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                }
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            }
                        }
                        // Bounce animation when selected
                        .scaleEffect(animatingFilter == filter ? 1.02 : 1.0)
                }
                .buttonStyle(NativeTabButtonStyle(isPressed: pressedFilter == filter))
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
                    // Empty gesture
                } onPressingChanged: { isPressing in
                    pressedFilter = isPressing ? filter : nil
                }
            }
        }
    }
}

// MARK: - Native Tab Button Style

/// Button style exactly matching iOS 26 native TabView touch dynamics
private struct NativeTabButtonStyle: ButtonStyle {
    let isPressed: Bool
    @State private var isBouncing = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Scale down to 0.92 when pressed, bounce to 1.02, then settle at 1.0
            .scaleEffect(configuration.isPressed ? 0.92 : (isBouncing ? 1.02 : 1.0))
            // No opacity change in native tab bar
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if !pressed && isBouncing == false {
                    // Trigger bounce on release
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                        isBouncing = true
                    }
                    // Reset bounce
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation {
                            isBouncing = false
                        }
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        CustomerFilterAccessoryView(selectedFilter: .constant(.all))
            .padding()
    }
    .background(Color.gray.opacity(0.2))
}
