//
//  ProductManagementView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct ProductManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var products: [Product]
    @Query private var productSizes: [ProductSize]
    
    @State private var showingAddProduct = false
    @State private var showingExcelImport = false
    @State private var showingExcelExport = false
    @State private var searchText = ""
    @State private var selectedProducts: Set<String> = []
    @State private var isBatchMode = false
    @State private var showingDeleteAlert = false
    @State private var productsToDelete: [Product] = []
    
    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products
        } else {
            return products.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.colors.contains { color in
                    color.localizedCaseInsensitiveContains(searchText)
                } ||
                product.sizeNames.contains { size in
                    size.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            // Search and toolbar
            searchAndToolbarView
            
            // Product list
            productListView
        }
        .navigationTitle("产品管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddProduct) {
            AddProductView()
        }
        .sheet(isPresented: $showingExcelImport) {
            ExcelImportView(dataType: .products)
        }
        .sheet(isPresented: $showingExcelExport) {
            ExcelExportView(dataType: .products)
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteSelectedProducts()
            }
        } message: {
            Text("确定要删除选中的 \(productsToDelete.count) 个产品吗？此操作不可撤销。")
        }
    }
    
    private var searchAndToolbarView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索产品名称、颜色或尺寸", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Toolbar
            HStack {
                if isBatchMode {
                    Button(action: { 
                        productsToDelete = products.filter { selectedProducts.contains($0.id) }
                        showingDeleteAlert = true
                    }) {
                        Label("删除", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .disabled(selectedProducts.isEmpty)
                } else {
                    Button(action: { showingAddProduct = true }) {
                        Label("添加", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
                
                Button(action: { showingExcelImport = true }) {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                
                Button(action: { showingExcelExport = true }) {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                
                Button(action: { toggleBatchMode() }) {
                    Label(isBatchMode ? "完成" : "批量", systemImage: isBatchMode ? "checkmark" : "list.bullet")
                }
                .buttonStyle(.bordered)
                .foregroundColor(isBatchMode ? .green : .primary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    private var productListView: some View {
        List {
            ForEach(filteredProducts) { product in
                if isBatchMode {
                    ProductRowView(
                        product: product,
                        isSelected: selectedProducts.contains(product.id),
                        isBatchMode: isBatchMode,
                        onSelect: { toggleProductSelection(product) }
                    )
                } else {
                    NavigationLink(destination: ProductDetailView(product: product)) {
                        ProductRowView(
                            product: product,
                            isSelected: false,
                            isBatchMode: false,
                            onSelect: {}
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func toggleBatchMode() {
        withAnimation {
            isBatchMode.toggle()
            if !isBatchMode {
                selectedProducts.removeAll()
            }
        }
    }
    
    private func toggleProductSelection(_ product: Product) {
        if isBatchMode {
            if selectedProducts.contains(product.id) {
                selectedProducts.remove(product.id)
            } else {
                selectedProducts.insert(product.id)
            }
        }
    }
    
    private func deleteProduct(_ product: Product) {
        productsToDelete = [product]
        showingDeleteAlert = true
    }
    
    private func deleteSelectedProducts() {
        let productsToDelete = products.filter { selectedProducts.contains($0.id) }
        
        for product in productsToDelete {
            // Delete associated sizes first
            if let sizes = product.sizes {
                for size in sizes {
                    modelContext.delete(size)
                }
            }
            modelContext.delete(product)
        }
        
        selectedProducts.removeAll()
        isBatchMode = false
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting products: \(error)")
        }
    }
}

struct ProductRowView: View {
    let product: Product
    let isSelected: Bool
    let isBatchMode: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection checkbox
            if isBatchMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Product image
            productImage
            
            // Product info
            VStack(alignment: .leading, spacing: 8) {
                Text(product.name)
                    .font(.title3)
                    .fontWeight(.medium)
                
                if !product.colors.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(product.colors, id: \.self) { color in
                                Text(color)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }
                } else {
                    Text("暂无颜色")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Sizes
                if let sizes = product.sizes, !sizes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(sizes) { size in
                                Text(size.size)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                } else {
                    Text("暂无尺寸")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private var productImage: some View {
        Group {
            if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

// MARK: - Product Detail View
struct ProductDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let product: Product
    
    @State private var showingEditSheet = false
    @Query private var outOfStockItems: [CustomerOutOfStock]
    
    var productOutOfStockItems: [CustomerOutOfStock] {
        outOfStockItems.filter { $0.product?.id == product.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                productInfoView
                sizesView
                outOfStockHistoryView
            }
            .padding()
        }
        .navigationTitle("产品详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProductView(product: product)
        }
    }
    
    private var productInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("产品信息")
                .font(.headline)
            
            HStack(spacing: 16) {
                // Product image
                if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(product.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !product.colors.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(product.colors, id: \.self) { color in
                                    Text(color)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    } else {
                        Text("暂无颜色")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("创建时间: \(product.createdAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var sizesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("可用尺寸")
                .font(.headline)
            
            if let sizes = product.sizes, !sizes.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(sizes) { size in
                        Text(size.size)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            } else {
                Text("暂无尺寸信息")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var outOfStockHistoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("缺货记录")
                .font(.headline)
            
            if productOutOfStockItems.isEmpty {
                Text("暂无缺货记录")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(productOutOfStockItems.sorted { $0.requestDate > $1.requestDate }) { item in
                        NavigationLink(destination: CustomerOutOfStockDetailView(item: item)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.customer?.name ?? "未知客户")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("数量: \(item.quantity)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(item.status.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(statusColor(item.status).opacity(0.2))
                                        .foregroundColor(statusColor(item.status))
                                        .cornerRadius(4)
                                    
                                    Text(item.requestDate, style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func statusColor(_ status: OutOfStockStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .confirmed: return .blue
        case .inProduction: return .purple
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Edit Product View
struct EditProductView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let product: Product
    
    @State private var name: String
    @State private var colors: [String]
    @State private var newColor: String = ""
    @State private var imageData: Data?
    @State private var selectedImage: PhotosPickerItem?
    @State private var sizes: [String]
    @State private var newSize: String = ""
    
    init(product: Product) {
        self.product = product
        _name = State(initialValue: product.name)
        _colors = State(initialValue: product.colors)
        _imageData = State(initialValue: product.imageData)
        _sizes = State(initialValue: product.sizeNames)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("产品信息") {
                    TextField("产品名称", text: $name)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("产品颜色")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("添加颜色", text: $newColor)
                            Button("添加") {
                                addColor()
                            }
                            .disabled(newColor.isEmpty)
                        }
                        
                        if !colors.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(colors, id: \.self) { color in
                                        HStack {
                                            Text(color)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .cornerRadius(6)
                                            
                                            Button("×") {
                                                removeColor(color)
                                            }
                                            .font(.caption)
                                            .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("产品图片") {
                    HStack {
                        if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $selectedImage, matching: .images) {
                                Label("选择图片", systemImage: "photo")
                            }
                            
                            if imageData != nil {
                                Button("删除图片") {
                                    imageData = nil
                                    selectedImage = nil
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section("产品尺寸") {
                    HStack {
                        TextField("新尺寸", text: $newSize)
                        Button("添加") {
                            if !newSize.isEmpty && !sizes.contains(newSize) {
                                sizes.append(newSize)
                                newSize = ""
                            }
                        }
                        .disabled(newSize.isEmpty)
                    }
                    
                    ForEach(sizes, id: \.self) { size in
                        HStack {
                            Text(size)
                            Spacer()
                            Button("删除") {
                                sizes.removeAll { $0 == size }
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("编辑产品")
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
                    .disabled(name.isEmpty || colors.isEmpty)
                }
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
    }
    
    private func addColor() {
        let trimmedColor = newColor.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedColor.isEmpty && !colors.contains(trimmedColor) {
            colors.append(trimmedColor)
            newColor = ""
        }
    }
    
    private func removeColor(_ color: String) {
        colors.removeAll { $0 == color }
    }
    
    private func saveChanges() {
        product.name = name
        product.colors = colors
        product.imageData = imageData
        product.updatedAt = Date()
        
        // Update sizes
        if let existingSizes = product.sizes {
            // Remove sizes that are no longer in the list
            for size in existingSizes {
                if !sizes.contains(size.size) {
                    modelContext.delete(size)
                }
            }
        }
        
        // Add new sizes
        for sizeName in sizes {
            if !(product.sizes?.contains { $0.size == sizeName } ?? false) {
                let newSize = ProductSize(size: sizeName, product: product)
                modelContext.insert(newSize)
                if product.sizes == nil {
                    product.sizes = []
                }
                product.sizes?.append(newSize)
            }
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving product: \(error)")
        }
    }
}



#Preview {
    ProductManagementView()
        .modelContainer(for: [Product.self, ProductSize.self], inMemory: true)
} 
