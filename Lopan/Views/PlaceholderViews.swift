//
//  PlaceholderViews.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

// MARK: - Salesperson Views
struct SalesAnalyticsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.success)
                
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
    @Environment(\.modelContext) private var modelContext
    @Query private var products: [Product]
    @State private var searchText = ""
    
    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products.sorted { $0.createdAt > $1.createdAt }
        } else {
            return products.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.colors.contains { color in
                    color.localizedCaseInsensitiveContains(searchText)
                } ||
                product.sizeNames.contains { size in
                    size.localizedCaseInsensitiveContains(searchText)
                }
            }.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar with white background
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索产品名称、颜色或尺寸", text: $searchText)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(LopanColors.backgroundSecondary)
                    .cornerRadius(10)
                    .shadow(color: LopanColors.textPrimary.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .padding()
                .background(LopanColors.backgroundSecondary)
                
                // Statistics bar - only product count with enhanced background
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        ProductionStatusStatCard(
                            title: "产品总数",
                            count: products.count,
                            color: LopanColors.info
                        )
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [LopanColors.primary.opacity(0.05), LopanColors.primary.opacity(0.1)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LopanColors.primary.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom)
                .background(LopanColors.backgroundSecondary)
                
                // Product list
                if filteredProducts.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "shirt")
                            .font(.system(size: 50))
                            .foregroundColor(LopanColors.secondary)
                        Text(searchText.isEmpty ? "暂无产品数据" : "未找到匹配的产品")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("产品数据由销售部门管理，仓库管理员仅可查看")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredProducts, id: \.id) { product in
                                ReadOnlyProductRow(product: product)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(LopanColors.backgroundSecondary)
                }
            }
            .navigationTitle("生产款式管理")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProductionStatusStatCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .font(.title2)
                    .foregroundColor(color)
                Text("\(count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct ReadOnlyProductRow: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 12) {
            // Enhanced product image placeholder
            if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 70)
                    .clipped()
                    .cornerRadius(12)
                    .shadow(color: LopanColors.textPrimary.opacity(0.3), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [LopanColors.secondary.opacity(0.1), LopanColors.secondary.opacity(0.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(LopanColors.secondary.opacity(0.6))
                    )
                    .shadow(color: LopanColors.textPrimary.opacity(0.2), radius: 1, x: 0, y: 1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(product.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if !product.colors.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(LopanColors.info)
                            .font(.caption)
                        Text("颜色: \(product.colors.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let sizes = product.sizes, !sizes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "ruler.fill")
                            .foregroundColor(LopanColors.success)
                            .font(.caption)
                        Text("尺寸: \(sizes.map { $0.size }.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(LopanColors.warning)
                        .font(.caption)
                    Text("创建于: \(product.createdAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            VStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(LopanColors.info.opacity(0.6))
                    .font(.caption)
                Text("只读")
                    .font(.caption2)
                    .foregroundColor(LopanColors.info.opacity(0.6))
            }
            .padding(.trailing, 4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(LopanColors.background)
        .cornerRadius(8)
    }
}

struct WarehouseStatusView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 60))
                .foregroundColor(LopanColors.warning)
            
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
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.info)
                
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
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.success)
                
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
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.info)
                
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
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.warning)
                
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
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.error)
                
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
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.premium)
                
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
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.info)
                
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
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.success)
                
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
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(LopanColors.premium)
                
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
