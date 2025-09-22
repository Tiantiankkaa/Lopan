//
//  EditPackagingRecordView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import SwiftUI
import SwiftData

struct EditPackagingRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var packagingTeams: [PackagingTeam]
    @Query private var products: [Product]
    
    let record: PackagingRecord
    
    @State private var selectedTeamId: String
    @State private var selectedProductId: String
    @State private var totalPackages: Int
    @State private var totalPackagesText: String
    @State private var stylesPerPackage: Int
    @State private var selectedStylesPerPackage: String
    @State private var customStylesPerPackage: String
    @State private var selectedStatus: PackagingStatus
    @State private var notes: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var priority: PackagingPriority
    @State private var reminderEnabled: Bool
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let stylesPerPackageOptions = ["12", "24", "36", "48", "60", "其他"]
    
    init(record: PackagingRecord) {
        self.record = record
        self._selectedTeamId = State(initialValue: record.teamId)
        self._selectedProductId = State(initialValue: record.styleCode) // styleCode now stores product ID
        self._totalPackages = State(initialValue: record.totalPackages)
        self._totalPackagesText = State(initialValue: "\(record.totalPackages)")
        self._stylesPerPackage = State(initialValue: record.stylesPerPackage)
        
        // Initialize selectedStylesPerPackage based on current value
        let currentStylesPerPackage = record.stylesPerPackage
        if ["12", "24", "36", "48", "60"].contains("\(currentStylesPerPackage)") {
            self._selectedStylesPerPackage = State(initialValue: "\(currentStylesPerPackage)")
            self._customStylesPerPackage = State(initialValue: "")
        } else {
            self._selectedStylesPerPackage = State(initialValue: "其他")
            self._customStylesPerPackage = State(initialValue: "\(currentStylesPerPackage)")
        }
        
        self._selectedStatus = State(initialValue: record.status)
        self._notes = State(initialValue: record.notes ?? "")
        self._dueDate = State(initialValue: record.dueDate ?? Date().addingTimeInterval(24 * 60 * 60))
        self._hasDueDate = State(initialValue: record.dueDate != nil)
        self._priority = State(initialValue: record.priority)
        self._reminderEnabled = State(initialValue: record.reminderEnabled)
    }
    
    private var selectedTeam: PackagingTeam? {
        packagingTeams.first { $0.id == selectedTeamId }
    }
    
    private var selectedProduct: Product? {
        products.first { $0.id == selectedProductId }
    }
    
    private var availableProducts: [Product] {
        // Show all products
        return products
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    DatePicker("包装日期", selection: .constant(record.packageDate), displayedComponents: .date)
                        .disabled(true)
                    
                    Picker("包装团队", selection: $selectedTeamId) {
                        ForEach(packagingTeams.filter { $0.isActive }, id: \.id) { team in
                            Text(team.teamName).tag(team.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("产品", selection: $selectedProductId) {
                        ForEach(availableProducts, id: \.id) { product in
                            Text(product.name).tag(product.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("状态", selection: $selectedStatus) {
                        ForEach(PackagingStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("包装数量")) {
                    HStack {
                        Text("包装总数")
                        Spacer()
                        TextField("包装总数", text: $totalPackagesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: totalPackagesText) { _, newValue in
                                if let value = Int(newValue), value > 0 {
                                    totalPackages = value
                                } else if newValue.isEmpty {
                                    totalPackages = 0
                                } else {
                                    // Reset to previous valid value
                                    totalPackagesText = "\(totalPackages)"
                                }
                            }
                    }
                    
                    HStack {
                        Text("每包数量")
                        Spacer()
                        Picker("每包数量", selection: $selectedStylesPerPackage) {
                            ForEach(stylesPerPackageOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedStylesPerPackage) { _, newValue in
                            if newValue == "其他" {
                                stylesPerPackage = Int(customStylesPerPackage) ?? 1
                            } else {
                                stylesPerPackage = Int(newValue) ?? 1
                                customStylesPerPackage = ""
                            }
                        }
                    }
                    
                    if selectedStylesPerPackage == "其他" {
                        HStack {
                            Text("自定义数量")
                            Spacer()
                            TextField("输入数量", text: $customStylesPerPackage)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: customStylesPerPackage) { _, newValue in
                                    if let value = Int(newValue), value > 0 {
                                        stylesPerPackage = value
                                    } else if newValue.isEmpty {
                                        stylesPerPackage = 1
                                    }
                                }
                        }
                    }
                    
                    HStack {
                        Text("总产品数")
                        Spacer()
                        Text("\(totalPackages * stylesPerPackage)")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("任务设置")) {
                    Picker("优先级", selection: $priority) {
                        ForEach(PackagingPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 8, height: 8)
                                Text(priority.displayName)
                            }.tag(priority)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Toggle("设置截止日期", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("截止日期", selection: $dueDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(CompactDatePickerStyle())
                        
                        Toggle("启用提醒", isOn: $reminderEnabled)
                        
                        if record.reminderSent {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("提醒已发送")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("备注")) {
                    TextField("添加备注信息...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("记录信息")) {
                    HStack {
                        Text("创建时间")
                        Spacer()
                        Text(record.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("更新时间")
                        Spacer()
                        Text(record.updatedAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("编辑包装记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canSave: Bool {
        !selectedTeamId.isEmpty && !selectedProductId.isEmpty && totalPackages > 0 && stylesPerPackage > 0
    }
    
    private func saveChanges() {
        guard let team = selectedTeam,
              let product = selectedProduct else {
            alertMessage = "请选择团队和产品"
            showingAlert = true
            return
        }
        
        // Update the record
        record.teamId = team.id
        record.teamName = team.teamName
        record.styleCode = product.id // Use product ID as style code
        record.styleName = product.name
        record.totalPackages = totalPackages
        record.stylesPerPackage = stylesPerPackage
        record.status = selectedStatus
        record.notes = notes.isEmpty ? nil : notes
        record.dueDate = hasDueDate ? dueDate : nil
        record.priority = priority
        record.reminderEnabled = hasDueDate && reminderEnabled
        
        // Reset reminder if due date or reminder settings changed
        if !hasDueDate || !reminderEnabled {
            record.reminderSent = false
        }
        
        record.updateTotalItems()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "保存失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}