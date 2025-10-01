//
//  EnhancedSkeletonView.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/28.
//

import SwiftUI

/// Enhanced skeleton loading system that provides sophisticated content placeholders
/// Supports various content types and maintains accessibility standards
struct EnhancedSkeletonView: View {

    // MARK: - Configuration

    enum SkeletonType {
        case text(lines: Int = 1)
        case card
        case image(aspectRatio: CGFloat = 1.0)
        case list(items: Int = 3)
        case dashboard
        case custom(height: CGFloat)

        var defaultHeight: CGFloat {
            switch self {
            case .text: return 20
            case .card: return 120
            case .image: return 120
            case .list: return 200
            case .dashboard: return 300
            case .custom(let height): return height
            }
        }
    }

    struct Configuration {
        let animationDuration: Double
        let shimmerColors: [Color]
        let cornerRadius: CGFloat
        let enableShimmer: Bool
        let enableAccessibilityAnnouncements: Bool

        static let `default` = Configuration(
            animationDuration: 1.5,
            shimmerColors: [
                Color(UIColor.systemGray5),
                Color(UIColor.systemGray4),
                Color(UIColor.systemGray5)
            ],
            cornerRadius: 8,
            enableShimmer: true,
            enableAccessibilityAnnouncements: true
        )

        static let subtle = Configuration(
            animationDuration: 2.0,
            shimmerColors: [
                Color(UIColor.systemGray6),
                Color(UIColor.systemGray5),
                Color(UIColor.systemGray6)
            ],
            cornerRadius: 6,
            enableShimmer: false,
            enableAccessibilityAnnouncements: false
        )
    }

    // MARK: - Properties

    let type: SkeletonType
    let configuration: Configuration

    @State private var shimmerPosition: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        type: SkeletonType,
        configuration: Configuration = .default
    ) {
        self.type = type
        self.configuration = configuration
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch type {
            case .text(let lines):
                textSkeleton(lines: lines)
            case .card:
                cardSkeleton
            case .image(let aspectRatio):
                imageSkeleton(aspectRatio: aspectRatio)
            case .list(let items):
                listSkeleton(items: items)
            case .dashboard:
                dashboardSkeleton
            case .custom(let height):
                customSkeleton(height: height)
            }
        }
        .onAppear {
            startShimmerAnimation()
            announceLoadingState()
        }
    }

    // MARK: - Skeleton Types

    private func textSkeleton(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<lines, id: \.self) { index in
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 16)
                    .frame(maxWidth: index == lines - 1 ? .infinity * 0.7 : .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
            }
        }
    }

    private var cardSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon placeholder
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    // Title placeholder
                    Rectangle()
                        .fill(shimmerGradient)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity * 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))

                    // Subtitle placeholder
                    Rectangle()
                        .fill(shimmerGradient)
                        .frame(height: 12)
                        .frame(maxWidth: .infinity * 0.8)
                        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
                }

                Spacer()

                // Action indicator placeholder
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
            }

            // Additional content placeholder
            Rectangle()
                .fill(shimmerGradient)
                .frame(height: 32)
                .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        }
        .padding(LopanSpacing.md)
        .background(
            Color(UIColor.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous)
        )
    }

    private func imageSkeleton(aspectRatio: CGFloat) -> some View {
        Rectangle()
            .fill(shimmerGradient)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
    }

    private func listSkeleton(items: Int) -> some View {
        VStack(spacing: 12) {
            ForEach(0..<items, id: \.self) { _ in
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(shimmerGradient)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle()
                            .fill(shimmerGradient)
                            .frame(height: 14)
                            .frame(maxWidth: .infinity * 0.7)
                            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))

                        Rectangle()
                            .fill(shimmerGradient)
                            .frame(height: 12)
                            .frame(maxWidth: .infinity * 0.5)
                            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var dashboardSkeleton: some View {
        VStack(spacing: 20) {
            // Header section
            VStack(alignment: .leading, spacing: 12) {
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 24)
                    .frame(maxWidth: .infinity * 0.6)
                    .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))

                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity * 0.8)
                    .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
            }

            // Metrics grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(shimmerGradient)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
                }
            }

            // List section
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(shimmerGradient)
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
                }
            }
        }
    }

    private func customSkeleton(height: CGFloat) -> some View {
        Rectangle()
            .fill(shimmerGradient)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
    }

    // MARK: - Shimmer Effect

    private var shimmerGradient: LinearGradient {
        if configuration.enableShimmer && !reduceMotion {
            return LinearGradient(
                colors: configuration.shimmerColors,
                startPoint: UnitPoint(x: shimmerPosition - 0.3, y: 0.5),
                endPoint: UnitPoint(x: shimmerPosition + 0.3, y: 0.5)
            )
        } else {
            return LinearGradient(
                colors: [configuration.shimmerColors.first ?? .gray],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func startShimmerAnimation() {
        guard configuration.enableShimmer && !reduceMotion else { return }

        withAnimation(
            .linear(duration: configuration.animationDuration)
            .repeatForever(autoreverses: false)
        ) {
            shimmerPosition = 2
        }
    }

    private func announceLoadingState() {
        guard configuration.enableAccessibilityAnnouncements else { return }

        UIAccessibility.post(
            notification: .announcement,
            argument: "Loading content"
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Shows skeleton loading state while content is loading
    func skeleton(
        when isLoading: Bool,
        type: EnhancedSkeletonView.SkeletonType = .card,
        configuration: EnhancedSkeletonView.Configuration = .default
    ) -> some View {
        Group {
            if isLoading {
                EnhancedSkeletonView(type: type, configuration: configuration)
            } else {
                self
            }
        }
    }

    /// Shows skeleton with custom content replacement
    func skeletonReplacement<SkeletonContent: View>(
        when isLoading: Bool,
        @ViewBuilder skeleton: () -> SkeletonContent
    ) -> some View {
        Group {
            if isLoading {
                skeleton()
            } else {
                self
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct SkeletonPreview: View {
        @State private var isLoading = true

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Text Skeleton")
                                .font(.headline)

                            EnhancedSkeletonView(type: .text(lines: 3))
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Card Skeleton")
                                .font(.headline)

                            EnhancedSkeletonView(type: .card)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Dashboard Skeleton")
                                .font(.headline)

                            EnhancedSkeletonView(type: .dashboard)
                        }

                        Button(isLoading ? "Show Content" : "Show Skeleton") {
                            withAnimation {
                                isLoading.toggle()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                .navigationTitle("Skeleton Loading")
            }
        }
    }

    return SkeletonPreview()
}