//
//  SimplifiedStatCard.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/28.
//  Refined status card component tuned for Apple design language
//

import SwiftUI
import UIKit

/// A refined status card that aligns with Apple design aesthetics while remaining lightweight and accessible.
/// Designed for use inside the customer out-of-stock management dashboard.
public struct SimplifiedStatCard: View {

    // MARK: - Public Properties

    let title: String
    let value: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let isLoading: Bool
    let onTap: () -> Void

    // MARK: - Environment & Metrics

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var horizontalPadding: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 14
    @ScaledMetric(relativeTo: .title3) private var iconContainerSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var focusIndicatorHeight: CGFloat = 4

    // MARK: - Private State

    @State private var isPressed = false

    // MARK: - Initialiser

    public init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        isSelected: Bool = false,
        isLoading: Bool = false,
        onTap: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.isSelected = isSelected
        self.isLoading = isLoading
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        Button(action: handleTap) {
            cardContent
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = false }
                }
        )
        .hoverEffect(.highlight)
        .opacity(isPressed ? 0.94 : 1.0)
        .scaleEffect(isPressed ? 0.985 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: isLoading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(displayValueForAccessibility)")
        .accessibilityHint(isSelected ? "已选中，双击取消选择" : "双击筛选此状态")
        .accessibilityAddTraits(isLoading ? [.isButton, .updatesFrequently] : .isButton)
        .disabled(isLoading)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                iconBadge

                Spacer(minLength: 4)

                valueView
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay(focusIndicator, alignment: .topLeading)
        .shadow(color: cardShadowColor, radius: isSelected ? 10 : 6, x: 0, y: isSelected ? 6 : 4)
    }

    // MARK: - Icon & Value Views

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: iconContainerSize / 2, style: .continuous)
                .fill(iconBackgroundGradient)

            Image(systemName: icon)
                .font(.system(size: iconContainerSize * 0.58, weight: .semibold))
                .foregroundStyle(iconForeground)
        }
        .frame(width: iconContainerSize, height: iconContainerSize)
        .accessibilityHidden(true)
    }

    private var valueView: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(color)
                    .frame(width: 28, height: 28)
            } else {
                valueText
            }
        }
        .frame(minWidth: 40)
    }

    private var valueText: some View {
        let text = Text(value)
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(valueColor)
            .lineLimit(1)
            .minimumScaleFactor(0.65)

        if #available(iOS 17.0, *) {
            return text
                .contentTransition(.numericText(value: numericAnimationValue))
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: numericAnimationValue)
                .eraseToAnyView()
        } else {
            return text
                .animation(.easeInOut(duration: 0.2), value: value)
                .eraseToAnyView()
        }
    }

    // MARK: - Decorative Elements

    private var focusIndicator: some View {
        Capsule(style: .continuous)
            .fill(selectionHighlightGradient)
            .frame(width: 44, height: focusIndicatorHeight)
            .opacity(isSelected ? 1 : 0)
            .offset(y: -(focusIndicatorHeight / 2))
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(accentOverlayColor)
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(borderGradient, lineWidth: isSelected ? 1.75 : 1)
            .opacity(0.9)
    }

    // MARK: - Computed Helpers

    private var displayValueForAccessibility: String {
        isLoading ? "正在加载" : value
    }

    private var numericAnimationValue: Double {
        let digitsOnly = value.filter { $0.isNumber }
        if let numeric = Double(digitsOnly) {
            return numeric
        }
        return Double(abs(value.hashValue % 10_000))
    }

    private var iconForeground: Color {
        isLoading ? LopanColors.textSecondary.opacity(0.45) : color.opacity(colorScheme == .dark ? 0.95 : 0.9)
    }

    private var iconBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(colorScheme == .dark ? 0.25 : 0.18),
                color.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var valueColor: Color {
        if isLoading {
            return LopanColors.textSecondary.opacity(0.45)
        }
        return isSelected ? color : LopanColors.textPrimary
    }

    private var titleColor: Color {
        if isLoading {
            return LopanColors.textSecondary.opacity(0.45)
        }
        return isSelected ? color.opacity(colorScheme == .dark ? 0.85 : 0.9) : LopanColors.textSecondary
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(isSelected ? 0.7 : 0.35),
                color.opacity(isSelected ? 0.4 : 0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectionHighlightGradient: LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(0.85),
                color.opacity(0.45)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var accentOverlayColor: Color {
        let baseOpacity: Double = colorScheme == .dark ? 0.32 : 0.18
        return color.opacity(baseOpacity)
    }

    private var cardShadowColor: Color {
        color.opacity(colorScheme == .dark ? 0.28 : 0.18)
    }

    // MARK: - Actions

    private func handleTap() {
        guard !isLoading else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        onTap()
    }
}

// MARK: - Private Helpers

private extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

// MARK: - Preview Provider

#Preview("SimplifiedStatCard - Modern") {
    VStack(spacing: 20) {
        SimplifiedStatCard(
            title: "总计",
            value: "142",
            icon: "list.bullet.rectangle.fill",
            color: LopanColors.primary,
            isSelected: true
        )

        SimplifiedStatCard(
            title: "待处理",
            value: "28",
            icon: "clock.fill",
            color: LopanColors.warning
        )

        SimplifiedStatCard(
            title: "已完成",
            value: "96",
            icon: "checkmark.circle.fill",
            color: LopanColors.success,
            isLoading: true
        )

        SimplifiedStatCard(
            title: "已退货",
            value: "18",
            icon: "arrow.uturn.left",
            color: LopanColors.error
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("SimplifiedStatCard - Compact Grid") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
        SimplifiedStatCard(
            title: "总计",
            value: "142",
            icon: "list.bullet.rectangle.fill",
            color: LopanColors.primary,
            isSelected: true
        )
        SimplifiedStatCard(
            title: "待处理",
            value: "28",
            icon: "clock.fill",
            color: LopanColors.warning
        )
        SimplifiedStatCard(
            title: "已完成",
            value: "96",
            icon: "checkmark.circle.fill",
            color: LopanColors.success
        )
        SimplifiedStatCard(
            title: "已退货",
            value: "18",
            icon: "arrow.uturn.left",
            color: LopanColors.error
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
