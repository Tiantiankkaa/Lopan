//
//  ColorManagementView.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI
import SwiftData

struct ColorManagementView: View {
    @StateObject private var colorService: ColorService
    @ObservedObject private var authService: AuthenticationService
    
    @Binding var showingAddColor: Bool
    @State private var showingEditColor = false
    @State private var selectedColorForEdit: ColorCard?
    @State private var searchText = ""
    
    // Dependencies needed for ColorService creation
    let repositoryFactory: RepositoryFactory
    let auditService: NewAuditingService
    
    init(authService: AuthenticationService, repositoryFactory: RepositoryFactory, auditService: NewAuditingService, showingAddColor: Binding<Bool>) {
        self.authService = authService
        self.repositoryFactory = repositoryFactory
        self.auditService = auditService
        self._showingAddColor = showingAddColor
        
        // Create ColorService in a safer way
        self._colorService = StateObject(wrappedValue: ColorService(
            colorRepository: repositoryFactory.colorRepository,
            machineRepository: repositoryFactory.machineRepository,
            auditService: auditService,
            authService: authService
        ))
    }
    
    var filteredColors: [ColorCard] {
        if searchText.isEmpty {
            return colorService.colors
        } else {
            return colorService.colors.filter { color in
                color.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if colorService.isLoading {
                    ProgressView("加载颜色卡...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredColors.isEmpty {
                    if searchText.isEmpty {
                        emptyStateView
                    } else {
                        searchEmptyView
                    }
                } else {
                    colorGridView
                }
            }
            .navigationTitle("颜色管理")
            .navigationBarBackButtonHidden(true)
            .searchable(text: $searchText, prompt: "搜索颜色")
            .refreshable {
                await colorService.loadColors()
            }
            .alert("Error", isPresented: .constant(colorService.errorMessage != nil)) {
            Button("确定") {
                colorService.clearError()
            }
        } message: {
            if let errorMessage = colorService.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingAddColor) {
            AddColorSheet(colorService: colorService)
        }
        .sheet(isPresented: $showingEditColor) {
            if let colorToEdit = selectedColorForEdit {
                EditColorSheet(color: colorToEdit, colorService: colorService)
            }
        }
        .task {
            await colorService.loadColors()
        }
        .safeAreaInset(edge: .bottom) {
            // Floating Action Button
            if canManageColors {
                HStack {
                    Spacer()
                    Button(action: {
                        showingAddColor = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("添加颜色")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(LopanColors.primary)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "paintpalette")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("暂无颜色卡")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("创建第一个颜色卡来开始配置生产")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if canManageColors {
                Button("添加颜色") {
                    showingAddColor = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchEmptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("未找到匹配的颜色")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Color Grid View
    private var colorGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredColors, id: \.id) { color in
                    ColorCardView(
                        color: color,
                        onEdit: canManageColors ? { editColor(color) } : nil,
                        onDelete: canManageColors ? { deleteColor(color) } : nil
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Properties
    private var canManageColors: Bool {
        authService.currentUser?.hasRole(.workshopManager) == true ||
        authService.currentUser?.hasRole(.administrator) == true
    }
    
    // MARK: - Actions
    private func editColor(_ color: ColorCard) {
        selectedColorForEdit = color
        showingEditColor = true
    }
    
    private func deleteColor(_ color: ColorCard) {
        Task {
            await colorService.deleteColor(color)
        }
    }
}

// MARK: - Color Card Component
struct ColorCardView: View {
    let color: ColorCard
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 12) {
            // Color preview
            RoundedRectangle(cornerRadius: 12)
                .fill(color.swiftUIColor)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LopanColors.secondary.opacity(0.3), lineWidth: 1)
                )
            
            // Color info
            VStack(spacing: 4) {
                Text(color.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(color.hexCode)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospaced()
            }
            
            // Status indicator
            if !color.isActive {
                Text("已停用")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(LopanColors.warning.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .contextMenu {
            if let onEdit = onEdit {
                Button("编辑", action: onEdit)
            }
            if let onDelete = onDelete {
                Button("删除", role: .destructive, action: onDelete)
            }
        }
        .onLongPressGesture {
            if let onEdit = onEdit {
                onEdit()
            }
        }
    }
}

// MARK: - Add Color Sheet
struct AddColorSheet: View {
    @ObservedObject var colorService: ColorService
    @Environment(\.dismiss) private var dismiss
    
    @State private var colorName = ""
    @State private var selectedColor = LopanColors.primary
    @State private var isAdding = false
    
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
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    TextField("颜色名称", text: $colorName)
                        .textFieldStyle(.roundedBorder)
                    
                    ColorPicker("选择颜色", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("添加颜色") {
                        Task {
                            isAdding = true
                            let success = await colorService.addColor(
                                name: colorName,
                                hexCode: "#\(selectedColor.toHex())"
                            )
                            isAdding = false
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAdding)
                    
                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isAdding)
                }
            }
            .padding()
            .navigationTitle("添加颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct ColorManagementView_Previews: PreviewProvider {
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
        
        ColorManagementView(
            authService: authService,
            repositoryFactory: repositoryFactory,
            auditService: auditService,
            showingAddColor: .constant(false)
        )
    }
}