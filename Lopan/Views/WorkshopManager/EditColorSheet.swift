//
//  EditColorSheet.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/1.
//

import SwiftUI
import SwiftData

struct EditColorSheet: View {
    let color: ColorCard
    @ObservedObject var colorService: ColorService
    @Environment(\.dismiss) private var dismiss
    
    @State private var colorName: String
    @State private var selectedColor: Color
    @State private var isUpdating = false
    
    init(color: ColorCard, colorService: ColorService) {
        self.color = color
        self.colorService = colorService
        self._colorName = State(initialValue: color.name)
        self._selectedColor = State(initialValue: color.swiftUIColor)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    // Color preview
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedColor)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(LopanColors.secondary.opacity(0.3), lineWidth: 2)
                        )
                    
                    Text("#\(selectedColor.toHex())")
                        .font(.caption)
                        .monospaced()
                        .foregroundColor(LopanColors.textSecondary)
                }
                
                VStack(spacing: 16) {
                    LopanTextField(
                        title: "颜色名称",
                        placeholder: "请输入颜色名称",
                        text: $colorName,
                        variant: .outline,
                        state: colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .error : .normal,
                        isRequired: true,
                        icon: "paintpalette",
                        errorText: colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "颜色名称不能为空" : nil
                    )

                    ColorPicker("选择颜色", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                }
                
                // Original color info
                VStack(alignment: .leading, spacing: 8) {
                    Text("原始信息")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 4) {
                        HStack {
                            Text("名称:")
                                .foregroundColor(LopanColors.textSecondary)
                            Spacer()
                            Text(color.name)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("颜色:")
                                .foregroundColor(LopanColors.textSecondary)
                            Spacer()
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(LopanColors.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                Text(color.hexCode)
                                    .font(.caption)
                                    .monospaced()
                            }
                        }
                    }
                }
                .padding()
                .background {
                    if #available(iOS 26.0, *) {
                        LiquidGlassMaterial(type: .card, cornerRadius: 12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LopanColors.backgroundSecondary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    LopanButton(
                        "保存修改",
                        style: .primary,
                        isEnabled: !isFormInvalid && !isUpdating,
                        isLoading: isUpdating,
                        icon: "checkmark"
                    ) {
                        Task {
                            isUpdating = true
                            let success = await colorService.updateColor(
                                color,
                                name: colorName,
                                hexCode: "#\(selectedColor.toHex())"
                            )
                            isUpdating = false
                            if success {
                                dismiss()
                            }
                        }
                    }

                    LopanButton(
                        "取消",
                        style: .secondary,
                        isEnabled: !isUpdating
                    ) {
                        dismiss()
                    }
                }
            }
            .padding()
            .navigationTitle("编辑颜色")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LopanButton(
                        "取消",
                        style: .ghost,
                        isEnabled: !isUpdating
                    ) {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(colorService.errorMessage != nil)) {
                LopanButton("确定", style: .primary) {
                    colorService.clearError()
                }
            } message: {
                if let errorMessage = colorService.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private var isFormInvalid: Bool {
        let trimmedName = colorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty || 
               (trimmedName == color.name && selectedColor.toHex() == color.hexCode.replacingOccurrences(of: "#", with: ""))
    }
}


// MARK: - Preview
#if DEBUG
struct EditColorSheet_Previews: PreviewProvider {
    static var previews: some View {
        let sampleColor = ColorCard(
            name: "天空蓝",
            hexCode: "#87CEEB",
            createdBy: "admin"
        )
        
        // Use the existing LocalRepositoryFactory for preview
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
        
        let colorService = ColorService(
            colorRepository: repositoryFactory.colorRepository,
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        )
        
        EditColorSheet(color: sampleColor, colorService: colorService)
    }
}
#endif