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
    let batch: ProductionBatch
    let repositoryFactory: RepositoryFactory
    @ObservedObject var authService: AuthenticationService
    let auditService: NewAuditingService
    
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var batchEditPermissionService: StandardBatchEditPermissionService
    @StateObject private var productionBatchService: ProductionBatchService
    
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
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else {
                    simplifiedContentView
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
                if batch.status == .unsubmitted {
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
                if batch.status == .unsubmitted {
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
    }
    
    // MARK: - Loading View (加载视图)
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在加载批次数据...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Simplified Content View (简化内容视图)
    
    private var simplifiedContentView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                batchInfoSection
                productConfigSection
            }
            .padding()
        }
    }
    
    
    // MARK: - Batch Info Section (批次信息区域)
    
    private var batchInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "批次信息", icon: "square.stack.3d.down.right")
            
            batchInfoCard
        }
    }
    
    private var batchInfoCard: some View {
        VStack(spacing: 16) {
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
                
                batchStatusBadge
            }
            
            if batch.isShiftBatch, let targetDate = batch.targetDate, let shift = batch.shift {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("日期")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(targetDate))
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
                    
                    Text(batch.machineId)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if batch.allowsColorModificationOnly {
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
    
    private var batchStatusBadge: some View {
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
                .fill(Color.orange.opacity(0.2))
        )
        .foregroundColor(.orange)
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
                .stroke(hasConfigChanged(at: index) ? Color.blue : Color.clear, lineWidth: 2)
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
                
                if batch.status == .unsubmitted {
                    Text("可编辑")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green.opacity(0.2))
                        )
                        .foregroundColor(.green)
                }
            }
            
            if batch.status == .unsubmitted {
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
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("优先级")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(config.wrappedValue.priority)")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("预期产量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(config.wrappedValue.expectedOutput)")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
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
                .fill(Color.blue)
                .frame(width: 6, height: 6)
            
            Text("已修改")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
    }
    
    
    // MARK: - Production Config Redirect Sheet (生产配置跳转弹出框)
    
    private var productionConfigRedirectSheet: some View {
        NavigationView {
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
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
        if batch.status == .unsubmitted {
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
        
        await MainActor.run {
            isSaving = true
        }
        
        do {
            // Only allow saving for unsubmitted batches
            guard batch.status == .unsubmitted else {
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
            
            // Update batch timestamp
            try await repositoryFactory.productionBatchRepository.updateBatch(batch)
            
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
        // Double-check status before deletion
        guard batch.status == .unsubmitted else {
            await showError("只能删除未提交的批次")
            return
        }
        
        await MainActor.run {
            isDeleting = true
        }
        
        do {
            // Delete the batch
            try await repositoryFactory.productionBatchRepository.deleteBatch(batch)
            
            // Create audit log for deletion
            await auditService.logOperation(
                operationType: .delete,
                entityType: .productionBatch,
                entityId: batch.id,
                entityDescription: "Batch \(batch.batchNumber)",
                operatorUserId: authService.currentUser?.id ?? "unknown",
                operatorUserName: authService.currentUser?.name ?? "Unknown User",
                operationDetails: [
                    "action": "delete_batch",
                    "batch_number": batch.batchNumber,
                    "machine_id": batch.machineId,
                    "status": batch.status.rawValue
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
        // Only allow submission of unsubmitted batches
        guard batch.status == .unsubmitted else {
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
            
            // Submit the batch using the service
            let success = await productionBatchService.submitBatch(batch)
            
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
            batchNumber: "BATCH-20250813-0001",
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
