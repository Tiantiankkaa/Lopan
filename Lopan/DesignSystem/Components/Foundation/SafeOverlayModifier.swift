//
//  SafeOverlayModifier.swift
//  Lopan
//
//  Created by Claude on 2025/8/2.
//

import SwiftUI

/// A custom modifier for consistent overlay handling across the app
/// Ensures proper safe area handling and prevents content overlap during slide-up animations
struct SafeOverlayModifier: ViewModifier {
    let isPresented: Bool
    let overlayContent: AnyView
    
    func body(content: Content) -> some View {
        content
            .overlay(
                isPresented ? 
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea(.container, edges: .all)
                    
                    overlayContent
                        .padding(.horizontal)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            Color.clear.frame(height: 44) // Navigation bar space
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            Color.clear.frame(height: 34) // Tab bar space
                        }
                }
                .zIndex(999)
                .animation(.easeInOut(duration: 0.25), value: isPresented)
                : nil
            )
    }
}

extension View {
    /// Adds a safe overlay that respects navigation and tab bars during slide-up animations
    /// - Parameters:
    ///   - isPresented: Whether the overlay is currently presented
    ///   - content: The content to display in the overlay
    /// - Returns: A view with the safe overlay modifier applied
    func safeOverlay<Content: View>(
        isPresented: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        self.modifier(SafeOverlayModifier(
            isPresented: isPresented,
            overlayContent: AnyView(content())
        ))
    }
}

/// A specialized processing overlay that follows design system conventions
struct ProcessingOverlay: View {
    let message: String
    let progress: Double?
    let statusMessage: String?
    
    init(
        message: String = "正在处理...",
        progress: Double? = nil,
        statusMessage: String? = nil
    ) {
        self.message = message
        self.progress = progress
        self.statusMessage = statusMessage
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
            
            if let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)
            }
            
            if let statusMessage = statusMessage {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.8)),
            removal: .opacity.combined(with: .scale(scale: 1.1))
        ))
    }
}

extension View {
    /// Adds a processing overlay with consistent styling
    /// - Parameters:
    ///   - isProcessing: Whether processing is currently active
    ///   - message: The message to display
    ///   - progress: Optional progress value (0.0 to 1.0)
    ///   - statusMessage: Optional status message
    /// - Returns: A view with the processing overlay
    func processingOverlay(
        isProcessing: Bool,
        message: String = "正在处理...",
        progress: Double? = nil,
        statusMessage: String? = nil
    ) -> some View {
        self.safeOverlay(isPresented: isProcessing) {
            ProcessingOverlay(
                message: message,
                progress: progress,
                statusMessage: statusMessage
            )
        }
    }
}