import SwiftUI
import SwiftData

/// Main dashboard for batch processing and approval workflows
struct BatchProcessingDashboardView: View {
    
    // MARK: - Properties
    
    let repositoryFactory: RepositoryFactory
    @ObservedObject var authService: AuthenticationService
    let auditService: NewAuditingService
    
    @ObservedObject var coordinator: BatchOperationCoordinator
    @ObservedObject var productionBatchService: ProductionBatchService
    @ObservedObject var sessionService: SessionSecurityService
    
    @State private var selectedDate = Date()
    @State private var activeSheet: SheetType?
    @State private var isProcessing = false
    
    enum SheetType: Identifiable {
        case templateSelector
        case batchCreation
        case conflictResolution
        
        var id: String {
            switch self {
            case .templateSelector: return "templateSelector"
            case .batchCreation: return "batchCreation"
            case .conflictResolution: return "conflictResolution"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        repositoryFactory: RepositoryFactory, 
        authService: AuthenticationService, 
        auditService: NewAuditingService,
        coordinator: BatchOperationCoordinator,
        productionBatchService: ProductionBatchService,
        sessionService: SessionSecurityService
    ) {
        self.repositoryFactory = repositoryFactory
        self.authService = authService
        self.auditService = auditService
        self.coordinator = coordinator
        self.productionBatchService = productionBatchService
        self.sessionService = sessionService
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date selection and quick actions
            headerSection
            
            // Main content area
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Workflow status overview
                    workflowStatusSection
                    
                    // Batch processing interface
                    batchProcessingSection
                    
                    // Quick actions
                    quickActionsSection
                    
                    // Analytics overview
                    analyticsSection
                }
                .padding()
                // Add bottom padding to account for tab bar
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 34)
                }
            }
        }
        .navigationTitle("批次处理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await initializeWorkflow()
            }
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .templateSelector:
                BatchTemplateSelector(
                    coordinator: coordinator,
                    onTemplateSelected: handleTemplateSelection
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .batchCreation:
                BatchCreationSheet(
                    coordinator: coordinator,
                    targetDate: selectedDate
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .conflictResolution:
                BatchConflictResolutionSheet(
                    coordinator: coordinator,
                    conflicts: coordinator.activeConflicts,
                    onResolutionComplete: handleConflictResolution
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("批次处理中心")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("管理和审批生产批次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Date selector
                DatePicker("目标日期", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: selectedDate) { _, newDate in
                        Task {
                            await refreshWorkflow(for: newDate)
                        }
                    }
            }
            .padding(.horizontal)
            
            // Quick status bar
            HStack {
                DashboardStatusBadge(
                    title: "待处理批次",
                    count: coordinator.availableBatches.count,
                    color: .orange
                )
                
                DashboardStatusBadge(
                    title: "活跃冲突",
                    count: coordinator.activeConflicts.count,
                    color: coordinator.activeConflicts.isEmpty ? .green : .red
                )
                
                DashboardStatusBadge(
                    title: "审批组",
                    count: coordinator.batchGroups.count,
                    color: .blue
                )
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Workflow Status Section
    
    private var workflowStatusSection: some View {
        LopanCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                    Text("工作流状态")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                if let workflow = coordinator.currentWorkflow {
                    HStack {
                        Circle()
                            .fill(workflowStatusColor(workflow.status.color))
                            .frame(width: 12, height: 12)
                        Text(workflow.status.displayText)
                            .font(.headline)
                        Spacer()
                        Text(workflow.targetDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if coordinator.isProcessing {
                        ProgressView(value: coordinator.workflowProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text(coordinator.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("无活跃工作流")
                        .foregroundColor(.secondary)
                    
                    Button("启动新工作流") {
                        Task {
                            await initiateNewWorkflow()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    // MARK: - Batch Processing Section
    
    private var batchProcessingSection: some View {
        LopanCard(variant: .elevated) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "square.stack.3d.down.right")
                        .foregroundColor(.blue)
                    Text("批次处理")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                if coordinator.currentWorkflow != nil {
                    // Batch selection interface
                    BatchMultiSelectInterface(
                        coordinator: coordinator,
                        targetDate: selectedDate,
                        onSelectionChanged: handleBatchSelectionChanged
                    )
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                } else {
                    EmptyStateView(
                        icon: "square.stack.3d.down.right",
                        title: "无可用批次",
                        subtitle: "请先启动工作流以查看可用批次"
                    )
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        LopanCard(variant: .elevated) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.blue)
                    Text("快速操作")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    QuickActionButton(
                        title: "应用模板",
                        icon: "doc.text.below.ecg",
                        color: .blue
                    ) {
                        activeSheet = .templateSelector
                    }
                    
                    QuickActionButton(
                        title: "创建批次",
                        icon: "plus.square",
                        color: .green
                    ) {
                        activeSheet = .batchCreation
                    }
                    
                    QuickActionButton(
                        title: "解决冲突",
                        icon: "exclamationmark.triangle",
                        color: .orange,
                        isEnabled: !coordinator.activeConflicts.isEmpty
                    ) {
                        activeSheet = .conflictResolution
                    }
                    
                    QuickActionButton(
                        title: "复制配置",
                        icon: "doc.on.doc",
                        color: .purple
                    ) {
                        Task {
                            await copyPreviousConfiguration()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Analytics Section
    
    private var analyticsSection: some View {
        LopanCard(variant: .elevated) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                    Text("今日概览")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    HStack {
                        AnalyticsItem(
                            title: "处理效率",
                            value: String(format: "%.1f%%", coordinator.workflowProgress * 100),
                            icon: "speedometer",
                            color: .blue
                        )
                        
                        AnalyticsItem(
                            title: "冲突解决率",
                            value: "85%", // This would come from analytics
                            icon: "checkmark.shield",
                            color: .green
                        )
                    }
                    
                    HStack {
                        AnalyticsItem(
                            title: "设备利用率",
                            value: "78%", // This would come from analytics
                            icon: "gear",
                            color: .orange
                        )
                        
                        AnalyticsItem(
                            title: "平均处理时间",
                            value: "2.3分钟", // This would come from analytics
                            icon: "clock",
                            color: .purple
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeWorkflow() async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            try await coordinator.initiateApprovalWorkflow(
                for: selectedDate,
                coordinatorId: currentUser.id
            )
        } catch {
            print("Failed to initialize workflow: \(error)")
        }
    }
    
    private func initiateNewWorkflow() async {
        guard let currentUser = authService.currentUser else { return }
        
        do {
            try await coordinator.initiateApprovalWorkflow(
                for: selectedDate,
                coordinatorId: currentUser.id
            )
        } catch {
            print("Failed to initiate new workflow: \(error)")
        }
    }
    
    private func refreshWorkflow(for date: Date) async {
        selectedDate = date
        await initializeWorkflow()
    }
    
    private func handleBatchSelectionChanged(_ selectedBatchIds: Set<String>) {
        // Handle batch selection changes
        print("Selected batches: \(selectedBatchIds)")
    }
    
    private func handleTemplateSelection(template: BatchTemplate) {
        // Handle template selection
        activeSheet = nil
        print("Selected template: \(template.name)")
    }
    
    private func handleConflictResolution(_ resolutions: [ConflictResolution]) {
        activeSheet = nil
        print("Resolved \(resolutions.count) conflicts")
    }
    
    private func copyPreviousConfiguration() async {
        // Implementation for copying previous day's configuration
        let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        
        guard let currentUser = authService.currentUser else { return }
        
        do {
            _ = try await coordinator.batchRepository.copyConfiguration(
                from: previousDate,
                to: selectedDate,
                machineIds: nil,
                coordinatorId: currentUser.id
            )
            await refreshWorkflow(for: selectedDate)
        } catch {
            print("Failed to copy configuration: \(error)")
        }
    }
    
    private func workflowStatusColor(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Supporting Views

struct DashboardStatusBadge: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? color : .gray)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .primary : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? color.opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
        .disabled(!isEnabled)
    }
}

struct AnalyticsItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

// MARK: - Extensions
// WorkflowStatus extensions are defined in BatchOperationCoordinator.swift