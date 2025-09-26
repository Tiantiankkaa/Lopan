//
//  BatchOutOfStockCreationView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import SwiftData

struct OutOfStockProductItem: Identifiable {
    let id = UUID()
    var product: Product?
    var productSize: ProductSize?
    var quantity: String = ""
    var notes: String = ""
}

struct BatchOutOfStockCreationView: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.dismiss) private var dismiss
    
    private var salespersonService: SalespersonServiceProvider {
        appDependencies.serviceFactory.salespersonServiceProvider
    }
    
    let customers: [Customer]
    let products: [Product]
    let onSaveCompleted: (() -> Void)?
    
    @State private var selectedCustomer: Customer?
    @State private var productItems: [OutOfStockProductItem] = [OutOfStockProductItem()]
    @State private var showingCustomerPicker = false
    @State private var customerSearchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LopanColors.backgroundSecondary.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        customerSelectionCard
                        
                        if selectedCustomer != nil {
                            VStack(spacing: 12) {
                                productItemsHeader
                                
                                ForEach(Array(productItems.enumerated()), id: \.element.id) { index, item in
                                    ProductItemCard(
                                        index: index,
                                        productItems: $productItems,
                                        products: products,
                                        onDelete: productItems.count > 1 ? {
                                            deleteProductItem(with: item.id)
                                        } : nil
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                }
                                
                                addProductButton
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("新增缺货记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { 
                        dismiss() 
                    }
                    .foregroundColor(LopanColors.error)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveItems()
                    }
                    .disabled(!isValidForSave || isLoading)
                    .fontWeight(.semibold)
                    .foregroundColor(isValidForSave ? LopanColors.primary : LopanColors.textSecondary)
                }
            }
            .sheet(isPresented: $showingCustomerPicker) {
                SearchableCustomerPicker(
                    customers: customers,
                    selectedCustomer: $selectedCustomer,
                    searchText: $customerSearchText
                )
            }
            .alert("保存失败", isPresented: $showingErrorAlert) {
                Button("确定") { }
            } message: {
                Text(errorMessage ?? "保存缺货记录时发生错误")
            }
            .overlay {
                if isLoading {
                    ZStack {
                        LopanColors.textPrimary.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("正在保存...")
                                .font(.headline)
                                .foregroundColor(LopanColors.textOnPrimary)
                        }
                        .padding(24)
                        .background(LopanColors.textPrimary.opacity(0.8))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var customerSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(LopanColors.info)
                    .font(.title2)
                Text("选择客户")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Button(action: {
                showingCustomerPicker = true
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let customer = selectedCustomer {
                            Text(customer.name)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(customer.address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            if !customer.phone.isEmpty {
                                Text(customer.phone)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("点击选择客户")
                                .font(.title3)
                                .foregroundColor(LopanColors.info)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: selectedCustomer == nil ? "plus.circle" : "chevron.right")
                        .foregroundColor(LopanColors.info)
                        .font(.title2)
                        .scaleEffect(selectedCustomer == nil ? 1.2 : 1.0)
                }
                .padding(16)
                .background(selectedCustomer == nil ? LopanColors.info.opacity(0.05) : LopanColors.backgroundPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedCustomer == nil ? LopanColors.info.opacity(0.3) : LopanColors.border, lineWidth: selectedCustomer == nil ? 2 : 1)
                        .animation(.easeInOut(duration: 0.2), value: selectedCustomer != nil)
                )
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(LopanColors.background)
        .cornerRadius(16)
        .shadow(color: LopanColors.textPrimary.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    private var productItemsHeader: some View {
        HStack {
            Image(systemName: "cube.box.fill")
                .foregroundColor(LopanColors.warning)
                .font(.title2)
            Text("产品列表")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("\(productItems.count) 个产品")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(LopanColors.backgroundSecondary)
                .cornerRadius(8)
        }
        .padding(.horizontal, 4)
    }
    
    private var addProductButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                addProductItem()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("添加另一个产品")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            .foregroundColor(LopanColors.info)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(LopanColors.info.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LopanColors.info.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isValidForSave: Bool {
        guard selectedCustomer != nil else { return false }
        
        return productItems.allSatisfy { item in
            item.product != nil && 
            !item.quantity.isEmpty && 
            Int(item.quantity) != nil && 
            Int(item.quantity)! > 0
        }
    }
    
    private func addProductItem() {
        withAnimation {
            productItems.append(OutOfStockProductItem())
        }
    }
    
    private func deleteProductItem(with id: UUID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            productItems.removeAll { $0.id == id }
        }
    }
    
    private func saveItems() {
        guard let customer = selectedCustomer else { return }
        
        isLoading = true
        
        Task {
            do {
                let requests = productItems.compactMap { item -> OutOfStockCreationRequest? in
                    guard let product = item.product,
                          let quantity = Int(item.quantity),
                          quantity > 0 else { return nil }
                    
                    return OutOfStockCreationRequest(
                        customer: customer,
                        product: product,
                        productSize: item.productSize,
                        quantity: quantity,
                        notes: item.notes.isEmpty ? nil : item.notes,
                        createdBy: appDependencies.authenticationService.currentUser?.id ?? "unknown_user"
                    )
                }
                
                try await salespersonService.customerOutOfStockService.createMultipleOutOfStockItems(requests)
                
                await MainActor.run {
                    onSaveCompleted?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                    isLoading = false
                }
            }
        }
    }
}

struct ProductItemCard: View {
    let index: Int
    @Binding var productItems: [OutOfStockProductItem]
    let products: [Product]
    let onDelete: (() -> Void)?
    
    @State private var showingProductPicker = false
    @State private var productSearchText = ""
    @State private var isDeleting = false
    @State private var quantityButtonScale: CGFloat = 1.0
    
    private var item: OutOfStockProductItem {
        guard index < productItems.count else {
            return OutOfStockProductItem()
        }
        return productItems[index]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with delete button
            cardHeader
            
            // Product selection area
            productSelectionArea
            
            // Quantity and notes section
            if item.product != nil {
                quantityAndNotesSection
            }
        }
        .background(LopanColors.background)
        .cornerRadius(16)
        .shadow(color: LopanColors.textPrimary.opacity(0.08), radius: 6, x: 0, y: 2)
        .scaleEffect(isDeleting ? 0.95 : 1.0)
        .opacity(isDeleting ? 0.7 : 1.0)
        .sheet(isPresented: $showingProductPicker) {
            SearchableProductPicker(
                products: products,
                selectedProduct: Binding(
                    get: { 
                        guard index >= 0 && index < productItems.count else { return nil as Product? }
                        return productItems[index].product 
                    },
                    set: { (newProduct: Product?) in
                        guard index >= 0 && index < productItems.count else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            productItems[index].product = newProduct
                            if newProduct != nil && productItems[index].quantity.isEmpty {
                                productItems[index].quantity = "1"
                            }
                        }
                    }
                ),
                selectedProductSize: Binding(
                    get: { 
                        guard index >= 0 && index < productItems.count else { return nil as ProductSize? }
                        return productItems[index].productSize 
                    },
                    set: { (newSize: ProductSize?) in
                        guard index >= 0 && index < productItems.count else { return }
                        productItems[index].productSize = newSize
                    }
                ),
                searchText: $productSearchText
            )
        }
    }
    
    private var cardHeader: some View {
        HStack {
            Text("产品 #\(index + 1)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let onDelete = onDelete {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDeleting = true
                    }
                    
                    LopanHapticEngine.shared.medium()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(LopanColors.error)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var productSelectionArea: some View {
        Button(action: {
            showingProductPicker = true
        }) {
            HStack(spacing: 16) {
                // Product image
                productImageView
                
                // Product info
                VStack(alignment: .leading, spacing: 6) {
                    if let product = item.product {
                        Text(product.name)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if let size = item.productSize {
                            Label("尺寸: \(size.size)", systemImage: "ruler")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !product.colors.isEmpty {
                            Label("颜色: \(product.colors.joined(separator: ", "))", systemImage: "paintpalette")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("点击选择产品")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(LopanColors.info)
                        
                        Text("从产品库中选择")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: item.product == nil ? "plus.circle" : "chevron.right")
                    .foregroundColor(LopanColors.info)
                    .font(.title2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var productImageView: some View {
        Group {
            if let product = item.product,
               let imageData = product.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.product == nil ? LopanColors.info.opacity(0.1) : LopanColors.backgroundSecondary)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: item.product == nil ? "plus" : "photo")
                            .font(.title3)
                            .foregroundColor(item.product == nil ? LopanColors.primary : LopanColors.textSecondary)
                    )
            }
        }
    }
    
    private var quantityAndNotesSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                quantitySelector
                notesInput
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private var quantitySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(LopanColors.success)
                Text("数量")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack(spacing: 20) {
                // Quick quantity buttons
                HStack(spacing: 8) {
                    ForEach([1, 5, 10], id: \.self) { quickValue in
                        Button(action: {
                            guard index >= 0 && index < productItems.count else { return }
                            LopanHapticEngine.shared.light()
                            
                            withAnimation(.easeInOut(duration: 0.2)) {
                                productItems[index].quantity = String(quickValue)
                            }
                        }) {
                            Text("\(quickValue)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Int(item.quantity) == quickValue ? LopanColors.textPrimary : LopanColors.primary)
                                .frame(width: 32, height: 32)
                                .background(Int(item.quantity) == quickValue ? LopanColors.info : LopanColors.info.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                // Quantity controls
                HStack(spacing: 12) {
                    Button(action: {
                        guard index >= 0 && index < productItems.count else { return }
                        let currentValue = Int(productItems[index].quantity) ?? 0
                        if currentValue > 1 {
                            LopanHapticEngine.shared.light()
                            
                            withAnimation(.easeInOut(duration: 0.15)) {
                                quantityButtonScale = 0.9
                                productItems[index].quantity = String(currentValue - 1)
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    quantityButtonScale = 1.0
                                }
                            }
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor((Int(item.quantity) ?? 0) <= 1 ? LopanColors.secondary : LopanColors.error)
                    }
                    .scaleEffect(quantityButtonScale)
                    .disabled((Int(item.quantity) ?? 0) <= 1)
                    
                    TextField("数量", text: Binding(
                        get: { 
                            guard index >= 0 && index < productItems.count else { return "" }
                            return productItems[index].quantity 
                        },
                        set: { newValue in
                            guard index >= 0 && index < productItems.count else { return }
                            productItems[index].quantity = newValue
                        }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 70)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    
                    Button(action: {
                        guard index >= 0 && index < productItems.count else { return }
                        let currentValue = Int(productItems[index].quantity) ?? 0
                        
                        LopanHapticEngine.shared.light()
                        
                        withAnimation(.easeInOut(duration: 0.15)) {
                            quantityButtonScale = 0.9
                            productItems[index].quantity = String(currentValue + 1)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                quantityButtonScale = 1.0
                            }
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(LopanColors.info)
                    }
                    .scaleEffect(quantityButtonScale)
                }
            }
        }
    }
    
    private var notesInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(LopanColors.premium)
                Text("备注")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                Text("可选")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextField("添加备注信息（可选）", text: Binding(
                get: { 
                    guard index >= 0 && index < productItems.count else { return "" }
                    return productItems[index].notes 
                },
                set: { newValue in
                    guard index >= 0 && index < productItems.count else { return }
                    productItems[index].notes = newValue
                }
            ), axis: .vertical)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .lineLimit(1...3)
        }
    }
    
}

// MARK: - SearchableCustomerPicker

internal struct SearchableCustomerPicker: View {
    let customers: [Customer]
    @Binding var selectedCustomer: Customer?
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss
    
    private var filteredCustomers: [Customer] {
        if searchText.isEmpty {
            return customers
        } else {
            return customers.filter { customer in
                customer.name.localizedCaseInsensitiveContains(searchText) ||
                customer.phone.contains(searchText) ||
                customer.address.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                List(filteredCustomers) { customer in
                    CustomerRow(
                        customer: customer,
                        isSelected: selectedCustomer?.id == customer.id
                    ) {
                        selectedCustomer = customer
                        dismiss()
                    }
                }
            }
            .navigationTitle("选择客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SearchableProductPicker

internal struct SearchableProductPicker: View {
    let products: [Product]
    @Binding var selectedProduct: Product?
    @Binding var selectedProductSize: ProductSize?
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss
    
    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products
        } else {
            return products.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
product.colorDisplay.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                List(filteredProducts) { product in
                    ProductRow(
                        product: product,
                        isSelected: selectedProduct?.id == product.id
                    ) {
                        selectedProduct = product
                        selectedProductSize = product.sizes?.first
                        dismiss()
                    }
                }
            }
            .navigationTitle("选择产品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

internal struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

internal struct CustomerRow: View {
    let customer: Customer
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(customer.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(customer.phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(customer.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LopanColors.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

internal struct ProductRow: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("颜色: \(product.colorDisplay)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !product.sizeNames.isEmpty {
                        Text("尺码: \(product.sizeNames.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LopanColors.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    BatchOutOfStockCreationView(customers: [], products: [], onSaveCompleted: nil)
}
