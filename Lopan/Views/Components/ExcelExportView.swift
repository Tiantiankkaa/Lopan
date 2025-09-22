//
//  ExcelExportView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct ExcelExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let dataType: DataType
    
    @Query private var customers: [Customer]
    @Query private var products: [Product]
    
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportResult: ExcelExportResult?
    @State private var exportedFileURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Excel 导出")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(dataType == .customers ? "导出客户数据" : "导出产品数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Data Summary
                VStack(alignment: .leading, spacing: 15) {
                    Text("数据概览")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("总数量:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(dataType == .customers ? customers.count : products.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("导出格式:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("CSV")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Export Options
                VStack(alignment: .leading, spacing: 15) {
                    Text("导出选项")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 导出为 CSV 格式文件")
                        Text("• 包含所有字段信息")
                        Text("• 自动生成文件名")
                        Text("• 支持分享和保存")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Export Button
                Button(action: exportData) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isExporting ? "导出中..." : "开始导出")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isExporting ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isExporting)
                .sheet(isPresented: $showingShareSheet) {
                    if let url = exportedFileURL {
                        ShareSheet(activityItems: [url])
                    }
                }
                
                // Export Result
                if let result = exportResult {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                            Text(result.message)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Excel 导出")
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
    
    private func exportData() {
        isExporting = true
        exportResult = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileURL: URL?
            
            switch dataType {
            case .customers:
                fileURL = ExcelService.shared.exportCustomers(customers)
            case .products:
                fileURL = ExcelService.shared.exportProducts(products)
            }
            
            DispatchQueue.main.async {
                self.isExporting = false
                
                if let url = fileURL {
                    self.exportedFileURL = url
                    self.showingShareSheet = true
                    self.exportResult = ExcelExportResult(success: true, message: "文件已准备就绪，请选择保存位置")
                } else {
                    self.exportResult = ExcelExportResult(success: false, message: "导出失败")
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ExcelExportResult {
    let success: Bool
    let message: String
    let fileURL: URL?
    
    init(success: Bool, message: String, fileURL: URL? = nil) {
        self.success = success
        self.message = message
        self.fileURL = fileURL
    }
}



#Preview {
    ExcelExportView(dataType: .products)
        .modelContainer(for: [Product.self, ProductSize.self], inMemory: true)
} 