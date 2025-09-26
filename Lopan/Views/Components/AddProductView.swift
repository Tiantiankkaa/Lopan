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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Product Information Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("产品信息")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(LopanColors.textPrimary)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("产品名称", text: $productName)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(LopanColors.backgroundSecondary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LopanColors.border, lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("产品颜色")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(LopanColors.textPrimary)
                                
                                HStack {
                                    TextField("添加颜色", text: $newColor)
                                        .font(.body)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(LopanColors.backgroundSecondary)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(LopanColors.border, lineWidth: 1)
                                        )
                                    
                                    Button("添加") {
                                        addColor()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(newColor.isEmpty)
                                }
                                
                                if !colors.isEmpty {
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 8) {
                                        ForEach(colors, id: \.self) { color in
                                            HStack(spacing: 6) {
                                                LopanBadge(color, style: .neutral, size: .medium)
                                                
                                                Button(action: {
                                                    removeColor(color)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.subheadline)
                                                        .foregroundColor(LopanColors.error)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LopanColors.surface)
                            .shadow(color: LopanColors.shadow, radius: 2, x: 0, y: 1)
                    )
                    
                    // Product Image Section  
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("产品图片")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(LopanColors.textPrimary)
                            Spacer()
                        }
                        
                        HStack(spacing: 20) {
                            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(LopanColors.border, lineWidth: 0.5)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LopanColors.backgroundTertiary)
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(LopanColors.textSecondary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(LopanColors.border, lineWidth: 0.5)
                                    )
                            }
                            
                            VStack(spacing: 12) {
                                PhotosPicker(selection: $selectedImage, matching: .images) {
                                    Label("选择图片", systemImage: "photo")
                                }
                                .buttonStyle(.borderedProminent)
                                
                                if imageData != nil {
                                    Button("清除图片") {
                                        imageData = nil
                                        selectedImage = nil
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(LopanColors.error)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LopanColors.surface)
                            .shadow(color: LopanColors.shadow, radius: 2, x: 0, y: 1)
                    )
                    
                    // Product Sizes Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("产品尺寸")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(LopanColors.textPrimary)
                            Spacer()
                        }
                        
                        HStack {
                            TextField("添加尺寸", text: $newSize)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(LopanColors.backgroundSecondary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LopanColors.border, lineWidth: 1)
                                )
                            
                            Button("添加") {
                                addSize()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newSize.isEmpty)
                        }
                        
                        if !sizes.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(sizes, id: \.self) { size in
                                    HStack(spacing: 6) {
                                        LopanBadge(size, style: .secondary, size: .medium)
                                        
                                        Button(action: {
                                            removeSize(size)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.subheadline)
                                                .foregroundColor(LopanColors.error)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LopanColors.surface)
                            .shadow(color: LopanColors.shadow, radius: 2, x: 0, y: 1)
                    )
                }
                .padding(20)
            }
            .background(LopanColors.background)
            .navigationTitle("添加产品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(LopanColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProduct()
                    }
                    .disabled(productName.isEmpty || colors.isEmpty)
                    .foregroundColor(productName.isEmpty || colors.isEmpty ? LopanColors.textTertiary : LopanColors.primary)
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