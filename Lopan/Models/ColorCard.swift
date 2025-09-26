//
//  ColorCard.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData
import SwiftUI

@Model
public final class ColorCard {
    public var id: String
    var name: String
    var hexCode: String
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String
    var isActive: Bool
    
    init(name: String, hexCode: String, createdBy: String) {
        self.id = UUID().uuidString
        self.name = name
        self.hexCode = hexCode
        self.createdAt = Date()
        self.updatedAt = Date()
        self.createdBy = createdBy
        self.isActive = true
    }
    
    // MARK: - Computed Properties
    var swiftUIColor: Color {
        return Color(hex: hexCode) ?? LopanColors.secondary
    }
    
    var displayName: String {
        return name
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}