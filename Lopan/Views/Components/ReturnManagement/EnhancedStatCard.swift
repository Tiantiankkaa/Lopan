//
//  EnhancedStatCard.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/18.
//

import SwiftUI

struct EnhancedStatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    let subtitle: String?
    
    init(title: String, count: Int, color: Color, icon: String, subtitle: String? = nil) {
        self.title = title
        self.count = count
        self.color = color
        self.icon = icon
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 20, height: 20)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.background)
                .shadow(color: color.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(count)")
        .accessibilityHint(subtitle != nil ? subtitle! : "")
    }
}

struct StatisticsOverviewCard: View {
    let needsDeliveryCount: Int
    let partialDeliveryCount: Int
    let completedDeliveryCount: Int
    let lastUpdated: Date

    var totalItems: Int {
        needsDeliveryCount + partialDeliveryCount + completedDeliveryCount
    }

    var completionRate: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedDeliveryCount) / Double(totalItems)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("还货概况")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("完成率 \(Int(completionRate * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("最近更新")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(lastUpdated.formatted(.dateTime.hour().minute()))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress Bar
            if totalItems > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("总进度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(completedDeliveryCount)/\(totalItems)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    ProgressView(value: completionRate)
                        .progressViewStyle(LinearProgressViewStyle(tint: LopanColors.success))
                        .scaleEffect(y: 2)
                }
            }

            // Statistics Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                EnhancedStatCard(
                    title: "待还货",
                    count: needsDeliveryCount,
                    color: LopanColors.warning,
                    icon: "exclamationmark.triangle.fill"
                )

                EnhancedStatCard(
                    title: "部分还货",
                    count: partialDeliveryCount,
                    color: LopanColors.info,
                    icon: "clock.fill"
                )

                EnhancedStatCard(
                    title: "已完成",
                    count: completedDeliveryCount,
                    color: LopanColors.success,
                    icon: "checkmark.circle.fill"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.background)
                .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("还货统计概览")
        .accessibilityValue("总共\(totalItems)项，已完成\(completedDeliveryCount)项，完成率\(Int(completionRate * 100))%")
    }
}

#Preview {
    VStack(spacing: 20) {
        EnhancedStatCard(
            title: "待还货",
            count: 15,
            color: LopanColors.warning,
            icon: "exclamationmark.triangle.fill",
            subtitle: "优先处理"
        )
        
        StatisticsOverviewCard(
            needsDeliveryCount: 15,
            partialDeliveryCount: 8,
            completedDeliveryCount: 23,
            lastUpdated: Date()
        )
    }
    .padding()
    .background(LopanColors.backgroundSecondary)
}
