//
//  GridProductCard.swift
//  Lopan
//
//  Grid layout product card for 2-column view
//

import SwiftUI

struct GridProductCard: View {
    let product: Product
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Product Image
                if let firstImageData = product.imageDataArray.first,
                   let uiImage = UIImage(data: firstImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Placeholder for products without images
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#F3F4F6") ?? Color.gray.opacity(0.1))
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: "#D1D5DB") ?? Color.gray.opacity(0.3))
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    // Product Name
                    Text(product.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#111827") ?? Color.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Price
                    Text(product.formattedPrice)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "#111827") ?? Color.primary)

                    // Status Indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(product.inventoryStatus.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Status indicator color based on inventory status
    private var statusColor: Color {
        switch product.inventoryStatus {
        case .active:
            return Color(hex: "#10B981") ?? Color.green  // green-500
        case .lowStock:
            return Color(hex: "#F59E0B") ?? Color.orange  // amber-500
        case .inactive:
            return Color(hex: "#6B7280") ?? Color.gray    // gray-500
        }
    }
}

#Preview {
    GridProductCard(
        product: Product(
            sku: "AIR-270",
            name: "Air Max 270",
            price: 150.00
        ),
        onTap: {}
    )
    .frame(width: 180)
    .padding()
    .background(Color(hex: "#F7F8FA"))
}
