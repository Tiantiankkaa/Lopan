//
//  AddProductView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddProductView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var productName = ""
    @State private var colors: [String] = []
    @State private var newColor = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var sizes: [String] = []
    @State private var newSize = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("产品信息") {
                    TextField("产品名称", text: $productName)
                    
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
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack {
                            PhotosPicker(selection: $selectedImage, matching: .images) {
                                Label("选择图片", systemImage: "photo")
                            }
                            .buttonStyle(.bordered)
                            
                            if imageData != nil {
                                Button("清除图片") {
                                    imageData = nil
                                    selectedImage = nil
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section("产品尺寸") {
                    HStack {
                        TextField("添加尺寸", text: $newSize)
                        Button("添加") {
                            addSize()
                        }
                        .disabled(newSize.isEmpty)
                    }
                    
                    ForEach(sizes, id: \.self) { size in
                        HStack {
                            Text(size)
                            Spacer()
                            Button("删除") {
                                removeSize(size)
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("添加产品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProduct()
                    }
                    .disabled(productName.isEmpty || colors.isEmpty)
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
    
    private func addSize() {
        let trimmedSize = newSize.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSize.isEmpty && !sizes.contains(trimmedSize) {
            sizes.append(trimmedSize)
            newSize = ""
        }
    }
    
    private func removeSize(_ size: String) {
        sizes.removeAll { $0 == size }
    }
    
    private func saveProduct() {
        let product = Product(name: productName, colors: colors, imageData: imageData)
        
        // Add sizes
        for sizeName in sizes {
            let size = ProductSize(size: sizeName, product: product)
            if product.sizes == nil {
                product.sizes = []
            }
            product.sizes?.append(size)
        }
        
        modelContext.insert(product)
        
        do {
            try modelContext.save()
            print("✅ Product saved successfully: \(product.name)")
            print("✅ Product ID: \(product.id)")
            print("✅ Product created at: \(product.createdAt)")
            NotificationCenter.default.post(name: .productAdded, object: product)
        } catch {
            print("❌ Failed to save product: \(error)")
        }
        
        dismiss()
    }
}

#Preview {
    AddProductView()
        .modelContainer(for: [Product.self, ProductSize.self], inMemory: true)
} 