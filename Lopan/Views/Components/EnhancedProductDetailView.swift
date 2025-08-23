//
//  EnhancedProductDetailView.swift
//  Lopan
//
//  Created by Claude Code for Product Management Redesign
//

import SwiftUI
import SwiftData

struct EnhancedProductDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var serviceFactory: ServiceFactory
    
    let product: Product
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingImageGallery = false
    @State private var selectedImageIndex = 0
    @State private var isImageExpanded = false
    @State private var dragOffset = CGSize.zero
    @State private var imageScale: CGFloat = 1.0
    @State private var lastScaleValue: CGFloat = 1.0
    
    // Responsive layout
    @State private var screenSize = CGSize.zero
    @State private var isCompactLayout = false
    
    // Gesture states
    @State private var magnifyGesture = MagnificationGesture()
    @State private var dragGesture = DragGesture()
    
    // Actions menu
    @State private var showingActionsMenu = false
    
    private var isLargeScreen: Bool {
        screenSize.width > 375
    }
    
    private var contentPadding: CGFloat {
        isCompactLayout ? 16 : 20
    }
    
    private var cardSpacing: CGFloat {
        isCompactLayout ? 16 : 20
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: cardSpacing) {
                    productImageSection
                    productInfoSection
                    productAttributesSection
                    productMetadataSection
                    actionButtonsSection
                }
                .padding(.horizontal, contentPadding)
                .padding(.bottom, 20)
            }
            .background(LopanColors.background)
            .onAppear {
                updateLayout(for: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                updateLayout(for: newSize)
            }
        }
        .navigationTitle("产品详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarMenu
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProductView(product: product)
        }
        .sheet(isPresented: $showingImageGallery) {
            imageGalleryView
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteProduct()
            }
        } message: {
            Text("确定要删除产品 \"\(product.name)\" 吗？此操作不可撤销。")
        }
        .sheet(isPresented: $showingShareSheet) {
            shareView
        }
        .sheet(isPresented: $showingActionsMenu) {
            actionsMenuView
        }
    }
    
    // MARK: - Product Image Section
    
    private var productImageSection: some View {
        VStack(spacing: 16) {
            if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                expandableImageView(uiImage: uiImage)
            } else {
                placeholderImageView
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func expandableImageView(uiImage: UIImage) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: isImageExpanded ? screenSize.height * 0.6 : (isLargeScreen ? 250 : 200))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .scaleEffect(imageScale)
                    .offset(dragOffset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScaleValue
                                    lastScaleValue = value
                                    imageScale *= delta
                                    imageScale = min(max(imageScale, 0.5), 3.0)
                                }
                                .onEnded { _ in
                                    lastScaleValue = 1.0
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if imageScale < 1.0 {
                                            imageScale = 1.0
                                        }
                                    }
                                },
                            
                            DragGesture()
                                .onChanged { value in
                                    if imageScale > 1.0 {
                                        dragOffset = value.translation
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if imageScale <= 1.0 {
                                            dragOffset = .zero
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            if imageScale > 1.0 {
                                imageScale = 1.0
                                dragOffset = .zero
                            } else {
                                imageScale = 2.0
                            }
                        }
                    }
                    .onTapGesture {
                        if !isImageExpanded {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isImageExpanded = true
                            }
                        }
                    }
                
                if isImageExpanded {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isImageExpanded = false
                                    imageScale = 1.0
                                    dragOffset = .zero
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding()
                        }
                        Spacer()
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isImageExpanded ? Color.black : Color.white)
            )
            
            if !isImageExpanded {
                HStack(spacing: 16) {
                    Button("查看大图") {
                        showingImageGallery = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(LopanColors.primary)
                    
                    Button("分享图片") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(LopanColors.primary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
    
    private var placeholderImageView: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LopanColors.backgroundTertiary)
                .frame(height: isLargeScreen ? 200 : 160)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(LopanColors.textTertiary)
                        
                        Text("暂无产品图片")
                            .font(.headline)
                            .foregroundColor(LopanColors.textSecondary)
                        
                        Text("点击编辑按钮添加图片")
                            .font(.caption)
                            .foregroundColor(LopanColors.textTertiary)
                    }
                )
                .onTapGesture {
                    showingEditSheet = true
                }
                .padding(20)
        }
    }
    
    // MARK: - Product Info Section
    
    private var productInfoSection: some View {
        responsiveCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.name)
                            .font(isCompactLayout ? .title2 : .title)
                            .fontWeight(.bold)
                            .foregroundColor(LopanColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "tag.fill")
                                .font(.caption)
                                .foregroundColor(LopanColors.primary)
                            
                            Text("产品编号: \(product.id.prefix(8))")
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                                .accessibilityLabel("产品编号 \(product.id.prefix(8))")
                        }
                    }
                    
                    Spacer()
                    
                    statusIndicator
                }
                
                Divider()
                    .foregroundColor(LopanColors.border)
                
                productDescription
            }
        }
    }
    
    private var statusIndicator: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(LopanColors.success)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(LopanColors.success.opacity(0.3), lineWidth: 4)
                        .scaleEffect(1.5)
                )
            
            Text("有库存")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.success)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("库存状态：有库存")
    }
    
    private var productDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("产品描述")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(LopanColors.textPrimary)
            
            Text("这是一款高质量的产品，采用优质材料制造，具有出色的耐用性和美观的外观设计。")
                .font(.body)
                .foregroundColor(LopanColors.textSecondary)
                .lineLimit(nil)
        }
    }
    
    // MARK: - Product Attributes Section
    
    private var productAttributesSection: some View {
        VStack(spacing: cardSpacing) {
            colorsSection
            sizesSection
        }
    }
    
    private var colorsSection: some View {
        responsiveCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("可用颜色", systemImage: "paintpalette.fill")
                
                if !product.colors.isEmpty {
                    if isCompactLayout {
                        compactColorsView
                    } else {
                        standardColorsView
                    }
                } else {
                    emptyStateView("暂无颜色信息", "点击编辑按钮添加颜色选项")
                }
            }
        }
    }
    
    private var sizesSection: some View {
        responsiveCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("可用尺寸", systemImage: "ruler.fill")
                
                if let sizes = product.sizes, !sizes.isEmpty {
                    if isCompactLayout {
                        compactSizesView(sizes)
                    } else {
                        standardSizesView(sizes)
                    }
                } else {
                    emptyStateView("暂无尺寸信息", "点击编辑按钮添加尺寸选项")
                }
            }
        }
    }
    
    private var standardColorsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(product.colors, id: \.self) { color in
                colorCard(color)
            }
        }
    }
    
    private var compactColorsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(product.colors, id: \.self) { color in
                    LopanBadge(color, style: .neutral, size: .medium)
                }
            }
            .padding(.horizontal, 1)
        }
    }
    
    private func colorCard(_ color: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(colorForName(color))
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 0.5))
            
            Text(color)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(LopanColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func standardSizesView(_ sizes: [ProductSize]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(sizes, id: \.id) { size in
                LopanBadge(size.size, style: .secondary, size: .large)
            }
        }
    }
    
    private func compactSizesView(_ sizes: [ProductSize]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sizes, id: \.id) { size in
                    LopanBadge(size.size, style: .secondary, size: .medium)
                }
            }
            .padding(.horizontal, 1)
        }
    }
    
    // MARK: - Product Metadata Section
    
    private var productMetadataSection: some View {
        responsiveCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("产品信息", systemImage: "info.circle.fill")
                
                VStack(spacing: 12) {
                    metadataRow("创建时间", value: product.createdAt.formatted(.dateTime.day().month().year()))
                    
                    if product.updatedAt != product.createdAt {
                        metadataRow("更新时间", value: product.updatedAt.formatted(.dateTime.day().month().year()))
                    }
                    
                    metadataRow("颜色数量", value: "\(product.colors.count) 种")
                    metadataRow("尺寸数量", value: "\(product.sizes?.count ?? 0) 种")
                }
            }
        }
    }
    
    private func metadataRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.callout)
                .foregroundColor(LopanColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textPrimary)
        }
    }
    
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("编辑产品") {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    showingEditSheet = true
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.white)
                .tint(LopanColors.primary)
                .accessibilityHint("编辑产品信息")
                
                Button("更多操作") {
                    showingActionsMenu = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(LopanColors.primary)
            }
            
            if isLargeScreen {
                HStack(spacing: 12) {
                    Button("复制产品") {
                        duplicateProduct()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(LopanColors.primary)
                    
                    Button("分享产品") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(LopanColors.primary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Utility Views
    
    private func responsiveCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(contentPadding)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
    }
    
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundColor(LopanColors.primary)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(LopanColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
        }
    }
    
    private func emptyStateView(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textSecondary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(LopanColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(LopanColors.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            showingEditSheet = true
        }
    }
    
    // MARK: - Toolbar and Sheets
    
    private var toolbarMenu: some View {
        Menu {
            Button(action: { showingEditSheet = true }) {
                Label("编辑产品", systemImage: "pencil")
            }
            
            Button(action: duplicateProduct) {
                Label("复制产品", systemImage: "doc.on.doc")
            }
            
            Button(action: { showingShareSheet = true }) {
                Label("分享产品", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(action: { showingDeleteAlert = true }) {
                Label("删除产品", systemImage: "trash")
            }
            .foregroundColor(.red)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundColor(LopanColors.primary)
        }
    }
    
    private var imageGalleryView: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(imageScale)
                        .offset(dragOffset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        imageScale = value
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring()) {
                                            if imageScale < 1 {
                                                imageScale = 1
                                            } else if imageScale > 4 {
                                                imageScale = 4
                                            }
                                        }
                                    },
                                
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring()) {
                                            dragOffset = .zero
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                imageScale = imageScale > 1 ? 1 : 2
                                dragOffset = .zero
                            }
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingImageGallery = false
                        imageScale = 1
                        dragOffset = .zero
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var shareView: some View {
        Text("分享功能")
            .presentationDetents([.medium])
    }
    
    private var actionsMenuView: some View {
        NavigationView {
            List {
                Button(action: duplicateProduct) {
                    Label("复制产品", systemImage: "doc.on.doc")
                }
                
                Button(action: { showingShareSheet = true }) {
                    Label("分享产品", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { /* Export action */ }) {
                    Label("导出产品", systemImage: "square.and.arrow.up")
                }
                
                Section {
                    Button(action: { showingDeleteAlert = true }) {
                        Label("删除产品", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("产品操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showingActionsMenu = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Functions
    
    private func updateLayout(for size: CGSize) {
        screenSize = size
        isCompactLayout = size.width < 375
    }
    
    private func colorForName(_ colorName: String) -> Color {
        let lowercased = colorName.lowercased()
        switch lowercased {
        case "红色", "红", "red": return .red
        case "蓝色", "蓝", "blue": return .blue
        case "绿色", "绿", "green": return .green
        case "黄色", "黄", "yellow": return .yellow
        case "橙色", "橙", "orange": return .orange
        case "紫色", "紫", "purple": return .purple
        case "粉色", "粉", "pink": return .pink
        case "黑色", "黑", "black": return .black
        case "白色", "白", "white": return .white
        case "灰色", "灰", "gray", "grey": return .gray
        case "棕色", "棕", "brown": return Color(.systemBrown)
        default: return Color(.systemGray3)
        }
    }
    
    private func duplicateProduct() {
        let duplicatedProduct = Product(
            name: "\(product.name) 副本",
            colors: product.colors,
            imageData: product.imageData
        )
        
        if let originalSizes = product.sizes {
            for originalSize in originalSizes {
                let duplicatedSize = ProductSize(size: originalSize.size, product: duplicatedProduct)
                if duplicatedProduct.sizes == nil {
                    duplicatedProduct.sizes = []
                }
                duplicatedProduct.sizes?.append(duplicatedSize)
            }
        }
        
        modelContext.insert(duplicatedProduct)
        
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .productAdded, object: duplicatedProduct)
        } catch {
            print("Failed to duplicate product: \(error)")
        }
    }
    
    private func deleteProduct() {
        modelContext.delete(product)
        
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .productDeleted, object: nil)
            dismiss()
        } catch {
            print("Failed to delete product: \(error)")
        }
    }
}

#Preview {
    let sampleProduct = Product(
        name: "iPhone 15 Pro Max",
        colors: ["深空黑", "原色钛金属", "白色钛金属", "蓝色钛金属"],
        imageData: nil
    )
    
    return NavigationView {
        EnhancedProductDetailView(product: sampleProduct)
    }
    .modelContainer(for: [Product.self, ProductSize.self], inMemory: true)
}