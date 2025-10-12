//
//  HTMLProductCard.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-05.
//  Product card matching HTML mockup exactly - unified design
//

import SwiftUI

/// Product card component matching HTML mockup pixel-perfect
/// Single unified design with status dot + ring, stock count, timestamp
struct HTMLProductCard: View {
    let product: Product
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top Row: Name + SKU (left), Price (right)
            HStack(alignment: .top, spacing: 12) {
                // Left: Name + SKU
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .lopanTitleSmall()
                        .foregroundColor(LopanColors.productNameText) // gray-900
                        .lineLimit(1)

                    Text("SKU: \(product.formattedSKU)")
                        .lopanBodySmall()
                        .foregroundColor(LopanColors.productSKUText) // gray-500
                }

                Spacer(minLength: 8)

                // Right: Price
                Text(product.formattedPrice)
                    .font(.title2.bold())
                    .foregroundColor(LopanColors.productNameText) // gray-900
            }

            // Bottom Row: Status, Stock, Timestamp
            HStack(spacing: 12) {
                // Status with dot + ring
                HStack(spacing: 8) {
                    statusDotWithRing

                    Text(product.inventoryStatus.htmlLabel)
                        .lopanBodySmall()
                        .foregroundColor(LopanColors.chipInactiveText) // gray-600
                }

                Spacer()

                // Stock count - HIDE for Active status
                if product.inventoryStatus != .active {
                    HStack(spacing: 4) {
                        Text("\(product.inventoryQuantity)")
                            .lopanLabelMedium()
                            .foregroundColor(stockColor)

                        Text("in stock")
                            .lopanBodySmall()
                            .foregroundColor(LopanColors.chipInactiveText) // gray-600
                    }

                    Spacer()
                }

                // Timestamp
                Text(product.htmlRelativeTime)
                    .lopanBodySmall()
                    .foregroundColor(LopanColors.productSKUText) // gray-500
            }
            .padding(.top, 16)
        }
        .padding(16)
        .background(LopanColors.productCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LopanColors.productCardBorder, lineWidth: 1) // border-color
        )
        .lopanShadow(LopanShadows.xs)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to view product details")
    }

    // MARK: - Status Dot with Ring Effect

    /// Status indicator with ring-2 effect matching HTML
    /// <span class="h-2.5 w-2.5 rounded-full bg-green-500 ring-2 ring-green-100"></span>
    private var statusDotWithRing: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(product.inventoryStatus.htmlRingColor)
                .frame(width: 14, height: 14) // 2.5 (10pt) + ring-2 (4pt)

            // Inner dot
            Circle()
                .fill(product.inventoryStatus.htmlDotColor)
                .frame(width: 10, height: 10) // h-2.5 w-2.5 = 10pt
        }
    }

    // MARK: - Stock Color Coding

    private var stockColor: Color {
        switch product.inventoryStatus {
        case .active:
            return Color(hex: "#1F2937") ?? Color.primary // gray-800
        case .lowStock:
            return Color(hex: "#EF4444") ?? Color.red // red-500
        case .inactive:
            return Color(hex: "#1F2937") ?? Color.primary // gray-800
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = product.name
        label += ", SKU \(product.formattedSKU)"
        label += ", \(product.formattedPrice)"
        label += ", \(product.inventoryStatus.htmlLabel)"
        label += ", \(product.inventoryQuantity) in stock"
        label += ", \(product.htmlRelativeTime)"
        return label
    }
}

// MARK: - Product Extension for HTML Rendering

extension Product {
    /// HTML-style relative time (e.g., "Updated 2h ago")
    var htmlRelativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relativeTime = formatter.localizedString(for: updatedAt, relativeTo: Date())
        return "Updated \(relativeTime)"
    }
}

extension Product.InventoryStatus {
    /// HTML-style status labels
    var htmlLabel: String {
        switch self {
        case .active: return "Active"
        case .lowStock: return "Low Stock"
        case .inactive: return "Inactive"
        }
    }

    /// Status dot colors matching HTML
    var htmlDotColor: Color {
        switch self {
        case .active: return Color(hex: "#10B981") ?? Color.green // green-500
        case .lowStock: return Color(hex: "#F59E0B") ?? Color.yellow // yellow-500
        case .inactive: return Color(hex: "#9CA3AF") ?? Color.gray // gray-400
        }
    }

    /// Ring colors matching HTML (lighter shade)
    var htmlRingColor: Color {
        switch self {
        case .active: return Color(hex: "#D1FAE5") ?? Color.green.opacity(0.2) // green-100
        case .lowStock: return Color(hex: "#FEF3C7") ?? Color.yellow.opacity(0.2) // yellow-100
        case .inactive: return Color(hex: "#F3F4F6") ?? Color.gray.opacity(0.2) // gray-100
        }
    }
}

// Note: Color.init(hex:) extension already exists in ColorCard.swift

// MARK: - Preview

#Preview {
    let sampleProduct1: Product = {
        let product = Product(
            sku: "PRD-AM270",
            name: "Air Max 270",
            imageData: nil,
            price: 150.00
        )
        product.sizes = [
            ProductSize(size: "S", quantity: 25, product: product),
            ProductSize(size: "M", quantity: 30, product: product),
            ProductSize(size: "L", quantity: 20, product: product)
        ]
        return product
    }()

    let sampleProduct2: Product = {
        let product = Product(
            sku: "PRD-PRESTO",
            name: "React Presto",
            imageData: nil,
            price: 120.00
        )
        product.sizes = [
            ProductSize(size: "M", quantity: 8, product: product),
            ProductSize(size: "L", quantity: 4, product: product)
        ]
        return product
    }()

    let sampleProduct3: Product = {
        let product = Product(
            sku: "PRD-ZOOMX",
            name: "ZoomX Invincible Run",
            imageData: nil,
            price: 180.00
        )
        product.sizes = []
        return product
    }()

    VStack(spacing: 12) {
        HTMLProductCard(product: sampleProduct1, onTap: { print("Tapped 1") })
        HTMLProductCard(product: sampleProduct2, onTap: { print("Tapped 2") })
        HTMLProductCard(product: sampleProduct3, onTap: { print("Tapped 3") })
        Spacer()
    }
    .padding(16)
    .background(Color(hex: "#F7F8FA") ?? Color.gray.opacity(0.05))
}
