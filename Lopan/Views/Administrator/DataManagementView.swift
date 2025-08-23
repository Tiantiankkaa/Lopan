//
//  DataManagementView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import SwiftData

// MARK: - Data Management Main View (数据管理主视图)

/// Comprehensive data management interface for administrators
/// 管理员的综合数据管理界面
struct DataManagementView: View {
    @EnvironmentObject var serviceFactory: ServiceFactory
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Export Tab
                DataExportView()
                    .tabItem {
                        Label("数据导出", systemImage: "square.and.arrow.up")
                    }
                    .tag(0)
                
                // Import Tab
                DataImportView()
                    .tabItem {
                        Label("数据导入", systemImage: "square.and.arrow.down")
                    }
                    .tag(1)
                
                // Backup Tab
                DataBackupView()
                    .tabItem {
                        Label("数据备份", systemImage: "externaldrive")
                    }
                    .tag(2)
                
                // Recovery Tab
                DataRecoveryView()
                    .tabItem {
                        Label("数据恢复", systemImage: "arrow.clockwise")
                    }
                    .tag(3)
            }
            .navigationTitle("数据管理")
            .environmentObject(serviceFactory)
        }
        .requirePermission(.backupData)
    }
}

// MARK: - Data Export View (数据导出视图)

struct DataExportView: View {
    @EnvironmentObject var serviceFactory: ServiceFactory
    
    // Configuration state
    @State private var selectedDataTypes: Set<ExportDataType> = []
    @State private var selectedFormat: ExportFormat = .json
    @State private var includeSensitiveData = false
    @State private var compressionType: ExportConfiguration.CompressionType = .none
    @State private var enableEncryption = false
    @State private var encryptionPassword = ""
    @State private var exportTitle = ""
    @State private var exportDescription = ""
    @State private var startDate = Date().addingTimeInterval(-30 * 24 * 3600) // 30 days ago
    @State private var endDate = Date()
    @State private var useDateRange = false
    
    // UI state
    @State private var showingExportConfiguration = false
    @State private var showingActiveExports = false
    
    private var exportEngine: DataExportEngine {
        serviceFactory.dataExportEngine
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Text("数据导出")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("活动导出") {
                    showingActiveExports = true
                }
                .sheet(isPresented: $showingActiveExports) {
                    ActiveExportsView(exportEngine: exportEngine)
                }
                
                Button("新建导出") {
                    showingExportConfiguration = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Export history
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(exportEngine.exportHistory, id: \.jobId) { result in
                        ExportHistoryCard(result: result)
                    }
                    
                    if exportEngine.exportHistory.isEmpty {
                        VStack {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("暂无导出记录")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Text("点击\"新建导出\"开始导出数据")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingExportConfiguration) {
            ExportConfigurationSheet(
                selectedDataTypes: $selectedDataTypes,
                selectedFormat: $selectedFormat,
                includeSensitiveData: $includeSensitiveData,
                compressionType: $compressionType,
                enableEncryption: $enableEncryption,
                encryptionPassword: $encryptionPassword,
                exportTitle: $exportTitle,
                exportDescription: $exportDescription,
                startDate: $startDate,
                endDate: $endDate,
                useDateRange: $useDateRange,
                exportEngine: exportEngine
            )
        }
    }
}

// MARK: - Export Configuration Sheet (导出配置表单)

struct ExportConfigurationSheet: View {
    @Binding var selectedDataTypes: Set<ExportDataType>
    @Binding var selectedFormat: ExportFormat
    @Binding var includeSensitiveData: Bool
    @Binding var compressionType: ExportConfiguration.CompressionType
    @Binding var enableEncryption: Bool
    @Binding var encryptionPassword: String
    @Binding var exportTitle: String
    @Binding var exportDescription: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var useDateRange: Bool
    
    let exportEngine: DataExportEngine
    
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportError: Error?
    
    var body: some View {
        NavigationView {
            Form {
                Section("导出内容") {
                    ForEach(ExportDataType.allCases, id: \.self) { dataType in
                        HStack {
                            Image(systemName: dataType.icon)
                                .foregroundColor(.blue)
                            
                            Toggle(dataType.displayName, isOn: Binding(
                                get: { selectedDataTypes.contains(dataType) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedDataTypes.insert(dataType)
                                    } else {
                                        selectedDataTypes.remove(dataType)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                Section("导出格式") {
                    Picker("格式", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    
                    Toggle("包含敏感数据", isOn: $includeSensitiveData)
                        .help("包含用户认证信息、联系方式等敏感数据")
                }
                
                Section("时间范围") {
                    Toggle("使用时间范围", isOn: $useDateRange)
                    
                    if useDateRange {
                        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                    }
                }
                
                Section("压缩与加密") {
                    Picker("压缩类型", selection: $compressionType) {
                        ForEach(ExportConfiguration.CompressionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Toggle("启用加密", isOn: $enableEncryption)
                    
                    if enableEncryption {
                        SecureField("加密密码", text: $encryptionPassword)
                            .textContentType(.password)
                    }
                }
                
                Section("导出信息") {
                    TextField("导出标题", text: $exportTitle)
                    TextField("描述", text: $exportDescription, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("配置导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("开始导出") {
                        startExport()
                    }
                    .disabled(selectedDataTypes.isEmpty || isExporting)
                }
            }
        }
        .alert("导出错误", isPresented: Binding<Bool>(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("确定") { exportError = nil }
        } message: {
            Text(exportError?.localizedDescription ?? "未知错误")
        }
    }
    
    private func startExport() {
        isExporting = true
        
        let dateRange = useDateRange ? ExportConfiguration.DateRange(
            startDate: startDate,
            endDate: endDate
        ) : nil
        
        let encryption = enableEncryption ? ExportConfiguration.EncryptionConfig(
            algorithm: "AES-256",
            keySize: 256,
            password: encryptionPassword.isEmpty ? nil : encryptionPassword
        ) : nil
        
        let configuration = ExportConfiguration(
            dataTypes: Array(selectedDataTypes),
            format: selectedFormat,
            dateRange: dateRange,
            includeSensitiveData: includeSensitiveData,
            compression: compressionType,
            encryption: encryption,
            title: exportTitle,
            description: exportDescription,
            requestedBy: "Administrator" // In real app, get from auth service
        )
        
        Task {
            do {
                _ = try await exportEngine.startExport(configuration: configuration)
                await MainActor.run {
                    isExporting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    exportError = error
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - Export History Card (导出历史卡片)

struct ExportHistoryCard: View {
    let result: ExportResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.configuration.metadata.title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(result.configuration.format.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(result.recordCount) 条记录")
                    Text("•")
                    Text(result.fileSizeFormatted)
                    Text("•")
                    Text(result.startTime, style: .date)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if result.success {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("成功")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("失败")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if result.success {
                    Button("下载") {
                        if let fileURL = result.fileURL {
                            shareFile(fileURL)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private func shareFile(_ url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Active Exports View (活动导出视图)

struct ActiveExportsView: View {
    @ObservedObject var exportEngine: DataExportEngine
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(exportEngine.activeExports.keys), id: \.self) { jobId in
                    if let progress = exportEngine.activeExports[jobId] {
                        ActiveExportRow(progress: progress, exportEngine: exportEngine)
                    }
                }
                
                if exportEngine.activeExports.isEmpty {
                    VStack {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无活动导出")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                }
            }
            .navigationTitle("活动导出")
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

// MARK: - Active Export Row (活动导出行)

struct ActiveExportRow: View {
    let progress: ExportProgress
    let exportEngine: DataExportEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Job \(progress.jobId.prefix(8))")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !progress.isCompleted {
                    Button("取消") {
                        Task {
                            await exportEngine.cancelExport(jobId: progress.jobId)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
            
            Text(progress.currentStepName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: progress.progressPercentage)
                .progressViewStyle(.linear)
            
            HStack {
                Text("\(Int(progress.progressPercentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("步骤 \(progress.currentStep)/\(progress.totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Import View (数据导入视图)

struct DataImportView: View {
    @EnvironmentObject var serviceFactory: ServiceFactory
    @State private var showingImportConfiguration = false
    @State private var showingActiveImports = false
    
    private var importEngine: DataImportEngine {
        serviceFactory.dataImportEngine
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Text("数据导入")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("活动导入") {
                    showingActiveImports = true
                }
                .sheet(isPresented: $showingActiveImports) {
                    ActiveImportsView(importEngine: importEngine)
                }
                
                Button("新建导入") {
                    showingImportConfiguration = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Import history
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(importEngine.importHistory, id: \.jobId) { result in
                        ImportHistoryCard(result: result)
                    }
                    
                    if importEngine.importHistory.isEmpty {
                        VStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("暂无导入记录")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Text("点击\"新建导入\"开始导入数据")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingImportConfiguration) {
            ImportConfigurationSheet(importEngine: importEngine)
        }
    }
}

// MARK: - Import Configuration Sheet (导入配置表单)

struct ImportConfigurationSheet: View {
    let importEngine: DataImportEngine
    
    @State private var selectedFile: URL?
    @State private var sourceFormat: ExportFormat = .json
    @State private var targetDataType: ExportDataType = .productionBatches
    @State private var dryRun = true
    @State private var createBackup = true
    @State private var conflictResolution: ImportConfiguration.ConflictResolution = .skip
    @State private var showingFilePicker = false
    
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var importError: Error?
    
    var body: some View {
        NavigationView {
            Form {
                Section("导入文件") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(selectedFile?.lastPathComponent ?? "未选择文件")
                                .foregroundColor(selectedFile == nil ? .secondary : .primary)
                            
                            if let fileURL = selectedFile {
                                Text(fileURL.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("选择文件") {
                            showingFilePicker = true
                        }
                    }
                }
                
                Section("导入配置") {
                    Picker("源格式", selection: $sourceFormat) {
                        ForEach(ExportFormat.allCases.filter { $0 != .pdf }, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    
                    Picker("目标数据类型", selection: $targetDataType) {
                        ForEach(ExportDataType.allCases, id: \.self) { dataType in
                            HStack {
                                Image(systemName: dataType.icon)
                                Text(dataType.displayName)
                            }.tag(dataType)
                        }
                    }
                    
                    Picker("冲突处理", selection: $conflictResolution) {
                        ForEach([ImportConfiguration.ConflictResolution.skip, .overwrite, .merge, .fail], id: \.self) { resolution in
                            Text(resolution.displayName).tag(resolution)
                        }
                    }
                }
                
                Section("安全设置") {
                    Toggle("试运行", isOn: $dryRun)
                        .help("仅验证数据而不实际导入")
                    
                    Toggle("导入前创建备份", isOn: $createBackup)
                        .help("在导入前自动创建现有数据的备份")
                }
                
                Section("验证规则") {
                    Text("将使用 \(targetDataType.displayName) 的默认验证规则")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("配置导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("开始导入") {
                        startImport()
                    }
                    .disabled(selectedFile == nil || isImporting)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json, .commaSeparatedText, .xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedFile = urls.first
            case .failure(let error):
                importError = error
            }
        }
        .alert("导入错误", isPresented: Binding<Bool>(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("确定") { importError = nil }
        } message: {
            Text(importError?.localizedDescription ?? "未知错误")
        }
    }
    
    private func startImport() {
        guard let fileURL = selectedFile else { return }
        
        isImporting = true
        
        let validationRules = importEngine.getDefaultValidationRules(for: targetDataType)
        
        let configuration = ImportConfiguration(
            sourceFormat: sourceFormat,
            targetDataType: targetDataType,
            validationRules: validationRules,
            conflictResolution: conflictResolution,
            dryRun: dryRun,
            createBackup: createBackup,
            title: "数据导入",
            description: "从文件导入数据",
            importedBy: "Administrator" // In real app, get from auth service
        )
        
        Task {
            do {
                _ = try await importEngine.startImport(configuration: configuration, fileURL: fileURL)
                await MainActor.run {
                    isImporting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    importError = error
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Import History Card (导入历史卡片)

struct ImportHistoryCard: View {
    let result: ImportResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.configuration.metadata.title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(result.configuration.targetDataType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(result.totalRecords) 总计")
                    Text("•")
                    Text("\(result.successfulRecords) 成功")
                        .foregroundColor(.green)
                    if result.failedRecords > 0 {
                        Text("•")
                        Text("\(result.failedRecords) 失败")
                            .foregroundColor(.red)
                    }
                }
                .font(.caption)
                
                Text(result.startTime, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if result.success {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("成功")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("失败")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Text("\(Int(result.successRate * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

// MARK: - Active Imports View (活动导入视图)

struct ActiveImportsView: View {
    @ObservedObject var importEngine: DataImportEngine
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(importEngine.activeImports.keys), id: \.self) { jobId in
                    if let progress = importEngine.activeImports[jobId] {
                        ActiveImportRow(progress: progress, importEngine: importEngine)
                    }
                }
                
                if importEngine.activeImports.isEmpty {
                    VStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无活动导入")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                }
            }
            .navigationTitle("活动导入")
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

// MARK: - Active Import Row (活动导入行)

struct ActiveImportRow: View {
    let progress: ImportProgress
    let importEngine: DataImportEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Job \(progress.jobId.prefix(8))")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !progress.isCompleted {
                    Button("取消") {
                        Task {
                            await importEngine.cancelImport(jobId: progress.jobId)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
            
            Text(progress.currentPhase.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: progress.progressPercentage)
                .progressViewStyle(.linear)
            
            HStack {
                Text("\(Int(progress.progressPercentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack {
                    Text("\(progress.validRecords) 有效")
                        .foregroundColor(.green)
                    Text("•")
                    Text("\(progress.invalidRecords) 无效")
                        .foregroundColor(.red)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Backup View (数据备份视图)

struct DataBackupView: View {
    @EnvironmentObject var serviceFactory: ServiceFactory
    @State private var showingBackupConfiguration = false
    @State private var showingActiveBackups = false
    @State private var showingBackupScheduler = false
    
    private var backupService: DataBackupService {
        serviceFactory.dataBackupService
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Text("数据备份")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("活动备份") {
                    showingActiveBackups = true
                }
                .sheet(isPresented: $showingActiveBackups) {
                    ActiveBackupsView(backupService: backupService)
                }
                
                Button("计划备份") {
                    showingBackupScheduler = true
                }
                .sheet(isPresented: $showingBackupScheduler) {
                    BackupSchedulerView(backupService: backupService)
                }
                
                Button("立即备份") {
                    showingBackupConfiguration = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Backup history
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(backupService.backupHistory, id: \.id) { backup in
                        BackupHistoryCard(backup: backup, backupService: backupService)
                    }
                    
                    if backupService.backupHistory.isEmpty {
                        VStack {
                            Image(systemName: "externaldrive")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("暂无备份记录")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Text("点击\"立即备份\"创建第一个备份")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingBackupConfiguration) {
            BackupConfigurationSheet(backupService: backupService)
        }
    }
}

// MARK: - Backup Configuration Sheet (备份配置表单)

struct BackupConfigurationSheet: View {
    let backupService: DataBackupService
    
    @State private var selectedDataTypes: Set<ExportDataType> = [.productionBatches, .machines]
    @State private var backupName = ""
    @State private var backupDescription = ""
    @State private var compressionLevel: BackupConfiguration.CompressionLevel = .balanced
    @State private var enableEncryption = false
    @State private var encryptionPassword = ""
    @State private var incrementalBackup = false
    @State private var verifyBackup = true
    @State private var notifyOnCompletion = true
    
    @Environment(\.dismiss) private var dismiss
    @State private var isBackingUp = false
    @State private var backupError: Error?
    
    var body: some View {
        NavigationView {
            Form {
                Section("备份内容") {
                    ForEach(ExportDataType.allCases, id: \.self) { dataType in
                        HStack {
                            Image(systemName: dataType.icon)
                                .foregroundColor(.blue)
                            
                            Toggle(dataType.displayName, isOn: Binding(
                                get: { selectedDataTypes.contains(dataType) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedDataTypes.insert(dataType)
                                    } else {
                                        selectedDataTypes.remove(dataType)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                Section("备份设置") {
                    TextField("备份名称", text: $backupName)
                    TextField("描述", text: $backupDescription, axis: .vertical)
                        .lineLimit(3)
                    
                    Picker("压缩级别", selection: $compressionLevel) {
                        ForEach(BackupConfiguration.CompressionLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }
                
                Section("安全设置") {
                    Toggle("启用加密", isOn: $enableEncryption)
                    
                    if enableEncryption {
                        SecureField("加密密码", text: $encryptionPassword)
                            .textContentType(.password)
                    }
                }
                
                Section("高级选项") {
                    Toggle("增量备份", isOn: $incrementalBackup)
                        .help("仅备份自上次备份以来的更改")
                    
                    Toggle("验证备份", isOn: $verifyBackup)
                        .help("备份完成后验证文件完整性")
                    
                    Toggle("完成时通知", isOn: $notifyOnCompletion)
                }
            }
            .navigationTitle("配置备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("开始备份") {
                        startBackup()
                    }
                    .disabled(selectedDataTypes.isEmpty || isBackingUp)
                }
            }
        }
        .alert("备份错误", isPresented: Binding<Bool>(
            get: { backupError != nil },
            set: { if !$0 { backupError = nil } }
        )) {
            Button("确定") { backupError = nil }
        } message: {
            Text(backupError?.localizedDescription ?? "未知错误")
        }
    }
    
    private func startBackup() {
        isBackingUp = true
        
        Task {
            do {
                _ = try await backupService.createBackup(
                    dataTypes: Array(selectedDataTypes),
                    name: backupName.isEmpty ? nil : backupName,
                    reason: backupDescription
                )
                await MainActor.run {
                    isBackingUp = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    backupError = error
                    isBackingUp = false
                }
            }
        }
    }
}

// MARK: - Backup History Card (备份历史卡片)

struct BackupHistoryCard: View {
    let backup: BackupInfo
    let backupService: DataBackupService
    
    @State private var showingBackupDetails = false
    @State private var isDeletingBackup = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(backup.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                HStack {
                    ForEach(backup.dataTypes, id: \.self) { dataType in
                        Text(dataType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                HStack {
                    Text(backup.fileSizeFormatted)
                    Text("•")
                    Text(backup.createdAt, style: .date)
                    if backup.isEncrypted {
                        Text("•")
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Button("详情") {
                    showingBackupDetails = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("删除") {
                    deleteBackup()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                .disabled(isDeletingBackup)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
        .sheet(isPresented: $showingBackupDetails) {
            BackupDetailsView(backup: backup, backupService: backupService)
        }
    }
    
    private func deleteBackup() {
        isDeletingBackup = true
        Task {
            try? await backupService.deleteBackup(backup)
            await MainActor.run {
                isDeletingBackup = false
            }
        }
    }
}

// MARK: - Backup Details View (备份详情视图)

struct BackupDetailsView: View {
    let backup: BackupInfo
    let backupService: DataBackupService
    
    @Environment(\.dismiss) private var dismiss
    @State private var backupDetails: [String: Any] = [:]
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            List {
                Section("基本信息") {
                    DetailRow(title: "备份名称", value: backup.name)
                    DetailRow(title: "创建时间", value: backup.createdAt.formatted())
                    DetailRow(title: "文件大小", value: backup.fileSizeFormatted)
                    DetailRow(title: "校验和", value: backup.checksum)
                }
                
                Section("数据类型") {
                    ForEach(backup.dataTypes, id: \.self) { dataType in
                        HStack {
                            Image(systemName: dataType.icon)
                                .foregroundColor(.blue)
                            Text(dataType.displayName)
                            Spacer()
                            if let count = backup.recordCounts[dataType] {
                                Text("\(count) 条记录")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("文件信息") {
                    DetailRow(title: "文件路径", value: backup.fileURL.path)
                    DetailRow(title: "加密状态", value: backup.isEncrypted ? "已加密" : "未加密")
                    DetailRow(title: "压缩比", value: String(format: "%.1f%%", backup.compressionRatio * 100))
                    DetailRow(title: "增量备份", value: backup.isIncremental ? "是" : "否")
                    
                    if let parentId = backup.parentBackupId {
                        DetailRow(title: "父备份ID", value: parentId)
                    }
                }
            }
            .navigationTitle("备份详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadBackupDetails()
        }
    }
    
    private func loadBackupDetails() async {
        do {
            let details = try await backupService.getBackupDetails(backup)
            await MainActor.run {
                backupDetails = details
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Detail Row (详情行)

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Active Backups View (活动备份视图)

struct ActiveBackupsView: View {
    @ObservedObject var backupService: DataBackupService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(backupService.activeBackups.keys), id: \.self) { jobId in
                    if let progress = backupService.activeBackups[jobId] {
                        ActiveBackupRow(progress: progress, backupService: backupService)
                    }
                }
                
                if backupService.activeBackups.isEmpty {
                    VStack {
                        Image(systemName: "externaldrive")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无活动备份")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                }
            }
            .navigationTitle("活动备份")
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

// MARK: - Active Backup Row (活动备份行)

struct ActiveBackupRow: View {
    let progress: BackupProgress
    let backupService: DataBackupService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.configurationName)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !progress.isCompleted {
                    Button("取消") {
                        Task {
                            await backupService.cancelBackup(jobId: progress.jobId)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
            
            Text(progress.currentPhase.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ProgressView(value: progress.progressPercentage)
                .progressViewStyle(.linear)
            
            HStack {
                Text("\(Int(progress.progressPercentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(progress.processedDataTypes)/\(progress.totalDataTypes) 类型")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Backup Scheduler View (备份调度器视图)

struct BackupSchedulerView: View {
    let backupService: DataBackupService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("备份调度")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                Text("自动备份调度功能正在开发中")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("备份调度")
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

// MARK: - Data Recovery View (数据恢复视图)

struct DataRecoveryView: View {
    @EnvironmentObject var serviceFactory: ServiceFactory
    @State private var selectedBackup: BackupInfo?
    @State private var showingRecoveryConfiguration = false
    
    private var backupService: DataBackupService {
        serviceFactory.dataBackupService
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("数据恢复")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if selectedBackup != nil {
                    Button("配置恢复") {
                        showingRecoveryConfiguration = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            
            Divider()
            
            // Available backups
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(backupService.getAvailableBackups(), id: \.id) { backup in
                        RecoveryBackupCard(
                            backup: backup,
                            isSelected: selectedBackup?.id == backup.id,
                            onSelect: { selectedBackup = backup }
                        )
                    }
                    
                    if backupService.backupHistory.isEmpty {
                        VStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("暂无可用备份")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Text("请先创建备份后再进行恢复操作")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingRecoveryConfiguration) {
            if let backup = selectedBackup {
                RecoveryConfigurationSheet(backup: backup, backupService: backupService)
            }
        }
    }
}

// MARK: - Recovery Backup Card (恢复备份卡片)

struct RecoveryBackupCard: View {
    let backup: BackupInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(backup.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                HStack {
                    ForEach(backup.dataTypes, id: \.self) { dataType in
                        Text(dataType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                HStack {
                    Text(backup.fileSizeFormatted)
                    Text("•")
                    Text(backup.createdAt, style: .date)
                    if backup.isEncrypted {
                        Text("•")
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(isSelected ? "已选择" : "选择") {
                onSelect()
            }
            .buttonStyle(.plain)
            .controlSize(.small)
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

// MARK: - Recovery Configuration Sheet (恢复配置表单)

struct RecoveryConfigurationSheet: View {
    let backup: BackupInfo
    let backupService: DataBackupService
    
    @State private var selectedDataTypes: Set<ExportDataType>
    @State private var recoveryMode: RecoveryConfiguration.RecoveryMode = .selectiveRestore
    @State private var conflictResolution: RecoveryConfiguration.ConflictResolution = .skipConflicts
    @State private var createPreRecoveryBackup = true
    @State private var verifyIntegrity = true
    @State private var rollbackOnFailure = true
    
    @Environment(\.dismiss) private var dismiss
    @State private var isRecovering = false
    @State private var recoveryError: Error?
    
    init(backup: BackupInfo, backupService: DataBackupService) {
        self.backup = backup
        self.backupService = backupService
        self._selectedDataTypes = State(initialValue: Set(backup.dataTypes))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("恢复来源") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(backup.name)
                                .font(.headline)
                            Text(backup.createdAt.formatted())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(backup.fileSizeFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("恢复内容") {
                    ForEach(backup.dataTypes, id: \.self) { dataType in
                        HStack {
                            Image(systemName: dataType.icon)
                                .foregroundColor(.blue)
                            
                            Toggle(dataType.displayName, isOn: Binding(
                                get: { selectedDataTypes.contains(dataType) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedDataTypes.insert(dataType)
                                    } else {
                                        selectedDataTypes.remove(dataType)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                Section("恢复模式") {
                    Picker("模式", selection: $recoveryMode) {
                        Text(RecoveryConfiguration.RecoveryMode.fullRestore.displayName)
                            .tag(RecoveryConfiguration.RecoveryMode.fullRestore)
                        Text(RecoveryConfiguration.RecoveryMode.selectiveRestore.displayName)
                            .tag(RecoveryConfiguration.RecoveryMode.selectiveRestore)
                        Text(RecoveryConfiguration.RecoveryMode.mergeWithExisting.displayName)
                            .tag(RecoveryConfiguration.RecoveryMode.mergeWithExisting)
                    }
                    
                    Picker("冲突处理", selection: $conflictResolution) {
                        Text(RecoveryConfiguration.ConflictResolution.skipConflicts.displayName)
                            .tag(RecoveryConfiguration.ConflictResolution.skipConflicts)
                        Text(RecoveryConfiguration.ConflictResolution.overwriteExisting.displayName)
                            .tag(RecoveryConfiguration.ConflictResolution.overwriteExisting)
                        Text(RecoveryConfiguration.ConflictResolution.createDuplicates.displayName)
                            .tag(RecoveryConfiguration.ConflictResolution.createDuplicates)
                    }
                }
                
                Section("安全设置") {
                    Toggle("恢复前创建备份", isOn: $createPreRecoveryBackup)
                        .help("在恢复前自动创建当前数据的备份")
                    
                    Toggle("验证备份完整性", isOn: $verifyIntegrity)
                        .help("恢复前验证备份文件的完整性")
                    
                    Toggle("失败时回滚", isOn: $rollbackOnFailure)
                        .help("如果恢复失败，自动回滚到恢复前状态")
                }
            }
            .navigationTitle("配置恢复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("开始恢复") {
                        startRecovery()
                    }
                    .disabled(selectedDataTypes.isEmpty || isRecovering)
                }
            }
        }
        .alert("恢复错误", isPresented: Binding<Bool>(
            get: { recoveryError != nil },
            set: { if !$0 { recoveryError = nil } }
        )) {
            Button("确定") { recoveryError = nil }
        } message: {
            Text(recoveryError?.localizedDescription ?? "未知错误")
        }
    }
    
    private func startRecovery() {
        isRecovering = true
        
        let configuration = RecoveryConfiguration(
            id: UUID().uuidString,
            backupInfo: backup,
            targetDataTypes: Array(selectedDataTypes),
            recoveryMode: recoveryMode,
            conflictResolution: conflictResolution,
            createPreRecoveryBackup: createPreRecoveryBackup,
            verifyIntegrity: verifyIntegrity,
            rollbackOnFailure: rollbackOnFailure
        )
        
        Task {
            do {
                try await backupService.restoreFromBackup(configuration: configuration)
                await MainActor.run {
                    isRecovering = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    recoveryError = error
                    isRecovering = false
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DataManagementView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        DataManagementView()
            .environmentObject(ServiceFactory(repositoryFactory: LocalRepositoryFactory(modelContext: container.mainContext)))
    }
}
#endif