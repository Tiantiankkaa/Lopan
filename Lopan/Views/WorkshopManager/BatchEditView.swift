//
//  BatchEditView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/13.
//

import SwiftUI
import SwiftData

// MARK: - Batch Edit View (批次编辑视图)
struct BatchEditView: View {
    // Legacy support (向后兼容支持)
    private let batch: ProductionBatch?
    private let batchId: String?
    
    let repositoryFactory: RepositoryFactory
    @ObservedObject var authService: AuthenticationService
    let auditService: NewAuditingService
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var batchEditPermissionService: StandardBatchEditPermissionService
    @StateObject private var productionBatchService: ProductionBatchService
    @StateObject private var batchEditService: BatchEditService
    
    @State private var productConfigs: [ProductConfig] = []
    @State private var originalProductConfigs: [ProductConfig] = []
    @State private var editedConfigs: [ProductConfig] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingColorOnlyWarning = false
    @State private var showingProductionConfigRedirect = false
    @State private var availableColors: [ColorCard] = []
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isSubmitting = false
    
    // MARK: - Initializers (初始化方法)
    
    /// Initialize with batch ID (recommended approach)
    /// 使用批次ID初始化（推荐方式）
    init(
        batchId: String,
        repositoryFactory: RepositoryFactory,
        authService: AuthenticationService,
        auditService: NewAuditingService
    ) {
        self.batch = nil
        self.batchId = batchId
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        
        // Initialize services
        let permissionService = StandardBatchEditPermissionService(authService: authService)
        self._batchEditPermissionService = StateObject(wrappedValue: permissionService)
        
        let productionService = ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        )
        self._productionBatchService = StateObject(wrappedValue: productionService)
        
        // Initialize batch edit service for ID-based approach
        let batchService = BatchEditService(
            batchId: batchId,
            repository: repositoryFactory.productionBatchRepository
        )
        self._batchEditService = StateObject(wrappedValue: batchService)
    }
    
    /// Initialize with batch object (legacy support)
    /// 使用批次对象初始化（向后兼容）
    init(
        batch: ProductionBatch,
        repositoryFactory: RepositoryFactory,
        authService: AuthenticationService,
        auditService: NewAuditingService
    ) {
        self.batch = batch
        self.batchId = nil
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        
        // Initialize services
        let permissionService = StandardBatchEditPermissionService(authService: authService)
        self._batchEditPermissionService = StateObject(wrappedValue: permissionService)
        
        let productionService = ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        )
        self._productionBatchService = StateObject(wrappedValue: productionService)
        
        // Create dummy batch edit service for legacy mode (not used)
        let dummyBatchService = BatchEditService(
            batchId: batch.id,
            repository: repositoryFactory.productionBatchRepository
        )
        self._batchEditService = StateObject(wrappedValue: dummyBatchService)
    }
    
    // MARK: - Computed Properties (计算属性)
    
    /// Get current batch information
    /// 获取当前批次信息
    private var currentBatchInfo: BatchDetailInfo? {
        if batchId != nil {
            // New ID-based approach
            return batchEditService.batchInfo
        } else if let batch = batch {
            // Legacy batch object approach
            return BatchDetailInfo(from: batch)
        }
        return nil
    }
    
    /// Check if currently loading batch data
    /// 检查是否正在加载批次数据
    private var isBatchLoading: Bool {
        // Only show loading for ID-based approach
        return batchId != nil ? batchEditService.isLoading : false
    }
    
    /// Get batch loading error message
    /// 获取批次加载错误信息
    private var batchErrorMessage: String? {
        // Only show errors for ID-based approach
        return batchId != nil ? batchEditService.errorMessage : nil
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isBatchLoading {
                    batchLoadingView
                } else if let errorMessage = batchErrorMessage {
                    batchErrorView(errorMessage)
                } else if let batchInfo = currentBatchInfo {
                    batchContentView(batchInfo)
                } else {
                    batchNotFoundView
                }
            }
        }
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - Loading and Error Views (加载和错误视图)
    
    private var batchLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载批次信息...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func batchErrorView(_ errorMessage: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("加载失败")
                .font(.headline)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("重试") {
                Task {
                    if batchId != nil {
                        await batchEditService.refreshBatch()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var batchNotFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("批次不存在")
                .font(.headline)
            
            Text("请检查批次是否已被删除或权限不足")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Main Content View (主内容视图)
    
    private func batchContentView(_ batchInfo: BatchDetailInfo) -> some View {
        Group {
            if isLoading {
                legacyLoadingView
            } else {
                batchDetailContentView(batchInfo)
            }
        }
        .navigationTitle("编辑批次")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            
            // Delete button - only for unsubmitted batches
            if batchInfo.status == .unsubmitted {
                ToolbarItem(placement: .destructiveAction) {
                    Menu {
                        Button("删除批次", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isDeleting || isSubmitting)
                }
            }
            
            // Submit button - only for unsubmitted batches
            if batchInfo.status == .unsubmitted {
                ToolbarItem(placement: .primaryAction) {
                    Button("提交") {
                        Task {
                            await submitBatch()
                        }
                    }
                    .disabled(isSubmitting || isDeleting)
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button("保存") {
                        Task {
                            await saveBatch()
                        }
                    }
                    .disabled(!hasChanges || isSaving || isDeleting || isSubmitting)
                }
            }
        }
        .task {
            await loadBatchData()
        }
        .alert("错误", isPresented: $showingError, presenting: errorMessage) { _ in
            Button("确定", role: .cancel) { }
        } message: { message in
            Text(message)
        }
        .alert("颜色限制编辑", isPresented: $showingColorOnlyWarning) {
            Button("继续", role: .cancel) { }
            Button("前往生产配置") {
                showingProductionConfigRedirect = true
            }
        } message: {
            Text("当前批次仅支持颜色修改。如需修改产品结构，请前往生产配置功能。")
        }
        .sheet(isPresented: $showingProductionConfigRedirect) {
            productionConfigRedirectSheet
        }
        .alert("删除确认", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                Task {
                    await deleteBatch()
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除这个未提交的批次吗？删除后无法恢复。")
        }
    }
    
    // MARK: - Loading View (加载视图)
    
    private var legacyLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在加载批次数据...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Implementation Methods (实现方法)
    
    /// Load initial data for the view
    /// 加载视图的初始数据
    private func loadInitialData() async {
        // Load batch information if using ID-based approach
        if batchId != nil {
            await batchEditService.loadBatch()
        }
        
        // Load additional data (product configs, colors) for both approaches
        if let batchInfo = currentBatchInfo {
            await loadAdditionalData(for: batchInfo)
        }
    }
    
    /// Load additional data needed for editing
    /// 加载编辑所需的额外数据
    private func loadAdditionalData(for batchInfo: BatchDetailInfo) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            async let productConfigsTask = repositoryFactory.productionBatchRepository.fetchProductConfigs(forBatch: batchInfo.id)
            async let colorsTask = repositoryFactory.colorRepository.fetchAllColors()
            
            let (configs, colors) = try await (productConfigsTask, colorsTask)
            
            await MainActor.run {
                self.productConfigs = configs
                self.originalProductConfigs = configs
                self.editedConfigs = configs
                self.availableColors = colors
                self.isLoading = false
            }
        } catch {
            await showError("加载批次数据失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    /// Main content view using BatchDetailInfo
    /// 使用BatchDetailInfo的主要内容视图
    private func batchDetailContentView(_ batchInfo: BatchDetailInfo) -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                batchInfoSection(batchInfo: batchInfo)
                productConfigSection
            }
            .padding()
        }
    }
    
    
    // MARK: - Batch Info Section (批次信息区域)
    
    private func batchInfoSection(batchInfo: BatchDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "批次信息", icon: "square.stack.3d.down.right")
            
            batchInfoCard(batchInfo: batchInfo)
            
            // Show execution info for completed batches
            if batchInfo.status == .completed, let executionInfo = batchInfo.executionTypeInfo {
                executionInfoCard(batchInfo: batchInfo, executionInfo: executionInfo)
            }
        }
    }
    
    private func batchInfoCard(batchInfo: BatchDetailInfo) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("批次号")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(batchInfo.batchNumber + " (" + batchInfo.batchType.displayName + ")")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                batchStatusBadge(status: batchInfo.status)
            }
            
            if batchInfo.isShiftBatch, let targetDate = batchInfo.targetDate, let shift = batchInfo.shift {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("日期")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(DateTimeUtilities.formatDate(targetDate))
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("班次")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: shift == .morning ? "sun.min" : "moon")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(shift == .morning ? .orange : .indigo)
                            
                            Text(shift.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设备")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(batchInfo.machineId)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if batchInfo.allowsColorModificationOnly {
                    colorOnlyBadge
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func batchStatusBadge(status: BatchStatus) -> some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(status.color.opacity(0.2))
            )
            .foregroundColor(status.color)
    }
    
    private var colorOnlyBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "paintpalette")
                .font(.system(size: 12, weight: .medium))
            
            Text("颜色模式")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(LopanColors.warning.opacity(0.2))
        )
        .foregroundColor(.orange)
    }
    
    // MARK: - Execution Info Card (执行信息卡片)
    
    private func executionInfoCard(batchInfo: BatchDetailInfo, executionInfo: (type: String, details: String)) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: batchInfo.isAutoCompleted ? "clock.arrow.circlepath" : "person.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(batchInfo.isAutoCompleted ? .blue : .green)
                        
                        Text(executionInfo.type)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Text(executionInfo.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if batchInfo.isAutoCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
            
            // Execution details section
            VStack(spacing: 12) {
                if batchInfo.isAutoCompleted {
                    // Auto-completed batch details
                    autoCompletedDetailsView(batchInfo: batchInfo)
                } else {
                    // Manual execution details
                    manualExecutionDetailsView(batchInfo: batchInfo)
                }
                
                // Runtime duration (common for both types)
                if let runtimeDuration = batchInfo.formattedRuntimeDuration {
                    runtimeDurationView(duration: runtimeDuration)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(batchInfo.isAutoCompleted ? LopanColors.primary.opacity(0.3) : LopanColors.success.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func autoCompletedDetailsView(batchInfo: BatchDetailInfo) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("班次时间")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: batchInfo.shift == .morning ? "sun.min" : "moon")
                        .font(.caption)
                        .foregroundColor(batchInfo.shift == .morning ? .orange : .indigo)
                    
                    Text(batchInfo.shift?.timeRangeDisplay ?? "未知班次")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            HStack {
                Text("执行日期")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let targetDate = batchInfo.targetDate {
                    Text(DateTimeUtilities.formatDate(targetDate))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func manualExecutionDetailsView(batchInfo: BatchDetailInfo) -> some View {
        VStack(spacing: 8) {
            if let executionTime = batchInfo.executionTime {
                HStack {
                    Text("执行时间")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(DateTimeUtilities.formatDateTime(executionTime))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            if let completedAt = batchInfo.completedAt {
                HStack {
                    Text("完成时间")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(DateTimeUtilities.formatDateTime(completedAt))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func runtimeDurationView(duration: String) -> some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("运行时长")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(duration)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LopanColors.primary.opacity(0.1))
                )
        }
    }
    
    // MARK: - Product Config Section (产品配置区域)
    
    private var productConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "产品配置", icon: "cube.box")
            
            if editedConfigs.isEmpty {
                productEmptyState
            } else {
                productConfigList
            }
        }
    }
    
    private var productEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.box")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("暂无产品配置")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("该批次尚未配置任何产品")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var productConfigList: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(editedConfigs.enumerated()), id: \.offset) { index, config in
                productConfigEditCard(config: binding(for: index), index: index)
            }
        }
    }
    
    private func productConfigEditCard(config: Binding<ProductConfig>, index: Int) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.wrappedValue.productName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("产品 #\(index + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if hasConfigChanged(at: index) {
                    changedIndicator
                }
            }
            
            colorDisplayFields(config: config)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hasConfigChanged(at: index) ? LopanColors.primary : Color.clear, lineWidth: 2)
        )
    }
    
    private func colorDisplayFields(config: Binding<ProductConfig>) -> some View {
        VStack(spacing: 12) {
            // Current color with edit capability for unsubmitted batches
            HStack {
                Text("颜色配置")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let batchInfo = currentBatchInfo, batchInfo.status == .unsubmitted {
                    Text("可编辑")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LopanColors.success.opacity(0.2))
                        )
                        .foregroundColor(.green)
                }
            }
            
            if let batchInfo = currentBatchInfo, batchInfo.status == .unsubmitted {
                colorSelectionRow(config: config)
            } else {
                // Display-only color for submitted batches
                HStack {
                    Text("主色")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorForId(config.wrappedValue.primaryColorId))
                            .frame(width: 16, height: 16)
                        
                        Text(colorNameForId(config.wrappedValue.primaryColorId))
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.tertiarySystemBackground))
                    )
                }
            }
            
            // Show other product details
            Spacer()
        }
    }
    
    private func colorSelectionRow(config: Binding<ProductConfig>) -> some View {
        HStack {
            Text("主色")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Menu {
                ForEach(availableColors, id: \.id) { color in
                    Button(color.name) {
                        config.wrappedValue.primaryColorId = color.id
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(colorForId(config.wrappedValue.primaryColorId))
                        .frame(width: 16, height: 16)
                    
                    Text(colorNameForId(config.wrappedValue.primaryColorId))
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
        }
    }
    
    private var changedIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(LopanColors.primary)
                .frame(width: 6, height: 6)
            
            Text("已修改")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
    }
    
    
    // MARK: - Production Config Redirect Sheet (生产配置跳转弹出框)
    
    private var productionConfigRedirectSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("前往生产配置")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("在生产配置中，您可以进行完整的产品结构编辑，包括添加、删除和修改产品参数。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                
                Button("打开生产配置") {
                    // This would navigate to production configuration
                    showingProductionConfigRedirect = false
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("生产配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingProductionConfigRedirect = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods (辅助方法)
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
    
    // Date formatting functions replaced with DateTimeUtilities
    
    private func binding(for index: Int) -> Binding<ProductConfig> {
        Binding(
            get: { editedConfigs[index] },
            set: { editedConfigs[index] = $0 }
        )
    }
    
    private func hasConfigChanged(at index: Int) -> Bool {
        guard index < editedConfigs.count && index < originalProductConfigs.count else { return false }
        
        let original = originalProductConfigs[index]
        let edited = editedConfigs[index]
        
        // For unsubmitted batches, allow color changes only
        if let batchInfo = currentBatchInfo, batchInfo.status == .unsubmitted {
            return original.primaryColorId != edited.primaryColorId
        }
        
        // For submitted batches, no changes allowed
        return false
    }
    
    private var hasChanges: Bool {
        return editedConfigs.enumerated().contains { index, _ in
            hasConfigChanged(at: index)
        }
    }
    
    private func colorForId(_ colorId: String) -> Color {
        availableColors.first { $0.id == colorId }?.swiftUIColor ?? .gray
    }
    
    private func colorNameForId(_ colorId: String) -> String {
        availableColors.first { $0.id == colorId }?.name ?? colorId
    }
    
    // MARK: - Data Loading and Actions (数据加载和操作)
    
    private func loadBatchData() async {
        // This method is kept for backward compatibility with legacy views
        // New ID-based views should use loadAdditionalData instead
        guard let batch = batch else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            async let productConfigsTask = repositoryFactory.productionBatchRepository.fetchProductConfigs(forBatch: batch.id)
            async let colorsTask = repositoryFactory.colorRepository.fetchAllColors()
            
            let (configs, colors) = try await (productConfigsTask, colorsTask)
            
            await MainActor.run {
                self.productConfigs = configs
                self.originalProductConfigs = configs
                self.editedConfigs = configs
                self.availableColors = colors
                self.isLoading = false
            }
        } catch {
            await showError("加载批次数据失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func saveBatch() async {
        guard hasChanges else { return }
        guard let batchInfo = currentBatchInfo else { return }
        
        await MainActor.run {
            isSaving = true
        }
        
        do {
            // Only allow saving for unsubmitted batches
            guard batchInfo.status == .unsubmitted else {
                await showError("只能编辑未提交的批次")
                await MainActor.run {
                    isSaving = false
                }
                return
            }
            
            // Save changes - only color changes are allowed for unsubmitted batches
            for editedConfig in editedConfigs {
                try await repositoryFactory.productionBatchRepository.updateProductConfig(editedConfig)
            }
            
            // Update batch using ID or legacy object
            if let batchId = batchId {
                // ID-based approach: fetch batch and update
                if let batch = try await repositoryFactory.productionBatchRepository.fetchBatchById(batchId) {
                    try await repositoryFactory.productionBatchRepository.updateBatch(batch)
                }
            } else if let batch = batch {
                // Legacy approach: direct update
                try await repositoryFactory.productionBatchRepository.updateBatch(batch)
            }
            
            // Reset original configs to reflect the saved state
            await MainActor.run {
                self.originalProductConfigs = self.editedConfigs
            }
            
        } catch {
            await showError("保存批次失败: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isSaving = false
        }
    }
    
    private func deleteBatch() async {
        guard let batchInfo = currentBatchInfo else { return }
        
        // Double-check status before deletion
        guard batchInfo.status == .unsubmitted else {
            await showError("只能删除未提交的批次")
            return
        }
        
        await MainActor.run {
            isDeleting = true
        }
        
        do {
            // Delete the batch using ID or legacy object
            if let batchId = batchId {
                try await repositoryFactory.productionBatchRepository.deleteBatch(id: batchId)
            } else if let batch = batch {
                try await repositoryFactory.productionBatchRepository.deleteBatch(batch)
            }
            
            // Create audit log for deletion
            await auditService.logOperation(
                operationType: .delete,
                entityType: .productionBatch,
                entityId: batchInfo.id,
                entityDescription: "Batch \(batchInfo.batchNumber)",
                operatorUserId: authService.currentUser?.id ?? "unknown",
                operatorUserName: authService.currentUser?.name ?? "Unknown User",
                operationDetails: [
                    "action": "delete_batch",
                    "batch_number": batchInfo.batchNumber,
                    "machine_id": batchInfo.machineId,
                    "status": batchInfo.status.rawValue
                ]
            )
            
            // Dismiss the view after successful deletion
            await MainActor.run {
                dismiss()
            }
        } catch {
            await showError("删除批次失败: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isDeleting = false
        }
    }
    
    private func submitBatch() async {
        guard let batchInfo = currentBatchInfo else { return }
        
        // Only allow submission of unsubmitted batches
        guard batchInfo.status == .unsubmitted else {
            await showError("只能提交未提交的批次")
            return
        }
        
        await MainActor.run {
            isSubmitting = true
        }
        
        do {
            // Save any pending changes first
            if hasChanges {
                for editedConfig in editedConfigs {
                    try await repositoryFactory.productionBatchRepository.updateProductConfig(editedConfig)
                }
            }
            
            // Submit the batch using the service - need to get actual batch object
            let batchToSubmit: ProductionBatch?
            if let batchId = batchId {
                batchToSubmit = try await repositoryFactory.productionBatchRepository.fetchBatchById(batchId)
            } else {
                batchToSubmit = batch
            }
            
            guard let actualBatch = batchToSubmit else {
                await showError("无法找到批次信息")
                await MainActor.run {
                    isSubmitting = false
                }
                return
            }
            
            let success = await productionBatchService.submitBatch(actualBatch)
            
            if success {
                await MainActor.run {
                    dismiss()
                }
            } else {
                await showError(productionBatchService.errorMessage ?? "提交批次失败")
            }
        } catch {
            await showError("提交批次失败: \(error.localizedDescription)")
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
struct BatchEditView_Previews: PreviewProvider {
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
        
        // Create a mock batch
        let mockBatch = ProductionBatch(
            machineId: "machine1",
            mode: .singleColor,
            submittedBy: "preview-user",
            submittedByName: "Preview User",
            batchNumber: "PC-20250814-0001",
            targetDate: Date(),
            shift: .morning
        )
        
        return BatchEditView(
            batch: mockBatch,
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}
