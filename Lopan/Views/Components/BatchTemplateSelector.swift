import SwiftUI

/// Template selector for batch operations
struct BatchTemplateSelector: View {
    
    // MARK: - Properties
    
    @ObservedObject var coordinator: BatchOperationCoordinator
    let onTemplateSelected: (BatchTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var templates: [BatchTemplate] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedPriority: TemplatePriority?
    
    // MARK: - Computed Properties
    
    private var filteredTemplates: [BatchTemplate] {
        templates.filter { template in
            let matchesSearch = searchText.isEmpty || template.name.localizedCaseInsensitiveContains(searchText)
            let matchesPriority = selectedPriority == nil || template.priority == selectedPriority
            return matchesSearch && matchesPriority && template.isActive
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter section
                searchSection
                
                // Templates list
                templatesList
            }
            .navigationTitle("选择批次模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadTemplates()
            }
        }
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索模板...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("清除") {
                        searchText = ""
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Priority filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PriorityFilterChip(
                        title: "全部",
                        isSelected: selectedPriority == nil
                    ) {
                        selectedPriority = nil
                    }
                    
                    ForEach(TemplatePriority.allCases, id: \.self) { priority in
                        PriorityFilterChip(
                            title: priority.displayName,
                            isSelected: selectedPriority == priority
                        ) {
                            selectedPriority = selectedPriority == priority ? nil : priority
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Templates List
    
    private var templatesList: some View {
        Group {
            if isLoading {
                ProgressView("加载模板中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTemplates.isEmpty {
                EmptyTemplatesList(searchText: searchText, selectedPriority: selectedPriority)
            } else {
                List(filteredTemplates, id: \.id) { template in
                    TemplateRow(template: template) {
                        onTemplateSelected(template)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTemplates() {
        Task {
            do {
                templates = try await coordinator.batchRepository.fetchBatchTemplates()
                isLoading = false
            } catch {
                print("Failed to load templates: \(error)")
                isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views

struct PriorityFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TemplateRow: View {
    let template: BatchTemplate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Priority indicator
                Circle()
                    .fill(priorityColor(template.priority.color))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(template.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(template.priority.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(priorityColor(template.priority.color).opacity(0.2))
                            )
                            .foregroundColor(priorityColor(template.priority.color))
                    }
                    
                    Text(template.templateDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Label("\(template.productTemplates.count) 产品", systemImage: "cube.box")
                        
                        if !template.applicableMachines.isEmpty {
                            Label("\(template.applicableMachines.count) 设备", systemImage: "gear")
                        }
                        
                        Spacer()
                        
                        Text("更新于 \(template.lastModifiedAt, style: .date)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyTemplatesList: View {
    let searchText: String
    let selectedPriority: TemplatePriority?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(emptyMessage)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(emptySubMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
    
    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "无搜索结果"
        } else if selectedPriority != nil {
            return "无匹配模板"
        } else {
            return "暂无可用模板"
        }
    }
    
    private var emptySubMessage: String {
        if !searchText.isEmpty {
            return "尝试调整搜索关键词或筛选条件"
        } else {
            return "请先创建批次模板以便快速应用配置"
        }
    }
}

// MARK: - Helper Functions

private func priorityColor(_ colorString: String) -> Color {
    switch colorString {
    case "gray": return .gray
    case "blue": return .blue
    case "orange": return .orange
    case "red": return .red
    default: return .gray
    }
}