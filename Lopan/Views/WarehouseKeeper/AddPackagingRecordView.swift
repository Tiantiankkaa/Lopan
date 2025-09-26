//
//  AddPackagingRecordView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import SwiftUI
import SwiftData

struct AddPackagingRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var packagingTeams: [PackagingTeam]
    @Query private var products: [Product]
    
    let selectedDate: Date
    
    @State private var selectedTeamId = ""
    @State private var selectedProductId = ""
    @State private var totalPackages = 1
    @State private var totalPackagesText = "1"
    @State private var stylesPerPackage = 1
    @State private var selectedStylesPerPackage = "12"
    @State private var customStylesPerPackage = ""
    @State private var notes = ""
    @State private var dueDate = Date().addingTimeInterval(24 * 60 * 60) // Default to tomorrow
    @State private var hasDueDate = false
    @State private var priority: PackagingPriority = .medium
    @State private var reminderEnabled = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let stylesPerPackageOptions = ["12", "24", "36", "48", "60", "其他"]
    
    private var selectedTeam: PackagingTeam? {
        packagingTeams.first { $0.id == selectedTeamId }
    }
    
    private var selectedProduct: Product? {
        products.first { $0.id == selectedProductId }
    }
    
    private var availableProducts: [Product] {
        // For now, show all products. Could filter by team specialization if needed
        return products
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    DatePicker("包装日期", selection: .constant(selectedDate), displayedComponents: .date)
                        .disabled(true)
                    
                    Picker("包装团队", selection: $selectedTeamId) {
                        Text("请选择团队").tag("")
                        ForEach(packagingTeams.filter { $0.isActive }, id: \.id) { team in
                            Text(team.teamName).tag(team.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("产品", selection: $selectedProductId) {
                        Text("请选择产品").tag("")
                        ForEach(availableProducts, id: \.id) { product in
                            Text(product.name).tag(product.id)
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
                            .foregroundColor(LopanColors.primary)
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
                    }
                }
                
                Section(header: Text("备注")) {
                    TextField("添加备注信息...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加包装记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRecord()
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
        .onAppear {
            // Pre-select first active team if available
            if selectedTeamId.isEmpty, let firstTeam = packagingTeams.first(where: { $0.isActive }) {
                selectedTeamId = firstTeam.id
            }
            // Initialize stylesPerPackage based on default selection
            stylesPerPackage = Int(selectedStylesPerPackage) ?? 12
        }
    }
    
    private var canSave: Bool {
        !selectedTeamId.isEmpty && !selectedProductId.isEmpty && totalPackages > 0 && stylesPerPackage > 0
    }
    
    private func saveRecord() {
        guard let team = selectedTeam,
              let product = selectedProduct else {
            alertMessage = "请选择团队和产品"
            showingAlert = true
            return
        }
        
        let record = PackagingRecord(
            packageDate: selectedDate,
            teamId: team.id,
            teamName: team.teamName,
            styleCode: product.id, // Use product ID as style code
            styleName: product.name,
            totalPackages: totalPackages,
            stylesPerPackage: stylesPerPackage,
            notes: notes.isEmpty ? nil : notes,
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            reminderEnabled: hasDueDate && reminderEnabled,
            createdBy: "current_user" // TODO: Get from auth service
        )
        
        modelContext.insert(record)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "保存失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}