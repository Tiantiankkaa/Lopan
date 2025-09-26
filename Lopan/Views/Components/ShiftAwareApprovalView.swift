//
//  ShiftAwareApprovalView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import SwiftUI
import SwiftData

// MARK: - Shift-Aware Approval View (班次感知审批视图)
struct ShiftAwareApprovalView: View {
    let batch: ProductionBatch
    let repositoryFactory: RepositoryFactory
    @ObservedObject var authService: AuthenticationService
    let auditService: NewAuditingService
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var productionBatchService: ProductionBatchService
    @StateObject private var batchEditPermissionService: StandardBatchEditPermissionService
    
    @State private var approvalNotes = ""
    @State private var isSubmitting = false
    @State private var showingApprovalConfirmation = false
    @State private var showingRejectionConfirmation = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var machineInfo: WorkshopMachine?
    @State private var productConfigs: [ProductConfig] = []
    @State private var showingExecutionSheet = false
    
    @StateObject private var dateShiftPolicy = StandardDateShiftPolicy()
    private let timeProvider = SystemTimeProvider()
    
    init(
        batch: ProductionBatch,
        repositoryFactory: RepositoryFactory,
        authService: AuthenticationService,
        auditService: NewAuditingService
    ) {
        self.batch = batch
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        
        // Initialize services
        let productionService = ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        )
        self._productionBatchService = StateObject(wrappedValue: productionService)
        
        let permissionService = StandardBatchEditPermissionService(authService: authService)
        self._batchEditPermissionService = StateObject(wrappedValue: permissionService)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    approvalHeaderSection
                    batchOverviewSection
                    shiftContextSection
                    machineAssignmentSection
                    productConfigurationSection
                    if batch.status == .pending {
                        approvalDecisionSection
                    } else if batch.status == .pendingExecution {
                        executionSection
                    }
                }
                .padding()
            }
            .navigationTitle("批次审批")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadApprovalData()
            }
            .alert("错误", isPresented: $showingError, presenting: errorMessage) { _ in
                Button("确定", role: .cancel) { }
            } message: { message in
                Text(message)
            }
            .confirmationDialog(
                "批准批次",
                isPresented: $showingApprovalConfirmation,
                titleVisibility: .visible
            ) {
                Button("确认批准", role: .destructive) {
                    Task {
                        await approveBatch()
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("确认批准批次 \(batch.batchNumber)？此操作将使批次进入待执行状态。")
            }
            .confirmationDialog(
                "拒绝批次",
                isPresented: $showingRejectionConfirmation,
                titleVisibility: .visible
            ) {
                Button("确认拒绝", role: .destructive) {
                    Task {
                        await rejectBatch()
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("确认拒绝批次 \(batch.batchNumber)？请确保已填写拒绝原因。")
            }
            .sheet(isPresented: $showingExecutionSheet) {
                ExecutionTimeSheet(
                    batch: batch,
                    onConfirm: { executionTime in
                        showingExecutionSheet = false
                        Task {
                            await executeBatch(at: executionTime)
                        }
                    },
                    onCancel: {
                        showingExecutionSheet = false
                    }
                )
            }
        }
    }
    
    // MARK: - Approval Header Section (审批头部区域)
    
    private var approvalHeaderSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(LopanColors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("批次审批")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("审查生产批次配置和班次安排")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                approvalStatusBadge
            }
            
            Divider()
        }
    }
    
    private var approvalStatusBadge: some View {
        VStack(spacing: 4) {
            Text(batch.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(batch.status.color.opacity(0.2))
                )
                .foregroundColor(batch.status.color)
            
            Text(formatTimeAgo(batch.submittedAt))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Batch Overview Section (批次概览)
    
    private var batchOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "批次概览", icon: "square.stack.3d.down.right")
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("批次号")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(batch.batchNumber)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("生产模式")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(batch.mode.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(LopanColors.primary)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("提交人")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(batch.submittedByName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("产品数量")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("\(productConfigs.count)")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LopanColors.backgroundSecondary)
            )
        }
    }
    
    // MARK: - Shift Context Section (班次背景信息)
    
    private var shiftContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "班次安排", icon: "calendar.badge.clock")
            
            if batch.isShiftBatch, let targetDate = batch.targetDate, let shift = batch.shift {
                shiftAwareBatchInfo(targetDate: targetDate, shift: shift)
            } else {
                legacyBatchInfo
            }
        }
    }
    
    private func shiftAwareBatchInfo(targetDate: Date, shift: Shift) -> some View {
        VStack(spacing: 16) {
            // Date and shift information
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("生产日期")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(LopanColors.primary)
                        
                        Text(formatFullDate(targetDate))
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("班次")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: shift == .morning ? "sun.min" : "moon")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(shift == .morning ? LopanColors.warning : LopanColors.primary)
                        
                        Text(shift.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Time policy and restrictions
            shiftPolicyInfo(targetDate: targetDate, shift: shift)
            
            // Color-only restriction indicator
            if batch.allowsColorModificationOnly {
                colorOnlyRestrictionIndicator
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
        )
    }
    
    private func shiftPolicyInfo(targetDate: Date, shift: Shift) -> some View {
        let cutoffInfo = dateShiftPolicy.getCutoffInfo(for: targetDate, currentTime: batch.submittedAt ?? Date())
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("时间政策")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Image(systemName: cutoffInfo.hasRestriction ? "clock.badge.exclamationmark" : "checkmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(cutoffInfo.hasRestriction ? LopanColors.warning : LopanColors.success)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(cutoffInfo.hasRestriction ? "时间限制模式" : "正常时间模式")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let message = cutoffInfo.restrictionMessage {
                        Text(message)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("批次创建时间符合政策要求")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("12:00截止")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LopanColors.backgroundTertiary)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cutoffInfo.hasRestriction ? LopanColors.warning.opacity(0.1) : LopanColors.success.opacity(0.1))
            )
        }
    }
    
    private var colorOnlyRestrictionIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("编辑限制")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LopanColors.warning)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("仅限颜色修改")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(LopanColors.warning)
                    
                    Text("此批次仅允许修改产品颜色配置")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LopanColors.warning.opacity(0.1))
            )
        }
    }
    
    private var legacyBatchInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("传统批次模式")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("此批次使用传统模式创建，无班次信息")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LopanColors.backgroundSecondary)
            )
        }
    }
    
    // MARK: - Machine Assignment Section (机器分配)
    
    private var machineAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "设备分配", icon: "gearshape.2")
            
            if let machine = machineInfo {
                machineInfoCard(machine)
            } else {
                machineLoadingCard
            }
        }
    }
    
    private func machineInfoCard(_ machine: WorkshopMachine) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: machine.isOperational ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(machine.isOperational ? LopanColors.success : LopanColors.warning)
                
                Circle()
                    .fill(machine.isOperational ? LopanColors.success : LopanColors.warning)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(machine.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("编号: \(machine.machineNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(machine.isOperational ? "运行正常" : "需要维护")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(machine.isOperational ? LopanColors.success : LopanColors.warning)
                    
                    Circle()
                        .fill(LopanColors.secondary.opacity(0.3))
                        .frame(width: 2, height: 2)
                    
                    Text("\(machine.stations.count)工位 · \(machine.totalGuns)喷枪")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !machine.isOperational {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LopanColors.warning)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(machine.isOperational ? LopanColors.clear : LopanColors.warning.opacity(0.5), lineWidth: 1)
        )
    }
    
    private var machineLoadingCard: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("正在加载设备信息...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
        )
    }
    
    // MARK: - Product Configuration Section (产品配置)
    
    private var productConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "产品配置", icon: "cube.box")
            
            if productConfigs.isEmpty {
                productEmptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(productConfigs.enumerated()), id: \.offset) { index, config in
                        productConfigCard(config: config, index: index)
                    }
                }
            }
        }
    }
    
    private var productEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.box")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("无产品配置")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("此批次未配置任何产品")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundSecondary)
        )
    }
    
    private func productConfigCard(config: ProductConfig, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(LopanColors.textPrimary)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(LopanColors.primary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(config.productName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "paintpalette")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("颜色: \(config.primaryColorId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let stationCount = config.stationCount {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("工位数: \(stationCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "gearshape.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("工位: \(config.occupiedStations.map(String.init).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if batch.allowsColorModificationOnly {
                Image(systemName: "paintpalette")
                    .font(.caption)
                    .foregroundColor(LopanColors.warning)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(LopanColors.warning.opacity(0.2))
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(LopanColors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(LopanColors.secondary.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    // MARK: - Approval Decision Section (审批决定)
    
    private var approvalDecisionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "审批决定", icon: "checkmark.shield")
            
            // Notes input
            VStack(alignment: .leading, spacing: 8) {
                Text("审批备注")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextField("输入审批备注（可选）", text: $approvalNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            
            // Action buttons
            if isSubmitting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("正在处理审批...")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LopanColors.backgroundSecondary)
                )
            } else {
                HStack(spacing: 12) {
                    // Reject button
                    Button(action: {
                        showingRejectionConfirmation = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("拒绝")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(LopanColors.error)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LopanColors.error.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LopanColors.error.opacity(0.5), lineWidth: 1)
                        )
                    }
                    
                    // Approve button
                    Button(action: {
                        showingApprovalConfirmation = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("批准")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(LopanColors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canApprove ? LopanColors.success : LopanColors.secondary)
                        )
                    }
                    .disabled(!canApprove)
                }
            }
            
            // Approval requirements checklist
            approvalRequirementsChecklist
        }
    }
    
    private var approvalRequirementsChecklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("审批检查项")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(spacing: 6) {
                approvalCheckItem(
                    title: "设备状态",
                    isValid: machineInfo?.isOperational ?? false,
                    message: (machineInfo?.isOperational ?? false) ? "设备运行正常" : "设备需要维护"
                )
                
                approvalCheckItem(
                    title: "产品配置",
                    isValid: !productConfigs.isEmpty,
                    message: !productConfigs.isEmpty ? "\(productConfigs.count)个产品已配置" : "无产品配置"
                )
                
                if batch.isShiftBatch {
                    let cutoffInfo = dateShiftPolicy.getCutoffInfo(
                        for: batch.targetDate ?? Date(),
                        currentTime: batch.submittedAt ?? Date()
                    )
                    
                    approvalCheckItem(
                        title: "时间政策",
                        isValid: true, // Batch was already created, so it passed validation
                        message: cutoffInfo.hasRestriction ? "限制模式下创建" : "正常模式下创建"
                    )
                }
                
                approvalCheckItem(
                    title: "批次状态",
                    isValid: batch.status == .pending,
                    message: batch.status == .pending ? "待审批状态正常" : "批次状态异常"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LopanColors.backgroundTertiary)
        )
    }
    
    private func approvalCheckItem(title: String, isValid: Bool, message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isValid ? LopanColors.success : LopanColors.error)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(message)
                .font(.caption2)
                .foregroundColor(isValid ? LopanColors.success : LopanColors.error)
        }
    }
    
    // MARK: - Execution Section (执行区域)
    
    private var executionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "批次执行", icon: "play.circle")
            
            // Execution status
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(LopanColors.warning)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("待执行")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("批次已批准，等待设置执行时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if let targetDate = batch.targetDate, let shift = batch.shift {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("计划班次")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: shift == .morning ? "sun.min" : "moon")
                                    .font(.caption)
                                    .foregroundColor(shift == .morning ? LopanColors.warning : LopanColors.primary)
                                
                                Text("\(formatFullDate(targetDate)) \(shift.displayName)")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("班次时间")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(shift.timeRangeDisplay)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(LopanColors.primary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LopanColors.backgroundTertiary)
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LopanColors.backgroundSecondary)
            )
            
            // Execute button
            Button(action: {
                showingExecutionSheet = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                    
                    Text("执行批次")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("设置执行时间")
                        .font(.caption)
                        .foregroundColor(LopanColors.textOnPrimary.opacity(0.8))
                }
                .foregroundColor(LopanColors.textPrimary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LopanColors.primary)
                )
            }
        }
    }
    
    // MARK: - Helper Methods (辅助方法)
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LopanColors.primary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        
        if hours > 0 {
            return "\(hours)小时前"
        } else if minutes > 0 {
            return "\(minutes)分钟前"
        } else {
            return "刚刚"
        }
    }
    
    private var canApprove: Bool {
        return machineInfo?.isOperational ?? false &&
               !productConfigs.isEmpty &&
               batch.status == .pending
    }
    
    // MARK: - Data Loading and Actions (数据加载和操作)
    
    private func loadApprovalData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadMachineInfo()
            }
            group.addTask {
                await self.loadProductConfigs()
            }
        }
    }
    
    private func loadMachineInfo() async {
        do {
            let machine = try await repositoryFactory.machineRepository.fetchMachineById(batch.machineId)
            await MainActor.run {
                self.machineInfo = machine
            }
        } catch {
            await showError("加载设备信息失败: \(error.localizedDescription)")
        }
    }
    
    private func loadProductConfigs() async {
        do {
            let configs = try await repositoryFactory.productionBatchRepository.fetchProductConfigs(forBatch: batch.id)
            await MainActor.run {
                self.productConfigs = configs
            }
        } catch {
            await showError("加载产品配置失败: \(error.localizedDescription)")
        }
    }
    
    private func approveBatch() async {
        await MainActor.run {
            isSubmitting = true
        }
        
        let success = await productionBatchService.approveBatch(batch, notes: approvalNotes.isEmpty ? nil : approvalNotes)
        
        if success {
            await MainActor.run {
                dismiss()
            }
        } else {
            await showError(productionBatchService.errorMessage ?? "批准批次失败")
        }
        
        await MainActor.run {
            isSubmitting = false
        }
    }
    
    private func rejectBatch() async {
        await MainActor.run {
            isSubmitting = true
        }
        
        let success = await productionBatchService.rejectBatch(batch, notes: approvalNotes.isEmpty ? "未提供原因" : approvalNotes)
        
        if success {
            await MainActor.run {
                dismiss()
            }
        } else {
            await showError(productionBatchService.errorMessage ?? "拒绝批次失败")
        }
        
        await MainActor.run {
            isSubmitting = false
        }
    }
    
    private func executeBatch(at executionTime: Date) async {
        await MainActor.run {
            isSubmitting = true
        }
        
        let success = await productionBatchService.executeBatch(batch, at: executionTime)
        
        if success {
            await MainActor.run {
                dismiss()
            }
        } else {
            await showError(productionBatchService.errorMessage ?? "执行批次失败")
        }
        
        await MainActor.run {
            isSubmitting = false
        }
    }
    
    private func showError(_ message: String) async {
        await MainActor.run {
            self.errorMessage = message
            self.showingError = true
        }
    }
}

// MARK: - Preview Support (预览支持)
struct ShiftAwareApprovalView_Previews: PreviewProvider {
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
        
        // Create a mock batch with shift information
        let mockBatch = ProductionBatch(
            machineId: "machine1",
            mode: .singleColor,
            submittedBy: "user1", 
            submittedByName: "张三",
            batchNumber: "BATCH001",
            targetDate: Date(),
            shift: .morning
        )
        mockBatch.status = .pending
        
        return ShiftAwareApprovalView(
            batch: mockBatch,
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}