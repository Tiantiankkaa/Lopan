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
        NavigationView {
            VStack(spacing: 0) {
                // Date picker and statistics header
                VStack(spacing: 16) {
                    DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .frame(maxWidth: .infinity)
                    
                    // Daily statistics cards
                    HStack(spacing: 16) {
                        PackagingStatCard(title: "总包装数", value: "\(dailyStats.totalPackages)", color: .blue)
                        PackagingStatCard(title: "总产品数", value: "\(dailyStats.totalItems)", color: .green)
                        PackagingStatCard(title: "团队数", value: "\(dailyStats.teamStats.count)", color: .purple)
                        PackagingStatCard(title: "款式数", value: "\(dailyStats.styleStats.count)", color: .orange)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // Search bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索款式或团队", text: $searchText)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Button(action: { showingAddRecord = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                
                // Records list
                if filteredRecords.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text(searchText.isEmpty ? "今日暂无包装记录" : "未找到匹配的记录")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if searchText.isEmpty {
                            Text("点击右上角 + 按钮添加包装记录")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredRecords, id: \.id) { record in
                            PackagingRecordRow(record: record) {
                                showingEditRecord = record
                            }
                        }
                        .onDelete(perform: confirmDelete)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("包装管理")
            .navigationBarTitleDisplayMode(.inline)
        }
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
        .background(Color(.systemBackground))
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
                    .foregroundColor(.blue)
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
            return .orange
        case .completed:
            return .green
        case .shipped:
            return .blue
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: PackagingRecord.self, PackagingTeam.self, ProductionStyle.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    PackagingManagementView()
        .modelContainer(container)
}