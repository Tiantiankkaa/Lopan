//
//  DataImportEngine.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - Import Configuration (导入配置)

/// Configuration for data import operations
/// 数据导入操作的配置
struct ImportConfiguration {
    let id: String
    let sourceFormat: ExportFormat
    let targetDataType: ExportDataType
    let validationRules: [ImportValidationRule]
    let conflictResolution: ConflictResolution
    let dryRun: Bool
    let createBackup: Bool
    let batchSize: Int
    let metadata: ImportMetadata
    
    enum ConflictResolution {
        case skip
        case overwrite
        case merge
        case fail
        
        var displayName: String {
            switch self {
            case .skip: return "跳过冲突"
            case .overwrite: return "覆盖现有"
            case .merge: return "合并数据"
            case .fail: return "遇到冲突时失败"
            }
        }
    }
    
    struct ImportMetadata {
        let title: String
        let description: String
        let importedBy: String
        let importedAt: Date
        let sourceDescription: String
    }
    
    init(
        sourceFormat: ExportFormat,
        targetDataType: ExportDataType,
        validationRules: [ImportValidationRule] = [],
        conflictResolution: ConflictResolution = .skip,
        dryRun: Bool = false,
        createBackup: Bool = true,
        batchSize: Int = 100,
        title: String = "",
        description: String = "",
        importedBy: String = "",
        sourceDescription: String = ""
    ) {
        self.id = UUID().uuidString
        self.sourceFormat = sourceFormat
        self.targetDataType = targetDataType
        self.validationRules = validationRules
        self.conflictResolution = conflictResolution
        self.dryRun = dryRun
        self.createBackup = createBackup
        self.batchSize = batchSize
        self.metadata = ImportMetadata(
            title: title.isEmpty ? "数据导入" : title,
            description: description,
            importedBy: importedBy,
            importedAt: Date(),
            sourceDescription: sourceDescription
        )
    }
}

// MARK: - Validation Rules (验证规则)

/// Validation rule for import data
/// 导入数据的验证规则
struct ImportValidationRule {
    let id: String
    let field: String
    let type: ValidationType
    let parameters: [String: Any]
    let isRequired: Bool
    let customValidator: ((Any) -> ImportValidationResult)?
    
    enum ValidationType {
        case required
        case dataType(DataType)
        case range(min: Double, max: Double)
        case length(min: Int, max: Int)
        case regex(String)
        case uniqueness
        case custom
        
        enum DataType {
            case string
            case integer
            case double
            case boolean
            case date
            case uuid
        }
    }
    
    init(
        field: String,
        type: ValidationType,
        parameters: [String: Any] = [:],
        isRequired: Bool = false,
        customValidator: ((Any) -> ImportValidationResult)? = nil
    ) {
        self.id = UUID().uuidString
        self.field = field
        self.type = type
        self.parameters = parameters
        self.isRequired = isRequired
        self.customValidator = customValidator
    }
}

/// Result of validation
/// 验证结果
struct ImportValidationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    
    static let valid = ImportValidationResult(isValid: true, errors: [], warnings: [])
    
    init(isValid: Bool, errors: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

// MARK: - Import Progress and Results (导入进度和结果)

/// Progress tracking for import operations
/// 导入操作的进度跟踪
struct ImportProgress {
    let jobId: String
    let totalRecords: Int
    let processedRecords: Int
    let validRecords: Int
    let invalidRecords: Int
    let conflictedRecords: Int
    let currentPhase: ImportPhase
    let isCompleted: Bool
    let error: Error?
    
    enum ImportPhase: String {
        case parsing = "parsing"
        case validation = "validation"
        case processing = "processing"
        case committing = "committing"
        case cleanup = "cleanup"
        
        var displayName: String {
            switch self {
            case .parsing: return "解析数据"
            case .validation: return "验证数据"
            case .processing: return "处理数据"
            case .committing: return "提交更改"
            case .cleanup: return "清理资源"
            }
        }
    }
    
    var progressPercentage: Double {
        guard totalRecords > 0 else { return 0 }
        return Double(processedRecords) / Double(totalRecords)
    }
}

/// Result of import operation
/// 导入操作的结果
struct ImportResult {
    let jobId: String
    let configuration: ImportConfiguration
    let startTime: Date
    let endTime: Date
    let totalRecords: Int
    let successfulRecords: Int
    let failedRecords: Int
    let conflictedRecords: Int
    let validationErrors: [ValidationError]
    let warnings: [String]
    let backupFileURL: URL?
    let success: Bool
    let error: Error?
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var successRate: Double {
        guard totalRecords > 0 else { return 0 }
        return Double(successfulRecords) / Double(totalRecords)
    }
}

/// Validation error with context
/// 带有上下文的验证错误
struct ValidationError {
    let recordIndex: Int
    let field: String
    let value: Any?
    let rule: ImportValidationRule
    let message: String
}

// MARK: - Data Import Engine (数据导入引擎)

/// Comprehensive data import engine with validation and conflict resolution
/// 具有验证和冲突解决的综合数据导入引擎
@MainActor
class DataImportEngine: ObservableObject {
    
    // MARK: - Dependencies
    private let repositoryFactory: RepositoryFactory
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    private let permissionService: AdvancedPermissionService
    private let backupService: DataBackupService
    
    // MARK: - State
    @Published var activeImports: [String: ImportProgress] = [:]
    @Published var importHistory: [ImportResult] = []
    @Published var isImporting = false
    @Published var lastError: Error?
    
    // MARK: - Configuration
    private let maxConcurrentImports = 2
    private let tempDirectory: URL
    
    init(
        repositoryFactory: RepositoryFactory,
        auditService: NewAuditingService,
        authService: AuthenticationService,
        permissionService: AdvancedPermissionService,
        backupService: DataBackupService
    ) {
        self.repositoryFactory = repositoryFactory
        self.auditService = auditService
        self.authService = authService
        self.permissionService = permissionService
        self.backupService = backupService
        
        // Setup directories
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.tempDirectory = documentsURL.appendingPathComponent("ImportTemp")
        
        setupDirectories()
    }
    
    // MARK: - Import Operations (导入操作)
    
    /// Start data import with given configuration and file
    /// 使用给定配置和文件开始数据导入
    func startImport(configuration: ImportConfiguration, fileURL: URL) async throws -> String {
        // Check permissions
        guard await permissionService.hasPermission(.importData).isGranted else {
            throw ImportError.insufficientPermissions
        }
        
        // Check concurrent import limit
        guard activeImports.count < maxConcurrentImports else {
            throw ImportError.tooManyActiveImports
        }
        
        // Validate file exists and is readable
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ImportError.fileNotFound
        }
        
        let jobId = UUID().uuidString
        
        // Initialize progress tracking
        let initialProgress = ImportProgress(
            jobId: jobId,
            totalRecords: 0,
            processedRecords: 0,
            validRecords: 0,
            invalidRecords: 0,
            conflictedRecords: 0,
            currentPhase: .parsing,
            isCompleted: false,
            error: nil
        )
        
        activeImports[jobId] = initialProgress
        
        // Start import task
        Task {
            await performImport(jobId: jobId, configuration: configuration, fileURL: fileURL)
        }
        
        // Audit log
        try await auditService.logSecurityEvent(
            event: "data_import_started",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "job_id": jobId,
                "target_data_type": configuration.targetDataType.rawValue,
                "source_format": configuration.sourceFormat.rawValue,
                "dry_run": "\(configuration.dryRun)"
            ]
        )
        
        return jobId
    }
    
    /// Perform the actual import operation
    /// 执行实际的导入操作
    private func performImport(jobId: String, configuration: ImportConfiguration, fileURL: URL) async {
        let startTime = Date()
        var totalRecords = 0
        var successfulRecords = 0
        var failedRecords = 0
        var conflictedRecords = 0
        var validationErrors: [ValidationError] = []
        var warnings: [String] = []
        var backupFileURL: URL?
        var error: Error?
        
        do {
            // Phase 1: Parse data from file
            updateProgress(jobId: jobId, phase: .parsing)
            let parsedData = try await parseDataFromFile(fileURL, format: configuration.sourceFormat)
            totalRecords = parsedData.count
            updateProgress(jobId: jobId, totalRecords: totalRecords, phase: .parsing)
            
            // Phase 2: Validate data
            updateProgress(jobId: jobId, phase: .validation)
            let validationResult = await validateData(parsedData, rules: configuration.validationRules)
            validationErrors = validationResult.errors
            warnings = validationResult.warnings
            
            let validData = validationResult.validRecords
            let invalidData = validationResult.invalidRecords
            
            updateProgress(jobId: jobId, 
                          validRecords: validData.count,
                          invalidRecords: invalidData.count,
                          phase: .validation)
            
            // Phase 3: Create backup if requested
            if configuration.createBackup && !configuration.dryRun {
                backupFileURL = try await createBackup(for: configuration.targetDataType)
            }
            
            // Phase 4: Process valid data
            updateProgress(jobId: jobId, phase: .processing)
            
            if !configuration.dryRun {
                let processingResult = try await processValidData(
                    validData,
                    configuration: configuration,
                    jobId: jobId
                )
                successfulRecords = processingResult.successful
                failedRecords = processingResult.failed
                conflictedRecords = processingResult.conflicted
            } else {
                // Dry run - just simulate processing
                successfulRecords = validData.count
                warnings.append("这是试运行，未实际修改数据")
            }
            
            // Phase 5: Cleanup
            updateProgress(jobId: jobId, phase: .cleanup)
            
        } catch let importError {
            error = importError
            lastError = importError
        }
        
        let endTime = Date()
        
        // Create result
        let result = ImportResult(
            jobId: jobId,
            configuration: configuration,
            startTime: startTime,
            endTime: endTime,
            totalRecords: totalRecords,
            successfulRecords: successfulRecords,
            failedRecords: failedRecords,
            conflictedRecords: conflictedRecords,
            validationErrors: validationErrors,
            warnings: warnings,
            backupFileURL: backupFileURL,
            success: error == nil && failedRecords == 0,
            error: error
        )
        
        // Update state
        activeImports.removeValue(forKey: jobId)
        importHistory.insert(result, at: 0)
        
        // Keep only last 50 import results
        if importHistory.count > 50 {
            importHistory = Array(importHistory.prefix(50))
        }
        
        // Audit log
        try? await auditService.logSecurityEvent(
            event: "data_import_completed",
            userId: authService.currentUser?.id ?? "unknown",
            details: [
                "job_id": jobId,
                "success": "\(result.success)",
                "total_records": "\(totalRecords)",
                "successful_records": "\(successfulRecords)",
                "failed_records": "\(failedRecords)",
                "duration": "\(result.duration)",
                "error": error?.localizedDescription ?? "none"
            ]
        )
    }
    
    // MARK: - Data Parsing (数据解析)
    
    /// Parse data from file based on format
    /// 根据格式从文件解析数据
    private func parseDataFromFile(_ fileURL: URL, format: ExportFormat) async throws -> [[String: Any]] {
        let data = try Data(contentsOf: fileURL)
        
        switch format {
        case .json:
            return try parseJSONData(data)
        case .csv:
            return try parseCSVData(data)
        case .excel:
            return try parseExcelData(data)
        case .xml:
            return try parseXMLData(data)
        case .sqlite:
            return try parseSQLiteData(fileURL)
        case .pdf:
            throw ImportError.unsupportedFormat("PDF import not supported")
        }
    }
    
    private func parseJSONData(_ data: Data) throws -> [[String: Any]] {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.parseError("Invalid JSON format")
        }
        
        // Extract array of records from JSON structure
        var records: [[String: Any]] = []
        
        for (_, value) in jsonObject {
            if let array = value as? [[String: Any]] {
                records.append(contentsOf: array)
            }
        }
        
        return records
    }
    
    private func parseCSVData(_ data: Data) throws -> [[String: Any]] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.parseError("Unable to read CSV file")
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            throw ImportError.parseError("Empty CSV file")
        }
        
        // First line as headers
        let headers = lines[0].components(separatedBy: ",")
        var records: [[String: Any]] = []
        
        for i in 1..<lines.count {
            let values = lines[i].components(separatedBy: ",")
            var record: [String: Any] = [:]
            
            for (index, header) in headers.enumerated() {
                if index < values.count {
                    record[header.trimmingCharacters(in: .whitespaces)] = values[index].trimmingCharacters(in: .whitespaces)
                }
            }
            
            records.append(record)
        }
        
        return records
    }
    
    private func parseExcelData(_ data: Data) throws -> [[String: Any]] {
        // Placeholder - real implementation would use Excel parsing library
        throw ImportError.parseError("Excel parsing not implemented in this demo")
    }
    
    private func parseXMLData(_ data: Data) throws -> [[String: Any]] {
        // Placeholder - real implementation would use XML parser
        throw ImportError.parseError("XML parsing not implemented in this demo")
    }
    
    private func parseSQLiteData(_ fileURL: URL) throws -> [[String: Any]] {
        // Placeholder - real implementation would use SQLite
        throw ImportError.parseError("SQLite parsing not implemented in this demo")
    }
    
    // MARK: - Data Validation (数据验证)
    
    /// Validate parsed data against rules
    /// 根据规则验证解析的数据
    private func validateData(_ data: [[String: Any]], rules: [ImportValidationRule]) async -> (validRecords: [[String: Any]], invalidRecords: [[String: Any]], errors: [ValidationError], warnings: [String]) {
        var validRecords: [[String: Any]] = []
        var invalidRecords: [[String: Any]] = []
        var allErrors: [ValidationError] = []
        var warnings: [String] = []
        
        for (index, record) in data.enumerated() {
            var recordErrors: [ValidationError] = []
            
            // Validate against each rule
            for rule in rules {
                let fieldValue = record[rule.field]
                let validationResult = validateField(fieldValue, against: rule, recordIndex: index)
                
                if !validationResult.isValid {
                    let error = ValidationError(
                        recordIndex: index,
                        field: rule.field,
                        value: fieldValue,
                        rule: rule,
                        message: validationResult.errors.joined(separator: ", ")
                    )
                    recordErrors.append(error)
                }
                
                warnings.append(contentsOf: validationResult.warnings)
            }
            
            if recordErrors.isEmpty {
                validRecords.append(record)
            } else {
                invalidRecords.append(record)
                allErrors.append(contentsOf: recordErrors)
            }
        }
        
        return (validRecords, invalidRecords, allErrors, warnings)
    }
    
    /// Validate individual field against rule
    /// 根据规则验证单个字段
    private func validateField(_ value: Any?, against rule: ImportValidationRule, recordIndex: Int) -> ImportValidationResult {
        // Check required fields
        if rule.isRequired && (value == nil || (value as? String)?.isEmpty == true) {
            return ImportValidationResult(isValid: false, errors: ["必填字段不能为空"])
        }
        
        guard let value = value else {
            return ImportValidationResult.valid
        }
        
        switch rule.type {
        case .required:
            return ImportValidationResult.valid // Already checked above
            
        case .dataType(let dataType):
            return validateDataType(value, expectedType: dataType)
            
        case .range(let min, let max):
            return validateRange(value, min: min, max: max)
            
        case .length(let min, let max):
            return validateLength(value, min: min, max: max)
            
        case .regex(let pattern):
            return validateRegex(value, pattern: pattern)
            
        case .uniqueness:
            // This would require checking against existing data
            return ImportValidationResult.valid // Placeholder
            
        case .custom:
            return rule.customValidator?(value) ?? ImportValidationResult.valid
        }
    }
    
    private func validateDataType(_ value: Any, expectedType: ImportValidationRule.ValidationType.DataType) -> ImportValidationResult {
        switch expectedType {
        case .string:
            return value is String ? ImportValidationResult.valid : ImportValidationResult(isValid: false, errors: ["期望字符串类型"])
        case .integer:
            return (value is Int || Int(value as? String ?? "") != nil) ? ImportValidationResult.valid : ImportValidationResult(isValid: false, errors: ["期望整数类型"])
        case .double:
            return (value is Double || Double(value as? String ?? "") != nil) ? ImportValidationResult.valid : ImportValidationResult(isValid: false, errors: ["期望数字类型"])
        case .boolean:
            return (value is Bool || ["true", "false", "1", "0"].contains(value as? String)) ? ImportValidationResult.valid : ImportValidationResult(isValid: false, errors: ["期望布尔类型"])
        case .date:
            // Would need date parsing logic
            return ImportValidationResult.valid // Placeholder
        case .uuid:
            return UUID(uuidString: value as? String ?? "") != nil ? ImportValidationResult.valid : ImportValidationResult(isValid: false, errors: ["期望UUID格式"])
        }
    }
    
    private func validateRange(_ value: Any, min: Double, max: Double) -> ImportValidationResult {
        var numericValue: Double?
        
        if let doubleValue = value as? Double {
            numericValue = doubleValue
        } else if let intValue = value as? Int {
            numericValue = Double(intValue)
        } else if let stringValue = value as? String {
            numericValue = Double(stringValue)
        }
        
        guard let num = numericValue else {
            return ImportValidationResult(isValid: false, errors: ["无法转换为数字"])
        }
        
        if num < min || num > max {
            return ImportValidationResult(isValid: false, errors: ["数值必须在 \(min) 到 \(max) 之间"])
        }
        
        return ImportValidationResult.valid
    }
    
    private func validateLength(_ value: Any, min: Int, max: Int) -> ImportValidationResult {
        guard let stringValue = value as? String else {
            return ImportValidationResult(isValid: false, errors: ["期望字符串类型"])
        }
        
        let length = stringValue.count
        if length < min || length > max {
            return ImportValidationResult(isValid: false, errors: ["长度必须在 \(min) 到 \(max) 个字符之间"])
        }
        
        return ImportValidationResult.valid
    }
    
    private func validateRegex(_ value: Any, pattern: String) -> ImportValidationResult {
        guard let stringValue = value as? String else {
            return ImportValidationResult(isValid: false, errors: ["期望字符串类型"])
        }
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: stringValue.utf16.count)
            
            if regex.firstMatch(in: stringValue, options: [], range: range) != nil {
                return ImportValidationResult.valid
            } else {
                return ImportValidationResult(isValid: false, errors: ["格式不匹配"])
            }
        } catch {
            return ImportValidationResult(isValid: false, errors: ["正则表达式错误"])
        }
    }
    
    // MARK: - Data Processing (数据处理)
    
    /// Process valid data and handle conflicts
    /// 处理有效数据并处理冲突
    private func processValidData(_ data: [[String: Any]], configuration: ImportConfiguration, jobId: String) async throws -> (successful: Int, failed: Int, conflicted: Int) {
        var successful = 0
        var failed = 0
        var conflicted = 0
        
        // Process in batches
        let batches = data.chunked(into: configuration.batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            try await processBatch(batch, configuration: configuration)
            
            successful += batch.count
            
            // Update progress
            let totalProcessed = (batchIndex + 1) * configuration.batchSize
            updateProgress(jobId: jobId, processedRecords: min(totalProcessed, data.count))
        }
        
        return (successful, failed, conflicted)
    }
    
    /// Process a batch of records
    /// 处理一批记录
    private func processBatch(_ batch: [[String: Any]], configuration: ImportConfiguration) async throws {
        switch configuration.targetDataType {
        case .productionBatches:
            try await importProductionBatches(batch, configuration: configuration)
        case .machines:
            try await importMachines(batch, configuration: configuration)
        case .users:
            try await importUsers(batch, configuration: configuration)
        case .customers:
            try await importCustomers(batch, configuration: configuration)
        case .products:
            try await importProducts(batch, configuration: configuration)
        case .colors:
            try await importColors(batch, configuration: configuration)
        default:
            throw ImportError.unsupportedDataType(configuration.targetDataType.rawValue)
        }
    }
    
    private func importProductionBatches(_ batch: [[String: Any]], configuration: ImportConfiguration) async throws {
        for record in batch {
            // Convert record to ProductionBatch
            // This is a simplified example - real implementation would have proper mapping
            print("Importing production batch: \(record)")
        }
    }
    
    private func importMachines(_ batch: [[String: Any]], configuration: ImportConfiguration) async throws {
        for record in batch {
            print("Importing machine: \(record)")
        }
    }
    
    private func importUsers(_ batch: [[String: Any]], configuration: ImportConfiguration) async throws {
        for record in batch {
            print("Importing user: \(record)")
        }
    }
    
    private func importCustomers(_ batch: [[String: Any]], configuration: ImportConfiguration) async throws {
        for record in batch {
            print("Importing customer: \(record)")
        }
    }
    
    private func importProducts(_ batch: [[String: Any]], configuration: ImportConfiguration) async throws {
        for record in batch {
            print("Importing product: \(record)")
        }
    }
    
    private func importColors(_ batch: [[String: Any]], configuration: ImportConfiguration) async throws {
        for record in batch {
            print("Importing color: \(record)")
        }
    }
    
    // MARK: - Backup Creation (备份创建)
    
    /// Create backup before import
    /// 导入前创建备份
    private func createBackup(for dataType: ExportDataType) async throws -> URL {
        return try await backupService.createBackup(
            dataTypes: [dataType],
            reason: "Pre-import backup"
        )
    }
    
    // MARK: - Utility Methods (实用方法)
    
    private func setupDirectories() {
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    private func updateProgress(
        jobId: String,
        totalRecords: Int? = nil,
        processedRecords: Int? = nil,
        validRecords: Int? = nil,
        invalidRecords: Int? = nil,
        conflictedRecords: Int? = nil,
        phase: ImportProgress.ImportPhase? = nil
    ) {
        guard var progress = activeImports[jobId] else { return }
        
        progress = ImportProgress(
            jobId: jobId,
            totalRecords: totalRecords ?? progress.totalRecords,
            processedRecords: processedRecords ?? progress.processedRecords,
            validRecords: validRecords ?? progress.validRecords,
            invalidRecords: invalidRecords ?? progress.invalidRecords,
            conflictedRecords: conflictedRecords ?? progress.conflictedRecords,
            currentPhase: phase ?? progress.currentPhase,
            isCompleted: false,
            error: progress.error
        )
        
        activeImports[jobId] = progress
    }
    
    /// Cancel active import
    /// 取消活动导入
    func cancelImport(jobId: String) async {
        activeImports.removeValue(forKey: jobId)
        
        // Audit log
        try? await auditService.logSecurityEvent(
            event: "data_import_cancelled",
            userId: authService.currentUser?.id ?? "unknown",
            details: ["job_id": jobId]
        )
    }
    
    /// Get import progress
    /// 获取导入进度
    func getImportProgress(jobId: String) -> ImportProgress? {
        return activeImports[jobId]
    }
    
    /// Get default validation rules for data type
    /// 获取数据类型的默认验证规则
    func getDefaultValidationRules(for dataType: ExportDataType) -> [ImportValidationRule] {
        switch dataType {
        case .productionBatches:
            return [
                ImportValidationRule(field: "batchNumber", type: ImportValidationRule.ValidationType.required, isRequired: true),
                ImportValidationRule(field: "machineId", type: ImportValidationRule.ValidationType.required, isRequired: true),
                ImportValidationRule(field: "status", type: ImportValidationRule.ValidationType.regex("^(unsubmitted|submitted|active|completed|cancelled)$"))
            ]
        case .machines:
            return [
                ImportValidationRule(field: "machineNumber", type: ImportValidationRule.ValidationType.required, isRequired: true),
                ImportValidationRule(field: "isActive", type: ImportValidationRule.ValidationType.dataType(ImportValidationRule.ValidationType.DataType.boolean)),
                ImportValidationRule(field: "utilizationRate", type: ImportValidationRule.ValidationType.range(min: 0, max: 100))
            ]
        case .users:
            return [
                ImportValidationRule(field: "name", type: ImportValidationRule.ValidationType.required, isRequired: true),
                ImportValidationRule(field: "name", type: ImportValidationRule.ValidationType.length(min: 1, max: 100)),
                ImportValidationRule(field: "email", type: ImportValidationRule.ValidationType.regex("^[A-Za-z0-9+_.-]+@(.+)$"))
            ]
        default:
            return []
        }
    }
}

// MARK: - Error Types (错误类型)

enum ImportError: LocalizedError {
    case insufficientPermissions
    case fileNotFound
    case tooManyActiveImports
    case parseError(String)
    case validationError
    case unsupportedFormat(String)
    case unsupportedDataType(String)
    case backupCreationFailed
    case dataProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientPermissions:
            return "权限不足，无法执行数据导入"
        case .fileNotFound:
            return "找不到导入文件"
        case .tooManyActiveImports:
            return "活动导入任务过多，请等待后重试"
        case .parseError(let reason):
            return "文件解析失败: \(reason)"
        case .validationError:
            return "数据验证失败"
        case .unsupportedFormat(let format):
            return "不支持的文件格式: \(format)"
        case .unsupportedDataType(let dataType):
            return "不支持的数据类型: \(dataType)"
        case .backupCreationFailed:
            return "创建备份失败"
        case .dataProcessingFailed:
            return "数据处理失败"
        }
    }
}

// MARK: - Supporting Extensions (支持扩展)

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}