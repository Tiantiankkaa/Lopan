//
//  PlaceholderViews.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI

// MARK: - Salesperson Views
struct SalesAnalyticsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("销售分析")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("销售数据统计和分析功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("销售分析")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Warehouse Keeper Views
struct ProductionStyleListView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shirt.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("生产款式管理")
                .font(.title)
                .fontWeight(.bold)
            
            Text("日常生产款式管理功能正在开发中...")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
        .navigationTitle("生产款式管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WarehouseStatusView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("入库状态")
                .font(.title)
                .fontWeight(.bold)
            
            Text("入库状态管理功能正在开发中...")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
        .navigationTitle("入库状态")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Workshop Manager Views
struct WorkshopProductionListView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("生产管理")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("车间生产状态管理功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("生产管理")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MachineStatusView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("设备状态")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("设备运行状态查看功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("设备状态")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - EVA Granulation Technician Views
struct EVAGranulationListView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("造粒记录")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("每日造粒数据记录功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("造粒记录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct RawMaterialView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("原材料管理")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("原材料消耗管理功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("原材料管理")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Workshop Technician Views
struct WorkshopIssueListView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("问题报告")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("生产问题报告功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("问题报告")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MachineMaintenanceView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("设备维护")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("设备维护记录管理功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("设备维护")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Administrator Views
struct AdminAnalyticsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("数据分析")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("管理员数据分析功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("数据分析")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SystemOverviewView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("系统概览")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("系统整体状态查看功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("系统概览")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProductionOverviewView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("生产概览")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("生产状态概览功能正在开发中...")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("生产概览")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
} 