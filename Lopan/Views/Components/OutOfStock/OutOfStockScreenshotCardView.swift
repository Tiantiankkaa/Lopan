//
//  OutOfStockScreenshotCardView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct OutOfStockScreenshotCardView: View {
    let item: CustomerOutOfStock
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            cardContent
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with customer name and status
            HStack {
                Text(formatCustomerName(item.customerDisplayName))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                statusBadge
            }
            
            // Address row
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text(item.customerAddress)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Product row
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                
                Text(formatProductName(item.productDisplayName))
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            // Quantity row
            HStack(spacing: 8) {
                Image(systemName: "number")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
                Text("缺货数量: \(item.quantity)")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Bottom row with dates
            HStack(spacing: 16) {
                // Entry date
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text("录入时间: \(formattedDate(item.requestDate))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Completion date (if completed)
                if item.status == .completed, let completionDate = item.actualCompletionDate {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        
                        Text("完成: \(formattedDate(completionDate))")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(16)
    }
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
            
            Text(item.status.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor)
        .cornerRadius(16)
    }
    
    private var statusColor: Color {
        switch item.status {
        case .pending: return .orange
        case .completed: return .green
        case .returned: return .red
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }
    
    private func formatCustomerName(_ originalName: String) -> String {
        // Extract number from customer name if it follows pattern like "标准客户197"
        let pattern = "(.*?)(\\d+)$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: originalName, options: [], range: NSRange(location: 0, length: originalName.count)) {
            
            let baseNameRange = Range(match.range(at: 1), in: originalName)
            let numberRange = Range(match.range(at: 2), in: originalName)
            
            if let baseNameRange = baseNameRange, let numberRange = numberRange {
                let baseName = String(originalName[baseNameRange]).trimmingCharacters(in: .whitespaces)
                let number = String(originalName[numberRange])
                return "\(baseName) \(number)" // Add space between base name and number
            }
        }
        
        return originalName
    }
    
    private func formatProductName(_ originalName: String) -> String {
        // Format should match "性感包臀裙-XL-灰色,黄色,酒红色,红色"
        return originalName // For now, keep as is since the model already formats correctly
    }
}

#Preview {
    VStack(spacing: 16) {
        OutOfStockScreenshotCardView(
            item: CustomerOutOfStock(
                customer: nil,
                product: nil,
                quantity: 111,
                notes: nil,
                createdBy: "demo"
            ),
            isSelected: false,
            isInSelectionMode: false,
            onTap: {},
            onLongPress: {}
        )
        
        OutOfStockScreenshotCardView(
            item: CustomerOutOfStock(
                customer: nil,
                product: nil,
                quantity: 26,
                notes: nil,
                createdBy: "demo"
            ),
            isSelected: false,
            isInSelectionMode: false,
            onTap: {},
            onLongPress: {}
        )
    }
    .padding()
}