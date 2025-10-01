//
//  ToastFeedbackView.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/28.
//

import SwiftUI

/// Toast feedback system for providing contextual user feedback
/// Follows Apple HIG guidelines for non-intrusive notifications
struct ToastFeedbackView: View {

    // MARK: - Configuration

    enum Style {
        case success
        case error
        case warning
        case info

        var color: Color {
            switch self {
            case .success: return LopanColors.success
            case .error: return LopanColors.error
            case .warning: return LopanColors.warning
            case .info: return LopanColors.info
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    // MARK: - Properties

    let message: String
    let style: Style
    let duration: TimeInterval
    let onDismiss: (() -> Void)?

    @State private var isVisible = false
    @State private var offset: CGFloat = -100
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        message: String,
        style: Style = .info,
        duration: TimeInterval = 3.0,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.style = style
        self.duration = duration
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: LopanSpacing.sm) {
            Image(systemName: style.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(style.color)
                .accessibilityHidden(true)

            Text(message)
                .lopanBodyMedium()
                .foregroundColor(LopanColors.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Spacer()

            Button {
                dismissToast()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(LopanColors.textSecondary)
            }
            .accessibilityLabel("Dismiss notification")
        }
        .padding(LopanSpacing.md)
        .background(
            Color(UIColor.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
                .stroke(style.color.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: LopanColors.shadow.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
        .offset(y: offset)
        .opacity(isVisible ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8),
            value: offset
        )
        .animation(
            .easeInOut(duration: reduceMotion ? 0 : 0.3),
            value: isVisible
        )
        .onAppear {
            showToast()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel("\(styleAccessibilityLabel) \(message)")
    }

    // MARK: - Methods

    private func showToast() {
        withAnimation {
            isVisible = true
            offset = 0
        }

        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            dismissToast()
        }

        // Accessibility announcement
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(styleAccessibilityLabel) \(message)"
        )

        // Haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: hapticStyle)
        impactGenerator.impactOccurred()
    }

    private func dismissToast() {
        withAnimation {
            isVisible = false
            offset = -100
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss?()
        }
    }

    private var styleAccessibilityLabel: String {
        switch style {
        case .success: return "Success"
        case .error: return "Error"
        case .warning: return "Warning"
        case .info: return "Information"
        }
    }

    private var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch style {
        case .success: return .light
        case .error: return .heavy
        case .warning: return .medium
        case .info: return .light
        }
    }
}

// MARK: - Toast Manager

@MainActor
class EnhancedToastManager: ObservableObject {
    @Published var currentToast: ToastData?

    struct ToastData: Identifiable {
        let id = UUID()
        let message: String
        let style: ToastFeedbackView.Style
        let duration: TimeInterval
    }

    func show(
        _ message: String,
        style: ToastFeedbackView.Style = .info,
        duration: TimeInterval = 3.0
    ) {
        currentToast = ToastData(
            message: message,
            style: style,
            duration: duration
        )
    }

    func showSuccess(_ message: String) {
        show(message, style: .success)
    }

    func showError(_ message: String) {
        show(message, style: .error, duration: 4.0)
    }

    func showWarning(_ message: String) {
        show(message, style: .warning, duration: 3.5)
    }

    func dismiss() {
        currentToast = nil
    }
}

// MARK: - View Extensions

extension View {
    /// Adds toast feedback capability to any view
    func withToastFeedback(toastManager: EnhancedToastManager) -> some View {
        self.overlay(alignment: .top) {
            if let toast = toastManager.currentToast {
                ToastFeedbackView(
                    message: toast.message,
                    style: toast.style,
                    duration: toast.duration
                ) {
                    toastManager.dismiss()
                }
                .padding(.top, 8)
                .padding(.horizontal, LopanSpacing.md)
                .zIndex(999)
            }
        }
    }
}

// MARK: - Environment Key

private struct ToastManagerKey: EnvironmentKey {
    @MainActor static let defaultValue = EnhancedToastManager()
}

extension EnvironmentValues {
    var toastManager: EnhancedToastManager {
        get { self[ToastManagerKey.self] }
        set { self[ToastManagerKey.self] = newValue }
    }
}

// MARK: - Preview

#Preview {
    struct ToastPreview: View {
        @StateObject private var toastManager = EnhancedToastManager()

        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Toast Feedback System")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(spacing: 12) {
                        Button("Show Success Toast") {
                            toastManager.showSuccess("Operation completed successfully!")
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Show Error Toast") {
                            toastManager.showError("Something went wrong. Please try again.")
                        }
                        .buttonStyle(.bordered)

                        Button("Show Warning Toast") {
                            toastManager.showWarning("Please review your input before proceeding.")
                        }
                        .buttonStyle(.bordered)

                        Button("Show Info Toast") {
                            toastManager.show("Here's some helpful information for you.")
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()
                }
                .padding()
                .withToastFeedback(toastManager: toastManager)
                .navigationTitle("Toast Preview")
            }
        }
    }

    return ToastPreview()
}