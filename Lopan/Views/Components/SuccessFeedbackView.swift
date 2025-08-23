//
//  SuccessFeedbackView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct SuccessFeedbackView: View {
    let message: String
    let icon: String
    let color: Color
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var offset: CGFloat = 20
    
    init(message: String, icon: String = "checkmark.circle.fill", color: Color = .green) {
        self.message = message
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .scaleEffect(scale)
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
                offset = 0
            }
            
            // Auto dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    opacity = 0.0
                    offset = -20
                }
            }
        }
    }
}

// MARK: - Toast Notification System

class ToastManager: ObservableObject {
    @Published var toasts: [ToastItem] = []
    
    func showToast(_ message: String, icon: String = "checkmark.circle.fill", color: Color = .green) {
        let toast = ToastItem(
            id: UUID(),
            message: message,
            icon: icon,
            color: color
        )
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toasts.append(toast)
        }
        
        // Auto remove after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.toasts.removeAll { $0.id == toast.id }
            }
        }
    }
    
    func removeToast(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            toasts.removeAll { $0.id == id }
        }
    }
}

struct ToastItem: Identifiable {
    let id: UUID
    let message: String
    let icon: String
    let color: Color
}

// MARK: - Toast Overlay View

struct ToastOverlayView: View {
    @ObservedObject var toastManager: ToastManager
    
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            
            ForEach(Array(toastManager.toasts.enumerated()), id: \.element.id) { index, toast in
                SuccessFeedbackView(
                    message: toast.message,
                    icon: toast.icon,
                    color: toast.color
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .onTapGesture {
                    toastManager.removeToast(toast.id)
                }
                .zIndex(Double(toastManager.toasts.count - index))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .allowsHitTesting(false) // Allow touches to pass through
    }
}

// MARK: - Success Animation Components

struct CheckmarkAnimation: View {
    @State private var animationProgress: CGFloat = 0
    @State private var scaleEffect: CGFloat = 0.5
    @State private var rotationAngle: Double = -10
    
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 60, color: Color = .green) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: size, height: size)
                .scaleEffect(scaleEffect)
            
            Circle()
                .stroke(color, lineWidth: 3)
                .frame(width: size * 0.8, height: size * 0.8)
                .scaleEffect(scaleEffect)
            
            // Checkmark path
            Path { path in
                // Checkmark coordinates (normalized to 0-1)
                let checkmarkPoints = [
                    CGPoint(x: 0.25, y: 0.5),
                    CGPoint(x: 0.4, y: 0.65),
                    CGPoint(x: 0.75, y: 0.35)
                ]
                
                // Scale points to actual size
                let scaledPoints = checkmarkPoints.map { point in
                    CGPoint(
                        x: point.x * size * 0.6,
                        y: point.y * size * 0.6
                    )
                }
                
                path.move(to: scaledPoints[0])
                path.addLine(to: scaledPoints[1])
                path.addLine(to: scaledPoints[2])
            }
            .trim(from: 0, to: animationProgress)
            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .scaleEffect(scaleEffect)
            .rotationEffect(.degrees(rotationAngle))
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Scale in animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            scaleEffect = 1.0
            rotationAngle = 0
        }
        
        // Checkmark draw animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                animationProgress = 1.0
            }
        }
        
        // Celebration pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scaleEffect = 1.1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    scaleEffect = 1.0
                }
            }
        }
    }
}

// MARK: - Loading to Success Transition

struct LoadingToSuccessView: View {
    @State private var isLoading = true
    @State private var showSuccess = false
    
    let message: String
    let onCompletion: (() -> Void)?
    
    init(message: String = "处理中...", onCompletion: (() -> Void)? = nil) {
        self.message = message
        self.onCompletion = onCompletion
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
            } else if showSuccess {
                CheckmarkAnimation()
                
                Text("操作成功")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
        .frame(width: 200, height: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            // Simulate loading completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoading = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showSuccess = true
                    }
                }
                
                // Call completion handler
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onCompletion?()
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        SuccessFeedbackView(message: "删除成功")
        
        SuccessFeedbackView(
            message: "批量操作完成",
            icon: "checkmark.circle.fill",
            color: .blue
        )
        
        CheckmarkAnimation()
        
        LoadingToSuccessView(message: "正在删除记录...")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}