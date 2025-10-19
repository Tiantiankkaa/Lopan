//
//  DataExportComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Simple Export Format (为了与现有DataExportEngine.swift区分)
enum SimpleExportFormat: String, CaseIterable, Codable, Identifiable {
    case json = "json"
    case csv = "csv"
    case excel = "xlsx"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .excel: return "Excel (XLSX)"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .excel: return "xlsx"
        }
    }
}

// MARK: - Simple Export Configuration (为了与现有DataExportEngine.swift区分)
struct SimpleExportConfig {
    let format: SimpleExportFormat
    let includeHeaders: Bool
    let dateFormat: String
    let filename: String?
    let filters: [String: Any]?
    
    init(
        format: SimpleExportFormat = .csv,
        includeHeaders: Bool = true,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss",
        filename: String? = nil,
        filters: [String: Any]? = nil
    ) {
        self.format = format
        self.includeHeaders = includeHeaders
        self.dateFormat = dateFormat
        self.filename = filename
        self.filters = filters
    }
}

// MARK: - Export Data Protocol
protocol ExportableData {
    func toCSVRow() -> [String]
    func toJSONObject() -> [String: Any]
    static func csvHeaders() -> [String]
}

// MARK: - Customer Out of Stock Export Extension
extension CustomerOutOfStock: ExportableData {
    func toCSVRow() -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return [
            customer?.name ?? "",
            customer?.address ?? "",
            customer?.phone ?? "",
            productDisplayName,
            String(quantity),
            status.displayName,
            dateFormatter.string(from: requestDate),
            String(deliveryQuantity),
            deliveryDate != nil ? dateFormatter.string(from: deliveryDate!) : "",
            notes ?? ""
        ]
    }
    
    func toJSONObject() -> [String: Any] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return [
            "id": id,
            "customer_name": customer?.name ?? "",
            "customer_address": customer?.address ?? "",
            "customer_phone": customer?.phone ?? "",
            "product_name": productDisplayName,
            "quantity": quantity,
            "status": status.rawValue,
            "status_display": status.displayName,
            "request_date": dateFormatter.string(from: requestDate),
            "delivery_quantity": deliveryQuantity,
            "delivery_date": deliveryDate != nil ? dateFormatter.string(from: deliveryDate!) : "",
            "notes": notes ?? "",
            "created_by": createdBy,
            "created_at": dateFormatter.string(from: createdAt),
            "updated_at": dateFormatter.string(from: updatedAt)
        ]
    }
    
    static func csvHeaders() -> [String] {
        return [
            "客户姓名",
            "客户地址",
            "客户电话",
            "产品名称",
            "数量",
            "优先级",
            "状态",
            "请求日期",
            "还货数量",
            "还货日期",
            "备注"
        ]
    }
}

// MARK: - Customer Export Extension
extension Customer: ExportableData {
    func toCSVRow() -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return [
            name,
            address,
            phone,
            dateFormatter.string(from: createdAt),
            dateFormatter.string(from: updatedAt)
        ]
    }
    
    func toJSONObject() -> [String: Any] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return [
            "id": id,
            "name": name,
            "address": address,
            "phone": phone,
            "created_at": dateFormatter.string(from: createdAt),
            "updated_at": dateFormatter.string(from: updatedAt)
        ]
    }
    
    static func csvHeaders() -> [String] {
        return [
            "客户姓名",
            "客户地址",
            "客户电话",
            "创建时间",
            "更新时间"
        ]
    }
}

// MARK: - Product Export Extension
extension Product: ExportableData {
    func toCSVRow() -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return [
            name,
            sku,
            sizeNames.joined(separator: ", "),
            dateFormatter.string(from: createdAt),
            dateFormatter.string(from: updatedAt)
        ]
    }

    func toJSONObject() -> [String: Any] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return [
            "id": id,
            "name": name,
            "sku": sku,
            "sizes": sizeNames,
            "created_at": dateFormatter.string(from: createdAt),
            "updated_at": dateFormatter.string(from: updatedAt)
        ]
    }

    static func csvHeaders() -> [String] {
        return [
            "产品名称",
            "SKU",
            "尺寸",
            "创建时间",
            "更新时间"
        ]
    }
}

// MARK: - AuditLog Export Extension
extension AuditLog: ExportableData {
    func toCSVRow() -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return [
            operationType.displayName,
            entityType.displayName,
            entityDescription,
            operatorUserName,
            operationDetails,
            dateFormatter.string(from: timestamp)
        ]
    }
    
    func toJSONObject() -> [String: Any] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return [
            "id": id,
            "operation_type": operationType.rawValue,
            "operation_type_display": operationType.displayName,
            "entity_type": entityType.rawValue,
            "entity_type_display": entityType.displayName,
            "entity_description": entityDescription,
            "operator_user_id": userId,
            "operator_user_name": operatorUserName,
            "operation_details": operationDetails,
            "timestamp": dateFormatter.string(from: timestamp)
        ]
    }
    
    static func csvHeaders() -> [String] {
        return [
            "操作类型",
            "实体类型", 
            "实体描述",
            "操作员",
            "操作详情",
            "时间戳"
        ]
    }
}

// MARK: - Data Export Service
@MainActor
class DataExportService: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: Error?
    
    func exportData<T: ExportableData>(
        _ data: [T],
        configuration: SimpleExportConfig
    ) async throws -> URL {
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        defer {
            isExporting = false
            exportProgress = 0.0
        }
        
        do {
            let exportedData = try await processDataForExport(data, configuration: configuration)
            let url = try await saveDataToFile(exportedData, configuration: configuration)
            return url
        } catch {
            exportError = error
            throw error
        }
    }
    
    private func processDataForExport<T: ExportableData>(
        _ data: [T],
        configuration: SimpleExportConfig
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let exportData: Data
                    
                    switch configuration.format {
                    case .csv:
                        exportData = try self.generateCSV(data, configuration: configuration)
                    case .json:
                        exportData = try self.generateJSON(data, configuration: configuration)
                    case .excel:
                        exportData = try self.generateExcel(data, configuration: configuration)
                    }
                    
                    DispatchQueue.main.async {
                        self.exportProgress = 1.0
                    }
                    
                    continuation.resume(returning: exportData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    nonisolated private func generateCSV<T: ExportableData>(
        _ data: [T],
        configuration: SimpleExportConfig
    ) throws -> Data {
        var csvContent = ""

        // Add headers if requested
        if configuration.includeHeaders {
            let headers = T.csvHeaders()
            csvContent += headers.joined(separator: ",") + "\n"
        }

        // Add data rows
        for item in data {
            let row = item.toCSVRow()
            let escapedRow = row.map { escapeCSVField($0) }
            csvContent += escapedRow.joined(separator: ",") + "\n"
        }

        guard let data = csvContent.data(using: .utf8) else {
            throw SimpleExportError.dataConversionFailed
        }

        return data
    }
    
    nonisolated private func generateJSON<T: ExportableData>(
        _ data: [T],
        configuration: SimpleExportConfig
    ) throws -> Data {
        let jsonObjects = data.map { item in
            return item.toJSONObject()
        }

        let jsonData: [String: Any] = [
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "total_records": data.count,
            "format": configuration.format.rawValue,
            "data": jsonObjects
        ]

        do {
            return try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
        } catch {
            throw SimpleExportError.jsonSerializationFailed(error)
        }
    }
    
    nonisolated private func generateExcel<T: ExportableData>(
        _ data: [T],
        configuration: SimpleExportConfig
    ) throws -> Data {
        // For Excel generation, we'll create a CSV and note that
        // a proper Excel library would be needed for full Excel support
        // This is a simplified implementation
        return try generateCSV(data, configuration: configuration)
    }
    
    private func saveDataToFile(_ data: Data, configuration: SimpleExportConfig) async throws -> URL {
        let filename = configuration.filename ?? generateFilename(for: configuration.format)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    private func generateFilename(for format: SimpleExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        return "export_\(timestamp).\(format.fileExtension)"
    }
    
    nonisolated private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escapedQuotes = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedQuotes)\""
        }
        return field
    }
}

// MARK: - Simple Export Error (避免与DataExportEngine冲突)
enum SimpleExportError: Error, LocalizedError {
    case dataConversionFailed
    case jsonSerializationFailed(Error)
    case fileWriteFailed(Error)
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .dataConversionFailed:
            return "数据转换失败"
        case .jsonSerializationFailed(let error):
            return "JSON序列化失败: \(error.localizedDescription)"
        case .fileWriteFailed(let error):
            return "文件写入失败: \(error.localizedDescription)"
        case .unsupportedFormat:
            return "不支持的导出格式"
        }
    }
}

// MARK: - Export Configuration View
struct ExportConfigurationView: View {
    @Binding var configuration: SimpleExportConfig
    @Binding var isPresented: Bool
    let onExport: (SimpleExportConfig) -> Void
    
    @State private var selectedFormat: SimpleExportFormat
    @State private var includeHeaders: Bool
    @State private var customFilename: String
    
    init(
        configuration: Binding<SimpleExportConfig>,
        isPresented: Binding<Bool>,
        onExport: @escaping (SimpleExportConfig) -> Void
    ) {
        self._configuration = configuration
        self._isPresented = isPresented
        self.onExport = onExport
        
        self._selectedFormat = State(initialValue: configuration.wrappedValue.format)
        self._includeHeaders = State(initialValue: configuration.wrappedValue.includeHeaders)
        self._customFilename = State(initialValue: configuration.wrappedValue.filename ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("导出格式") {
                    Picker("格式", selection: $selectedFormat) {
                        ForEach(SimpleExportFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("选择导出格式")
                }
                
                Section("选项") {
                    Toggle("包含表头", isOn: $includeHeaders)
                        .accessibilityLabel("包含表头")
                        .accessibilityValue(includeHeaders ? "开启" : "关闭")
                }
                
                Section("文件名") {
                    TextField("自定义文件名（可选）", text: $customFilename)
                        .accessibilityLabel("自定义文件名")
                        .accessibilityValue(customFilename.isEmpty ? "使用默认文件名" : customFilename)
                    
                    Text("留空将使用默认文件名")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                        .accessibilityHidden(true)
                }
                
                Section("预览") {
                    HStack {
                        Text("文件名:")
                            .foregroundColor(LopanColors.textSecondary)
                        Spacer()
                        Text(finalFilename)
                            .fontWeight(.medium)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("导出文件名: \(finalFilename)")
                }
            }
            .navigationTitle("导出设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .accessibilityLabel("取消导出")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("导出") {
                        let finalConfig = SimpleExportConfig(
                            format: selectedFormat,
                            includeHeaders: includeHeaders,
                            filename: customFilename.isEmpty ? nil : finalFilename
                        )
                        onExport(finalConfig)
                        isPresented = false
                    }
                    .accessibilityLabel("开始导出")
                }
            }
        }
        .adaptiveBackground()
    }
    
    private var finalFilename: String {
        if customFilename.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = dateFormatter.string(from: Date())
            return "export_\(timestamp).\(selectedFormat.fileExtension)"
        } else {
            let cleanFilename = customFilename.replacingOccurrences(of: ".", with: "_")
            return "\(cleanFilename).\(selectedFormat.fileExtension)"
        }
    }
}

// MARK: - Export Progress View
struct ExportProgressView: View {
    @StateObject private var exportService = DataExportService()
    let data: [any ExportableData]
    let configuration: SimpleExportConfig
    let onComplete: (URL) -> Void
    let onError: (Error) -> Void
    
    @State private var exportedFileURL: URL?
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            VStack(spacing: 16) {
                ProgressView(value: exportService.exportProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text("正在导出数据...")
                    .font(.headline)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text("\(Int(exportService.exportProgress * 100))% 完成")
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
            }
            
            // Cancel button
            Button("取消") {
                // Cancel export operation
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("导出进度 \(Int(exportService.exportProgress * 100)) 百分比完成")
        .onAppear {
            startExport()
        }
    }
    
    private func startExport() {
        Task {
            do {
                // This is a simplified version - in reality you'd need proper type handling
                let url = try await exportService.exportData(
                    data as! [CustomerOutOfStock],
                    configuration: configuration
                )
                onComplete(url)
            } catch {
                onError(error)
            }
        }
    }
}

// MARK: - Simple Share Sheet (避免与现有ShareSheet冲突)
struct SimpleShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export Button Component
struct ExportButton<T: ExportableData>: View {
    let data: [T]
    let buttonText: String
    let systemImage: String
    
    @State private var showingExportConfig = false
    @State private var showingProgressView = false
    @State private var showingShareSheet = false
    @State private var exportConfiguration = SimpleExportConfig()
    @State private var exportedFileURL: URL?
    @State private var exportError: Error?
    @State private var showingErrorAlert = false
    
    init(
        data: [T],
        buttonText: String = "导出",
        systemImage: String = "square.and.arrow.up"
    ) {
        self.data = data
        self.buttonText = buttonText
        self.systemImage = systemImage
    }
    
    var body: some View {
        Button(action: {
            showingExportConfig = true
        }) {
            Label(buttonText, systemImage: systemImage)
        }
        .accessibilityLabel("\(buttonText)数据")
        .accessibilityHint("轻点配置并导出数据")
        .sheet(isPresented: $showingExportConfig) {
            ExportConfigurationView(
                configuration: $exportConfiguration,
                isPresented: $showingExportConfig
            ) { config in
                exportConfiguration = config
                exportData()
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedFileURL {
                SimpleShareSheet(items: [url])
            }
        }
        .alert("导出错误", isPresented: $showingErrorAlert) {
            Button("确定") { }
        } message: {
            Text(exportError?.localizedDescription ?? "导出过程中发生未知错误")
        }
    }
    
    private func exportData() {
        Task {
            do {
                let exportService = DataExportService()
                let url = try await exportService.exportData(data, configuration: exportConfiguration)
                exportedFileURL = url
                showingShareSheet = true
            } catch {
                exportError = error
                showingErrorAlert = true
            }
        }
    }
}