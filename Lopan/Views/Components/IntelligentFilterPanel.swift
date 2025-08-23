//
//  IntelligentFilterPanel.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//  AI-powered intelligent filter system
//

import SwiftUI

// MARK: - Filter Panel State

@MainActor
class IntelligentFilterState: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCustomer: Customer?
    @Published var selectedProduct: Product?
    @Published var selectedStatus: OutOfStockStatus?
    @Published var selectedDateRange: DateRangeOption?
    @Published var customStartDate = Date()
    @Published var customEndDate = Date()
    
    // AI Suggestions
    @Published var searchSuggestions: [FilterSuggestion] = []
    @Published var quickFilters: [QuickFilter] = []
    @Published var isLoadingSuggestions = false
    
    // Preview
    @Published var previewCount = 0
    @Published var previewLoading = false
    
    var hasActiveFilters: Bool {
        selectedCustomer != nil || 
        selectedProduct != nil || 
        selectedStatus != nil || 
        selectedDateRange != nil ||
        !searchText.isEmpty
    }
    
    var activeFilterCount: Int {
        var count = 0
        if selectedCustomer != nil { count += 1 }
        if selectedProduct != nil { count += 1 }
        if selectedStatus != nil { count += 1 }
        if selectedDateRange != nil { count += 1 }
        if !searchText.isEmpty { count += 1 }
        return count
    }
}

// MARK: - Supporting Models

struct FilterSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let confidence: Double
    
    enum SuggestionType {
        case customer, product, address, keyword
        
        var icon: String {
            switch self {
            case .customer: return "person.fill"
            case .product: return "cube.fill"
            case .address: return "location.fill"
            case .keyword: return "magnifyingglass"
            }
        }
        
        var color: Color {
            switch self {
            case .customer: return .blue
            case .product: return .green
            case .address: return .orange
            case .keyword: return .purple
            }
        }
    }
}

struct QuickFilter: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let action: FilterAction
    
    enum FilterAction {
        case todayPending
        case thisWeekCompleted
        case topCustomers
        case recentReturns
        case urgentItems
    }
}

enum DateRangeOption: CaseIterable {
    case today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth, custom
    
    var title: String {
        switch self {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .thisWeek: return "本周"
        case .lastWeek: return "上周"
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .custom: return "自定义"
        }
    }
    
    var dateRange: (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            return (calendar.startOfDay(for: now), calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            return (calendar.startOfDay(for: yesterday), calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: yesterday))!)
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
        case .lastWeek:
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            let startOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
        case .custom:
            return (now, now) // Will be overridden by custom dates
        }
    }
}

// MARK: - Main Filter Panel

struct IntelligentFilterPanel: View {
    @StateObject private var filterState = IntelligentFilterState()
    @Environment(\.dismiss) private var dismiss
    
    @Binding var filters: OutOfStockFilters
    @Binding var searchText: String
    let onApply: () -> Void
    
    @State private var showingCustomDatePicker = false
    @State private var animationOffset: CGFloat = 300
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    aiSearchSection
                    quickFiltersSection
                    detailedFiltersSection
                    previewSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .offset(y: animationOffset)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animationOffset = 0
                }
                loadAISuggestions()
                generateQuickFilters()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("智能筛选")
                    .font(.title)
                    .fontWeight(.bold)
                
                if filterState.hasActiveFilters {
                    Text("\(filterState.activeFilterCount) 个活跃筛选")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("取消") {
                dismiss()
            }
            .foregroundColor(.blue)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - AI Search Section
    
    private var aiSearchSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Text("AI 智能搜索")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            // Smart search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("输入任意关键词，AI 会为您智能匹配...", text: $filterState.searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: filterState.searchText) { _ in
                        updateAISuggestions()
                    }
                
                if filterState.isLoadingSuggestions {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            
            // AI Suggestions
            if !filterState.searchSuggestions.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(filterState.searchSuggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion) {
                            applySuggestion(suggestion)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Quick Filters Section
    
    private var quickFiltersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text("快速筛选")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(filterState.quickFilters) { quickFilter in
                    QuickFilterCard(filter: quickFilter) {
                        applyQuickFilter(quickFilter)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Detailed Filters Section
    
    private var detailedFiltersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("精细筛选")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 16) {
                // Status Filter
                FilterSection(title: "状态筛选", icon: "flag.fill") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(OutOfStockStatus.allCases, id: \.self) { status in
                            StatusFilterButton(
                                status: status,
                                isSelected: filterState.selectedStatus == status
                            ) {
                                filterState.selectedStatus = filterState.selectedStatus == status ? nil : status
                                updatePreview()
                            }
                        }
                    }
                }
                
                Divider()
                
                // Date Range Filter
                FilterSection(title: "日期筛选", icon: "calendar.circle.fill") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(DateRangeOption.allCases, id: \.self) { option in
                            DateRangeButton(
                                option: option,
                                isSelected: filterState.selectedDateRange == option
                            ) {
                                if option == .custom {
                                    showingCustomDatePicker = true
                                } else {
                                    filterState.selectedDateRange = filterState.selectedDateRange == option ? nil : option
                                    updatePreview()
                                }
                            }
                        }
                    }
                }
                
                if filterState.selectedDateRange == .custom {
                    CustomDateRangePicker(
                        startDate: $filterState.customStartDate,
                        endDate: $filterState.customEndDate,
                        onChange: updatePreview
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                Divider()
                
                // Customer Filter (placeholder)
                FilterSection(title: "客户筛选", icon: "person.circle.fill") {
                    Button(action: selectCustomer) {
                        HStack {
                            Text(filterState.selectedCustomer?.name ?? "选择客户")
                                .foregroundColor(filterState.selectedCustomer != nil ? .primary : .secondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
                
                // Product Filter (placeholder)
                FilterSection(title: "产品筛选", icon: "cube.fill") {
                    Button(action: selectProduct) {
                        HStack {
                            Text(filterState.selectedProduct?.name ?? "选择产品")
                                .foregroundColor(filterState.selectedProduct != nil ? .primary : .secondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("筛选预览")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if filterState.previewLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(filterState.previewCount) 条记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                        )
                }
            }
            
            HStack(spacing: 12) {
                Button("清除全部") {
                    clearAllFilters()
                }
                .buttonStyle(.bordered)
                .disabled(!filterState.hasActiveFilters)
                
                Button("应用筛选 (\(filterState.previewCount))") {
                    applyFilters()
                }
                .buttonStyle(.borderedProminent)
                .disabled(filterState.previewCount == 0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadAISuggestions() {
        filterState.isLoadingSuggestions = true
        
        // Simulate AI suggestions loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            filterState.searchSuggestions = [
                FilterSuggestion(text: "张三", type: .customer, confidence: 0.95),
                FilterSuggestion(text: "运动鞋", type: .product, confidence: 0.88),
                FilterSuggestion(text: "北京", type: .address, confidence: 0.82),
                FilterSuggestion(text: "急需处理", type: .keyword, confidence: 0.76)
            ]
            filterState.isLoadingSuggestions = false
        }
    }
    
    private func generateQuickFilters() {
        filterState.quickFilters = [
            QuickFilter(title: "今日待处理", description: "今天需要处理的记录", icon: "clock.fill", action: .todayPending),
            QuickFilter(title: "本周已完成", description: "本周完成的记录", icon: "checkmark.circle.fill", action: .thisWeekCompleted),
            QuickFilter(title: "重要客户", description: "VIP客户的记录", icon: "star.fill", action: .topCustomers),
            QuickFilter(title: "最近退货", description: "近期退货记录", icon: "arrow.uturn.left.circle.fill", action: .recentReturns)
        ]
    }
    
    private func updateAISuggestions() {
        guard !filterState.searchText.isEmpty else {
            filterState.searchSuggestions = []
            return
        }
        
        filterState.isLoadingSuggestions = true
        
        // Simulate AI-powered suggestion update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // This would normally call an AI service
            filterState.isLoadingSuggestions = false
            updatePreview()
        }
    }
    
    private func applySuggestion(_ suggestion: FilterSuggestion) {
        switch suggestion.type {
        case .customer:
            // Would find and select the customer
            filterState.searchText = suggestion.text
        case .product:
            // Would find and select the product
            filterState.searchText = suggestion.text
        case .address, .keyword:
            filterState.searchText = suggestion.text
        }
        
        updatePreview()
    }
    
    private func applyQuickFilter(_ quickFilter: QuickFilter) {
        switch quickFilter.action {
        case .todayPending:
            filterState.selectedDateRange = .today
            filterState.selectedStatus = .pending
        case .thisWeekCompleted:
            filterState.selectedDateRange = .thisWeek
            filterState.selectedStatus = .completed
        case .topCustomers:
            // Would apply top customers filter
            break
        case .recentReturns:
            filterState.selectedDateRange = .thisWeek
            // Would apply return filter
            break
        case .urgentItems:
            filterState.selectedStatus = .pending
            // Would apply urgency filter
            break
        }
        
        updatePreview()
    }
    
    private func updatePreview() {
        filterState.previewLoading = true
        
        // Simulate preview calculation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // This would calculate the actual count based on current filters
            filterState.previewCount = Int.random(in: 1...1000)
            filterState.previewLoading = false
        }
    }
    
    private func clearAllFilters() {
        withAnimation(.easeInOut(duration: 0.3)) {
            filterState.searchText = ""
            filterState.selectedCustomer = nil
            filterState.selectedProduct = nil
            filterState.selectedStatus = nil
            filterState.selectedDateRange = nil
        }
        updatePreview()
    }
    
    private func applyFilters() {
        // Apply filters to the parent view
        searchText = filterState.searchText
        
        // Convert filter state to parent filter model
        // This is a simplified version - production code would do proper conversion
        
        dismiss()
        onApply()
    }
    
    private func selectCustomer() {
        // Show customer selection sheet
        print("Select customer")
    }
    
    private func selectProduct() {
        // Show product selection sheet
        print("Select product")
    }
}

// MARK: - Supporting Views

private struct SuggestionCard: View {
    let suggestion: FilterSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: suggestion.type.icon)
                    .font(.caption)
                    .foregroundColor(suggestion.type.color)
                
                Text(suggestion.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(suggestion.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(suggestion.type.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(suggestion.type.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

private struct QuickFilterCard: View {
    let filter: QuickFilter
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: filter.icon)
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(filter.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(filter.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(height: 80)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

private struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            content
        }
    }
}

private struct StatusFilterButton: View {
    let status: OutOfStockStatus
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(status.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? statusColor(status) : Color(.systemGray6))
                )
        }
    }
    
    private func statusColor(_ status: OutOfStockStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

private struct DateRangeButton: View {
    let option: DateRangeOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(option.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
        }
    }
}

private struct CustomDateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onChange: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("开始日期")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: startDate) { _ in onChange() }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("结束日期")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: endDate) { _ in onChange() }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

#Preview {
    @State var filters = OutOfStockFilters()
    @State var searchText = ""
    
    return IntelligentFilterPanel(
        filters: $filters,
        searchText: $searchText,
        onApply: {}
    )
}