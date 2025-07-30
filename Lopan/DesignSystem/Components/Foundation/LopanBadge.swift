//
//  LopanBadge.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Modern badge component system for Lopan production management app
/// Used for status indicators, notifications, and labels
struct LopanBadge: View {
    // MARK: - Properties
    let text: String
    let style: BadgeStyle
    let size: BadgeSize
    let icon: String?
    let iconPosition: IconPosition
    
    // MARK: - Initializers
    init(
        _ text: String,
        style: BadgeStyle = .primary,
        size: BadgeSize = .medium,
        icon: String? = nil,
        iconPosition: IconPosition = .leading
    ) {
        self.text = text
        self.style = style
        self.size = size
        self.icon = icon
        self.iconPosition = iconPosition
    }
    
    var body: some View {
        HStack(spacing: size.iconSpacing) {
            if iconPosition == .leading, let icon = icon {
                Image(systemName: icon)
                    .font(size.iconFont)
            }
            
            Text(text)
                .font(size.textFont)
                .fontWeight(.medium)
            
            if iconPosition == .trailing, let icon = icon {
                Image(systemName: icon)
                    .font(size.iconFont)
            }
        }
        .foregroundColor(style.foregroundColor)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.badge)
                .fill(style.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: LopanCornerRadius.badge)
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
        )
    }
}

// MARK: - Badge Styles
extension LopanBadge {
    enum BadgeStyle {
        case primary
        case secondary
        case success
        case warning
        case error
        case info
        case neutral
        case outline
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return LopanColors.primary
            case .secondary:
                return LopanColors.secondary
            case .success:
                return LopanColors.success
            case .warning:
                return LopanColors.warning
            case .error:
                return LopanColors.error
            case .info:
                return LopanColors.info
            case .neutral:
                return LopanColors.surface
            case .outline:
                return Color.clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .secondary, .success, .warning, .error, .info:
                return LopanColors.textOnPrimary
            case .neutral:
                return LopanColors.textPrimary
            case .outline:
                return LopanColors.primary
            }
        }
        
        var borderColor: Color {
            switch self {
            case .outline:
                return LopanColors.primary
            default:
                return Color.clear
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .outline:
                return 1
            default:
                return 0
            }
        }
    }
}

// MARK: - Badge Sizes
extension LopanBadge {
    enum BadgeSize {
        case small
        case medium
        case large
        
        var textFont: Font {
            switch self {
            case .small:
                return LopanTypography.caption
            case .medium:
                return LopanTypography.labelSmall
            case .large:
                return LopanTypography.labelMedium
            }
        }
        
        var iconFont: Font {
            switch self {
            case .small:
                return .system(size: 10, weight: .medium)
            case .medium:
                return .system(size: 12, weight: .medium)
            case .large:
                return .system(size: 14, weight: .medium)
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small:
                return LopanSpacing.xs
            case .medium:
                return LopanSpacing.sm
            case .large:
                return LopanSpacing.md
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small:
                return LopanSpacing.xxs
            case .medium:
                return LopanSpacing.xs
            case .large:
                return LopanSpacing.sm
            }
        }
        
        var iconSpacing: CGFloat {
            switch self {
            case .small:
                return LopanSpacing.xxs
            case .medium:
                return LopanSpacing.xs
            case .large:
                return LopanSpacing.xs
            }
        }
    }
}

// MARK: - Icon Position
extension LopanBadge {
    enum IconPosition {
        case leading
        case trailing
    }
}

// MARK: - Convenience Initializers
extension LopanBadge {
    /// Creates a status badge for production management
    static func status(
        _ status: OutOfStockStatus,
        size: BadgeSize = .medium
    ) -> LopanBadge {
        let (text, style, icon) = statusProperties(for: status)
        return LopanBadge(text, style: style, size: size, icon: icon)
    }
    
    /// Creates a priority badge
    static func priority(
        _ priority: Priority,
        size: BadgeSize = .medium
    ) -> LopanBadge {
        let (text, style, icon) = priorityProperties(for: priority)
        return LopanBadge(text, style: style, size: size, icon: icon)
    }
    
    /// Creates a count badge
    static func count(
        _ count: Int,
        style: BadgeStyle = .primary,
        size: BadgeSize = .small
    ) -> LopanBadge {
        LopanBadge(
            count > 99 ? "99+" : "\(count)",
            style: style,
            size: size
        )
    }
    
    /// Creates a notification badge
    static func notification(
        _ count: Int,
        size: BadgeSize = .small
    ) -> LopanBadge {
        if count == 0 {
            return LopanBadge("", style: .error, size: size)
        } else {
            return LopanBadge.count(count, style: .error, size: size)
        }
    }
    
    /// Creates a role badge
    static func role(
        _ role: UserRole,
        size: BadgeSize = .medium
    ) -> LopanBadge {
        let (style, icon) = roleProperties(for: role)
        return LopanBadge(
            role.displayName,
            style: style,
            size: size,
            icon: icon
        )
    }
    
    // MARK: - Helper Methods
    private static func statusProperties(for status: OutOfStockStatus) -> (String, BadgeStyle, String?) {
        switch status {
        case .pending:
            return ("待处理", .warning, "clock")
        case .confirmed:
            return ("已确认", .info, "checkmark")
        case .inProduction:
            return ("生产中", .primary, "gearshape")
        case .completed:
            return ("已完成", .success, "checkmark.circle")
        case .cancelled:
            return ("已取消", .error, "xmark")
        }
    }
    
    private static func priorityProperties(for priority: Priority) -> (String, BadgeStyle, String?) {
        switch priority {
        case .low:
            return ("低", .neutral, "arrow.down")
        case .medium:
            return ("中", .info, "minus")
        case .high:
            return ("高", .warning, "arrow.up")
        case .urgent:
            return ("紧急", .error, "exclamationmark")
        }
    }
    
    private static func roleProperties(for role: UserRole) -> (BadgeStyle, String?) {
        switch role {
        case .administrator:
            return (.primary, "crown")
        case .salesperson:
            return (.info, "person.badge.plus")
        case .warehouseKeeper:
            return (.warning, "building.2")
        case .workshopManager:
            return (.success, "gearshape.2")
        case .evaGranulationTechnician:
            return (.secondary, "drop")
        case .workshopTechnician:
            return (.neutral, "wrench")
        case .unauthorized:
            return (.error, "exclamationmark.triangle")
        }
    }
}

// MARK: - Priority and Status Enums (if not already defined)
enum Priority: CaseIterable {
    case low
    case medium
    case high
    case urgent
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: LopanSpacing.lg) {
            // Style variations
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Text("Badge Styles")
                    .font(LopanTypography.titleMedium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: LopanSpacing.sm) {
                    LopanBadge("Primary", style: .primary)
                    LopanBadge("Success", style: .success, icon: "checkmark")
                    LopanBadge("Warning", style: .warning, icon: "exclamationmark.triangle")
                    LopanBadge("Error", style: .error, icon: "xmark")
                    LopanBadge("Info", style: .info, icon: "info.circle")
                    LopanBadge("Outline", style: .outline)
                }
            }
            
            // Size variations
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Text("Badge Sizes")
                    .font(LopanTypography.titleMedium)
                
                HStack(spacing: LopanSpacing.md) {
                    LopanBadge("Small", style: .primary, size: .small)
                    LopanBadge("Medium", style: .primary, size: .medium)
                    LopanBadge("Large", style: .primary, size: .large)
                }
            }
            
            // Status badges
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Text("Status Badges")
                    .font(LopanTypography.titleMedium)
                
                HStack(spacing: LopanSpacing.sm) {
                    LopanBadge.status(.pending)
                    LopanBadge.status(.inProduction)
                    LopanBadge.status(.completed)
                }
            }
            
            // Count badges
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Text("Count Badges")
                    .font(LopanTypography.titleMedium)
                
                HStack(spacing: LopanSpacing.sm) {
                    LopanBadge.count(5)
                    LopanBadge.count(23)
                    LopanBadge.count(150)
                    LopanBadge.notification(3)
                }
            }
        }
        .padding()
    }
}