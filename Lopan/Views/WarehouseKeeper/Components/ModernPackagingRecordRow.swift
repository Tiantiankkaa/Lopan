//
//  ModernPackagingRecordRow.swift
//  Lopan
//
//  Created by Claude on 2025/8/31.
//

import SwiftUI
import SwiftData

/// Modern packaging record row with enhanced visual design and interactions
/// Following iOS 17+ design patterns with glass morphism and micro-interactions
struct ModernPackagingRecordRow: View {
    let record: PackagingRecord
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var isAnimated = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LopanSpacing.md) {
                // Leading icon with status indicator
                leadingIconView
                
                // Main content
                VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                    // Style info with badge
                    HStack(spacing: LopanSpacing.sm) {
                        Text(record.styleName)
                            .font(LopanTypography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(LopanColors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Style code badge
                        Text(record.styleCode)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(LopanColors.roleWarehouseKeeper)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(LopanColors.roleWarehouseKeeper.opacity(0.15))
                            )
                    }
                    
                    // Team and quantity info
                    HStack(spacing: LopanSpacing.sm) {
                        // Team info
                        HStack(spacing: LopanSpacing.xs) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(LopanColors.textSecondary)
                            
                            Text(record.teamName)
                                .font(LopanTypography.bodySmall)
                                .foregroundStyle(LopanColors.textSecondary)
                        }
                        
                        // Separator
                        Circle()
                            .fill(LopanColors.textSecondary)
                            .frame(width: 2, height: 2)
                        
                        // Quantity info
                        Text("\(record.totalPackages)包/\(record.totalItems)件")
                            .font(LopanTypography.bodySmall)
                            .foregroundStyle(LopanColors.textSecondary)
                        
                        Spacer()
                        
                        // Time stamp
                        Text(timeDisplayString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(LopanColors.textTertiary)
                    }
                }
                
                // Trailing chevron with animation
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LopanColors.textTertiary)
                    .rotationEffect(.degrees(isPressed ? 90 : 0))
                    .animation(.bouncy(duration: 0.3), value: isPressed)
            }
            .padding(LopanSpacing.md)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LopanCornerRadius.card))
            .scaleEffect(isPressed ? 0.98 : (isAnimated ? 1.0 : 0.95))
            .lopanShadow(isPressed ? LopanShadows.cardPressed : LopanShadows.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(LopanAnimation.cardHover) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            withAnimation(.bouncy(duration: 0.6).delay(Double.random(in: 0...0.2))) {
                isAnimated = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("点击查看详情")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Leading Icon View
    
    private var leadingIconView: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            LopanColors.roleWarehouseKeeper.opacity(0.15),
                            LopanColors.roleWarehouseKeeper.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
            
            // Main icon
            Image(systemName: "cube.box.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(LopanColors.roleWarehouseKeeper)
            
            // Status indicator (if needed)
            if record.isHighPriority {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(LopanColors.warning)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Card Background
    
    private var cardBackground: some View {
        ZStack {
            // Main background
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .fill(LopanColors.surface)
            
            // Subtle gradient overlay
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            LopanColors.roleWarehouseKeeper.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Border
            RoundedRectangle(cornerRadius: LopanCornerRadius.card)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            LopanColors.border.opacity(0.3),
                            LopanColors.border.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    // MARK: - Computed Properties
    
    private var timeDisplayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(record.packageDate) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: record.packageDate)
        } else {
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: record.packageDate)
        }
    }
    
    private var accessibilityLabel: String {
        return "包装记录: \(record.styleName)，编号 \(record.styleCode)，团队 \(record.teamName)，\(record.totalPackages)包\(record.totalItems)件"
    }
}

// MARK: - PackagingRecord Extension for UI

extension PackagingRecord {
    /// Determines if this record should be marked as high priority
    /// This could be based on business rules like large quantities, urgent orders, etc.
    var isHighPriority: Bool {
        // Example logic - could be customized based on business requirements
        return totalItems > 1000 || totalPackages > 50
    }
    
    /// Returns a color representing the record's status or priority
    var statusColor: Color {
        if isHighPriority {
            return LopanColors.warning
        }
        return LopanColors.success
    }
    
    /// Returns a formatted string for the packaging quantities
    var quantityDisplayString: String {
        return "\(totalPackages)包 / \(totalItems)件"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: LopanSpacing.sm) {
        // Sample records for preview
        ModernPackagingRecordRow(
            record: PackagingRecord(
                packageDate: Date(),
                teamId: "team-a",
                teamName: "包装A组",
                styleCode: "SK001",
                styleName: "休闲运动鞋",
                totalPackages: 25,
                stylesPerPackage: 10,
                createdBy: "user1"
            )
        ) {
            print("Tapped record 1")
        }
        
        ModernPackagingRecordRow(
            record: PackagingRecord(
                packageDate: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                teamId: "team-b",
                teamName: "包装B组",
                styleCode: "BL002",
                styleName: "商务皮鞋高端款",
                totalPackages: 65,
                stylesPerPackage: 20,
                createdBy: "user2"
            )
        ) {
            print("Tapped record 2")
        }
        
        ModernPackagingRecordRow(
            record: PackagingRecord(
                packageDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                teamId: "team-c",
                teamName: "包装C组",
                styleCode: "KD003",
                styleName: "儿童凉鞋",
                totalPackages: 12,
                stylesPerPackage: 10,
                createdBy: "user3"
            )
        ) {
            print("Tapped record 3")
        }
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
}