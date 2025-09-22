//
//  ExcelImportView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum DataType {
    case customers
    case products
}

struct ExcelImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let dataType: DataType
    
    @State private var showingFilePicker = false
    @State private var showingTemplateDownload = false
    @State private var importResult: ExcelImportResult?
    @State private var isImporting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                headerSection
                instructionsSection
                actionButtonsSection
                importResultSection
                Spacer()
            }
            .padding()
            .navigationTitle("Excel 导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("下载模板", isPresented: $showingTemplateDownload) {
                Button("下载客户模板") {
                    downloadTemplate(.customers)
                }
                Button("下载产品模板") {
                    downloadTemplate(.products)
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("选择要下载的模板类型")
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Excel 导入")
                .font(.title)
                .fontWeight(.bold)
            
            Text(dataType == .customers ? "导入客户数据" : "导入产品数据")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("导入说明")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• 支持 CSV 格式文件")
                Text("• 第一行为标题行，将被自动跳过")
                Text("• 请确保数据格式正确")
                
                if dataType == .customers {
                    Text("• 客户数据格式：姓名,地址,联系电话")
                } else {
                    Text("• 产品数据格式：产品名称,颜色(逗号分隔),尺寸(逗号分隔)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 15) {
            Button(action: { showingTemplateDownload = true }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("下载模板")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: { showingFilePicker = true }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("选择文件导入")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isImporting)
        }
    }
    
    private var importResultSection: some View {
        Group {
            if let result = importResult {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.success ? .green : .red)
                        Text(result.message)
                            .fontWeight(.medium)
                    }
                    
                    if let errors = result.errors, !errors.isEmpty {
                        Text("错误详情:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(errors.prefix(5), id: \.self) { error in
                                    Text("• \(error)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                if errors.count > 5 {
                                    Text("... 还有 \(errors.count - 5) 个错误")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                    }
                }
                .padding()
                .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            isImporting = true
            importResult = nil
            
            DispatchQueue.global(qos: .userInitiated).async {
                let result: ExcelImportResult
                
                switch dataType {
                case .customers:
                    result = ExcelService.shared.importCustomers(from: url, modelContext: modelContext)
                case .products:
                    result = ExcelService.shared.importProducts(from: url, modelContext: modelContext)
                }
                
                DispatchQueue.main.async {
                    self.importResult = result
                    self.isImporting = false
                    
                    if result.success {
                        // Post notification to refresh views
                        NotificationCenter.default.post(name: dataType == .customers ? .customerAdded : .productAdded, object: nil)
                    }
                }
            }
            
        case .failure(let error):
            importResult = ExcelImportResult(success: false, message: "文件选择失败: \(error.localizedDescription)")
        }
    }
    
    private func downloadTemplate(_ type: DataType) {
        let url: URL?
        
        switch type {
        case .customers:
            url = ExcelService.shared.generateCustomerTemplate()
        case .products:
            url = ExcelService.shared.generateProductTemplate()
        }
        
        if let url = url {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityVC, animated: true)
            }
        }
    }
}

#Preview {
    ExcelImportView(dataType: .products)
        .modelContainer(for: [Product.self, ProductSize.self], inMemory: true)
} 