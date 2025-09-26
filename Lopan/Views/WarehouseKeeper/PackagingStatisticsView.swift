//
//  PackagingStatisticsView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import SwiftUI
import SwiftData
import Charts

struct PackagingStatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var packagingRecords: [PackagingRecord]
    @Query private var packagingTeams: [PackagingTeam]
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedDate = Date()
    
    enum TimeRange: String, CaseIterable {
        case day = "day"
        case week = "week"
        case month = "month"
        
        var displayName: String {
            switch self {
            case .day:
                return "日"
            case .week:
                return "周"
            case .month:
                return "月"
            }
        }
    }
    
    // Get records within the selected time range
    private var timeRangeRecords: [PackagingRecord] {
        let calendar = Calendar.current
        let endDate = selectedDate
        let startDate: Date
        
        switch selectedTimeRange {
        case .day:
            startDate = calendar.startOfDay(for: endDate)
        case .week:
            startDate = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? endDate
        case .month:
            startDate = calendar.dateInterval(of: .month, for: endDate)?.start ?? endDate
        }
        
        return packagingRecords.filter { record in
            record.packageDate >= startDate && record.packageDate <= endDate
        }
    }
    
    // Daily statistics for chart display
    private var dailyStats: [DailyPackagingStat] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: timeRangeRecords) { record in
            calendar.startOfDay(for: record.packageDate)
        }
        
        return grouped.map { date, records in
            DailyPackagingStat(
                date: date,
                totalPackages: records.reduce(0) { $0 + $1.totalPackages },
                totalItems: records.reduce(0) { $0 + $1.totalItems },
                recordCount: records.count
            )
        }.sorted { $0.date < $1.date }
    }
    
    // Team performance statistics
    private var teamStats: [TeamPackagingStat] {
        let grouped = Dictionary(grouping: timeRangeRecords) { $0.teamName }
        
        return grouped.map { teamName, records in
            TeamPackagingStat(
                teamName: teamName,
                totalPackages: records.reduce(0) { $0 + $1.totalPackages },
                totalItems: records.reduce(0) { $0 + $1.totalItems },
                recordCount: records.count,
                averagePackagesPerRecord: Double(records.reduce(0) { $0 + $1.totalPackages }) / Double(max(records.count, 1))
            )
        }.sorted { $0.totalPackages > $1.totalPackages }
    }
    
    // Style statistics
    private var styleStats: [StylePackagingStat] {
        let grouped = Dictionary(grouping: timeRangeRecords) { $0.styleCode }
        
        return grouped.map { styleCode, records in
            StylePackagingStat(
                styleCode: styleCode,
                styleName: records.first?.styleName ?? "",
                totalPackages: records.reduce(0) { $0 + $1.totalPackages },
                totalItems: records.reduce(0) { $0 + $1.totalItems },
                recordCount: records.count
            )
        }.sorted { $0.totalPackages > $1.totalPackages }
    }
    
    // Overall statistics
    private var overallStats: OverallPackagingStat {
        let totalPackages = timeRangeRecords.reduce(0) { $0 + $1.totalPackages }
        let totalItems = timeRangeRecords.reduce(0) { $0 + $1.totalItems }
        let recordCount = timeRangeRecords.count
        let uniqueStyles = Set(timeRangeRecords.map { $0.styleCode }).count
        let uniqueTeams = Set(timeRangeRecords.map { $0.teamName }).count
        
        return OverallPackagingStat(
            totalPackages: totalPackages,
            totalItems: totalItems,
            recordCount: recordCount,
            uniqueStyles: uniqueStyles,
            uniqueTeams: uniqueTeams,
            averageItemsPerPackage: totalPackages > 0 ? Double(totalItems) / Double(totalPackages) : 0
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time range selector and date picker
                    VStack(spacing: 12) {
                        Picker("时间范围", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    .padding()
                    .background(LopanColors.backgroundSecondary)
                    .cornerRadius(12)
                    
                    // Overall statistics cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatisticCard(title: "总包装数", value: "\(overallStats.totalPackages)", color: LopanColors.info, icon: "cube.box")
                        StatisticCard(title: "总产品数", value: "\(overallStats.totalItems)", color: LopanColors.success, icon: "number")
                        StatisticCard(title: "记录数", value: "\(overallStats.recordCount)", color: LopanColors.accent, icon: "doc.text")
                        StatisticCard(title: "款式数", value: "\(overallStats.uniqueStyles)", color: LopanColors.warning, icon: "shirt")
                    }
                    
                    // Daily trend chart
                    if !dailyStats.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("包装趋势")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(dailyStats, id: \.date) { stat in
                                LineMark(
                                    x: .value("日期", stat.date),
                                    y: .value("包装数", stat.totalPackages)
                                )
                                .foregroundStyle(LopanColors.info)
                                
                                AreaMark(
                                    x: .value("日期", stat.date),
                                    y: .value("包装数", stat.totalPackages)
                                )
                                .foregroundStyle(LopanColors.info.opacity(0.1))
                            }
                            .frame(height: 200)
                            .padding()
                            .background(LopanColors.background)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Team performance
                    if !teamStats.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("团队表现")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(teamStats, id: \.teamName) { stat in
                                TeamPerformanceRow(stat: stat)
                            }
                        }
                        .padding()
                        .background(LopanColors.background)
                        .cornerRadius(12)
                    }
                    
                    // Style statistics
                    if !styleStats.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("款式统计")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(styleStats.prefix(10), id: \.styleCode) { stat in
                                StyleStatisticsRow(stat: stat)
                            }
                            
                            if styleStats.count > 10 {
                                Text("还有 \(styleStats.count - 10) 个款式...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(LopanColors.background)
                        .cornerRadius(12)
                    }
                    
                    // Empty state
                    if timeRangeRecords.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 50))
                                .foregroundColor(LopanColors.secondary)
                            Text("所选时间范围内暂无数据")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("请选择其他时间范围或添加包装记录")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("包装统计")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
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
        .background(LopanColors.background)
        .cornerRadius(12)
    }
}

struct TeamPerformanceRow: View {
    let stat: TeamPackagingStat
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.teamName)
                    .font(.headline)
                Text("\(stat.recordCount) 条记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 16) {
                    VStack(alignment: .trailing) {
                       Text("\(stat.totalPackages)")
                           .font(.title3)
                           .fontWeight(.bold)
                            .foregroundColor(LopanColors.info)
                        Text("包装数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .trailing) {
                       Text("\(stat.totalItems)")
                           .font(.title3)
                           .fontWeight(.bold)
                            .foregroundColor(LopanColors.success)
                        Text("产品数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(String(format: "平均 %.1f 包/记录", stat.averagePackagesPerRecord))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct StyleStatisticsRow: View {
    let stat: StylePackagingStat
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.styleName)
                    .font(.headline)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                VStack(alignment: .trailing) {
                   Text("\(stat.totalPackages)")
                       .font(.subheadline)
                       .fontWeight(.bold)
                        .foregroundColor(LopanColors.info)
                    Text("包装")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .trailing) {
                   Text("\(stat.totalItems)")
                       .font(.subheadline)
                       .fontWeight(.bold)
                        .foregroundColor(LopanColors.success)
                    Text("产品")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Structures

struct DailyPackagingStat {
    let date: Date
    let totalPackages: Int
    let totalItems: Int
    let recordCount: Int
}

struct TeamPackagingStat {
    let teamName: String
    let totalPackages: Int
    let totalItems: Int
    let recordCount: Int
    let averagePackagesPerRecord: Double
}

struct StylePackagingStat {
    let styleCode: String
    let styleName: String
    let totalPackages: Int
    let totalItems: Int
    let recordCount: Int
}

struct OverallPackagingStat {
    let totalPackages: Int
    let totalItems: Int
    let recordCount: Int
    let uniqueStyles: Int
    let uniqueTeams: Int
    let averageItemsPerPackage: Double
}

#Preview {
    let container = try! ModelContainer(for: PackagingRecord.self, PackagingTeam.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    PackagingStatisticsView()
        .modelContainer(container)
}
