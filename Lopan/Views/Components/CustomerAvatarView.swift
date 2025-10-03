//
//  CustomerAvatarView.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/02.
//

import SwiftUI

/// A color-coded avatar component for customers
/// Shows custom photo, custom color, or generates consistent colors based on customer name
struct CustomerAvatarView: View {
    let customer: Customer?  // Optional customer for full avatar support
    let customerName: String
    let size: CGFloat
    let avatarImageData: Data?
    let avatarBackgroundColor: String?
    let overrideColor: Color?  // Optional preview color for edit mode

    // Convenience initializer for name-only (backward compatibility)
    init(customerName: String, size: CGFloat) {
        self.customer = nil
        self.customerName = customerName
        self.size = size
        self.avatarImageData = nil
        self.avatarBackgroundColor = nil
        self.overrideColor = nil
    }

    // Full initializer with customer object
    init(customer: Customer, size: CGFloat, overrideColor: Color? = nil) {
        self.customer = customer
        self.customerName = customer.name
        self.size = size
        self.avatarImageData = customer.avatarImageData
        self.avatarBackgroundColor = customer.avatarBackgroundColor
        self.overrideColor = overrideColor
    }

    // Generate consistent color from name (fallback)
    private var avatarColor: Color {
        // Priority: override color > custom color > generated color
        if let override = overrideColor {
            return override
        }
        if let colorHex = avatarBackgroundColor, let color = Color(hex: colorHex) {
            return color
        }
        return generateColorFromName(customerName)
    }

    // Get first letter (or # for empty names)
    private var initial: String {
        if let firstChar = customerName.first {
            return String(firstChar).uppercased()
        }
        return "#"
    }

    var body: some View {
        Group {
            // If override color is set (edit mode preview), show color instead of photo
            if overrideColor != nil {
                // Show color with initial (preview mode)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [avatarColor, avatarColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay {
                        Text(initial)
                            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
            } else if let imageData = avatarImageData,
                      let uiImage = UIImage(data: imageData) {
                // Show custom photo
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Show color with initial
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [avatarColor, avatarColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay {
                        Text(initial)
                            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
            }
        }
        .shadow(color: avatarColor.opacity(0.3), radius: 4, x: 0, y: 2)
        .accessibilityLabel("\(customerName) 头像")
    }

    // MARK: - Color Generation

    /// Generates a consistent color based on the customer name using stable DJB2 hash
    /// - Note: Color reuse is expected when customer count exceeds palette size
    /// - Visual uniqueness is achieved through color + initial letter combination
    private func generateColorFromName(_ name: String) -> Color {
        // DJB2 hash algorithm for stable, deterministic color assignment
        var hash: UInt32 = 5381
        for char in name.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt32(char)
        }

        // Expanded 24-color palette for reduced collision probability
        let colorPalette: [Color] = [
            // Original 10 colors
            Color(red: 0.4, green: 0.6, blue: 1.0),    // Blue
            Color(red: 0.2, green: 0.8, blue: 0.5),    // Green
            Color(red: 0.7, green: 0.4, blue: 1.0),    // Purple
            Color(red: 1.0, green: 0.4, blue: 0.4),    // Red
            Color(red: 1.0, green: 0.8, blue: 0.3),    // Yellow
            Color(red: 0.5, green: 0.5, blue: 1.0),    // Indigo
            Color(red: 1.0, green: 0.5, blue: 0.7),    // Pink
            Color(red: 0.3, green: 0.9, blue: 0.8),    // Cyan
            Color(red: 1.0, green: 0.6, blue: 0.2),    // Orange
            Color(red: 0.6, green: 0.8, blue: 0.3),    // Lime

            // Additional 14 colors for better distribution
            Color(red: 0.9, green: 0.3, blue: 0.5),    // Rose
            Color(red: 0.3, green: 0.5, blue: 0.9),    // Sky Blue
            Color(red: 1.0, green: 0.4, blue: 0.6),    // Coral
            Color(red: 0.4, green: 0.9, blue: 0.6),    // Mint
            Color(red: 0.7, green: 0.5, blue: 0.9),    // Lavender
            Color(red: 0.9, green: 0.6, blue: 0.3),    // Peach
            Color(red: 0.4, green: 0.7, blue: 0.9),    // Light Blue
            Color(red: 0.9, green: 0.4, blue: 0.8),    // Magenta
            Color(red: 0.5, green: 0.9, blue: 0.4),    // Light Green
            Color(red: 1.0, green: 0.7, blue: 0.4),    // Amber
            Color(red: 0.6, green: 0.4, blue: 0.9),    // Deep Purple
            Color(red: 0.3, green: 0.7, blue: 0.7),    // Teal
            Color(red: 0.9, green: 0.5, blue: 0.4),    // Salmon
            Color(red: 0.5, green: 0.6, blue: 0.9),    // Periwinkle
        ]

        let index = Int(hash % UInt32(colorPalette.count))
        return colorPalette[index]
    }
}

// MARK: - Previews

#Preview("Single Avatar") {
    CustomerAvatarView(customerName: "张三", size: 60)
        .padding()
}

#Preview("Avatar Gallery") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            CustomerAvatarView(customerName: "Ava Thompson", size: 48)
            CustomerAvatarView(customerName: "Ethan Carter", size: 48)
            CustomerAvatarView(customerName: "Isabella Rossi", size: 48)
        }
        HStack(spacing: 16) {
            CustomerAvatarView(customerName: "Liam Walker", size: 48)
            CustomerAvatarView(customerName: "Olivia Bennett", size: 48)
            CustomerAvatarView(customerName: "Noah Hayes", size: 48)
        }
        HStack(spacing: 16) {
            CustomerAvatarView(customerName: "张三", size: 48)
            CustomerAvatarView(customerName: "李四", size: 48)
            CustomerAvatarView(customerName: "王五", size: 48)
        }
    }
    .padding()
}

#Preview("Different Sizes") {
    HStack(spacing: 20) {
        CustomerAvatarView(customerName: "张三", size: 32)
        CustomerAvatarView(customerName: "张三", size: 48)
        CustomerAvatarView(customerName: "张三", size: 64)
        CustomerAvatarView(customerName: "张三", size: 80)
    }
    .padding()
}
