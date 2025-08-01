//
//  BatchReviewView.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI
import SwiftData

struct BatchReviewView: View {
    @StateObject private var batchService: ProductionBatchService
    @StateObject private var machineService: MachineService
    @ObservedObject private var authService: AuthenticationService
    
    @State private var selectedBatch: ProductionBatch?
    @State private var showingReviewSheet = false
    @State private var reviewAction: ReviewAction = .approve
    @State private var reviewNotes = ""
    
    enum ReviewAction {
        case approve
        case reject
    }
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.authService = authService
        self._batchService = StateObject(wrappedValue: ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        ))
        self._machineService = StateObject(wrappedValue: MachineService(
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if batchService.isLoading {
                    ProgressView("加载待审核批次...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if batchService.pendingBatches.isEmpty {
                    emptyStateView
                } else {
                    pendingBatchesList
                }
            }
            .navigationTitle("批次审核")
            .refreshable {
                await loadData()
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
            .sheet(isPresented: $showingReviewSheet) {
                if let batch = selectedBatch {
                    ReviewSheet(
                        batch: batch,
                        action: reviewAction,
                        notes: $reviewNotes,
                        batchService: batchService
                    ) {
                        selectedBatch = nil
                        showingReviewSheet = false
                        reviewNotes = ""
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("暂无待审核批次")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("所有生产配置批次已审核完成")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Pending Batches List
    private var pendingBatchesList: some View {
        List {
            ForEach(batchService.pendingBatches, id: \.id) { batch in
                PendingBatchRow(
                    batch: batch,
                    onApprove: {
                        selectedBatch = batch
                        reviewAction = .approve
                        showingReviewSheet = true
                    },
                    onReject: {
                        selectedBatch = batch
                        reviewAction = .reject
                        showingReviewSheet = true
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Helper Methods
    private func loadData() async {
        await batchService.loadPendingBatches()
        await machineService.loadMachines()
    }
}

// MARK: - Pending Batch Row
struct PendingBatchRow: View {
    let batch: ProductionBatch
    let onApprove: () -> Void
    let onReject: () -> Void
    
    @State private var showingDetail = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(batch.batchNumber)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("提交人: \(batch.submittedByName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(batch.mode.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(batch.submittedAt.formatted(.dateTime.month().day().hour().minute()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Configuration summary
            VStack(spacing: 8) {
                HStack {
                    Label("\(batch.products.count) 个产品", systemImage: "cube.box")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label("\(batch.totalStationsUsed)/12 工位", systemImage: "grid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Configuration validation
                HStack {
                    Image(systemName: batch.isValidConfiguration ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(batch.isValidConfiguration ? .green : .red)
                    
                    Text(batch.isValidConfiguration ? "配置有效" : "配置无效")
                        .font(.caption)
                        .foregroundColor(batch.isValidConfiguration ? .green : .red)
                    
                    Spacer()
                }
            }
            
            // Products preview
            if !batch.products.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(batch.products, id: \.id) { product in
                            ProductPreviewCard(product: product)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("查看详情") {
                    showingDetail = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("拒绝") {
                    onReject()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Button("批准") {
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!batch.isValidConfiguration)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingDetail) {
            // Simplified detail view for preview - would normally pass proper service
            VStack {
                Text("Batch Detail")
                Text(batch.batchNumber)
                Button("Close") { showingDetail = false }
            }
            .padding()
        }
    }
}

// MARK: - Product Preview Card
struct ProductPreviewCard: View {
    let product: ProductConfig
    
    var body: some View {
        VStack(spacing: 4) {
            Text(product.productName)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(product.stationRange)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if product.isDualColor {
                Text("双色")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(6)
        .frame(width: 80)
    }
}

// MARK: - Review Sheet
struct ReviewSheet: View {
    let batch: ProductionBatch
    let action: BatchReviewView.ReviewAction
    @Binding var notes: String
    @ObservedObject var batchService: ProductionBatchService
    let onDismiss: () -> Void
    
    @State private var isProcessing = false
    
    var actionColor: Color {
        action == .approve ? .green : .red
    }
    
    var actionTitle: String {
        action == .approve ? "批准批次" : "拒绝批次"
    }
    
    var actionIcon: String {
        action == .approve ? "checkmark.seal.fill" : "xmark.seal.fill"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Action header
                VStack(spacing: 16) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 60))
                        .foregroundColor(actionColor)
                    
                    VStack(spacing: 8) {
                        Text(actionTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("批次: \(batch.batchNumber)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Batch summary
                batchSummarySection
                
                // Notes section
                notesSection
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding()
            .navigationTitle("审核批次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Batch Summary Section
    private var batchSummarySection: some View {
        VStack(spacing: 12) {
            Text("批次摘要")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                SummaryRow(label: "提交人", value: batch.submittedByName)
                SummaryRow(label: "生产模式", value: batch.mode.displayName)
                SummaryRow(label: "产品数量", value: "\(batch.products.count)")
                SummaryRow(label: "工位使用", value: "\(batch.totalStationsUsed)/12")
                SummaryRow(label: "提交时间", value: batch.submittedAt.formatted(.dateTime))
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(action == .approve ? "批准备注 (可选)" : "拒绝原因 (必填)")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextEditor(text: $notes)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(actionTitle) {
                performReviewAction()
            }
            .buttonStyle(.borderedProminent)
            .tint(actionColor)
            .disabled(isProcessing || (action == .reject && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            
            Button("取消") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)
        }
    }
    
    // MARK: - Helper Methods
    private func performReviewAction() {
        Task {
            isProcessing = true
            
            let success: Bool
            if action == .approve {
                success = await batchService.approveBatch(batch, notes: notes.isEmpty ? nil : notes)
            } else {
                success = await batchService.rejectBatch(batch, notes: notes)
            }
            
            isProcessing = false
            
            if success {
                onDismiss()
            }
        }
    }
}

// MARK: - Summary Row
struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview
struct BatchReviewView_Previews: PreviewProvider {
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
        
        BatchReviewView(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}