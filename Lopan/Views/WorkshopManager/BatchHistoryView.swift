//
//  BatchHistoryView.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI
import SwiftData

struct BatchHistoryView: View {
    @StateObject private var batchService: ProductionBatchService
    @ObservedObject private var authService: AuthenticationService
    
    @State private var selectedStatus: BatchStatus? = nil
    @State private var selectedBatch: ProductionBatch?
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.authService = authService
        self._batchService = StateObject(wrappedValue: ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        ))
    }
    
    var filteredBatches: [ProductionBatch] {
        if let status = selectedStatus {
            return batchService.batches.filter { $0.status == status }
        }
        return batchService.batches
    }
    
    var body: some View {
        VStack {
            if batchService.isLoading {
                ProgressView("加载批次历史...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainContent
            }
        }
            .refreshable {
                await batchService.loadBatches()
            }
            .alert("Error", isPresented: .constant(batchService.errorMessage != nil)) {
                Button("确定") {
                    batchService.clearError()
                }
            } message: {
                if let errorMessage = batchService.errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(item: $selectedBatch, onDismiss: {
                selectedBatch = nil
            }) { batch in
                BatchDetailView(batch: batch, batchService: batchService)
            }
        .task {
            await batchService.loadBatches()
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Status filter
            statusFilterSection
            
            // Batch list
            if filteredBatches.isEmpty {
                emptyStateView
            } else {
                batchListView
            }
        }
    }
    
    // MARK: - Status Filter Section
    private var statusFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All batches
                StatusFilterChip(
                    title: "全部",
                    count: batchService.batches.count,
                    isSelected: selectedStatus == nil
                ) {
                    selectedStatus = nil
                }
                
                // Status-specific filters
                ForEach(BatchStatus.allCases, id: \.self) { status in
                    let count = batchService.batches.filter { $0.status == status }.count
                    if count > 0 {
                        StatusFilterChip(
                            title: status.displayName,
                            count: count,
                            isSelected: selectedStatus == status,
                            color: Color(status.color)
                        ) {
                            selectedStatus = status
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("暂无批次记录")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("创建生产配置后，批次历史将显示在这里")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Batch List View
    private var batchListView: some View {
        List {
            ForEach(filteredBatches, id: \.id) { batch in
                BatchHistoryRow(batch: batch) {
                    selectedBatch = batch
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Status Filter Chip
struct StatusFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void
    
    init(title: String, count: Int, isSelected: Bool, color: Color = .blue, onTap: @escaping () -> Void) {
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.color = color
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : color.opacity(0.2))
                    .foregroundColor(isSelected ? .white : color)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Batch History Row
struct BatchHistoryRow: View {
    let batch: ProductionBatch
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(batch.batchNumber)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("提交于 \(batch.submittedAt.formatted(.dateTime.month().day().hour().minute()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(batch.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(batch.status.color).opacity(0.2))
                            .foregroundColor(Color(batch.status.color))
                            .cornerRadius(4)
                        
                        Text(batch.mode.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Content summary
                HStack {
                    Label("\(batch.products.count) 个产品", systemImage: "cube.box")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label("\(batch.totalStationsUsed)/12 工位", systemImage: "grid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Review info (if applicable)
                if let reviewedAt = batch.reviewedAt, let reviewedByName = batch.reviewedByName {
                    HStack {
                        Text("审核: \(reviewedByName)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(reviewedAt.formatted(.dateTime.month().day().hour().minute()))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Batch Detail View
struct BatchDetailView: View {
    let batch: ProductionBatch
    @ObservedObject var batchService: ProductionBatchService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic info
                    batchInfoSection
                    
                    // Products
                    productsSection
                    
                    // Review info
                    if batch.reviewedAt != nil {
                        reviewInfoSection
                    }
                    
                    // Timeline
                    timelineSection
                }
                .padding()
            }
            .navigationTitle("批次详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Batch Info Section
    private var batchInfoSection: some View {
        VStack(spacing: 12) {
            Text("批次信息")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                BatchInfoRow(label: "批次编号", value: batch.batchNumber)
                BatchInfoRow(label: "生产模式", value: batch.mode.displayName)
                BatchInfoRow(label: "设备ID", value: batch.machineId)
                BatchInfoRow(label: "状态", value: batch.status.displayName)
                BatchInfoRow(label: "提交人", value: batch.submittedByName)
                BatchInfoRow(label: "提交时间", value: batch.submittedAt.formatted(.dateTime))
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Products Section
    private var productsSection: some View {
        VStack(spacing: 12) {
            Text("产品配置")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                ForEach(batch.products, id: \.id) { product in
                    ProductDetailRow(product: product)
                }
            }
        }
    }
    
    // MARK: - Review Info Section
    private var reviewInfoSection: some View {
        VStack(spacing: 12) {
            Text("审核信息")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                if let reviewedByName = batch.reviewedByName {
                    BatchInfoRow(label: "审核人", value: reviewedByName)
                }
                
                if let reviewedAt = batch.reviewedAt {
                    BatchInfoRow(label: "审核时间", value: reviewedAt.formatted(.dateTime))
                }
                
                if let reviewNotes = batch.reviewNotes, !reviewNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("审核备注")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(reviewNotes)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Timeline Section
    private var timelineSection: some View {
        VStack(spacing: 12) {
            Text("时间线")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                TimelineRow(
                    title: "批次创建",
                    subtitle: "由 \(batch.submittedByName) 创建",
                    time: batch.createdAt,
                    isCompleted: true
                )
                
                TimelineRow(
                    title: "提交审核",
                    subtitle: "等待管理员审核",
                    time: batch.submittedAt,
                    isCompleted: true
                )
                
                if let reviewedAt = batch.reviewedAt {
                    TimelineRow(
                        title: batch.status == .approved ? "审核通过" : "审核拒绝",
                        subtitle: "由 \(batch.reviewedByName ?? "管理员") 审核",
                        time: reviewedAt,
                        isCompleted: true
                    )
                }
                
                if let appliedAt = batch.appliedAt {
                    TimelineRow(
                        title: "配置应用",
                        subtitle: "生产配置已应用到设备",
                        time: appliedAt,
                        isCompleted: true
                    )
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Info Row
struct BatchInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Product Detail Row
struct ProductDetailRow: View {
    let product: ProductConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(product.productName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("优先级 \(product.priority)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("工位: \(product.stationRange)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("预期产量: \(product.expectedOutput)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if product.isDualColor {
                    Text("双色生产")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Timeline Row
struct TimelineRow: View {
    let title: String
    let subtitle: String
    let time: Date
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Timeline indicator
            VStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                
                if isCompleted {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 2, height: 20)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(time.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct BatchHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            WorkshopMachine.self, WorkshopStation.self, WorkshopGun.self,
            ColorCard.self, ProductionBatch.self, ProductConfig.self,
            User.self, AuditLog.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        
        BatchHistoryView(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}