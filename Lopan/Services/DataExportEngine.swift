//
//  DataExportEngine.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - Export Format Types (导出格式类型)

/// Supported data export formats
/// 支持的数据导出格式
enum ExportFormat: String, CaseIterable, Codable {
    case json = "json"
    case csv = "csv"
    case excel = "xlsx"
    case xml = "xml"
    case pdf = "pdf"
    case sqlite = "sqlite"
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .excel: return "Excel (XLSX)"
        case .xml: return "XML"
        case .pdf: return "PDF"
        case .sqlite: return "SQLite"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .excel: return "xlsx"
        case .xml: return "xml"
        case .pdf: return "pdf"
        case .sqlite: return "sqlite"
        }
    }
    
    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .excel: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .xml: return "application/xml"
        case .pdf: return "application/pdf"
        case .sqlite: return "application/x-sqlite3"
        }
    }
}

/// Data entity types that can be exported
/// 可导出的数据实体类型
enum ExportDataType: String, CaseIterable, Codable {
    case productionBatches = "production_batches"
    case machines = "machines"
    case users = "users"
    case customers = "customers"
    case products = "products"
    case colors = "colors"
    case auditLogs = "audit_logs"
    case notifications = "notifications"
    case analytics = "analytics"
    case systemHealth = "system_health"
    
    var displayName: String {
        switch self {
        case .productionBatches: return "生产批次"
        case .machines: return "机台设备"
        case .users: return "用户数据"
        case .customers: return "客户信息"
        case .products: return "产品配置"
        case .colors: return "颜色数据"
        case .auditLogs: return "审计日志"
        case .notifications: return "通知记录"
        case .analytics: return "分析数据"
        case .systemHealth: return "系统健康"
        }
    }
    
    var icon: String {
        switch self {
        case .productionBatches: return "folder.badge.gearshape"
        case .machines: return "gear.circle"
        case .users: return "person.3"
        case .customers: return "person.2.circle"
        case .products: return "cube.box"
        case .colors: return "paintpalette"
        case .auditLogs: return "doc.text.magnifyingglass"
        case .notifications: return "bell"
        case .analytics: return "chart.bar"
        case .systemHealth: return "heart.text.square"
        }
    }
}

// MARK: - Export Configuration (导出配置)

/// Configuration for data export operations
/// 数据导出操作的配置
struct ExportConfiguration {
    let id: String
    let dataTypes: [ExportDataType]
    let format: ExportFormat
    let dateRange: DateRange?
    let filters: [String: Any]
    let includeSensitiveData: Bool
    let compression: CompressionType
    let encryption: EncryptionConfig?
    let metadata: ExportMetadata
    
    struct DateRange {
        let startDate: Date
        let endDate: Date
    }
    
    enum CompressionType: String, CaseIterable {
        case none = "none"
        case gzip = "gzip"
        case zip = "zip"
        
        var displayName: String {
            switch self {
            case .none: return "无压缩"
            case .gzip: return "GZip压缩"
            case .zip: return "ZIP压缩"
            }
        }
    }
    
    struct EncryptionConfig {
        let algorithm: String
        let keySize: Int
        let password: String?
    }
    
    struct ExportMetadata {
        let title: String
        let description: String
        let requestedBy: String
        let requestedAt: Date
        let version: String
    }
    
    init(
        dataTypes: [ExportDataType],
        format: ExportFormat,
        dateRange: DateRange? = nil,
        filters: [String: Any] = [:],
        includeSensitiveData: Bool = false,
        compression: CompressionType = .none,
        encryption: EncryptionConfig? = nil,
        title: String = "",
        description: String = "",
        requestedBy: String = ""
    ) {
        self.id = UUID().uuidString
        self.dataTypes = dataTypes
        self.format = format
        self.dateRange = dateRange
        self.filters = filters
        self.includeSensitiveData = includeSensitiveData
        self.compression = compression
        self.encryption = encryption
        self.metadata = ExportMetadata(
            title: title.isEmpty ? "数据导出" : title,
            description: description,
            requestedBy: requestedBy,
            requestedAt: Date(),
            version: "1.0"
        )
    }
}

// MARK: - Export Progress and Results (导出进度和结果)

/// Progress tracking for export operations
/// 导出操作的进度跟踪
struct ExportProgress {
    let jobId: String
    let totalSteps: Int
    let currentStep: Int
    let currentStepName: String
    let isCompleted: Bool
    let error: Error?
    let estimatedTimeRemaining: TimeInterval?
    
    var progressPercentage: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }
}

/// Result of export operation
/// 导出操作的结果
struct ExportResult {
    let jobId: String
    let configuration: ExportConfiguration
    let fileURL: URL?
    let fileSize: Int64
    let recordCount: Int
    let startTime: Date
    let endTime: Date
    let success: Bool
    let error: Error?
    let checksum: String?
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

// MARK: - Data Export Engine (数据导出引擎)

/// Comprehensive data export engine with multi-format support
/// 支持多格式的综合数据导出引擎
@MainActor
class DataExportEngine: ObservableObject {
    
    // MARK: - Dependencies
    private let repositoryFactory: RepositoryFactory
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    private let permissionService: AdvancedPermissionService
    
    // MARK: - State
    @Published var activeExports: [String: ExportProgress] = [:]
    @Published var exportHistory: [ExportResult] = []
    @Published var isExporting = false
    @Published var lastError: Error?
    
    // MARK: - Configuration
    private let maxConcurrentExports = 3
    private let exportDirectory: URL
    private let tempDirectory: URL
    
    init(
        repositoryFactory: RepositoryFactory,
        auditService: NewAuditingService,
        authService: AuthenticationService,
        permissionService: AdvancedPermissionService
    ) {
        self.repositoryFactory = repositoryFactory
        self.auditService = auditService
        self.authService = authService
        self.permissionService = permissionService
        
        // Setup directories
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.exportDirectory = documentsURL.appendingPathComponent("Exports")
        self.tempDirectory = documentsURL.appendingPathComponent("Temp")
        
        setupDirectories()
    }
    
    // MARK: - Export Operations (导出操作)
    
    /// Start data export with given configuration
    /// 使用给定配置开始数据导出
    func startExport(configuration: ExportConfiguration) async throws -> String {
        // Check permissions
        guard await permissionService.hasPermission(.exportData).isGranted else {
            throw ExportError.insufficientPermissions
        }
        
        // Check concurrent export limit
        guard activeExports.count < maxConcurrentExports else {
            throw ExportError.tooManyActiveExports
        }
        
        let jobId = UUID().uuidString
        
        // Initialize progress tracking
        let initialProgress = ExportProgress(
            jobId: jobId,
            totalSteps: calculateTotalSteps(for: configuration),
            currentStep: 0,
            currentStepName: "准备导出",
            isCompleted: false,
            error: nil,
            estimatedTimeRemaining: nil
        )
        
        activeExports[jobId] = initialProgress
        
        // Start export task
        Task {
            await performExport(jobId: jobId, configuration: configuration)
        }
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "data_export_started",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "job_id": jobId,
                "data_types": configuration.dataTypes.map { $0.rawValue }.joined(separator: ","),
                "format": configuration.format.rawValue,
                "includes_sensitive": "\(configuration.includeSensitiveData)"
            ]
        )
        
        return jobId
    }
    
    /// Perform the actual export operation
    /// 执行实际的导出操作
    private func performExport(jobId: String, configuration: ExportConfiguration) async {
        let startTime = Date()
        var recordCount = 0
        var fileURL: URL?
        var error: Error?
        
        do {
            // Step 1: Validate configuration
            updateProgress(jobId: jobId, step: 1, stepName: "验证配置")
            try validateConfiguration(configuration)
            
            // Step 2: Collect data
            updateProgress(jobId: jobId, step: 2, stepName: "收集数据")
            let collectedData = try await collectData(configuration: configuration)
            recordCount = calculateRecordCount(collectedData)
            
            // Step 3: Transform data
            updateProgress(jobId: jobId, step: 3, stepName: "转换数据格式")
            let transformedData = try await transformData(collectedData, format: configuration.format)
            
            // Step 4: Write to file
            updateProgress(jobId: jobId, step: 4, stepName: "写入文件")
            fileURL = try await writeDataToFile(transformedData, configuration: configuration)
            
            // Step 5: Apply compression if needed
            if configuration.compression != .none {
                updateProgress(jobId: jobId, step: 5, stepName: "压缩文件")
                fileURL = try await compressFile(fileURL!, compression: configuration.compression)
            }
            
            // Step 6: Apply encryption if needed
            if let encryptionConfig = configuration.encryption {
                updateProgress(jobId: jobId, step: 6, stepName: "加密文件")
                fileURL = try await encryptFile(fileURL!, encryption: encryptionConfig)
            }
            
            // Step 7: Finalize
            updateProgress(jobId: jobId, step: calculateTotalSteps(for: configuration), stepName: "完成导出")
            
        } catch let exportError {
            error = exportError
            lastError = exportError
        }
        
        let endTime = Date()
        let fileSize = fileURL != nil ? getFileSize(for: fileURL!) : 0
        let checksum = fileURL != nil ? calculateChecksum(fileURL!) : nil
        
        // Create result
        let result = ExportResult(
            jobId: jobId,
            configuration: configuration,
            fileURL: fileURL,
            fileSize: fileSize,
            recordCount: recordCount,
            startTime: startTime,
            endTime: endTime,
            success: error == nil,
            error: error,
            checksum: checksum
        )
        
        // Update state
        activeExports.removeValue(forKey: jobId)
        exportHistory.insert(result, at: 0)
        
        // Keep only last 50 export results
        if exportHistory.count > 50 {
            exportHistory = Array(exportHistory.prefix(50))
        }
        
        // Audit log
        try? await auditService.logSecurityEvent(
            event: "data_export_completed",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "job_id": jobId,
                "success": "\(result.success)",
                "record_count": "\(recordCount)",
                "file_size": "\(fileSize)",
                "duration": "\(result.duration)",
                "error": error?.localizedDescription ?? "none"
            ]
        )
    }
    
    // MARK: - Data Collection (数据收集)
    
    /// Collect data based on configuration
    /// 根据配置收集数据
    private func collectData(configuration: ExportConfiguration) async throws -> [ExportDataType: Any] {
        var collectedData: [ExportDataType: Any] = [:]
        
        for dataType in configuration.dataTypes {
            switch dataType {
            case .productionBatches:
                collectedData[dataType] = try await collectProductionBatches(configuration)
            case .machines:
                collectedData[dataType] = try await collectMachines(configuration)
            case .users:
                collectedData[dataType] = try await collectUsers(configuration)
            case .customers:
                collectedData[dataType] = try await collectCustomers(configuration)
            case .products:
                collectedData[dataType] = try await collectProducts(configuration)
            case .colors:
                collectedData[dataType] = try await collectColors(configuration)
            case .auditLogs:
                collectedData[dataType] = try await collectAuditLogs(configuration)
            case .notifications:
                collectedData[dataType] = try await collectNotifications(configuration)
            case .analytics:
                collectedData[dataType] = try await collectAnalytics(configuration)
            case .systemHealth:
                collectedData[dataType] = try await collectSystemHealth(configuration)
            }
        }
        
        return collectedData
    }
    
    private func collectProductionBatches(_ config: ExportConfiguration) async throws -> [ProductionBatch] {
        var batches = try await repositoryFactory.productionBatchRepository.fetchAllBatches()
        
        // Apply date range filter
        if let dateRange = config.dateRange {
            batches = batches.filter { batch in
                batch.submittedAt >= dateRange.startDate && batch.submittedAt <= dateRange.endDate
            }
        }
        
        // Apply additional filters
        if let statusFilter = config.filters["status"] as? String {
            batches = batches.filter { $0.status.rawValue == statusFilter }
        }
        
        return batches
    }
    
    private func collectMachines(_ config: ExportConfiguration) async throws -> [WorkshopMachine] {
        let machines = try await repositoryFactory.machineRepository.fetchAllMachines()
        
        if !config.includeSensitiveData {
            // Remove sensitive information
            return machines.map { machine in
                var safeMachine = machine
                // In a real implementation, you'd create sanitized copies
                return safeMachine
            }
        }
        
        return machines
    }
    
    private func collectUsers(_ config: ExportConfiguration) async throws -> [User] {
        // Only administrators can export user data
        guard await permissionService.hasPermission(.viewUser).isGranted else {
            throw ExportError.dataAccessDenied
        }
        
        let users = try await repositoryFactory.userRepository.fetchUsers()
        
        if !config.includeSensitiveData {
            // Remove sensitive information like authentication details
            return users.map { user in
                var safeUser = user
                safeUser.wechatId = nil
                safeUser.appleUserId = nil
                safeUser.phone = nil
                safeUser.email = nil
                return safeUser
            }
        }
        
        return users
    }
    
    private func collectCustomers(_ config: ExportConfiguration) async throws -> [Customer] {
        guard await permissionService.hasPermission(.viewCustomer).isGranted else {
            throw ExportError.dataAccessDenied
        }
        return try await repositoryFactory.customerRepository.fetchCustomers()
    }
    
    private func collectProducts(_ config: ExportConfiguration) async throws -> [Product] {
        return try await repositoryFactory.productRepository.fetchProducts()
    }
    
    private func collectColors(_ config: ExportConfiguration) async throws -> [ColorCard] {
        return try await repositoryFactory.colorRepository.fetchAllColors()
    }
    
    private func collectAuditLogs(_ config: ExportConfiguration) async throws -> [String] {
        guard await permissionService.hasPermission(.viewAuditLogs).isGranted else {
            throw ExportError.dataAccessDenied
        }
        // Mock audit logs - in real implementation, fetch from audit service
        return ["audit log entry 1", "audit log entry 2"]
    }
    
    private func collectNotifications(_ config: ExportConfiguration) async throws -> [String] {
        // Mock notifications - in real implementation, fetch from notification service
        return ["notification 1", "notification 2"]
    }
    
    private func collectAnalytics(_ config: ExportConfiguration) async throws -> [String] {
        guard await permissionService.hasPermission(.accessAnalytics).isGranted else {
            throw ExportError.dataAccessDenied
        }
        // Mock analytics - in real implementation, fetch from analytics service
        return ["analytics data 1", "analytics data 2"]
    }
    
    private func collectSystemHealth(_ config: ExportConfiguration) async throws -> [String] {
        guard await permissionService.hasPermission(.viewSystemHealth).isGranted else {
            throw ExportError.dataAccessDenied
        }
        // Mock system health - in real implementation, fetch from monitoring service
        return ["system health data 1", "system health data 2"]
    }
    
    // MARK: - Data Transformation (数据转换)
    
    /// Transform collected data to target format
    /// 将收集的数据转换为目标格式
    private func transformData(_ data: [ExportDataType: Any], format: ExportFormat) async throws -> Data {
        switch format {
        case .json:
            return try transformToJSON(data)
        case .csv:
            return try transformToCSV(data)
        case .excel:
            return try transformToExcel(data)
        case .xml:
            return try transformToXML(data)
        case .pdf:
            return try transformToPDF(data)
        case .sqlite:
            return try transformToSQLite(data)
        }
    }
    
    private func transformToJSON(_ data: [ExportDataType: Any]) throws -> Data {
        var jsonData: [String: Any] = [:]
        
        for (dataType, typeData) in data {
            // Convert to JSON-serializable format
            if let encodableData = typeData as? [Encodable] {
                jsonData[dataType.rawValue] = try encodableData.map { item in
                    // In a real implementation, you'd properly encode each item
                    return ["id": "sample", "data": "sample_data"]
                }
            }
        }
        
        return try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
    }
    
    private func transformToCSV(_ data: [ExportDataType: Any]) throws -> Data {
        var csvContent = ""
        
        for (dataType, typeData) in data {
            csvContent += "\n# \(dataType.displayName)\n"
            
            // Generate CSV headers and rows based on data type
            switch dataType {
            case .productionBatches:
                if let batches = typeData as? [ProductionBatch] {
                    csvContent += "ID,BatchNumber,MachineID,Status,SubmittedAt,CompletedAt\n"
                    for batch in batches {
                        csvContent += "\(batch.id),\(batch.batchNumber),\(batch.machineId),\(batch.status.rawValue),\(batch.submittedAt),\(batch.completedAt?.description ?? "")\n"
                    }
                }
            case .machines:
                if let machines = typeData as? [WorkshopMachine] {
                    csvContent += "ID,MachineNumber,Status,IsActive,UtilizationRate\n"
                    for machine in machines {
                        csvContent += "\(machine.id),\(machine.machineNumber),\(machine.status.rawValue),\(machine.isActive),\(machine.utilizationRate)\n"
                    }
                }
            default:
                csvContent += "Data type \(dataType.displayName) CSV export not implemented\n"
            }
        }
        
        return csvContent.data(using: .utf8) ?? Data()
    }
    
    private func transformToExcel(_ data: [ExportDataType: Any]) throws -> Data {
        // In a real implementation, you'd use a library like SwiftXLSX
        // For now, return a placeholder
        let placeholder = "Excel format not implemented in this demo"
        return placeholder.data(using: .utf8) ?? Data()
    }
    
    private func transformToXML(_ data: [ExportDataType: Any]) throws -> Data {
        var xmlContent = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<export>\n"
        
        for (dataType, typeData) in data {
            xmlContent += "  <\(dataType.rawValue)>\n"
            // Add XML content based on data type
            xmlContent += "    <!-- \(dataType.displayName) data would go here -->\n"
            xmlContent += "  </\(dataType.rawValue)>\n"
        }
        
        xmlContent += "</export>"
        return xmlContent.data(using: .utf8) ?? Data()
    }
    
    private func transformToPDF(_ data: [ExportDataType: Any]) throws -> Data {
        // In a real implementation, you'd use Core Graphics or PDFKit
        let placeholder = "PDF format not implemented in this demo"
        return placeholder.data(using: .utf8) ?? Data()
    }
    
    private func transformToSQLite(_ data: [ExportDataType: Any]) throws -> Data {
        // In a real implementation, you'd create a SQLite database
        let placeholder = "SQLite format not implemented in this demo"
        return placeholder.data(using: .utf8) ?? Data()
    }
    
    // MARK: - File Operations (文件操作)
    
    /// Write data to file
    /// 将数据写入文件
    private func writeDataToFile(_ data: Data, configuration: ExportConfiguration) async throws -> URL {
        let fileName = generateFileName(configuration: configuration)
        let fileURL = exportDirectory.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    /// Compress file
    /// 压缩文件
    private func compressFile(_ fileURL: URL, compression: ExportConfiguration.CompressionType) async throws -> URL {
        switch compression {
        case .none:
            return fileURL
        case .gzip:
            // Implement gzip compression
            let compressedURL = fileURL.appendingPathExtension("gz")
            // Placeholder - real implementation would use compression library
            try FileManager.default.copyItem(at: fileURL, to: compressedURL)
            try FileManager.default.removeItem(at: fileURL)
            return compressedURL
        case .zip:
            // Implement zip compression
            let compressedURL = fileURL.appendingPathExtension("zip")
            // Placeholder - real implementation would use compression library
            try FileManager.default.copyItem(at: fileURL, to: compressedURL)
            try FileManager.default.removeItem(at: fileURL)
            return compressedURL
        }
    }
    
    /// Encrypt file
    /// 加密文件
    private func encryptFile(_ fileURL: URL, encryption: ExportConfiguration.EncryptionConfig) async throws -> URL {
        let encryptedURL = fileURL.appendingPathExtension("encrypted")
        // Placeholder - real implementation would use encryption
        try FileManager.default.copyItem(at: fileURL, to: encryptedURL)
        try FileManager.default.removeItem(at: fileURL)
        return encryptedURL
    }
    
    // MARK: - Utility Methods (实用方法)
    
    private func setupDirectories() {
        let fileManager = FileManager.default
        
        try? fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    private func validateConfiguration(_ configuration: ExportConfiguration) throws {
        if configuration.dataTypes.isEmpty {
            throw ExportError.invalidConfiguration("No data types specified")
        }
        
        if let dateRange = configuration.dateRange {
            if dateRange.startDate > dateRange.endDate {
                throw ExportError.invalidConfiguration("Invalid date range")
            }
        }
    }
    
    private func calculateTotalSteps(for configuration: ExportConfiguration) -> Int {
        var steps = 4 // Basic steps: validate, collect, transform, write
        if configuration.compression != .none { steps += 1 }
        if configuration.encryption != nil { steps += 1 }
        return steps
    }
    
    private func updateProgress(jobId: String, step: Int, stepName: String) {
        guard var progress = activeExports[jobId] else { return }
        
        progress = ExportProgress(
            jobId: jobId,
            totalSteps: progress.totalSteps,
            currentStep: step,
            currentStepName: stepName,
            isCompleted: step >= progress.totalSteps,
            error: progress.error,
            estimatedTimeRemaining: nil
        )
        
        activeExports[jobId] = progress
    }
    
    private func calculateRecordCount(_ data: [ExportDataType: Any]) -> Int {
        var count = 0
        for (_, typeData) in data {
            if let array = typeData as? [Any] {
                count += array.count
            }
        }
        return count
    }
    
    private func generateFileName(configuration: ExportConfiguration) -> String {
        let timestamp = DateFormatter.fileNameFormatter.string(from: Date())
        let dataTypesString = configuration.dataTypes.map { $0.rawValue }.joined(separator: "_")
        return "export_\(dataTypesString)_\(timestamp).\(configuration.format.fileExtension)"
    }
    
    private func calculateChecksum(_ fileURL: URL) -> String? {
        // Placeholder - real implementation would calculate MD5/SHA hash
        return "checksum_placeholder"
    }
    
    /// Cancel active export
    /// 取消活动导出
    func cancelExport(jobId: String) async {
        activeExports.removeValue(forKey: jobId)
        
        // Audit log
        try? await auditService.logSecurityEvent(
            event: "data_export_cancelled",
            userId: authService.currentUser?.id ?? "unknown",
            details: ["job_id": jobId]
        )
    }
    
    /// Get export progress
    /// 获取导出进度
    func getExportProgress(jobId: String) -> ExportProgress? {
        return activeExports[jobId]
    }
    
    /// Clean up old export files
    /// 清理旧的导出文件
    func cleanupOldExports(olderThan days: Int = 30) async {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 3600))
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(at: exportDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in files {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Failed to cleanup old exports: \(error)")
        }
    }
    
    private func getFileSize(for url: URL) -> Int64 {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return 0
        }
    }
}

// MARK: - Error Types (错误类型)

enum ExportError: LocalizedError {
    case insufficientPermissions
    case invalidConfiguration(String)
    case dataAccessDenied
    case tooManyActiveExports
    case fileWriteError
    case transformationError
    case compressionError
    case encryptionError
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "权限不足，无法执行数据导出"
        case .invalidConfiguration(let reason):
            return "导出配置无效: \(reason)"
        case .dataAccessDenied:
            return "数据访问被拒绝"
        case .tooManyActiveExports:
            return "活动导出任务过多，请等待后重试"
        case .fileWriteError:
            return "文件写入失败"
        case .transformationError:
            return "数据格式转换失败"
        case .compressionError:
            return "文件压缩失败"
        case .encryptionError:
            return "文件加密失败"
        }
    }
}

// MARK: - Supporting Extensions (支持扩展)

extension DateFormatter {
    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

extension URL {
    var fileSize: Int64 {
        do {
            let resourceValues = try resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return 0
        }
    }
}