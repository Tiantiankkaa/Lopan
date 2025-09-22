//
//  SystemConfigurationView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import SwiftData

// MARK: - System Configuration Main View (系统配置主视图)

/// Comprehensive system configuration management interface
/// 综合系统配置管理界面
struct SystemConfigurationView: View {
    @Environment(\.appDependencies) private var appDependencies
    
    @State private var selectedTab = 0
    @State private var showingSecuritySettings = false
    @State private var showingChangeRequests = false
    @State private var showingConfigurationHistory = false
    
    private var configurationService: SystemConfigurationService {
        appDependencies.serviceFactory.systemConfigurationService
    }
    
    private var securityService: ConfigurationSecurityService {
        appDependencies.serviceFactory.configurationSecurityService
    }

    var body: some View {
        VStack(spacing: 0) {
                // Header with quick actions
                headerSection
                
                // Tab view for different configuration sections
                TabView(selection: $selectedTab) {
                    // General Settings
                    ConfigurationCategoryView(
                        category: .system,
                        configurationService: configurationService
                    )
                    .tabItem {
                        Label("系统设置", systemImage: "gear")
                    }
                    .tag(0)
                    
                    // Security Settings
                    ConfigurationCategoryView(
                        category: .security,
                        configurationService: configurationService
                    )
                    .tabItem {
                        Label("安全设置", systemImage: "lock.shield")
                    }
                    .tag(1)
                    
                    // Production Settings
                    ConfigurationCategoryView(
                        category: .production,
                        configurationService: configurationService
                    )
                    .tabItem {
                        Label("生产设置", systemImage: "factory")
                    }
                    .tag(2)
                    
                    // Notification Settings
                    ConfigurationCategoryView(
                        category: .notification,
                        configurationService: configurationService
                    )
                    .tabItem {
                        Label("通知设置", systemImage: "bell")
                    }
                    .tag(3)
                    
                    // Performance Settings
                    ConfigurationCategoryView(
                        category: .performance,
                        configurationService: configurationService
                    )
                    .tabItem {
                        Label("性能设置", systemImage: "speedometer")
                    }
                    .tag(4)
                }
            }
            .navigationTitle("系统配置")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("变更请求") {
                            showingChangeRequests = true
                        }
                        
                        Button("历史记录") {
                            showingConfigurationHistory = true
                        }
                        
                        Menu {
                            Button("安全设置") {
                                showingSecuritySettings = true
                            }
                            
                            Button("导出配置") {
                                exportConfiguration()
                            }
                            
                            Button("导入配置") {
                                importConfiguration()
                            }
                            
                            Button("安全扫描") {
                                performSecurityScan()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        .sheet(isPresented: $showingSecuritySettings) {
            SecuritySettingsView(securityService: securityService)
        }
        .sheet(isPresented: $showingChangeRequests) {
            ConfigurationChangeRequestsView(configurationService: configurationService)
        }
        .sheet(isPresented: $showingConfigurationHistory) {
            ConfigurationHistoryView(configurationService: configurationService)
        }
        .requirePermission(.viewSystemConfiguration)
    }
    
    // MARK: - Header Section (头部区域)
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("系统配置管理")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("管理和配置系统设置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(securityService.encryptionStatus.isEnabled ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        
                        Text(securityService.encryptionStatus.isEnabled ? "加密启用" : "加密禁用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if configurationService.pendingChangeRequests.count > 0 {
                        Text("\(configurationService.pendingChangeRequests.count) 个待审核请求")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Quick stats
            ConfigurationOverviewWidget(configurationService: configurationService)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Actions (操作)
    
    private func exportConfiguration() {
        // Implementation for exporting configuration
    }
    
    private func importConfiguration() {
        // Implementation for importing configuration
    }
    
    private func performSecurityScan() {
        Task {
            try? await securityService.performSecurityScan()
        }
    }
}

// MARK: - Configuration Category View (配置分类视图)

struct ConfigurationCategoryView: View {
    let category: ConfigurationCategory
    let configurationService: SystemConfigurationService
    
    @State private var searchText = ""
    @State private var showingAdvancedOptions = false
    
    var filteredConfigurations: [ConfigurationDefinition] {
        let categoryConfigs = configurationService.getConfigurationsByCategory(category)
        
        if searchText.isEmpty {
            return categoryConfigs
        } else {
            return configurationService.searchConfigurations(searchText)
                .filter { $0.category == category }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category header
            categoryHeader
            
            // Search bar
            searchBar
            
            // Configuration list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredConfigurations) { definition in
                        ConfigurationItemView(
                            definition: definition,
                            configurationService: configurationService
                        )
                    }
                    
                    if filteredConfigurations.isEmpty {
                        emptyStateView
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Category Header (分类头部)
    
    private var categoryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("高级选项") {
                    showingAdvancedOptions = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .sheet(isPresented: $showingAdvancedOptions) {
            AdvancedCategoryOptionsView(
                category: category,
                configurationService: configurationService
            )
        }
    }
    
    // MARK: - Search Bar (搜索栏)
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索配置项...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Empty State (空状态)
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("没有找到配置项")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("尝试调整搜索条件或检查其他分类")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}

// MARK: - Configuration Item View (配置项视图)

struct ConfigurationItemView: View {
    let definition: ConfigurationDefinition
    let configurationService: SystemConfigurationService
    
    @State private var showingEditSheet = false
    @State private var showingDetailsSheet = false
    @State private var isExpanded = false
    
    private var currentSetting: ConfigurationSetting? {
        configurationService.currentSettings[definition.key]
    }
    
    private var displayValue: String {
        if definition.isSensitive {
            return "••••••••"
        }
        return currentSetting?.value.displayValue ?? definition.defaultValue.displayValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main configuration row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(definition.displayName)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if definition.isRequired {
                            Text("*")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        if definition.requiresRestart {
                            Text("重启")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                        
                        if definition.isSensitive {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                    }
                    
                    Text(definition.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    HStack {
                        Text("当前值:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(displayValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(definition.valueType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }
                }
                
                VStack(spacing: 8) {
                    Button("编辑") {
                        showingEditSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(definition.isReadOnly)
                    
                    Button("详情") {
                        showingDetailsSheet = true
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                }
            }
            
            // Expandable details
            if isExpanded {
                configurationDetails
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 1)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ConfigurationEditSheet(
                definition: definition,
                currentValue: currentSetting?.value ?? definition.defaultValue,
                configurationService: configurationService
            )
        }
        .sheet(isPresented: $showingDetailsSheet) {
            ConfigurationDetailsSheet(
                definition: definition,
                currentSetting: currentSetting,
                configurationService: configurationService
            )
        }
    }
    
    // MARK: - Configuration Details (配置详情)
    
    private var configurationDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("配置信息")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    DetailRow(title: "键名", value: definition.key)
                    DetailRow(title: "分类", value: definition.category.displayName)
                    DetailRow(title: "默认值", value: definition.defaultValue.displayValue)
                    DetailRow(title: "最小权限", value: definition.minimumPermissionLevel.displayName)
                    
                    if let lastModified = currentSetting?.lastModified {
                        DetailRow(title: "最后修改", value: lastModified.formatted())
                    }
                    
                    if let modifiedBy = currentSetting?.modifiedBy {
                        DetailRow(title: "修改者", value: modifiedBy)
                    }
                }
            }
            
            if !definition.tags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("标签")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(definition.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                }
            }
            
            if !definition.validationRules.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("验证规则")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(definition.validationRules.indices, id: \.self) { index in
                            let rule = definition.validationRules[index]
                            Text("• \(rule.type.rawValue)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Configuration Edit Sheet (配置编辑表单)

struct ConfigurationEditSheet: View {
    let definition: ConfigurationDefinition
    let currentValue: ConfigurationValue
    let configurationService: SystemConfigurationService
    
    @State private var newValue: ConfigurationValue
    @State private var changeReason = ""
    @State private var isUpdating = false
    @State private var updateError: Error?
    
    @Environment(\.dismiss) private var dismiss
    
    init(definition: ConfigurationDefinition, currentValue: ConfigurationValue, configurationService: SystemConfigurationService) {
        self.definition = definition
        self.currentValue = currentValue
        self.configurationService = configurationService
        self._newValue = State(initialValue: currentValue)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("配置信息") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(definition.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(definition.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("类型:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(definition.valueType.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if definition.requiresRestart {
                                Text("需要重启")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                Section("当前值") {
                    Text(currentValue.displayValue)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Section("新值") {
                    ConfigurationValueEditor(
                        valueType: definition.valueType,
                        value: $newValue,
                        definition: definition
                    )
                }
                
                Section("变更原因") {
                    TextField("请描述变更原因...", text: $changeReason, axis: .vertical)
                        .lineLimit(3)
                }
                
                if !definition.validationRules.isEmpty {
                    Section("验证规则") {
                        ForEach(definition.validationRules.indices, id: \.self) { index in
                            let rule = definition.validationRules[index]
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text(rule.errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("编辑配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        updateConfiguration()
                    }
                    .disabled(isUpdating || newValue == currentValue || changeReason.isEmpty)
                }
            }
        }
        .alert("更新错误", isPresented: Binding<Bool>(
            get: { updateError != nil },
            set: { if !$0 { updateError = nil } }
        )) {
            Button("确定") { updateError = nil }
        } message: {
            Text(updateError?.localizedDescription ?? "未知错误")
        }
    }
    
    private func updateConfiguration() {
        isUpdating = true
        
        Task {
            do {
                try await configurationService.setConfigurationValue(
                    definition.key,
                    value: newValue,
                    reason: changeReason
                )
                
                await MainActor.run {
                    isUpdating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    updateError = error
                    isUpdating = false
                }
            }
        }
    }
}

// MARK: - Configuration Value Editor (配置值编辑器)

struct ConfigurationValueEditor: View {
    let valueType: ConfigurationValueType
    @Binding var value: ConfigurationValue
    let definition: ConfigurationDefinition
    
    @State private var stringValue = ""
    @State private var intValue = 0
    @State private var doubleValue = 0.0
    @State private var boolValue = false
    
    var body: some View {
        switch valueType {
        case .string, .password, .url, .email:
            Group {
                if valueType == .password {
                    SecureField("输入密码", text: $stringValue)
                } else {
                    TextField("输入\(valueType.displayName)", text: $stringValue)
                }
            }
            .onChange(of: stringValue) { newValue in
                value = .string(newValue)
            }
            .onAppear {
                if case .string(let str) = value {
                    stringValue = str
                }
            }
            
        case .integer, .percentage:
            HStack {
                TextField("输入\(valueType.displayName)", value: $intValue, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                
                if valueType == .percentage {
                    Text("%")
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: intValue) { newValue in
                value = .integer(newValue)
            }
            .onAppear {
                if case .integer(let int) = value {
                    intValue = int
                }
            }
            
        case .double:
            TextField("输入\(valueType.displayName)", value: $doubleValue, formatter: NumberFormatter())
                .keyboardType(.decimalPad)
                .onChange(of: doubleValue) { newValue in
                    value = .double(newValue)
                }
                .onAppear {
                    if case .double(let double) = value {
                        doubleValue = double
                    }
                }
            
        case .boolean:
            Toggle(isOn: $boolValue) {
                Text("启用")
            }
            .onChange(of: boolValue) { newValue in
                value = .boolean(newValue)
            }
            .onAppear {
                if case .boolean(let bool) = value {
                    boolValue = bool
                }
            }
            
        case .duration:
            HStack {
                TextField("输入秒数", value: $intValue, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                
                Text("秒")
                    .foregroundColor(.secondary)
            }
            .onChange(of: intValue) { newValue in
                value = .integer(newValue)
            }
            .onAppear {
                if case .integer(let int) = value {
                    intValue = int
                }
            }
            
        case .array, .object:
            Text("复杂类型编辑暂不支持")
                .foregroundColor(.secondary)
                .italic()
        }
    }
}

// MARK: - Configuration Details Sheet (配置详情表单)

struct ConfigurationDetailsSheet: View {
    let definition: ConfigurationDefinition
    let currentSetting: ConfigurationSetting?
    let configurationService: SystemConfigurationService
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    DetailRow(title: "显示名称", value: definition.displayName)
                    DetailRow(title: "键名", value: definition.key)
                    DetailRow(title: "分类", value: definition.category.displayName)
                    DetailRow(title: "值类型", value: definition.valueType.displayName)
                    DetailRow(title: "默认值", value: definition.defaultValue.displayValue)
                }
                
                Section("当前设置") {
                    if let setting = currentSetting {
                        DetailRow(title: "当前值", value: definition.isSensitive ? "••••••••" : setting.value.displayValue)
                        DetailRow(title: "最后修改", value: setting.lastModified.formatted())
                        DetailRow(title: "修改者", value: setting.modifiedBy)
                        DetailRow(title: "版本", value: "\(setting.version)")
                    } else {
                        Text("使用默认值")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("属性") {
                    PropertyRow(title: "必填", isEnabled: definition.isRequired)
                    PropertyRow(title: "只读", isEnabled: definition.isReadOnly)
                    PropertyRow(title: "敏感", isEnabled: definition.isSensitive)
                    PropertyRow(title: "需要重启", isEnabled: definition.requiresRestart)
                }
                
                Section("权限") {
                    DetailRow(title: "最小权限级别", value: definition.minimumPermissionLevel.displayName)
                }
                
                if !definition.tags.isEmpty {
                    Section("标签") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(definition.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                if !definition.validationRules.isEmpty {
                    Section("验证规则") {
                        ForEach(definition.validationRules.indices, id: \.self) { index in
                            let rule = definition.validationRules[index]
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.type.rawValue.capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text(rule.errorMessage)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("操作") {
                    Button("重置为默认值") {
                        showingResetConfirmation = true
                    }
                    .foregroundColor(.orange)
                    .disabled(definition.isReadOnly)
                }
            }
            .navigationTitle("配置详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .alert("重置确认", isPresented: $showingResetConfirmation) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                resetToDefault()
            }
        } message: {
            Text("确定要将此配置重置为默认值吗？此操作无法撤销。")
        }
    }
    
    private func resetToDefault() {
        Task {
            try? await configurationService.resetConfigurationToDefault(
                definition.key,
                reason: "通过配置详情界面重置为默认值"
            )
        }
    }
}

// MARK: - Configuration Overview Widget (配置概览小组件)

struct ConfigurationOverviewWidget: View {
    @ObservedObject var configurationService: SystemConfigurationService
    
    var body: some View {
        HStack(spacing: 20) {
            OverviewItem(
                title: "总配置项",
                value: "\(configurationService.configurationDefinitions.count)",
                icon: "gear",
                color: .blue
            )
            
            OverviewItem(
                title: "待审核",
                value: "\(configurationService.pendingChangeRequests.count)",
                icon: "clock",
                color: .orange
            )
            
            OverviewItem(
                title: "已修改",
                value: "\(configurationService.currentSettings.count)",
                icon: "pencil",
                color: .green
            )
            
            OverviewItem(
                title: "分类",
                value: "\(ConfigurationCategory.allCases.count)",
                icon: "folder",
                color: .purple
            )
        }
    }
}

// MARK: - Overview Item (概览项)

struct OverviewItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Property Row (属性行)

struct PropertyRow: View {
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isEnabled ? .green : .gray)
        }
    }
}

// MARK: - Advanced Category Options View (高级分类选项视图)

struct AdvancedCategoryOptionsView: View {
    let category: ConfigurationCategory
    let configurationService: SystemConfigurationService
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingBulkEdit = false
    @State private var showingExport = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("批量操作") {
                    Button("批量编辑") {
                        showingBulkEdit = true
                    }
                    
                    Button("批量重置") {
                        bulkReset()
                    }
                    .foregroundColor(.orange)
                    
                    Button("导出分类配置") {
                        showingExport = true
                    }
                }
                
                Section("统计信息") {
                    let configs = configurationService.getConfigurationsByCategory(category)
                    
                    DetailRow(title: "配置项数量", value: "\(configs.count)")
                    DetailRow(title: "必填项", value: "\(configs.filter { $0.isRequired }.count)")
                    DetailRow(title: "只读项", value: "\(configs.filter { $0.isReadOnly }.count)")
                    DetailRow(title: "敏感项", value: "\(configs.filter { $0.isSensitive }.count)")
                }
            }
            .navigationTitle("\(category.displayName) 选项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func bulkReset() {
        // Implementation for bulk reset
    }
}

// MARK: - Security Settings View (安全设置视图)

struct SecuritySettingsView: View {
    @ObservedObject var securityService: ConfigurationSecurityService
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEncryptionSetup = false
    @State private var showingSecurityScan = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("加密状态") {
                    HStack {
                        Circle()
                            .fill(securityService.encryptionStatus.isEnabled ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                        
                        Text(securityService.encryptionStatus.isEnabled ? "配置加密已启用" : "配置加密已禁用")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button(securityService.encryptionStatus.isEnabled ? "管理" : "启用") {
                            showingEncryptionSetup = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Section("安全扫描") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("上次扫描")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let lastScan = securityService.lastSecurityScan {
                                Text(lastScan.formatted())
                                    .font(.body)
                            } else {
                                Text("从未扫描")
                                    .font(.body)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        Button("执行扫描") {
                            showingSecurityScan = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Section("安全事件") {
                    if securityService.activeSecurityEvents.isEmpty {
                        Text("暂无安全事件")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(securityService.activeSecurityEvents.prefix(5)) { event in
                            SecurityEventRow(event: event)
                        }
                    }
                }
            }
            .navigationTitle("安全设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEncryptionSetup) {
            EncryptionSetupView(securityService: securityService)
        }
        .sheet(isPresented: $showingSecurityScan) {
            SecurityScanView(securityService: securityService)
        }
    }
}

// MARK: - Configuration Change Requests View (配置变更请求视图)

struct ConfigurationChangeRequestsView: View {
    @ObservedObject var configurationService: SystemConfigurationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(configurationService.pendingChangeRequests) { request in
                    ChangeRequestRow(request: request, configurationService: configurationService)
                }
                
                if configurationService.pendingChangeRequests.isEmpty {
                    VStack {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("暂无待审核请求")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                }
            }
            .navigationTitle("变更请求")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Configuration History View (配置历史视图)

struct ConfigurationHistoryView: View {
    @ObservedObject var configurationService: SystemConfigurationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(configurationService.configurationHistory) { record in
                    HistoryRecordRow(record: record)
                }
                
                if configurationService.configurationHistory.isEmpty {
                    VStack {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("暂无历史记录")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                }
            }
            .navigationTitle("配置历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views (支持视图)

struct SecurityEventRow: View {
    let event: SecurityEvent
    
    var body: some View {
        HStack {
            Circle()
                .fill(event.severity.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.message)
                    .font(.caption)
                    .lineLimit(2)
                
                Text(event.timestamp.formatted())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ChangeRequestRow: View {
    let request: ConfigurationChangeRequest
    let configurationService: SystemConfigurationService
    
    @State private var showingDetails = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.configurationKey)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(request.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(request.priority.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(request.priority.color.opacity(0.2))
                        .foregroundColor(request.priority.color)
                        .cornerRadius(4)
                    
                    Text(request.requestedAt.formatted())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("查看") {
                showingDetails = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .sheet(isPresented: $showingDetails) {
            ChangeRequestDetailsView(request: request, configurationService: configurationService)
        }
    }
}

struct HistoryRecordRow: View {
    let record: ConfigurationChangeRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.configurationKey)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(record.changedAt.formatted())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("旧值:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(record.oldValue.displayValue)
                    .font(.caption)
                    .foregroundColor(.red)
                
                Text("→")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(record.newValue.displayValue)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            if !record.reason.isEmpty {
                Text(record.reason)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}

struct ChangeRequestDetailsView: View {
    let request: ConfigurationChangeRequest
    let configurationService: SystemConfigurationService
    
    @Environment(\.dismiss) private var dismiss
    @State private var reviewNotes = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("请求信息") {
                    DetailRow(title: "配置键", value: request.configurationKey)
                    DetailRow(title: "请求者", value: request.requestedBy)
                    DetailRow(title: "请求时间", value: request.requestedAt.formatted())
                    DetailRow(title: "优先级", value: request.priority.displayName)
                    DetailRow(title: "状态", value: request.status.displayName)
                }
                
                Section("变更内容") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("当前值:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(request.currentValue.displayValue)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("建议值:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(request.proposedValue.displayValue)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section("变更理由") {
                    Text(request.reason)
                        .font(.body)
                }
                
                if !request.estimatedImpact.isEmpty {
                    Section("预期影响") {
                        Text(request.estimatedImpact)
                            .font(.body)
                    }
                }
                
                if request.status == .pending {
                    Section("审核") {
                        TextField("审核备注", text: $reviewNotes, axis: .vertical)
                            .lineLimit(3)
                        
                        HStack {
                            Button("批准") {
                                approveRequest()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isProcessing)
                            
                            Button("拒绝") {
                                rejectRequest()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            .disabled(isProcessing || reviewNotes.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("变更请求详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func approveRequest() {
        isProcessing = true
        Task {
            try? await configurationService.approveChangeRequest(request.id, reviewNotes: reviewNotes)
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        }
    }
    
    private func rejectRequest() {
        isProcessing = true
        Task {
            try? await configurationService.rejectChangeRequest(request.id, reviewNotes: reviewNotes)
            await MainActor.run {
                isProcessing = false
                dismiss()
            }
        }
    }
}

struct EncryptionSetupView: View {
    @ObservedObject var securityService: ConfigurationSecurityService
    @Environment(\.dismiss) private var dismiss
    
    @State private var masterPassword = ""
    @State private var confirmPassword = ""
    @State private var isProcessing = false
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("加密设置") {
                    if securityService.encryptionStatus.isEnabled {
                        Text("配置加密当前已启用")
                            .foregroundColor(.green)
                        
                        Button("禁用加密") {
                            disableEncryption()
                        }
                        .foregroundColor(.red)
                        .disabled(isProcessing)
                    } else {
                        SecureField("主密码", text: $masterPassword)
                        SecureField("确认密码", text: $confirmPassword)
                        
                        Text("主密码用于加密敏感配置数据，请务必妥善保管。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("启用加密") {
                            enableEncryption()
                        }
                        .disabled(masterPassword.isEmpty || masterPassword != confirmPassword || isProcessing)
                    }
                }
            }
            .navigationTitle("加密设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .alert("操作错误", isPresented: Binding<Bool>(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("确定") { error = nil }
        } message: {
            Text(error?.localizedDescription ?? "未知错误")
        }
    }
    
    private func enableEncryption() {
        isProcessing = true
        Task {
            do {
                try await securityService.enableEncryption(masterPassword: masterPassword)
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isProcessing = false
                }
            }
        }
    }
    
    private func disableEncryption() {
        isProcessing = true
        Task {
            do {
                try await securityService.disableEncryption(masterPassword: masterPassword)
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isProcessing = false
                }
            }
        }
    }
}

struct SecurityScanView: View {
    @ObservedObject var securityService: ConfigurationSecurityService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isScanning = false
    @State private var scanResult: SecurityScanResult?
    @State private var scanError: Error?
    
    var body: some View {
        NavigationStack {
            VStack {
                if isScanning {
                    VStack(spacing: 20) {
                        ProgressView()
                            .controlSize(.large)
                        
                        Text("正在执行安全扫描...")
                            .font(.headline)
                        
                        Text("扫描系统配置中的安全问题")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let result = scanResult {
                    SecurityScanResultView(result: result)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                        
                        Text("配置安全扫描")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("扫描系统配置以发现潜在的安全问题")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("开始扫描") {
                            startScan()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("安全扫描")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .alert("扫描错误", isPresented: Binding<Bool>(
            get: { scanError != nil },
            set: { if !$0 { scanError = nil } }
        )) {
            Button("确定") { scanError = nil }
        } message: {
            Text(scanError?.localizedDescription ?? "未知错误")
        }
    }
    
    private func startScan() {
        isScanning = true
        Task {
            do {
                let result = try await securityService.performSecurityScan()
                await MainActor.run {
                    scanResult = result
                    isScanning = false
                }
            } catch {
                await MainActor.run {
                    scanError = error
                    isScanning = false
                }
            }
        }
    }
}

struct SecurityScanResultView: View {
    let result: SecurityScanResult
    
    var body: some View {
        List {
            Section("扫描结果") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("安全评分")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(result.score)/100")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(result.riskLevel.color)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("风险等级")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(result.riskLevel.displayName)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(result.riskLevel.color)
                    }
                }
            }
            
            Section("发现的问题 (\(result.findings.count))") {
                if result.findings.isEmpty {
                    Text("未发现安全问题")
                        .foregroundColor(.green)
                        .italic()
                } else {
                    ForEach(result.findings) { finding in
                        SecurityFindingRow(finding: finding)
                    }
                }
            }
            
            Section("建议") {
                ForEach(result.recommendations, id: \.self) { recommendation in
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text(recommendation)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

struct SecurityFindingRow: View {
    let finding: SecurityFinding
    
    var body: some View {
        HStack {
            Circle()
                .fill(finding.severity.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(finding.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let config = finding.affectedConfiguration {
                    Text("影响配置: \(config)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Text(finding.severity.rawValue.uppercased())
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(finding.severity.color.opacity(0.2))
                .foregroundColor(finding.severity.color)
                .cornerRadius(4)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SystemConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let modelContext = container.mainContext
        
        SystemConfigurationView()
            .environmentObject(ServiceFactory(repositoryFactory: LocalRepositoryFactory(modelContext: modelContext)))
    }
}
#endif