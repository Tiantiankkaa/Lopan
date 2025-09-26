//
//  AuditLogDetailViews.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import SwiftUI

// MARK: - Filters View
struct FiltersView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedOperationType: OperationType?
    @Binding var selectedEntityType: EntityType?
    @Binding var selectedUserId: String?
    @Binding var dateRange: HistoricalBacktrackingView.DateRange
    @Binding var startDate: Date
    @Binding var endDate: Date
    let uniqueUsers: [String]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("时间范围")) {
                    Picker("日期范围", selection: $dateRange) {
                        ForEach(HistoricalBacktrackingView.DateRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if dateRange == .custom {
                        DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                    }
                }
                
                Section(header: Text("操作类型")) {
                    Picker("操作类型", selection: $selectedOperationType) {
                        Text("全部").tag(nil as OperationType?)
                        ForEach(OperationType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.iconName)
                                Text(type.displayName)
                            }.tag(type as OperationType?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("实体类型")) {
                    Picker("实体类型", selection: $selectedEntityType) {
                        Text("全部").tag(nil as EntityType?)
                        ForEach(EntityType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type as EntityType?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("操作用户")) {
                    Picker("用户", selection: $selectedUserId) {
                        Text("全部用户").tag(nil as String?)
                        ForEach(uniqueUsers, id: \.self) { user in
                            Text(user).tag(user as String?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section {
                    Button("重置筛选条件") {
                        resetFilters()
                    }
                    .foregroundColor(LopanColors.error)
                }
            }
            .navigationTitle("筛选条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func resetFilters() {
        selectedOperationType = nil
        selectedEntityType = nil
        selectedUserId = nil
        dateRange = .week
        startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        endDate = Date()
    }
}

// MARK: - Operation Detail View
struct OperationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let auditLog: AuditLog
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header card
                    headerCard
                    
                    // Basic information
                    basicInfoCard
                    
                    // Operation details
                    operationDetailsCard
                    
                    // Additional info (if available)
                    if let batchId = auditLog.batchId {
                        batchInfoCard(batchId: batchId)
                    }
                    
                    // Related entities (if any)
                    if !auditLog.relatedEntityIds.isEmpty {
                        relatedEntitiesCard
                    }
                }
                .padding()
            }
            .navigationTitle("操作详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Operation icon and type
            HStack {
                ZStack {
                    Circle()
                        .fill(operationColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: auditLog.operationType.iconName)
                        .foregroundColor(operationColor)
                        .font(.system(size: 24, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(auditLog.operationType.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(auditLog.entityType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Entity description
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("操作对象")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(auditLog.entityDescription)
                        .font(.headline)
                }
                Spacer()
            }
        }
        .padding()
        .background(LopanColors.backgroundSecondary.opacity(0.5))
        .cornerRadius(12)
    }
    
    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                AuditInfoRow(label: "操作时间", value: auditLog.formattedTimestamp)
                AuditInfoRow(label: "操作用户", value: auditLog.operatorUserName)
                AuditInfoRow(label: "用户ID", value: auditLog.userId)
                AuditInfoRow(label: "实体ID", value: auditLog.entityId)
                
                if let deviceInfo = auditLog.deviceInfo {
                    AuditInfoRow(label: "设备信息", value: deviceInfo)
                }
            }
        }
        .padding()
        .background(LopanColors.background)
        .cornerRadius(12)
    }
    
    private var operationDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作详情")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let detailsDict = auditLog.operationDetailsDict {
                operationDetailsContent(detailsDict)
            } else {
                Text("无详细信息")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(LopanColors.background)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func operationDetailsContent(_ details: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Handle different operation types
            switch auditLog.operationType {
            case .create, .update, .delete:
                if let operation = parseCustomerOutOfStockOperation(from: details) {
                    customerOutOfStockOperationView(operation)
                } else {
                    genericDetailsView(details)
                }
                
            case .statusChange:
                statusChangeView(details)
                
            case .returnProcess:
                returnProcessView(details)
                
            case .batchUpdate, .batchDelete:
                batchOperationView(details)
                
            default:
                genericDetailsView(details)
            }
        }
    }
    
    private func customerOutOfStockOperationView(_ operation: CustomerOutOfStockOperation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let beforeValues = operation.beforeValues {
                VStack(alignment: .leading, spacing: 8) {
                    Text("修改前")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.error.opacity(0.8))
                    
                    customerOutOfStockValuesView(beforeValues)
                }
                .padding()
                .background(LopanColors.error.opacity(0.05))
                .cornerRadius(8)
            }
            
            if let afterValues = operation.afterValues {
                VStack(alignment: .leading, spacing: 8) {
                    Text(operation.beforeValues == nil ? "创建内容" : "修改后")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.success.opacity(0.8))
                    
                    customerOutOfStockValuesView(afterValues)
                }
                .padding()
                .background(LopanColors.success.opacity(0.05))
                .cornerRadius(8)
            }
            
            if !operation.changedFields.isEmpty && operation.changedFields != ["all"] && operation.changedFields != ["deleted"] {
                VStack(alignment: .leading, spacing: 4) {
                    Text("变更字段")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(operation.changedFields.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let additionalInfo = operation.additionalInfo {
                AuditInfoRow(label: "备注", value: additionalInfo)
            }
        }
    }
    
    private func customerOutOfStockValuesView(_ values: CustomerOutOfStockOperation.CustomerOutOfStockValues) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let customerName = values.customerName {
                AuditInfoRow(label: "客户", value: customerName, compact: true)
            }
            if let productName = values.productName {
                AuditInfoRow(label: "产品", value: productName, compact: true)
            }
            if let quantity = values.quantity {
                AuditInfoRow(label: "数量", value: "\(quantity)", compact: true)
            }
            if let status = values.status {
                AuditInfoRow(label: "状态", value: status, compact: true)
            }
            if let notes = values.notes, !notes.isEmpty {
                AuditInfoRow(label: "备注", value: notes, compact: true)
            }
            if let returnQuantity = values.returnQuantity, returnQuantity > 0 {
                AuditInfoRow(label: "还货数量", value: "\(returnQuantity)", compact: true)
            }
            if let returnNotes = values.returnNotes, !returnNotes.isEmpty {
                AuditInfoRow(label: "还货备注", value: returnNotes, compact: true)
            }
        }
    }
    
    private func statusChangeView(_ details: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let fromStatus = details["fromStatus"] as? String,
               let toStatus = details["toStatus"] as? String {
                HStack {
                    StatusBadge(status: fromStatus, color: LopanColors.error)
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    StatusBadge(status: toStatus, color: LopanColors.success)
                }
            }
            
            if let reason = details["statusChangeReason"] as? String {
                AuditInfoRow(label: "变更原因", value: reason, compact: true)
            }
        }
    }
    
    private func returnProcessView(_ details: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let returnQuantity = details["returnQuantity"] as? Int {
                AuditInfoRow(label: "本次还货数量", value: "\(returnQuantity)", compact: true)
            }
            
            if let totalReturn = details["newTotalReturnQuantity"] as? Int {
                AuditInfoRow(label: "累计还货数量", value: "\(totalReturn)", compact: true)
            }
            
            if let remaining = details["remainingQuantity"] as? Int {
                AuditInfoRow(label: "剩余数量", value: "\(remaining)", compact: true)
            }
            
            if let notes = details["returnNotes"] as? String, !notes.isEmpty {
                AuditInfoRow(label: "还货备注", value: notes, compact: true)
            }
        }
    }
    
    private func batchOperationView(_ details: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let batchOp = details["batchOperation"] as? [String: Any] {
                if let totalCount = batchOp["totalCount"] as? Int {
                    AuditInfoRow(label: "影响项目数", value: "\(totalCount)", compact: true)
                }
                
                if let operationType = batchOp["operationType"] as? String {
                    AuditInfoRow(label: "批量操作类型", value: operationType, compact: true)
                }
            }
            
            if let descriptions = details["affectedEntityDescriptions"] as? [String] {
                VStack(alignment: .leading, spacing: 4) {
                    Text("影响的项目")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(descriptions.prefix(5).enumerated()), id: \.offset) { index, description in
                        Text("• \(description)")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    if descriptions.count > 5 {
                        Text("... 还有 \(descriptions.count - 5) 个项目")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func genericDetailsView(_ details: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(details.keys.sorted(), id: \.self) { key in
                if let value = details[key] {
                    AuditInfoRow(label: key, value: "\(value)", compact: true)
                }
            }
        }
    }
    
    private func batchInfoCard(batchId: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("批量操作信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            AuditInfoRow(label: "批量ID", value: batchId)
            
            if !auditLog.relatedEntityIds.isEmpty {
                AuditInfoRow(label: "关联项目数", value: "\(auditLog.relatedEntityIds.count)")
            }
        }
        .padding()
        .background(LopanColors.background)
        .cornerRadius(12)
    }
    
    private var relatedEntitiesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关联实体")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(auditLog.relatedEntityIds.prefix(10).enumerated()), id: \.offset) { index, entityId in
                    Text("• \(entityId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if auditLog.relatedEntityIds.count > 10 {
                    Text("... 还有 \(auditLog.relatedEntityIds.count - 10) 个关联实体")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(LopanColors.background)
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private var operationColor: Color {
        switch auditLog.operationType.color {
        case "green": return LopanColors.success
        case "blue": return LopanColors.primary
        case "red": return LopanColors.error
        case "orange": return LopanColors.warning
        case "purple": return LopanColors.primary
        case "indigo": return LopanColors.primary
        case "teal": return LopanColors.primary
        default: return LopanColors.textSecondary
        }
    }
    
    private func parseCustomerOutOfStockOperation(from details: [String: Any]) -> CustomerOutOfStockOperation? {
        guard let operationDict = details["operation"] as? [String: Any] else { return nil }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: operationDict, options: [])
            let operation = try JSONDecoder().decode(CustomerOutOfStockOperation.self, from: data)
            return operation
        } catch {
            return nil
        }
    }
}

// MARK: - Supporting Components

struct AuditInfoRow: View {
    let label: String
    let value: String
    var compact: Bool = false
    
    var body: some View {
        if compact {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                Text(value)
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct StatusBadge: View {
    let status: String
    let color: Color
    
    var body: some View {
        Text(status)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}