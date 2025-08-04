import SwiftUI

/// Step-by-step conflict resolution wizard for batch operations
struct BatchConflictResolutionSheet: View {
    
    // MARK: - Properties
    
    @ObservedObject private var coordinator: BatchOperationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep: ResolutionStep = .overview
    @State private var selectedConflict: ConfigurationConflict?
    @State private var resolutions: [ConflictResolution] = []
    @State private var isProcessing: Bool = false
    @State private var resolutionStrategy: ResolutionStrategy = .automatic
    @State private var resolutionNotes: String = ""
    
    private let conflicts: [ConfigurationConflict]
    private let onResolutionComplete: ([ConflictResolution]) -> Void
    
    // MARK: - Computed Properties
    
    private var progressValue: Double {
        switch currentStep {
        case .overview: return 0.25
        case .selectConflict: return 0.5
        case .chooseResolution: return 0.75
        case .confirmation: return 1.0
        }
    }
    
    private var sortedConflicts: [ConfigurationConflict] {
        conflicts.sorted { $0.severity.rawValue > $1.severity.rawValue }
    }
    
    private var autoResolvableConflicts: [ConfigurationConflict] {
        conflicts.filter { $0.canAutoResolve }
    }
    
    private var manualConflicts: [ConfigurationConflict] {
        conflicts.filter { !$0.canAutoResolve }
    }
    
    // MARK: - Initialization
    
    init(
        coordinator: BatchOperationCoordinator,
        conflicts: [ConfigurationConflict],
        onResolutionComplete: @escaping ([ConflictResolution]) -> Void
    ) {
        self.coordinator = coordinator
        self.conflicts = conflicts
        self.onResolutionComplete = onResolutionComplete
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Main content
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("冲突解决")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .processingOverlay(
            isProcessing: isProcessing,
            message: "正在处理冲突解决..."
        )
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            ProgressView(value: progressValue)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            HStack {
                ForEach(ResolutionStep.allCases, id: \.self) { step in
                    HStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 12, height: 12)
                        
                        if step != .confirmation {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
            }
            
            Text(currentStep.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .overview:
            overviewStep
        case .selectConflict:
            conflictSelectionStep
        case .chooseResolution:
            resolutionChoiceStep
        case .confirmation:
            confirmationStep
        }
    }
    
    // MARK: - Overview Step
    
    private var overviewStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("检测到配置冲突")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("在继续批量审批之前，需要解决以下配置冲突")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Conflict summary
                LopanCard {
                    VStack(spacing: 16) {
                        HStack {
                            Text("冲突概览")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 20) {
                            ConflictMetric(
                                title: "总冲突数",
                                value: "\(conflicts.count)",
                                color: .orange
                            )
                            
                            ConflictMetric(
                                title: "自动解决",
                                value: "\(autoResolvableConflicts.count)",
                                color: .green
                            )
                            
                            ConflictMetric(
                                title: "需手动处理",
                                value: "\(manualConflicts.count)",
                                color: .red
                            )
                        }
                    }
                }
                
                // Conflict types breakdown
                if !conflicts.isEmpty {
                    conflictTypesBreakdown
                }
                
                // Auto-resolution option
                if !autoResolvableConflicts.isEmpty {
                    autoResolutionOption
                }
            }
            .padding()
        }
    }
    
    private var conflictTypesBreakdown: some View {
        LopanCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("冲突类型分布")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                let conflictGroups = Dictionary(grouping: conflicts, by: { $0.type })
                
                ForEach(Array(conflictGroups.keys).sorted(by: { $0.severity.rawValue > $1.severity.rawValue }), id: \.self) { type in
                    ConflictTypeRow(
                        type: type,
                        count: conflictGroups[type]?.count ?? 0,
                        conflicts: conflictGroups[type] ?? []
                    )
                }
            }
        }
    }
    
    private var autoResolutionOption: some View {
        LopanCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.blue)
                    
                    Text("自动解决建议")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                Text("系统可以自动解决 \(autoResolvableConflicts.count) 个冲突，您可以选择先尝试自动解决。")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Button("自动解决所有可解决的冲突") {
                    performAutoResolution()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
        }
    }
    
    // MARK: - Conflict Selection Step
    
    private var conflictSelectionStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("选择要解决的冲突")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("请选择一个冲突进行详细查看和解决")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                LazyVStack(spacing: 12) {
                    ForEach(sortedConflicts, id: \.id) { conflict in
                        ConflictSelectionCard(
                            conflict: conflict,
                            isSelected: selectedConflict?.id == conflict.id
                        ) {
                            selectedConflict = conflict
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Resolution Choice Step
    
    private var resolutionChoiceStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let conflict = selectedConflict {
                    // Conflict details
                    ConflictDetailCard(conflict: conflict)
                    
                    // Resolution options
                    ResolutionOptionsCard(
                        conflict: conflict,
                        selectedStrategy: $resolutionStrategy,
                        notes: $resolutionNotes
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Confirmation Step
    
    private var confirmationStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("解决方案确认")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("请确认以下解决方案并执行")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Resolution summary
                if !resolutions.isEmpty {
                    ResolutionSummaryCard(resolutions: resolutions)
                }
                
                // Final action button
                Button("执行解决方案") {
                    executeResolutions()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || resolutions.isEmpty)
            }
            .padding()
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            if currentStep != .overview {
                Button("上一步") {
                    goToPreviousStep()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button(nextButtonTitle) {
                goToNextStep()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canProceedToNextStep)
        }
        .padding()
    }
    
    
    // MARK: - Helper Properties
    
    private var nextButtonTitle: String {
        switch currentStep {
        case .overview: return "开始解决"
        case .selectConflict: return selectedConflict != nil ? "下一步" : "选择冲突"
        case .chooseResolution: return "确认方案"
        case .confirmation: return "完成"
        }
    }
    
    private var canProceedToNextStep: Bool {
        switch currentStep {
        case .overview: return true
        case .selectConflict: return selectedConflict != nil
        case .chooseResolution: return !resolutionNotes.isEmpty || resolutionStrategy == .automatic
        case .confirmation: return !resolutions.isEmpty
        }
    }
    
    // MARK: - Methods
    
    private func stepColor(for step: ResolutionStep) -> Color {
        if step.rawValue <= currentStep.rawValue {
            return .blue
        } else {
            return Color.secondary.opacity(0.3)
        }
    }
    
    private func goToNextStep() {
        switch currentStep {
        case .overview:
            currentStep = .selectConflict
        case .selectConflict:
            if selectedConflict != nil {
                currentStep = .chooseResolution
            }
        case .chooseResolution:
            if let conflict = selectedConflict {
                createResolution(for: conflict)
                currentStep = .confirmation
            }
        case .confirmation:
            dismiss()
        }
    }
    
    private func goToPreviousStep() {
        switch currentStep {
        case .overview:
            break
        case .selectConflict:
            currentStep = .overview
        case .chooseResolution:
            currentStep = .selectConflict
        case .confirmation:
            currentStep = .chooseResolution
        }
    }
    
    private func createResolution(for conflict: ConfigurationConflict) {
        let resolution = ConflictResolution(
            conflictType: conflict.type,
            conflictDescription: conflict.description,
            resolutionStrategy: resolutionStrategy,
            resolutionDetails: resolutionNotes,
            resolvedBy: coordinator.currentWorkflow?.coordinatorId ?? "",
            impactedMachineIds: conflict.affectedMachineIds
        )
        
        resolutions.append(resolution)
    }
    
    private func performAutoResolution() {
        Task {
            isProcessing = true
            
            do {
                let autoResolutions = try await coordinator.batchRepository.autoResolveConflicts(autoResolvableConflicts)
                resolutions.append(contentsOf: autoResolutions)
                
                // Move to confirmation if all conflicts are resolved
                if manualConflicts.isEmpty {
                    currentStep = .confirmation
                } else {
                    currentStep = .selectConflict
                }
                
            } catch {
                // Handle error
                print("Auto-resolution failed: \(error)")
            }
            
            isProcessing = false
        }
    }
    
    private func executeResolutions() {
        Task {
            isProcessing = true
            
            do {
                for resolution in resolutions {
                    try await coordinator.resolveConflict(
                        conflicts.first { $0.type == resolution.conflictType }!,
                        resolution: resolution
                    )
                }
                
                onResolutionComplete(resolutions)
                dismiss()
                
            } catch {
                // Handle error
                print("Resolution execution failed: \(error)")
            }
            
            isProcessing = false
        }
    }
}

// MARK: - Supporting Views

struct ConflictMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ConflictTypeRow: View {
    let type: ConflictType
    let count: Int
    let conflicts: [ConfigurationConflict]
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(type.severity.color))
                    .frame(width: 8, height: 8)
                
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

struct ConflictSelectionCard: View {
    let conflict: ConfigurationConflict
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            LopanCard {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(conflict.type.displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            ConflictSeverityBadge(severity: conflict.severity)
                        }
                        
                        Text(conflict.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        if !conflict.affectedMachineIds.isEmpty {
                            Text("影响设备: \(conflict.affectedMachineIds.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ConflictDetailCard: View {
    let conflict: ConfigurationConflict
    
    var body: some View {
        LopanCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("冲突详情")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    ConflictSeverityBadge(severity: conflict.severity)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(title: "类型", value: conflict.type.displayName)
                    DetailRow(title: "描述", value: conflict.description)
                    
                    if !conflict.affectedMachineIds.isEmpty {
                        DetailRow(title: "影响设备", value: conflict.affectedMachineIds.joined(separator: ", "))
                    }
                    
                    if let suggestion = conflict.suggestedResolution {
                        DetailRow(title: "建议解决方案", value: suggestion)
                    }
                    
                    DetailRow(title: "检测时间", value: conflict.detectedAt.formatted())
                    DetailRow(title: "可自动解决", value: conflict.canAutoResolve ? "是" : "否")
                }
            }
        }
    }
}

struct ResolutionOptionsCard: View {
    let conflict: ConfigurationConflict
    @Binding var selectedStrategy: ResolutionStrategy
    @Binding var notes: String
    
    var body: some View {
        LopanCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("选择解决策略")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    ForEach(ResolutionStrategy.allCases, id: \.self) { strategy in
                        ResolutionStrategyOption(
                            strategy: strategy,
                            isSelected: selectedStrategy == strategy,
                            isAvailable: isStrategyAvailable(strategy, for: conflict)
                        ) {
                            selectedStrategy = strategy
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("解决备注")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("输入解决方案详情...", text: $notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
            }
        }
    }
    
    private func isStrategyAvailable(_ strategy: ResolutionStrategy, for conflict: ConfigurationConflict) -> Bool {
        switch strategy {
        case .automatic:
            return conflict.canAutoResolve
        case .manual, .escalated, .postponed, .cancelled:
            return true
        }
    }
}

struct ResolutionStrategyOption: View {
    let strategy: ResolutionStrategy
    let isSelected: Bool
    let isAvailable: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(strategy.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isAvailable ? .primary : .secondary)
                    
                    Text(strategyDescription(strategy))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isAvailable)
    }
    
    private func strategyDescription(_ strategy: ResolutionStrategy) -> String {
        switch strategy {
        case .automatic:
            return "系统自动解决此冲突"
        case .manual:
            return "手动解决此冲突"
        case .escalated:
            return "上报给管理员处理"
        case .postponed:
            return "延后处理此冲突"
        case .cancelled:
            return "取消相关操作"
        }
    }
}

struct ResolutionSummaryCard: View {
    let resolutions: [ConflictResolution]
    
    var body: some View {
        LopanCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("解决方案摘要")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                ForEach(resolutions, id: \.id) { resolution in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(resolution.conflictType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(resolution.resolutionStrategy.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        if !resolution.resolutionDetails.isEmpty {
                            Text(resolution.resolutionDetails)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if resolution.id != resolutions.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct ConflictSeverityBadge: View {
    let severity: ConflictSeverity
    
    var body: some View {
        Text(severity.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(severity.color).opacity(0.2))
            .foregroundColor(Color(severity.color))
            .cornerRadius(8)
    }
}

// MARK: - Supporting Types

enum ResolutionStep: Int, CaseIterable {
    case overview = 0
    case selectConflict = 1
    case chooseResolution = 2
    case confirmation = 3
    
    var description: String {
        switch self {
        case .overview: return "1. 冲突概览"
        case .selectConflict: return "2. 选择冲突"
        case .chooseResolution: return "3. 选择方案"
        case .confirmation: return "4. 确认执行"
        }
    }
}