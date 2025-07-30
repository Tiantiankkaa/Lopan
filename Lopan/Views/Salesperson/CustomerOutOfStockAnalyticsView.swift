//
//  CustomerOutOfStockAnalyticsView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct CustomerOutOfStockAnalyticsView: View {
    @Query private var outOfStockItems: [CustomerOutOfStock]
    @State private var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case week = "week"
        case month = "month"
        case quarter = "quarter"
        case year = "year"
        
        var displayName: String {
            switch self {
            case .week:
                return "本周"
            case .month:
                return "本月"
            case .quarter:
                return "本季度"
            case .year:
                return "本年"
            }
        }
    }
    
    var filteredItems: [CustomerOutOfStock] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch selectedTimeRange {
        case .week:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .month:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .quarter:
            let quarter = (calendar.component(.month, from: now) - 1) / 3
            startDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: quarter * 3 + 1)) ?? now
        case .year:
            startDate = calendar.dateInterval(of: .year, for: now)?.start ?? now
        }
        
        return outOfStockItems.filter { $0.requestDate >= startDate }
    }
    
    var statusCounts: [OutOfStockStatus: Int] {
        Dictionary(grouping: filteredItems, by: { $0.status })
            .mapValues { $0.count }
    }
    
    var priorityCounts: [OutOfStockPriority: Int] {
        Dictionary(grouping: filteredItems, by: { $0.priority })
            .mapValues { $0.count }
    }
    
    var totalItems: Int {
        filteredItems.count
    }
    
    var completedItems: Int {
        filteredItems.filter { $0.status == .completed }.count
    }
    
    var pendingItems: Int {
        filteredItems.filter { $0.status == .pending }.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    timeRangeSelector
                    summaryCardsView
                    statusDistributionView
                    priorityDistributionView
                    recentItemsView
                }
                .padding(.vertical)
            }
            .navigationTitle("缺货分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
            }
        }
    }
    
    private var timeRangeSelector: some View {
        Picker("时间范围", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private var summaryCardsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            AnalyticsCard(
                title: "总缺货记录",
                value: "\(totalItems)",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )
            
            AnalyticsCard(
                title: "已完成",
                value: "\(completedItems)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            AnalyticsCard(
                title: "待处理",
                value: "\(pendingItems)",
                icon: "clock.fill",
                color: .blue
            )
            
            AnalyticsCard(
                title: "完成率",
                value: totalItems > 0 ? "\(Int((Double(completedItems) / Double(totalItems)) * 100))%" : "0%",
                icon: "percent",
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    private var statusDistributionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("状态分布")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(OutOfStockStatus.allCases, id: \.self) { status in
                    let count = statusCounts[status] ?? 0
                    if count > 0 {
                        HStack {
                            Text(status.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("(\(totalItems > 0 ? Int((Double(count) / Double(totalItems)) * 100) : 0)%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(statusColor(status).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var priorityDistributionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("优先级分布")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(OutOfStockPriority.allCases, id: \.self) { priority in
                    let count = priorityCounts[priority] ?? 0
                    if count > 0 {
                        HStack {
                            Text(priority.displayName)
                                .font(.subheadline)
                                .foregroundColor(priorityColor(priority))
                            
                            Spacer()
                            
                            Text("\(count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("(\(totalItems > 0 ? Int((Double(count) / Double(totalItems)) * 100) : 0)%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(priorityColor(priority).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var recentItemsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近缺货记录")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(Array(filteredItems.prefix(5)), id: \.id) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.customer?.name ?? "")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(item.product?.name ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(item.status.displayName)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusColor(item.status).opacity(0.2))
                                .foregroundColor(statusColor(item.status))
                                .cornerRadius(4)
                            Text(item.requestDate, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func statusColor(_ status: OutOfStockStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .confirmed:
            return .blue
        case .inProduction:
            return .purple
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    private func priorityColor(_ priority: OutOfStockPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}

struct AnalyticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    CustomerOutOfStockAnalyticsView()
        .modelContainer(for: CustomerOutOfStock.self, inMemory: true)
} 