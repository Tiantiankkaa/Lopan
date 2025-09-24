//
//  DynamicTypeShowcase.swift
//  Lopan
//
//  Dynamic Type XL preview showcase for iOS 26 Phase 1 compliance
//  Tests all critical components at accessibility sizes
//

import SwiftUI

/// Comprehensive Dynamic Type showcase for Phase 1 components
struct DynamicTypeShowcase: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {

                    // Section: Foundation Components
                    DynamicTypeSectionHeader(title: "Foundation Components")

                    DynamicTypeComponentTest {
                        LopanButtonShowcase()
                    }

                    DynamicTypeComponentTest {
                        LopanCardShowcase()
                    }

                    DynamicTypeComponentTest {
                        LopanBadgeShowcase()
                    }

                    // Section: Key User Interfaces
                    DynamicTypeSectionHeader(title: "Key User Interfaces")

                    DynamicTypeComponentTest {
                        QuickStatCardShowcase()
                    }

                    DynamicTypeComponentTest {
                        CustomerOutOfStockCardShowcase()
                    }

                    DynamicTypeComponentTest {
                        BatchProcessingCardShowcase()
                    }
                }
                .padding()
            }
            .navigationTitle("Dynamic Type Testing")
            .background(LopanColors.backgroundPrimary)
        }
    }
}

// MARK: - Component Showcases

struct LopanButtonShowcase: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("LopanButton at XL Sizes")
                .font(LopanTypography.headlineMedium)

            LopanButton(
                title: "Primary Action Button with Long Text",
                style: .primary,
                size: .large
            ) { }

            LopanButton(
                title: "Secondary",
                style: .secondary,
                size: .medium
            ) { }

            LopanButton(
                title: "Small Button",
                style: .tertiary,
                size: .small
            ) { }
        }
    }
}

struct LopanCardShowcase: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("LopanCard at XL Sizes")
                .font(LopanTypography.headlineMedium)

            LopanCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customer Out-of-Stock Management")
                        .font(LopanTypography.titleLarge)

                    Text("This is a longer subtitle that should wrap properly at extra large Dynamic Type sizes without truncating important information.")
                        .font(LopanTypography.bodyMedium)
                        .foregroundColor(LopanColors.textSecondary)

                    HStack {
                        Text("Status:")
                            .font(LopanTypography.labelMedium)

                        Text("Active")
                            .font(LopanTypography.labelMedium)
                            .foregroundColor(LopanColors.success)
                    }
                }
            }
        }
    }
}

struct LopanBadgeShowcase: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("LopanBadge at XL Sizes")
                .font(LopanTypography.headlineMedium)

            HStack {
                LopanBadge("Pending", style: .warning)
                LopanBadge("Completed", style: .success)
                LopanBadge("Error State", style: .error)
            }
        }
    }
}

struct QuickStatCardShowcase: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("QuickStatCard at XL Sizes")
                .font(LopanTypography.headlineMedium)

            QuickStatCard(
                title: "Total Out-of-Stock Items",
                value: "1,234",
                subtitle: "Across all customers this week",
                trend: .up,
                trendValue: "+12.5%"
            )
        }
    }
}

struct CustomerOutOfStockCardShowcase: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Customer Out-of-Stock Card at XL Sizes")
                .font(LopanTypography.headlineMedium)

            OutOfStockCardView(
                customerName: "ABC Manufacturing Company Ltd.",
                productName: "High-Precision Metal Component Series X",
                quantity: 500,
                requestDate: Date(),
                status: .pending,
                priority: .high,
                onTap: { },
                onEdit: { },
                onDelete: { }
            )
        }
    }
}

struct BatchProcessingCardShowcase: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Batch Processing at XL Sizes")
                .font(LopanTypography.headlineMedium)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Batch #2024-09-001")
                        .font(LopanTypography.titleLarge)

                    Spacer()

                    LopanBadge("In Progress", style: .info)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Machine Assignment: Workshop Line A")
                        .font(LopanTypography.bodyMedium)

                    Text("Products: High-Volume Production Run with Multiple Components")
                        .font(LopanTypography.bodyMedium)
                        .foregroundColor(LopanColors.textSecondary)

                    Text("Estimated Completion: Tomorrow 2:30 PM")
                        .font(LopanTypography.labelMedium)
                        .foregroundColor(LopanColors.textTertiary)
                }

                HStack {
                    Text("Progress")
                        .font(LopanTypography.labelMedium)

                    Spacer()

                    Text("67%")
                        .font(LopanTypography.labelMedium)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(LopanColors.surface)
            .cornerRadius(12)
        }
    }
}

// MARK: - Helper Components

struct DynamicTypeSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(LopanTypography.headlineLarge)
                .foregroundColor(LopanColors.primary)

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct DynamicTypeComponentTest<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 16) {
            content

            // Show multiple size previews
            HStack {
                Text("XL")
                    .font(.caption2)
                    .padding(4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)

                Text("AX3")
                    .font(.caption2)
                    .padding(4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)

                Text("AX5")
                    .font(.caption2)
                    .padding(4)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(4)

                Spacer()
            }
        }
        .padding()
        .background(LopanColors.surfaceElevated)
        .cornerRadius(12)
    }
}

// MARK: - Previews

#Preview("Default Size") {
    DynamicTypeShowcase()
        .environment(\.dynamicTypeSize, .large)
}

#Preview("Extra Large") {
    DynamicTypeShowcase()
        .environment(\.dynamicTypeSize, .xLarge)
}

#Preview("XXX Large") {
    DynamicTypeShowcase()
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Accessibility 3") {
    DynamicTypeShowcase()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5 (Maximum)") {
    DynamicTypeShowcase()
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Dark Mode - AX5") {
    DynamicTypeShowcase()
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("High Contrast") {
    DynamicTypeShowcase()
        .environment(\.dynamicTypeSize, .accessibility5)
        .environment(\.accessibilityDifferentiateWithoutColor, true)
}