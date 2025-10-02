//
//  CustomerOutOfStockAnalyticsView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct CustomerOutOfStockAnalyticsView: View {
    @Query(
        sort: [SortDescriptor(\CustomerOutOfStock.requestDate, order: .reverse)]
    ) private var outOfStockItems: [CustomerOutOfStock]
    @State private var selectedTimeRange: TimeRange = .week
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    enum TimeRange: String, CaseIterable {
        case week, month, quarter, year
        
        var titleKey: LocalizedStringKey {
            LocalizedStringKey("analytics_time_range_\(rawValue)")
        }
        
        func startDate(from date: Date, calendar: Calendar) -> Date {
            switch self {
            case .week:
                return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            case .month:
                return calendar.dateInterval(of: .month, for: date)?.start ?? date
            case .quarter:
                let quarter = (calendar.component(.month, from: date) - 1) / 3
                let month = quarter * 3 + 1
                return calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: month)) ?? date
            case .year:
                return calendar.dateInterval(of: .year, for: date)?.start ?? date
            }
        }
    }
    
    private var filteredItems: [CustomerOutOfStock] {
        let calendar = Calendar.current
        let startDate = selectedTimeRange.startDate(from: Date(), calendar: calendar)
        return outOfStockItems.filter { $0.requestDate >= startDate }
    }
    
    private var statusCounts: [OutOfStockStatus: Int] {
        Dictionary(grouping: filteredItems, by: { $0.status })
            .mapValues { $0.count }
    }
    
    private var totalItems: Int { filteredItems.count }
    private var completedItems: Int { filteredItems.filter { $0.status == .completed }.count }
    private var pendingItems: Int { filteredItems.filter { $0.status == .pending }.count }
    
    private var completionRate: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }
    
    private var recentItems: [CustomerOutOfStock] {
        Array(filteredItems.sorted { $0.requestDate > $1.requestDate }.prefix(5))
    }
    
    private var statusOverview: [(status: OutOfStockStatus, count: Int)] {
        OutOfStockStatus.allCases.map { status in
            (status, statusCounts[status] ?? 0)
        }
    }
    
    private var percentageFormat: FloatingPointFormatStyle<Double>.Percent {
        .percent.precision(.fractionLength(0))
    }
    
    private var requestDateFormat: Date.FormatStyle {
        Date.FormatStyle.dateTime
            .year()
            .month()
            .day()
            .weekday(.wide)
    }
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: LopanSpacing.gridSpacing),
            GridItem(.flexible(), spacing: LopanSpacing.gridSpacing)
        ]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LopanSpacing.contentSpacing) {
                    timeRangeSelector
                    summaryCardsView
                    statusDistributionView
                    recentItemsView
                }
                .padding(.horizontal, LopanSpacing.screenPadding)
                .padding(.vertical, LopanSpacing.lg)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                // PHASE 1 OPTIMIZATION: Enable scroll optimization for analytics data
                LopanScrollOptimizer.shared.startOptimization()
            }
            .onDisappear {
                // PHASE 1 OPTIMIZATION: Stop scroll optimization when view disappears
                LopanScrollOptimizer.shared.stopOptimization()
            }
            .navigationTitle("out_of_stock_analytics".localized)
            .navigationBarTitleDisplayMode(.inline)
            .background(LopanColors.backgroundPrimary.ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("analytics_screen_accessibility_label".localized)
            .accessibilityHint("analytics_screen_accessibility_hint".localized)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ExportButton(
                        data: filteredItems,
                        buttonText: "export".localized,
                        systemImage: "square.and.arrow.up"
                    )
                    .buttonStyle(.bordered)
                    .accessibilityLabel("analytics_export_accessibility_label".localized)
                }
            }
        }
    }
    
    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            Text("analytics_time_range_title".localized)
                .font(.headline)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            Picker("analytics_time_range_title".localized, selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.titleKey).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("analytics_time_range_accessibility_hint".localized)
        }
        .accessibilityElement(children: .combine)
    }
    
    private var summaryCardsView: some View {
        LazyVGrid(columns: gridColumns, spacing: LopanSpacing.gridSpacing) {
            AnalyticsCard(
                titleKey: "analytics_card_total_records",
                displayValue: totalItems.formatted(),
                numericValue: Double(totalItems),
                icon: "exclamationmark.triangle.fill",
                tint: LopanColors.warning,
                reduceMotion: reduceMotion
            )
            
            AnalyticsCard(
                titleKey: "analytics_card_completed_records",
                displayValue: completedItems.formatted(),
                numericValue: Double(completedItems),
                icon: "checkmark.circle.fill",
                tint: LopanColors.success,
                reduceMotion: reduceMotion
            )
            
            AnalyticsCard(
                titleKey: "analytics_card_pending_records",
                displayValue: pendingItems.formatted(),
                numericValue: Double(pendingItems),
                icon: "clock.fill",
                tint: LopanColors.info,
                reduceMotion: reduceMotion
            )
            
            AnalyticsCard(
                titleKey: "analytics_card_completion_rate",
                displayValue: completionRate.formatted(percentageFormat),
                numericValue: completionRate,
                icon: "percent",
                tint: LopanColors.accent,
                reduceMotion: reduceMotion
            )
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: selectedTimeRange)
    }
    
    private var statusDistributionView: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Text("analytics_status_distribution_title".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                
                ForEach(statusOverview, id: \.status) { status, count in
                    AnalyticsStatusRow(
                        title: localizedStatusName(status),
                        count: count,
                        total: totalItems,
                        tint: statusTint(for: status),
                        percentageText: percentageText(for: count),
                        reduceMotion: reduceMotion
                    )
                }
            }
        }
    }
    
    private var recentItemsView: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Text("analytics_recent_records_title".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                
                if recentItems.isEmpty {
                    Text("analytics_recent_records_empty".localized)
                        .font(.footnote)
                        .foregroundColor(LopanColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: LopanSpacing.sm) {
                        ForEach(recentItems, id: \.id) { item in
                            AnalyticsRecentRow(
                                item: item,
                                statusName: localizedStatusName(item.status),
                                statusTint: statusTint(for: item.status),
                                dateFormat: requestDateFormat
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func localizedStatusName(_ status: OutOfStockStatus) -> String {
        switch status {
        case .pending:
            return "out_of_stock_status_pending".localized
        case .completed:
            return "out_of_stock_status_completed".localized
        case .refunded:
            return "out_of_stock_status_returned".localized
        }
    }
    
    private func statusTint(for status: OutOfStockStatus) -> Color {
        switch status {
        case .pending:
            return LopanColors.warning
        case .completed:
            return LopanColors.success
        case .refunded:
            return LopanColors.error
        }
    }
    
    private func percentageText(for count: Int) -> String {
        guard totalItems > 0 else {
            return Double.zero.formatted(percentageFormat)
        }
        let ratio = Double(count) / Double(totalItems)
        return ratio.formatted(percentageFormat)
    }
}

private struct AnalyticsCard: View {
    let titleKey: String
    let displayValue: String
    let numericValue: Double?
    let icon: String
    let tint: Color
    let reduceMotion: Bool
    
    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 28
    
    var body: some View {
        AnalyticsSurface {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                
                valueView
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(LocalizedStringKey(titleKey))
                    .font(.footnote)
                    .foregroundColor(LopanColors.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
            .accessibilityValue(Text(displayValue))
        }
    }
    
    @ViewBuilder
    private var valueView: some View {
        if let numericValue {
            if #available(iOS 17.0, *) {
                Text(displayValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .contentTransition(.numericText(value: numericValue))
                    .transaction { transaction in
                        transaction.animation = reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)
                    }
            } else {
                Text(displayValue)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        } else {
            Text(displayValue)
                .font(.title2)
                .fontWeight(.bold)
        }
    }
}

private struct AnalyticsStatusRow: View {
    let title: String
    let count: Int
    let total: Int
    let tint: Color
    let percentageText: String
    let reduceMotion: Bool
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: LopanSpacing.xs) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: LopanSpacing.sm)
                
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(LopanColors.textPrimary)
                    .accessibilityLabel(Text("analytics_status_count_accessibility_label".localized(with: title)))
                
                Text(percentageText)
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(tint)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: progress)
        }
        .padding(.vertical, LopanSpacing.xs)
        .padding(.horizontal, LopanSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.container, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("analytics_status_row_accessibility_value".localized(with: count, percentageText)))
    }
}

private struct AnalyticsRecentRow: View {
    let item: CustomerOutOfStock
    let statusName: String
    let statusTint: Color
    let dateFormat: Date.FormatStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.customerDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: LopanSpacing.sm)
                
                Text(statusName)
                    .font(.caption)
                    .foregroundColor(statusTint)
                    .padding(.horizontal, LopanSpacing.xs)
                    .padding(.vertical, LopanSpacing.xxxs)
                    .background(statusTint.opacity(0.1))
                    .clipShape(Capsule())
                    .accessibilityLabel(Text("analytics_recent_status_accessibility_label".localized(with: statusName)))
            }
            
            Text(item.product?.name ?? "analytics_recent_record_unknown_product".localized)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            Text(item.requestDate, format: dateFormat)
                .font(.caption2)
                .foregroundColor(LopanColors.textTertiary)
        }
        .padding(.vertical, LopanSpacing.xs)
        .padding(.horizontal, LopanSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.container, style: .continuous)
                .fill(LopanColors.backgroundSecondary.opacity(0.8))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("analytics_recent_record_accessibility_label".localized(with: item.customerDisplayName)))
        .accessibilityValue(Text("analytics_recent_record_accessibility_value".localized(with: statusName)))
    }
}

#Preview {
    CustomerOutOfStockAnalyticsView()
        .modelContainer(for: CustomerOutOfStock.self, inMemory: true)
}
