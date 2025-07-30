//
//  HistoricalBacktrackingView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import SwiftUI
import SwiftData

struct HistoricalBacktrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAuditLogs: [AuditLog]
    
    @State private var searchText = ""
    @State private var selectedOperationType: OperationType? = nil
    @State private var selectedEntityType: EntityType? = nil
    @State private var selectedUserId: String? = nil
    @State private var dateRange: DateRange = .week
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var showingFilters = false
    @State private var showingOperationDetail: AuditLog? = nil
    
    enum DateRange: String, CaseIterable {
        case today = "today"
        case week = "week"
        case month = "month"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .today:
                return "今天"
            case .week:
                return "最近一周"
            case .month:
                return "最近一月"
            case .custom:
                return "自定义"
            }
        }
    }
    
    private var filteredAuditLogs: [AuditLog] {
        var logs = allAuditLogs
        
        // Date range filtering
        let calendar = Calendar.current
        let filterStartDate: Date
        let filterEndDate = endDate
        
        switch dateRange {
        case .today:
            filterStartDate = calendar.startOfDay(for: Date())
        case .week:
            filterStartDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            filterStartDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .custom:
            filterStartDate = startDate
        }
        
        logs = logs.filter { log in
            log.operationTimestamp >= filterStartDate && log.operationTimestamp <= filterEndDate
        }
        
        // Operation type filtering
        if let selectedOperationType = selectedOperationType {
            logs = logs.filter { $0.operationType == selectedOperationType }
        }
        
        // Entity type filtering
        if let selectedEntityType = selectedEntityType {
            logs = logs.filter { $0.entityType == selectedEntityType }
        }
        
        // User filtering
        if let selectedUserId = selectedUserId, !selectedUserId.isEmpty {
            logs = logs.filter { $0.operatorUserId == selectedUserId }
        }
        
        // Search text filtering
        if !searchText.isEmpty {
            logs = logs.filter { log in
                log.entityDescription.localizedCaseInsensitiveContains(searchText) ||
                log.operatorUserName.localizedCaseInsensitiveContains(searchText) ||
                log.operationDetails.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs.sorted { $0.operationTimestamp > $1.operationTimestamp }
    }
    
    private var uniqueUsers: [String] {
        Array(Set(allAuditLogs.map { $0.operatorUserName })).sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search and filters
                headerView
                
                // Statistics summary
                statisticsView
                
                // Audit logs list
                if filteredAuditLogs.isEmpty {
                    emptyStateView
                } else {
                    auditLogsList
                }
            }
            .navigationTitle("历史回溯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(item: $showingOperationDetail) { log in
            OperationDetailView(auditLog: log)
        }
        .sheet(isPresented: $showingFilters) {
            FiltersView(
                selectedOperationType: $selectedOperationType,
                selectedEntityType: $selectedEntityType,
                selectedUserId: $selectedUserId,
                dateRange: $dateRange,
                startDate: $startDate,
                endDate: $endDate,
                uniqueUsers: uniqueUsers
            )
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索操作记录、用户或详情", text: $searchText)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // Quick date filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Button(action: { dateRange = range }) {
                            Text(range.displayName)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(dateRange == range ? Color.blue : Color(.systemGray6))
                                .foregroundColor(dateRange == range ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
    }
    
    private var statisticsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                HistoryStatCard(
                    title: "总操作数",
                    value: "\(filteredAuditLogs.count)",
                    icon: "chart.bar.fill",
                    color: .blue
                )
                
                HistoryStatCard(
                    title: "今日操作",
                    value: "\(todayOperationsCount)",
                    icon: "calendar.badge.clock",
                    color: .orange
                )
                
                HistoryStatCard(
                    title: "活跃用户",
                    value: "\(activeUsersCount)",
                    icon: "person.3.fill",
                    color: .green
                )
                
                HistoryStatCard(
                    title: "缺货操作",
                    value: "\(outOfStockOperationsCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    private var auditLogsList: some View {
        List {
            ForEach(filteredAuditLogs, id: \.id) { log in
                AuditLogRow(log: log) {
                    showingOperationDetail = log
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("暂无操作记录")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text("在选定的时间范围内没有找到匹配的操作记录")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("重置筛选条件") {
                resetFilters()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var todayOperationsCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return filteredAuditLogs.filter { calendar.isDate($0.operationTimestamp, inSameDayAs: today) }.count
    }
    
    private var activeUsersCount: Int {
        Set(filteredAuditLogs.map { $0.operatorUserId }).count
    }
    
    private var outOfStockOperationsCount: Int {
        filteredAuditLogs.filter { $0.entityType == .customerOutOfStock }.count
    }
    
    // MARK: - Helper Methods
    
    private func resetFilters() {
        searchText = ""
        selectedOperationType = nil
        selectedEntityType = nil
        selectedUserId = nil
        dateRange = .week
        startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        endDate = Date()
    }
}

// MARK: - Audit Log Row Component
struct AuditLogRow: View {
    let log: AuditLog
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Operation icon
            ZStack {
                Circle()
                    .fill(operationColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: log.operationType.iconName)
                    .foregroundColor(operationColor)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Operation description
                HStack {
                    Text(log.operationType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(log.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Entity information
                Text(log.entityDescription)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // User and timestamp
                HStack {
                    Label(log.operatorUserName, systemImage: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label(log.entityType.displayName, systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var operationColor: Color {
        switch log.operationType.color {
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "indigo": return .indigo
        case "teal": return .teal
        default: return .gray
        }
    }
}

// MARK: - Stat Card Component
struct HistoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 120)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}

#Preview {
    let container = try! ModelContainer(for: AuditLog.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    HistoricalBacktrackingView()
        .modelContainer(container)
}