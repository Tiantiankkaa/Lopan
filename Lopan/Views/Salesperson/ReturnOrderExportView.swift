//
//  ReturnOrderExportView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct ReturnOrderExportView: View {
    @Environment(\.dismiss) private var dismiss
    let items: [CustomerOutOfStock]
    
    @State private var selectedItems: Set<String> = []
    @State private var exportType: ExportType = .pendingReturns
    @State private var showingExportResult = false
    @State private var exportResultMessage = ""
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingSaveDialog = false
    
    var body: some View {
        NavigationStack {
            VStack {
                headerSection
                exportTypeSection
                itemsListSection
                actionButtons
            }
            .navigationTitle("export_return_orders".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("导出结果", isPresented: $showingExportResult) {
                Button("确定") {
                    if exportedFileURL != nil {
                        dismiss()
                    }
                }
                if let _ = exportedFileURL {
                    Button("分享文件") {
                        showingShareSheet = true
                    }
                    Button("保存到文件") {
                        showingSaveDialog = true
                    }
                }
            } message: {
                if let url = exportedFileURL {
                    let fileInfo = FileShareService.shared.getFileInfo(url)
                    Text("文件名: \(fileInfo.name)\n文件大小: \(fileInfo.size)\n\n\(exportResultMessage)")
                } else {
                    Text(exportResultMessage)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    FileShareSheet(url: url, isPresented: $showingShareSheet)
                }
            }
        }
        .onAppear {
            initializeSelection()
        }
        .onChange(of: showingSaveDialog) { _, newValue in
            if newValue {
                handleSaveToFiles()
                showingSaveDialog = false
            }
        }
    }
    
    private var headerSection: some View {
        VStack {
            Text("选择要导出的还货记录")
                .font(.headline)
            
            Text("共 \(items.count) 条记录可供导出")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var exportTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导出类型")
                .font(.headline)
            
            VStack(spacing: 8) {
                ExportTypeButton(
                    type: .pendingReturns,
                    selectedType: $exportType,
                    title: "待还货记录",
                    subtitle: "仅导出需要还货的记录"
                )
                
                ExportTypeButton(
                    type: .allReturns,
                    selectedType: $exportType,
                    title: "所有还货记录",
                    subtitle: "导出所有相关的还货记录"
                )
                
                ExportTypeButton(
                    type: .selectedOnly,
                    selectedType: $exportType,
                    title: "仅选中记录",
                    subtitle: "只导出下方选中的记录"
                )
            }
        }
        .padding()
    }
    
    private var itemsListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("记录列表 (\(filteredItems.count) 条)")
                    .font(.headline)
                
                Spacer()
                
                Button(selectedItems.count == filteredItems.count ? "取消全选" : "全选") {
                    toggleSelectAll()
                }
                .font(.caption)
                .foregroundColor(LopanColors.info)
            }
            .padding(.horizontal)
            
            List {
                ForEach(filteredItems, id: \.id) { item in
                    ExportItemRow(
                        item: item,
                        isSelected: selectedItems.contains(item.id),
                        onToggle: { toggleItemSelection(item) }
                    )
                }
            }
            .listStyle(PlainListStyle())
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Text("将导出 \(itemsToExport.count) 条记录")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { exportReturnOrders() }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出 Excel 文件")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(itemsToExport.isEmpty ? LopanColors.disabled : LopanColors.success)
                .foregroundColor(LopanColors.textPrimary)
                .cornerRadius(10)
            }
            .disabled(itemsToExport.isEmpty)
        }
        .padding()
    }
    
    private var filteredItems: [CustomerOutOfStock] {
        switch exportType {
        case .pendingReturns:
            return items.filter { $0.needsDelivery }
        case .allReturns:
            return items
        case .selectedOnly:
            return items.filter { selectedItems.contains($0.id) }
        }
    }

    private var itemsToExport: [CustomerOutOfStock] {
        switch exportType {
        case .pendingReturns:
            return items.filter { $0.needsDelivery }
        case .allReturns:
            return items
        case .selectedOnly:
            return items.filter { selectedItems.contains($0.id) }
        }
    }

    private func initializeSelection() {
        // Select all items that need delivery by default
        selectedItems = Set(items.filter { $0.needsDelivery }.map { $0.id })
    }
    
    private func toggleSelectAll() {
        if selectedItems.count == filteredItems.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(filteredItems.map { $0.id })
        }
    }
    
    private func toggleItemSelection(_ item: CustomerOutOfStock) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    private func exportReturnOrders() {
        let exportItems = itemsToExport
        
        guard !exportItems.isEmpty else {
            exportResultMessage = "没有可导出的记录"
            showingExportResult = true
            return
        }
        
        if let url = ExcelService.shared.exportReturnOrders(exportItems) {
            exportedFileURL = url
            exportResultMessage = "成功导出 \(exportItems.count) 条还货记录到文件"
        } else {
            exportResultMessage = "导出失败，请重试"
        }
        
        showingExportResult = true
    }
    
    private func handleSaveToFiles() {
        guard let url = exportedFileURL else { return }
        
        FileShareService.shared.saveFileToDocuments(url) { success, message in
            DispatchQueue.main.async {
                exportResultMessage = message
                showingExportResult = true
            }
        }
    }
}

enum ExportType: CaseIterable {
    case pendingReturns
    case allReturns
    case selectedOnly
}

struct ExportTypeButton: View {
    let type: ExportType
    @Binding var selectedType: ExportType
    let title: String
    let subtitle: String
    
    var body: some View {
        Button(action: { selectedType = type }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: selectedType == type ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedType == type ? LopanColors.primary : LopanColors.secondary)
            }
            .padding()
            .background(selectedType == type ? LopanColors.primary.opacity(0.1) : LopanColors.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExportItemRow: View {
    let item: CustomerOutOfStock
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? LopanColors.primary : LopanColors.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.customerDisplayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(item.productDisplayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("剩余: \(item.remainingQuantity)")
                            .font(.caption)
                            .foregroundColor(LopanColors.warning)
                        
                        if item.hasPartialDelivery {
                            Text("已发货: \(item.deliveryQuantity)")
                                .font(.caption)
                                .foregroundColor(LopanColors.info)
                        }
                    }
                }
                
                Spacer()
                
                returnStatusBadge
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var returnStatusBadge: some View {
        Text(returnStatusText)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(returnStatusColor.opacity(0.2))
            .foregroundColor(returnStatusColor)
            .cornerRadius(4)
    }
    
    private var returnStatusText: String {
        if item.isFullyDelivered {
            return "fully_delivered".localized
        } else if item.hasPartialDelivery {
            return "partially_delivered".localized
        } else if item.needsDelivery {
            return "needs_delivery".localized
        } else {
            return item.status.displayName
        }
    }

    private var returnStatusColor: Color {
        if item.isFullyDelivered {
            return LopanColors.success
        } else if item.hasPartialDelivery {
            return LopanColors.primary
        } else if item.needsDelivery {
            return LopanColors.warning
        } else {
            return LopanColors.textSecondary
        }
    }
}
