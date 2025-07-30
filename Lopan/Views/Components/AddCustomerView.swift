//
//  AddCustomerView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct AddCustomerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("客户信息") {
                    TextField("客户姓名", text: $name)
                    TextField("客户地址", text: $address)
                    TextField("联系电话 (可选)", text: $phone)
                }
            }
            .navigationTitle("添加客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCustomer()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
        }
    }
    
    private func saveCustomer() {
        let customer = Customer(name: name, address: address, phone: phone.isEmpty ? "" : phone)
        modelContext.insert(customer)
        
        do {
            try modelContext.save()
            print("✅ Customer saved successfully: \(customer.name)")
            NotificationCenter.default.post(name: .customerAdded, object: customer)
        } catch {
            print("❌ Failed to save customer: \(error)")
        }
        
        dismiss()
    }
}

#Preview {
    AddCustomerView()
        .modelContainer(for: Customer.self, inMemory: true)
} 