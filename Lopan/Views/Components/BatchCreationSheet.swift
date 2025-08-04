import SwiftUI

/// Sheet for creating new production batches
struct BatchCreationSheet: View {
    
    // MARK: - Properties
    
    @ObservedObject var coordinator: BatchOperationCoordinator
    let targetDate: Date
    @Environment(\.dismiss) private var dismiss
    
    @State private var batchName = ""
    @State private var selectedMachineId = ""
    @State private var selectedMode: ProductionMode = .singleColor
    @State private var priority: ApprovalPriority = .medium
    @State private var notes = ""
    @State private var isCreating = false
    @State private var availableMachines: [String] = []
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("批次名称", text: $batchName)
                    
                    Picker("生产设备", selection: $selectedMachineId) {
                        ForEach(availableMachines, id: \.self) { machineId in
                            Text("设备 \(machineId)").tag(machineId)
                        }
                    }
                    
                    Picker("生产模式", selection: $selectedMode) {
                        ForEach(ProductionMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    
                    Picker("优先级", selection: $priority) {
                        ForEach(ApprovalPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                }
                
                Section("配置详情") {
                    DatePicker("目标日期", selection: .constant(targetDate), displayedComponents: .date)
                        .disabled(true)
                    
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section("创建选项") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        Text("批次将以待审批状态创建")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("创建生产批次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        createBatch()
                    }
                    .disabled(!canCreateBatch || isCreating)
                }
            }
            .onAppear {
                loadAvailableMachines()
            }
        }
        .interactiveDismissDisabled(isCreating)
    }
    
    // MARK: - Computed Properties
    
    private var canCreateBatch: Bool {
        !batchName.isEmpty && !selectedMachineId.isEmpty
    }
    
    // MARK: - Helper Methods
    
    private func loadAvailableMachines() {
        // For now, use placeholder machine IDs
        // In production, this would fetch from machine repository
        availableMachines = ["M001", "M002", "M003", "M004", "M005"]
        if !availableMachines.isEmpty {
            selectedMachineId = availableMachines[0]
        }
    }
    
    private func createBatch() {
        guard canCreateBatch else { return }
        
        isCreating = true
        
        Task {
            do {
                // Create a new production batch
                let batch = ProductionBatch(
                    machineId: selectedMachineId,
                    mode: selectedMode,
                    submittedBy: "current_user", // Would get from auth service
                    submittedByName: "Current User" // Would get from auth service
                )
                
                // Add basic product configuration if needed
                // This is a simplified version - in production would have full product configuration
                
                // For now, just create an empty batch
                // The user can add products through the regular production configuration interface
                
                print("Created batch: \(batch.id) for machine \(selectedMachineId)")
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isCreating = false
                    print("Failed to create batch: \(error)")
                }
            }
        }
    }
}

// MARK: - Extensions
// Extensions removed as they already exist in the model files