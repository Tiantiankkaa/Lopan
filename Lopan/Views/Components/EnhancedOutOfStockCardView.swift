//
//  EnhancedOutOfStockCardView.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/8.
//  Enhanced card design matching HTML mockup with iOS 26 patterns
//

import SwiftUI

// MARK: - Enhanced Out-of-Stock Card View

/// Redesigned card matching HTML mockup with modern iOS 26 design
struct EnhancedOutOfStockCardView: View {
    // MARK: - SwipeAction Enum
    enum SwipeAction {
        case delete
        case complete
        case edit
    }

    let item: CustomerOutOfStock
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onSwipeAction: (SwipeAction) -> Void

    @State private var cardScale: CGFloat = 1.0

    var body: some View {
        cardContent
            .background(cardBackground)
            .scaleEffect(cardScale)
            .animation(smoothAnimation, value: isSelected)
            .onTapGesture {
                if isInSelectionMode {
                    onTap()
                } else {
                    // Navigate to detail
                    onTap()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                // Enter selection mode
                onLongPress()
                triggerHaptic()
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                deleteButton
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                markCompleteButton
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Double tap to view details, long press to select")
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(uiColor: .systemBackground))
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? LopanColors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            // Header: Customer name + Status badge
            headerRow

            // OOS duration
            oosDurationRow

            Divider()
                .opacity(0.5)

            // Top critical product
            topCriticalProductRow

            // Progress bar
            OutOfStockProgressBar(item: item)

            // Last update info
            lastUpdateRow
        }
        .padding(LopanSpacing.md)
        .overlay(alignment: .topLeading) {
            if isInSelectionMode {
                selectionCheckmark
                    .padding(LopanSpacing.sm)
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                // Customer name + region
                HStack(spacing: 4) {
                    Text(item.customerDisplayName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("• \(extractRegion())")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }

                // Address subtitle (optional)
                if !item.customerAddress.isEmpty {
                    Text(item.customerAddress)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status badge
            statusBadge
        }
    }

    // MARK: - OOS Duration Row

    private var oosDurationRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundColor(oosDurationColor)

            Text("OOS since \(formatDate(item.requestDate)) (\(daysSinceRequest) days)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(oosDurationColor)
        }
        .padding(.horizontal, LopanSpacing.xs)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(oosDurationColor.opacity(0.1))
        )
    }

    // MARK: - Top Critical Product Row

    private var topCriticalProductRow: some View {
        HStack(spacing: 4) {
            Text("Top critical:")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("\(item.productDisplayName) • \(item.quantity)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }

    // MARK: - Last Update Row

    private var lastUpdateRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text("Last update: \(item.updatedBy ?? item.createdBy)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            Text(item.updatedAt, style: .relative)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text(item.status.displayName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, LopanSpacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(item.status.color)
            )
    }

    // MARK: - Selection Checkmark

    private var selectionCheckmark: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24))
            .foregroundColor(isSelected ? LopanColors.primary : .secondary)
            .symbolEffect(.bounce, value: isSelected)
    }

    // MARK: - Swipe Actions

    private var markCompleteButton: some View {
        Button {
            onSwipeAction(.complete)
            triggerHaptic()
        } label: {
            Label("Complete", systemImage: "checkmark.circle.fill")
        }
        .tint(.green)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onSwipeAction(.delete)
            triggerHaptic()
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
    }

    // MARK: - Computed Properties

    private var daysSinceRequest: Int {
        Calendar.current.dateComponents([.day], from: item.requestDate, to: Date()).day ?? 0
    }

    private var oosDurationColor: Color {
        let days = daysSinceRequest
        if days <= 7 {
            return .green
        } else if days <= 14 {
            return .orange
        } else {
            return .red
        }
    }

    private var accessibilityLabel: String {
        "\(item.customerDisplayName), \(item.status.displayName), \(item.productDisplayName), \(item.quantity) units, OOS for \(daysSinceRequest) days"
    }

    // MARK: - Helper Methods

    private func extractRegion() -> String {
        // Extract region from address (simplified)
        let addressParts = item.customerAddress.components(separatedBy: " ")
        return addressParts.first ?? "Unknown"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - iOS 26 Smooth Animation

    @available(iOS 26.0, *)
    private var smoothIOS26Animation: Animation {
        .smooth(duration: 0.3)
    }

    private var smoothAnimation: Animation {
        if #available(iOS 26.0, *) {
            return smoothIOS26Animation
        } else {
            return .spring(response: 0.3, dampingFraction: 0.7)
        }
    }
}

// MARK: - Preview

#Preview("Pending Card") {
    let item: CustomerOutOfStock = {
        let customer = Customer(
            name: "Ava Harper",
            address: "West District, Building A",
            phone: "1234567890"
        )

        let product = Product(
            sku: "SKU-XYZ-123",
            name: "Red Widget",
            imageData: nil,
            price: 29.99
        )

        let item = CustomerOutOfStock(
            customer: customer,
            product: product,
            quantity: 500,
            notes: "Urgent order",
            createdBy: "John Doe"
        )
        item.deliveryQuantity = 310
        item.updatedBy = "John Doe"
        return item
    }()

    VStack {
        EnhancedOutOfStockCardView(
            item: item,
            isSelected: false,
            isInSelectionMode: false,
            onTap: {},
            onLongPress: {},
            onSwipeAction: { _ in }
        )

        EnhancedOutOfStockCardView(
            item: item,
            isSelected: true,
            isInSelectionMode: true,
            onTap: {},
            onLongPress: {},
            onSwipeAction: { _ in }
        )
    }
    .padding()
}

#Preview("Completed Card") {
    let item: CustomerOutOfStock = {
        let customer = Customer(
            name: "Aaron Bennett",
            address: "East District, Tower B",
            phone: "9876543210"
        )

        let product = Product(
            sku: "SKU-ABC-456",
            name: "Blue Widget",
            imageData: nil,
            price: 39.99
        )

        let item = CustomerOutOfStock(
            customer: customer,
            product: product,
            quantity: 20,
            createdBy: "Jane Smith"
        )
        item.deliveryQuantity = 20
        item.status = .completed
        item.updatedBy = "Jane Smith"
        return item
    }()

    EnhancedOutOfStockCardView(
        item: item,
        isSelected: false,
        isInSelectionMode: false,
        onTap: {},
        onLongPress: {},
        onSwipeAction: { _ in }
    )
    .padding()
}

#Preview("Refunded Card") {
    let item: CustomerOutOfStock = {
        let customer = Customer(
            name: "Blake Carter",
            address: "Central District, Office C",
            phone: "5555555555"
        )

        let product = Product(
            sku: "SKU-QWE-789",
            name: "Green Widget",
            imageData: nil,
            price: 19.99
        )

        let item = CustomerOutOfStock(
            customer: customer,
            product: product,
            quantity: 5,
            createdBy: "Mike Johnson"
        )
        item.status = .refunded
        item.updatedBy = "Mike Johnson"
        return item
    }()

    EnhancedOutOfStockCardView(
        item: item,
        isSelected: false,
        isInSelectionMode: false,
        onTap: {},
        onLongPress: {},
        onSwipeAction: { _ in }
    )
    .padding()
}

#Preview("Dark Mode") {
    let item: CustomerOutOfStock = {
        let customer = Customer(
            name: "Ava Harper",
            address: "West District",
            phone: "1234567890"
        )

        let product = Product(
            sku: "SKU-XYZ-123",
            name: "Red Widget",
            imageData: nil,
            price: 29.99
        )

        let item = CustomerOutOfStock(
            customer: customer,
            product: product,
            quantity: 500,
            createdBy: "John Doe"
        )
        item.deliveryQuantity = 310
        return item
    }()

    EnhancedOutOfStockCardView(
        item: item,
        isSelected: false,
        isInSelectionMode: false,
        onTap: {},
        onLongPress: {},
        onSwipeAction: { _ in }
    )
    .padding()
    .preferredColorScheme(.dark)
}
