//
//  PackagingManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import SwiftUI
import SwiftData

struct PackagingManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var packagingRecords: [PackagingRecord]
    @Query private var packagingTeams: [PackagingTeam]
    @Query private var productionStyles: [ProductionStyle]
    
    @State private var selectedDate = Date()
    @State private var showingAddRecord = false
    @State private var showingEditRecord: PackagingRecord?
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var recordsToDelete: IndexSet?
    
    // Filtered records based on selected date and search text
    private var filteredRecords: [PackagingRecord] {
        let calendar = Calendar.current
        let filtered = packagingRecords.filter { record in
            calendar.isDate(record.packageDate, inSameDayAs: selectedDate)
        }
        
        if searchText.isEmpty {
            return filtered.sorted { $0.createdAt > $1.createdAt }
        } else {
            return filtered.filter { record in
                record.styleName.localizedCaseInsensitiveContains(searchText) ||
                record.styleCode.localizedCaseInsensitiveContains(searchText) ||
                record.teamName.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // Daily statistics for selected date
    private var dailyStats: PackagingDailyStats {
        let calendar = Calendar.current
        let dayRecords = packagingRecords.filter { calendar.isDate($0.packageDate, inSameDayAs: selectedDate) }
        
        let totalPackages = dayRecords.reduce(0) { $0 + $1.totalPackages }
        let totalItems = dayRecords.reduce(0) { $0 + $1.totalItems }
        
        // Team statistics
        let teamStats = Dictionary(grouping: dayRecords, by: { $0.teamName })
            .map { teamName, records in
                PackagingDailyStats.PackagingTeamStats(
                    teamName: teamName,
                    packages: records.reduce(0) { $0 + $1.totalPackages },
                    items: records.reduce(0) { $0 + $1.totalItems }
                )
            }
            .sorted { $0.teamName < $1.teamName }
        
        // Style statistics
        let styleStats = Dictionary(grouping: dayRecords, by: { $0.styleCode })
            .map { styleCode, records in
                PackagingDailyStats.PackagingStyleStats(
                    styleCode: styleCode,
                    styleName: records.first?.styleName ?? "",
                    packages: records.reduce(0) { $0 + $1.totalPackages },
                    items: records.reduce(0) { $0 + $1.totalItems }
                )
            }
            .sorted { $0.styleCode < $1.styleCode }
        
        return PackagingDailyStats(
            date: selectedDate,
            totalPackages: totalPackages,
            totalItems: totalItems,
            teamStats: teamStats,
            styleStats: styleStats
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern header with glass morphism effect
            VStack(spacing: LopanSpacing.md) {
                // Date selection with modern styling
                HStack(spacing: LopanSpacing.md) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(LopanColors.roleWarehouseKeeper)
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accentColor(LopanColors.roleWarehouseKeeper)
                    
                    Spacer()
                }
                
                // Modern statistics grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: LopanSpacing.sm) {
                    ModernStatCard(
                        title: "总包装数", 
                        value: "\(dailyStats.totalPackages)",
                        subtitle: "今日完成",
                        icon: "cube.box.fill",
                        color: LopanColors.roleWarehouseKeeper
                    )
                    
                    ModernStatCard(
                        title: "总产品数", 
                        value: "\(dailyStats.totalItems)",
                        subtitle: "产品件数",
                        icon: "shippingbox.fill",
                        color: LopanColors.success
                    )
                    
                    ModernStatCard(
                        title: "活跃团队", 
                        value: "\(dailyStats.teamStats.count)",
                        subtitle: "参与团队",
                        icon: "person.2.fill",
                        color: LopanColors.info
                    )
                    
                    ModernStatCard(
                        title: "款式种类", 
                        value: "\(dailyStats.styleStats.count)",
                        subtitle: "产品款式",
                        icon: "tag.fill",
                        color: LopanColors.warning
                    )
                }
            }
            .padding(LopanSpacing.lg)
            .background(
                LinearGradient(
                    colors: [
                        LopanColors.roleWarehouseKeeper.opacity(0.03),
                        LopanColors.surface
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Modern search bar with floating design
            VStack(spacing: LopanSpacing.md) {
                HStack(spacing: LopanSpacing.md) {
                    // Enhanced search field
                    HStack(spacing: LopanSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(LopanColors.textSecondary)
                        
                        TextField("搜索款式、团队或编号", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(LopanTypography.bodyMedium)
                    }
                    .padding(LopanSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: LopanCornerRadius.button)
                            .fill(LopanColors.surfaceElevated)
                            .shadow(color: LopanColors.textPrimary.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    
                    // Modern add button with floating design
                    Button(action: { showingAddRecord = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(LopanColors.textOnPrimary)
                    }
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        LopanColors.roleWarehouseKeeper,
                                        LopanColors.roleWarehouseKeeper.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .lopanShadow(LopanShadows.button)
                }
            }
            .padding(.horizontal, LopanSpacing.lg)
            .padding(.bottom, LopanSpacing.sm)
            
            // Content area with modern list or empty state
            if filteredRecords.isEmpty {
                emptyStateView
            } else {
                modernRecordsList
            }
        }
        .navigationTitle("包装管理")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddRecord) {
            AddPackagingRecordView(selectedDate: selectedDate)
        }
        .sheet(item: $showingEditRecord) { record in
            EditPackagingRecordView(record: record)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {
                recordsToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let offsets = recordsToDelete {
                    deleteRecords(offsets: offsets)
                }
                recordsToDelete = nil
            }
        } message: {
            Text("确定要删除选中的包装记录吗？此操作无法撤销。")
        }
    }
    
    private func confirmDelete(offsets: IndexSet) {
        recordsToDelete = offsets
        showingDeleteAlert = true
    }
    
    private func deleteRecords(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredRecords[index])
            }
        }
    }
    
    // MARK: - Modern UI Components
    
    private var emptyStateView: some View {
        VStack(spacing: LopanSpacing.lg) {
            Spacer()
            
            // Animated empty state illustration
            VStack(spacing: LopanSpacing.md) {
                ZStack {
                    Circle()
                        .fill(LopanColors.roleWarehouseKeeper.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: searchText.isEmpty ? "cube.box" : "magnifyingglass")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(LopanColors.roleWarehouseKeeper.opacity(0.6))
                        .symbolEffect(.pulse.byLayer.wholeSymbol, options: .repeating)
                }
                
                VStack(spacing: LopanSpacing.sm) {
                    Text(searchText.isEmpty ? "今日暂无包装记录" : "未找到匹配的记录")
                        .font(LopanTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(LopanColors.textPrimary)
                    
                    Text(searchText.isEmpty 
                         ? "开始添加今日的包装记录，追踪团队的工作进展" 
                         : "尝试使用其他关键词搜索，或检查搜索条件")
                        .font(LopanTypography.bodyMedium)
                        .foregroundStyle(LopanColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                if searchText.isEmpty {
                    Button(action: { showingAddRecord = true }) {
                        HStack(spacing: LopanSpacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                            Text("添加包装记录")
                                .font(LopanTypography.bodyMedium)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(LopanColors.textOnPrimary)
                        .padding(.horizontal, LopanSpacing.lg)
                        .padding(.vertical, LopanSpacing.md)
                        .background(
                            Capsule()
                                .fill(LopanColors.roleWarehouseKeeper)
                        )
                    }
                    .lopanShadow(LopanShadows.button)
                    .padding(.top, LopanSpacing.sm)
                }
            }
            
            Spacer()
        }
        .padding(LopanSpacing.lg)
    }
    
    private var modernRecordsList: some View {
        List {
            ForEach(filteredRecords, id: \.id) { record in
                ModernPackagingRecordRow(record: record) {
                    showingEditRecord = record
                }
                .listRowInsets(EdgeInsets(
                    top: LopanSpacing.xs,
                    leading: LopanSpacing.lg,
                    bottom: LopanSpacing.xs,
                    trailing: LopanSpacing.lg
                ))
                .listRowBackground(LopanColors.clear)
            }
            .onDelete(perform: confirmDelete)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(LopanColors.backgroundSecondary)
    }
}

struct PackagingStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(LopanColors.background)
        .cornerRadius(8)
    }
}

struct PackagingRecordRow: View {
    let record: PackagingRecord
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.styleName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(record.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                }
                
                Text(record.styleName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label("\(record.totalPackages) 包", systemImage: "cube.box")
                    Spacer()
                    Label("\(record.stylesPerPackage) 个/包", systemImage: "number")
                    Spacer()
                    Label(record.teamName, systemImage: "person.2")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(record.totalItems)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.primary)
                Text("总数")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var statusColor: Color {
        switch record.status {
        case .inProgress:
            return LopanColors.warning
        case .completed:
            return LopanColors.success
        case .shipped:
            return LopanColors.primary
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: PackagingRecord.self, PackagingTeam.self, ProductionStyle.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    PackagingManagementView()
        .modelContainer(container)
}