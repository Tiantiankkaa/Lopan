//
//  MachineApprovalStatusView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/12.
//

import SwiftUI
import SwiftData

struct MachineApprovalStatusView: View {
    let machineId: String
    let batchService: ProductionBatchService
    let onBatchTapped: (ProductionBatch) -> Void
    
    @State private var approvalBatches: [ProductionBatch] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAllBatches = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载审批状态...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if let errorMessage = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(LopanColors.warning)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(LopanColors.warning.opacity(0.1))
                .cornerRadius(8)
            } else if approvalBatches.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LopanColors.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("暂无待审批批次")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("此设备当前没有需要审批的生产配置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(LopanColors.success.opacity(0.1))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(approvalBatches.prefix(3), id: \.id) { batch in
                        ApprovalBatchCompactRow(
                            batch: batch,
                            onTap: { onBatchTapped(batch) }
                        )
                    }
                    
                    if approvalBatches.count > 3 {
                        Button("查看全部 \(approvalBatches.count) 个批次") {
                            showingAllBatches = true
                        }
                        .font(.caption)
                        .foregroundColor(LopanColors.info)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .task {
            await loadApprovalBatches()
        }
        .refreshable {
            await loadApprovalBatches()
        }
        .onChange(of: machineId) { _, newMachineId in
            // Clear current data immediately when machine changes
            approvalBatches = []
            errorMessage = nil
            
            // Load data for the new machine
            Task {
                await loadApprovalBatches()
            }
        }
        .sheet(isPresented: $showingAllBatches) {
            MachineApprovalDetailView(
                machineId: machineId,
                batches: approvalBatches,
                onBatchTapped: onBatchTapped
            )
        }
    }
    
    private func loadApprovalBatches() async {
        isLoading = true
        errorMessage = nil
        
        // Load all batches and filter for this machine
        await batchService.loadBatches()
        
        // Check if there was an error during loading
        if let error = batchService.errorMessage {
            errorMessage = "加载失败: \(error)"
            isLoading = false
            return
        }
        
        let allBatches = batchService.batches
        
        // Filter for batches that belong to this machine and need approval attention
        approvalBatches = allBatches.filter { batch in
            // Check if batch belongs to this machine
            guard batch.machineId == machineId else { return false }
            
            // Filter out old batches (rejected/completed) older than 24 hours
            let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
            
            switch batch.status {
            case .rejected:
                if let rejectedAt = batch.rejectedAt, rejectedAt < twentyFourHoursAgo {
                    return false  // Don't show rejected batches older than 24 hours
                }
            case .completed:
                if let completedAt = batch.completedAt, completedAt < twentyFourHoursAgo {
                    return false  // Don't show completed batches older than 24 hours
                }
            default:
                break
            }
            
            // Check if batch needs approval attention
            // Show: pending (待审批), pendingExecution (待执行), active (执行中), rejected (已拒绝), completed (已完成)
            switch batch.status {
            case .pending, .pendingExecution, .rejected, .active, .completed:
                return true
            case .unsubmitted, .approved:  // These statuses are no longer used in current workflow
                return false
            }
        }.sorted { $0.submittedAt > $1.submittedAt }
        
        isLoading = false
    }
}

// MARK: - Compact Approval Batch Row
struct ApprovalBatchCompactRow: View {
    let batch: ProductionBatch
    let onTap: () -> Void
    
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(batch.status.color)
                    .frame(width: 8, height: 8)
                
                // Batch info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(batch.batchNumber + " (" + batch.batchType.displayName + ")")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(timeAgoString(from: batch.submittedAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: batch.status.iconName)
                                .font(.caption2)
                                .foregroundColor(LopanColors.textPrimary)
                            
                            Text(batch.status.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(LopanColors.textPrimary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(batch.status.color)
                        .cornerRadius(6)
                        .accessibilityLabel(batch.status.accessibilityLabel)
                        
                        Text(batch.mode.displayName)
                            .font(.caption2)
                            .foregroundColor(LopanColors.info)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(LopanColors.primary.opacity(0.1))
                            .cornerRadius(3)
                        
                        // Show shift information for shift-aware batches
                        if batch.isShiftBatch, let shift = batch.shift {
                            HStack(spacing: 2) {
                                Image(systemName: shift == .morning ? "sun.min" : "moon")
                                    .font(.caption2)
                                    .foregroundColor(shift == .morning ? LopanColors.warning : LopanColors.info)
                                
                                Text(shift.displayName)
                                    .font(.caption2)
                                    .foregroundColor(shift == .morning ? LopanColors.warning : LopanColors.info)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background((shift == .morning ? LopanColors.warning : LopanColors.primary).opacity(0.1))
                            .cornerRadius(3)
                        }
                        
                        // Color-only indicator
                        if batch.allowsColorModificationOnly {
                            Image(systemName: "paintpalette")
                                .font(.caption2)
                                .foregroundColor(LopanColors.warning)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(LopanColors.warning.opacity(0.1))
                                .cornerRadius(3)
                        }
                        
                        if !batch.products.isEmpty {
                            Text("\(batch.products.count)产品")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Action indicator
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(6)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if days > 0 {
            return "\(days)天前"
        } else if hours > 0 {
            return "\(hours)小时前"
        } else if minutes > 0 {
            return "\(minutes)分钟前"
        } else {
            return "刚刚"
        }
    }
}

// MARK: - Preview
struct MachineApprovalStatusView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            WorkshopMachine.self, ProductionBatch.self, ProductConfig.self,
            User.self, AuditLog.self, ColorCard.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        
        let batchService = ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        )
        
        MachineApprovalStatusView(
            machineId: "test-machine-id",
            batchService: batchService,
            onBatchTapped: { _ in }
        )
    }
}