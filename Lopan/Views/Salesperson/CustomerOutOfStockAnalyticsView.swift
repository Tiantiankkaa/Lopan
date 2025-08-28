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
                    recentItemsView
                }
                .padding(.vertical)
            }
            .navigationTitle("缺货分析")
            .navigationBarTitleDisplayMode(.inline)
            .adaptiveBackground()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("缺货分析界面")
            .accessibilityHint("包含时间范围选择、汇总数据、状态分布的分析界面")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ExportButton(data: filteredItems, buttonText: "导出", systemImage: "square.and.arrow.up")
                        .buttonStyle(.bordered)
                        .accessibilityLabel("导出分析数据")
                }
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
        .accessibilityLabel("选择时间范围")
        .accessibilityHint("选择要分析的时间范围：本周、本月、本季度或本年")
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
            .padding(.horizontal)
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
                            Text(item.customerDisplayName)
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
        case .completed:
            return .green
        case .returned:
            return .red
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
                .dynamicTypeSize(.small...DynamicTypeSize.accessibility1)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .dynamicTypeSize(.small...DynamicTypeSize.accessibility1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    CustomerOutOfStockAnalyticsView()
        .modelContainer(for: CustomerOutOfStock.self, inMemory: true)
} 