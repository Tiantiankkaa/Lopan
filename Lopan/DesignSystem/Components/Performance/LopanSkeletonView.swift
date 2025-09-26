//
//  LopanSkeletonView.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/23.
//

import SwiftUI

/// Modern skeleton loading system for Lopan production management app
/// Provides accessible, animated placeholders that respect user preferences
public struct LopanSkeletonView: View {

    // MARK: - Properties

    let style: SkeletonStyle
    let isAnimated: Bool
    let accessibilityLabel: String

    @State private var isShimmering = false

    // MARK: - Initialization

    public init(
        style: SkeletonStyle,
        isAnimated: Bool = true,
        accessibilityLabel: String = "内容加载中"
    ) {
        self.style = style
        self.isAnimated = isAnimated && LopanAnimation.isMotionEnabled
        self.accessibilityLabel = accessibilityLabel
    }

    // MARK: - Body

    public var body: some View {
        Group {
            switch style {
            case .text(let lines, let lineHeight):
                textSkeleton(lines: lines, lineHeight: lineHeight)
            case .card:
                cardSkeleton
            case .list(let itemCount):
                listSkeleton(itemCount: itemCount)
            case .circular(let size):
                circularSkeleton(size: size)
            case .rectangular(let width, let height):
                rectangularSkeleton(width: width, height: height)
            case .custom(let content):
                content()
                    .skeletonEffect(isAnimated: isAnimated)
            }
        }
        .accessibilityElement(children: .ignore)
        .lopanAccessibility(
            role: .loading,
            label: accessibilityLabel,
            hint: "等待内容加载完成"
        )
        .onAppear {
            if isAnimated {
                withAnimation(LopanAnimation.breathe) {
                    isShimmering.toggle()
                }
            }
        }
    }

    // MARK: - Skeleton Components

    @ViewBuilder
    private func textSkeleton(lines: Int, lineHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            ForEach(0..<lines, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(LopanColors.skeletonBase)
                    .frame(height: lineHeight)
                    .frame(maxWidth: index == lines - 1 ? .infinity * 0.7 : .infinity)
                    .skeletonEffect(isAnimated: isAnimated)
            }
        }
    }

    private var cardSkeleton: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            // Header area
            HStack {
                RoundedRectangle(cornerRadius: LopanCornerRadius.circle)
                    .fill(LopanColors.skeletonBase)
                    .frame(width: 40, height: 40)
                    .skeletonEffect(isAnimated: isAnimated)

                VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LopanColors.skeletonBase)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity * 0.6)
                        .skeletonEffect(isAnimated: isAnimated)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(LopanColors.skeletonBase)
                        .frame(height: 12)
                        .frame(maxWidth: .infinity * 0.4)
                        .skeletonEffect(isAnimated: isAnimated)
                }

                Spacer()
            }

            // Content area
            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LopanColors.skeletonBase)
                        .frame(height: 14)
                        .skeletonEffect(isAnimated: isAnimated)
                }
            }
        }
        .padding(LopanSpacing.md)
        .background(LopanColors.surface)
        .cornerRadius(LopanCornerRadius.card)
    }

    @ViewBuilder
    private func listSkeleton(itemCount: Int) -> some View {
        VStack(spacing: LopanSpacing.sm) {
            ForEach(0..<itemCount, id: \.self) { index in
                LopanSkeletonView(
                    style: .card,
                    isAnimated: isAnimated,
                    accessibilityLabel: "列表项 \(index + 1) 加载中"
                )
                .animation(
                    LopanAnimation.listItemAppear.delay(Double(index) * 0.1),
                    value: isShimmering
                )
            }
        }
    }

    @ViewBuilder
    private func circularSkeleton(size: CGFloat) -> some View {
        Circle()
            .fill(LopanColors.skeletonBase)
            .frame(width: size, height: size)
            .skeletonEffect(isAnimated: isAnimated)
    }

    @ViewBuilder
    private func rectangularSkeleton(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: LopanCornerRadius.button)
            .fill(LopanColors.skeletonBase)
            .frame(width: width, height: height)
            .skeletonEffect(isAnimated: isAnimated)
    }
}

// MARK: - Skeleton Styles

extension LopanSkeletonView {
    public enum SkeletonStyle {
        case text(lines: Int = 3, lineHeight: CGFloat = 16)
        case card
        case list(itemCount: Int = 5)
        case circular(size: CGFloat = 40)
        case rectangular(width: CGFloat? = nil, height: CGFloat = 44)
        case custom(() -> AnyView)
    }
}

// MARK: - Skeleton Effect Modifier

private struct SkeletonEffectModifier: ViewModifier {
    let isAnimated: Bool
    @State private var opacity: Double = 0.3

    func body(content: Content) -> some View {
        content
            .opacity(isAnimated ? opacity : 0.3)
            .animation(
                isAnimated ? LopanAnimation.breathe : nil,
                value: opacity
            )
            .onAppear {
                if isAnimated {
                    withAnimation(LopanAnimation.breathe) {
                        opacity = 0.7
                    }
                }
            }
    }
}

private extension View {
    func skeletonEffect(isAnimated: Bool) -> some View {
        self.modifier(SkeletonEffectModifier(isAnimated: isAnimated))
    }
}

// MARK: - Convenience Skeleton Views

/// Ready-to-use skeleton components for common UI patterns
extension LopanSkeletonView {

    /// User list item skeleton
    public static func userListItem(isAnimated: Bool = true) -> some View {
        HStack {
            LopanSkeletonView(
                style: .circular(size: 44),
                isAnimated: isAnimated,
                accessibilityLabel: "用户头像加载中"
            )

            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                LopanSkeletonView(
                    style: .text(lines: 1, lineHeight: 16),
                    isAnimated: isAnimated,
                    accessibilityLabel: "用户姓名加载中"
                )

                LopanSkeletonView(
                    style: .text(lines: 1, lineHeight: 12),
                    isAnimated: isAnimated,
                    accessibilityLabel: "用户角色加载中"
                )
            }

            Spacer()

            LopanSkeletonView(
                style: .rectangular(width: 60, height: 24),
                isAnimated: isAnimated,
                accessibilityLabel: "用户状态加载中"
            )
        }
        .padding(LopanSpacing.md)
        .background(LopanColors.surface)
        .cornerRadius(LopanCornerRadius.card)
    }

    /// Product list item skeleton
    public static func productListItem(isAnimated: Bool = true) -> some View {
        HStack {
            LopanSkeletonView(
                style: .rectangular(width: 60, height: 60),
                isAnimated: isAnimated,
                accessibilityLabel: "产品图片加载中"
            )

            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                LopanSkeletonView(
                    style: .text(lines: 1, lineHeight: 18),
                    isAnimated: isAnimated,
                    accessibilityLabel: "产品名称加载中"
                )

                LopanSkeletonView(
                    style: .text(lines: 1, lineHeight: 14),
                    isAnimated: isAnimated,
                    accessibilityLabel: "产品价格加载中"
                )

                LopanSkeletonView(
                    style: .text(lines: 1, lineHeight: 12),
                    isAnimated: isAnimated,
                    accessibilityLabel: "产品库存加载中"
                )
            }

            Spacer()
        }
        .padding(LopanSpacing.md)
        .background(LopanColors.surface)
        .cornerRadius(LopanCornerRadius.card)
    }

    /// Dashboard stat card skeleton
    public static func statCard(isAnimated: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            HStack {
                LopanSkeletonView(
                    style: .circular(size: 32),
                    isAnimated: isAnimated,
                    accessibilityLabel: "统计图标加载中"
                )

                Spacer()

                LopanSkeletonView(
                    style: .rectangular(width: 50, height: 20),
                    isAnimated: isAnimated,
                    accessibilityLabel: "趋势指标加载中"
                )
            }

            LopanSkeletonView(
                style: .text(lines: 1, lineHeight: 24),
                isAnimated: isAnimated,
                accessibilityLabel: "统计数值加载中"
            )

            LopanSkeletonView(
                style: .text(lines: 1, lineHeight: 14),
                isAnimated: isAnimated,
                accessibilityLabel: "统计标题加载中"
            )
        }
        .padding(LopanSpacing.md)
        .background(LopanColors.surface)
        .cornerRadius(LopanCornerRadius.card)
        .frame(minHeight: 120)
    }
}

// MARK: - SwiftUI Integration

extension View {
    /// Conditionally shows skeleton or content based on loading state
    public func lopanSkeletonPlaceholder<SkeletonContent: View>(
        isLoading: Bool,
        @ViewBuilder skeleton: () -> SkeletonContent
    ) -> some View {
        ZStack {
            if isLoading {
                skeleton()
                    .transition(LopanAnimation.isMotionEnabled ? .lopanScaleAndFade : .opacity)
            } else {
                self
                    .transition(LopanAnimation.isMotionEnabled ? .lopanScaleAndFade : .opacity)
            }
        }
        .animation(LopanAnimation.contentRefresh, value: isLoading)
    }

    /// Applies skeleton effect to any view
    public func lopanSkeletonEffect(
        isActive: Bool,
        animation: Animation = LopanAnimation.breathe
    ) -> some View {
        self
            .opacity(isActive ? 0.3 : 1.0)
            .animation(isActive ? animation : nil, value: isActive)
    }
}

// MARK: - Color Extensions

extension LopanColors {
    /// Base color for skeleton elements
    public static let skeletonBase = LopanColors.backgroundSecondary

    /// Highlight color for skeleton shimmer effect
    public static let skeletonHighlight = LopanColors.backgroundSecondary
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: LopanSpacing.lg) {
            Group {
                Text("文本骨架屏")
                    .lopanTitleMedium()
                LopanSkeletonView(style: .text(lines: 3))

                Text("卡片骨架屏")
                    .lopanTitleMedium()
                LopanSkeletonView(style: .card)

                Text("用户列表项骨架屏")
                    .lopanTitleMedium()
                LopanSkeletonView.userListItem()

                Text("产品列表项骨架屏")
                    .lopanTitleMedium()
                LopanSkeletonView.productListItem()

                Text("统计卡片骨架屏")
                    .lopanTitleMedium()
                LopanSkeletonView.statCard()
            }
        }
        .padding()
    }
    .accessibilityPreview()
}