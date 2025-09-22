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
    @Environment(\.appDependencies) private var appDependencies
    
    private var productRepository: ProductRepository {
        appDependencies.serviceFactory.repositoryFactory.productRepository
    }
    
    @State private var products: [Product] = []
    @State private var productSizes: [ProductSize] = []
    
    @State private var showingAddProduct = false
    @State private var showingExcelImport = false
    @State private var showingExcelExport = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedProducts: Set<String> = []
    @State private var isBatchMode = false
    @State private var showingDeleteAlert = false
    @State private var productsToDelete: [Product] = []
    @State private var displayMode: AdaptiveProductCard.CardDisplayMode = .standard
    @State private var showingViewModeSelector = false
    @State private var searchSuggestions: [String] = []
    @State private var showingSmartActions = false
    @State private var filteredProducts: [Product] = []
    
    
    @MainActor
    private func updateFilteredProducts() {
        var filtered = products
        
        // 文本搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.colors.contains { color in
                    color.localizedCaseInsensitiveContains(searchText)
                } ||
                product.sizeNames.contains { size in
                    size.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        // 按名称默认排序
        filteredProducts = filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    
    private var currentSearchSuggestions: [String] {
        if searchText.isEmpty {
            return searchSuggestions
        } else {
            return searchSuggestions.filter { suggestion in
                suggestion.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Enhanced Search Bar
                enhancedSearchView
                
                // Batch Operations Controller
                BatchOperationsController(
                    isBatchMode: $isBatchMode,
                    selectedItems: $selectedProducts,
                    totalItems: products.count,
                    filteredItems: filteredProducts.map { $0.id },
                    onBulkAction: handleBulkAction,
                    onSelectAll: selectAllProducts,
                    onDeselectAll: deselectAllProducts
                )
                
                // View Controls
                if !isBatchMode {
                    viewControlsToolbar
                }
                
                // Enhanced Product List
                enhancedProductListView
            }
            
            // Smart Floating Action Button
            smartFloatingActionButton
        }
        .navigationTitle("产品管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                viewModeButton
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingExcelExport = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(LopanColors.primary)
                }
                .accessibilityLabel("导出产品")
            }
        }
        .sheet(isPresented: $showingAddProduct) {
            ModernAddProductView()
        }
        .sheet(isPresented: $showingViewModeSelector) {
            viewModeSelector
        }
        .adaptiveBackground()
        .onAppear {
            loadData()
            generateSearchSuggestions()
            updateFilteredProducts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .productAdded)) { _ in
            loadData()
            generateSearchSuggestions()
            updateFilteredProducts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .productUpdated)) { _ in
            loadData()
            generateSearchSuggestions()
            updateFilteredProducts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .productDeleted)) { _ in
            loadData()
            generateSearchSuggestions()
            updateFilteredProducts()
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
    
    // MARK: - Enhanced Search View
    
    private var enhancedSearchView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                LopanSearchBar(
                    searchText: $searchText,
                    placeholder: "搜索产品名称、颜色或尺寸...",
                    suggestions: currentSearchSuggestions,
                    style: .prominent,
                    showVoiceSearch: true,
                    onClear: {
                        isSearching = false
                    },
                    onSearch: { query in
                        performSearch(query)
                    }
                )
                
                if !isBatchMode {
                    batchModeToggleButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(LopanColors.background)
        .onChange(of: searchText) { _, newValue in
            isSearching = !newValue.isEmpty
            updateFilteredProducts()
        }
    }
    
    private var batchModeToggleButton: some View {
        Button(action: toggleBatchMode) {
            Image(systemName: "checklist")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(LopanColors.primary)
        }
        .frame(width: 44, height: 44)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .disabled(filteredProducts.isEmpty)
        .accessibilityLabel("批量操作模式")
        .accessibilityHint("启用批量选择和操作功能")
    }
    
    // MARK: - View Controls Toolbar
    
    private var viewControlsToolbar: some View {
        HStack {
            Spacer()
            
            // Results Count
            Text("\(filteredProducts.count) 个产品")
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
                .animation(.easeInOut(duration: 0.2), value: filteredProducts.count)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(LopanColors.background)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.border),
            alignment: .bottom
        )
    }
    
    // MARK: - Enhanced Product List View
    
    private var enhancedProductListView: some View {
        Group {
            if filteredProducts.isEmpty {
                enhancedEmptyStateView
            } else {
                virtualScrollingProductList
            }
        }
    }
    
    private var virtualScrollingProductList: some View {
        ScrollView {
            LazyVStack(spacing: displayMode == .compact ? 8 : 12) {
                ForEach(filteredProducts, id: \.id) { product in
                    productCardView(for: product)
                        .onAppear {
                            // Preload next items for smooth scrolling
                            if product == filteredProducts.last {
                                // Could implement pagination here
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 80) // Space for floating action button
        }
        .background(LopanColors.background)
        .refreshable {
            await refreshData()
        }
    }
    
    private func productCardView(for product: Product) -> some View {
        Group {
            if isBatchMode {
                AdaptiveProductCard(
                    product: product,
                    displayMode: displayMode,
                    selectionState: .selectable(isSelected: selectedProducts.contains(product.id)),
                    onSelect: { toggleProductSelection(product) },
                    onSecondaryAction: nil
                )
            } else {
                NavigationLink(destination: EnhancedProductDetailView(product: product)) {
                    AdaptiveProductCard(
                        product: product,
                        displayMode: displayMode,
                        selectionState: .none,
                        onSelect: {},
                        onSecondaryAction: { showProductActions(for: product) }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isBatchMode)
    }
    
    private var enhancedEmptyStateView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: isSearching ? "magnifyingglass" : "cube.box")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundColor(LopanColors.textTertiary)
                    .scaleEffect(isSearching ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isSearching)
                
                VStack(spacing: 8) {
                    Text(isSearching ? "未找到匹配产品" : "还没有产品")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Text(isSearching ? 
                         "尝试使用不同的搜索词或清除搜索条件" : 
                         "添加您的第一个产品开始管理库存"
                    )
                    .font(.body)
                    .foregroundColor(LopanColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                }
            }
            
            VStack(spacing: 12) {
                if isSearching {
                    Button("清除搜索") {
                        clearSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.white)
                    .tint(LopanColors.primary)
                } else {
                    Button("添加产品") {
                        showingAddProduct = true
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.white)
                    .tint(LopanColors.primary)
                    
                    Button("导入产品") {
                        showingExcelImport = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(LopanColors.primary)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LopanColors.background)
    }
    
    // MARK: - Smart Floating Action Button
    
    private var smartFloatingActionButton: some View {
        VStack(spacing: 12) {
            if showingSmartActions && !isBatchMode {
                quickActionButtons
            }
            
            mainFloatingActionButton
        }
        .padding(.trailing, 20)
        .padding(.bottom, 34)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showingSmartActions)
    }
    
    private var quickActionButtons: some View {
        VStack(spacing: 8) {
            quickActionButton(
                icon: "square.and.arrow.down",
                label: "导入",
                action: { showingExcelImport = true }
            )
            
            quickActionButton(
                icon: "plus",
                label: "添加",
                action: { 
                    showingAddProduct = true
                    showingSmartActions = false
                }
            )
        }
    }
    
    private func quickActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(LopanColors.primary.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: LopanColors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
    
    private var mainFloatingActionButton: some View {
        Button(action: {
            // Toggle showing/hiding options only
            showingSmartActions.toggle()
        }) {
            Image(systemName: showingSmartActions ? "plus" : "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(LopanColors.primary)
                .clipShape(Circle())
                .shadow(color: LopanColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                .rotationEffect(.degrees(showingSmartActions ? 45 : 0))
        }
        .scaleEffect(isBatchMode ? 0.8 : 1.0)
        .opacity(isBatchMode ? 0.6 : 1.0)
        .disabled(isBatchMode)
        .animation(.easeInOut(duration: 0.2), value: isBatchMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showingSmartActions)
        .accessibilityLabel(showingSmartActions ? "隐藏选项" : "显示选项")
    }
    
    // MARK: - Toolbar Components
    
    private var viewModeButton: some View {
        Button(action: { showingViewModeSelector = true }) {
            Image(systemName: displayModeIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LopanColors.primary)
        }
        .accessibilityLabel("切换视图模式")
    }
    
    private var displayModeIcon: String {
        switch displayMode {
        case .compact: return "list.bullet"
        case .standard: return "rectangle.grid.1x2"
        case .detailed: return "rectangle.portrait"
        }
    }
    
    
    private var viewModeSelector: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "eye")
                            .font(.title2)
                            .foregroundColor(LopanColors.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("视图模式")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(LopanColors.textPrimary)
                            
                            Text("选择产品列表的显示方式")
                                .font(.subheadline)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Divider()
                }
                
                VStack(spacing: 0) {
                    viewModeOption(.compact, "紧凑列表", "显示基本信息，节省空间")
                    viewModeOption(.standard, "标准卡片", "平衡的信息显示")
                    viewModeOption(.detailed, "详细视图", "完整的产品信息预览")
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingViewModeSelector = false
                    }
                    .foregroundColor(LopanColors.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func viewModeOption(_ mode: AdaptiveProductCard.CardDisplayMode, _ title: String, _ description: String) -> some View {
        Button(action: {
            displayMode = mode
            showingViewModeSelector = false
        }) {
            HStack(spacing: 16) {
                Image(systemName: mode == .compact ? "list.bullet" : 
                                 mode == .standard ? "rectangle.grid.1x2" : "rectangle.portrait")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(LopanColors.primary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }
                
                Spacer()
                
                if displayMode == mode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LopanColors.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.border),
            alignment: .bottom
        )
    }
    
    // MARK: - Action Functions
    
    private func toggleBatchMode() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isBatchMode.toggle()
            if !isBatchMode {
                selectedProducts.removeAll()
                showingSmartActions = false
            }
        }
    }
    
    
    
    private func performSearch(_ query: String) {
        // Debounced search functionality could be added here
        // Update search suggestions based on query
    }
    
    private func clearSearch() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            searchText = ""
            isSearching = false
        }
    }
    
    private func generateSearchSuggestions() {
        let allProductNames = products.map { $0.name }
        let allColors = products.flatMap { $0.colors }
        let allSizes = products.compactMap { $0.sizes }.flatMap { $0.map { $0.size } }
        
        searchSuggestions = Array(Set(allProductNames + allColors + allSizes)).sorted()
    }
    
    @MainActor
    private func selectAllProducts() {
        selectedProducts = Set(filteredProducts.map { $0.id })
    }
    
    @MainActor
    private func deselectAllProducts() {
        selectedProducts.removeAll()
    }
    
    private func handleBulkAction(_ action: BatchOperationsController.BatchAction) {
        switch action {
        case .delete:
            productsToDelete = products.filter { selectedProducts.contains($0.id) }
            showingDeleteAlert = true
        case .export:
            showingExcelExport = true
        }
    }
    
    
    private func duplicateSelectedProducts() {
        let productsToDuplicate = products.filter { selectedProducts.contains($0.id) }
        
        Task {
            do {
                for product in productsToDuplicate {
                    let duplicatedProduct = Product(
                        name: "\(product.name) 副本",
                        colors: product.colors,
                        imageData: product.imageData
                    )
                    
                    // Duplicate sizes
                    if let originalSizes = product.sizes {
                        for originalSize in originalSizes {
                            let duplicatedSize = ProductSize(size: originalSize.size, product: duplicatedProduct)
                            if duplicatedProduct.sizes == nil {
                                duplicatedProduct.sizes = []
                            }
                            duplicatedProduct.sizes?.append(duplicatedSize)
                        }
                    }
                    
                    try await productRepository.addProduct(duplicatedProduct)
                }
                
                selectedProducts.removeAll()
                isBatchMode = false
                
                // Reload data
                loadData()
            } catch {
                print("Failed to duplicate products: \(error)")
            }
        }
    }
    
    private func showProductActions(for product: Product) {
        // Show contextual menu for individual product
    }
    
    @MainActor
    private func refreshData() async {
        loadData()
        generateSearchSuggestions()
        updateFilteredProducts()
    }
    
    private func toggleProductSelection(_ product: Product) {
        if isBatchMode {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
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
    
    @MainActor
    private func loadData() {
        Task {
            do {
                products = try await productRepository.fetchProducts()
                updateFilteredProducts()
            } catch {
                print("Error loading products: \(error)")
            }
        }
    }
    
    private func deleteSelectedProducts() {
        let productsToDelete = products.filter { selectedProducts.contains($0.id) }
        
        Task {
            do {
                for product in productsToDelete {
                    try await productRepository.deleteProduct(product)
                }
                
                selectedProducts.removeAll()
                isBatchMode = false
                
                // Send notification that products were deleted
                NotificationCenter.default.post(name: .productDeleted, object: nil)
                
                // Reload products after deletion
                loadData()
            } catch {
                print("Failed to delete products: \(error)")
            }
        }
    }
}

struct ProductRowView: View {
    let product: Product
    let isSelected: Bool
    let isBatchMode: Bool
    let onSelect: () -> Void
    
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
        case "深蓝色", "深蓝", "navy", "dark blue": return Color(.systemBlue).opacity(0.7)
        case "浅蓝色", "浅蓝", "light blue": return Color(.systemBlue).opacity(0.3)
        case "军绿色", "军绿", "olive": return Color(.systemGreen).opacity(0.6)
        case "米色", "米", "beige": return Color(.systemBrown).opacity(0.3)
        case "格子": return Color(.systemGray2)
        default: return Color(.systemGray3)
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            selectionCheckbox
            productImage
            productInfoView
            Spacer()
            
            if !isBatchMode {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
        .padding(16)
        .background(backgroundView)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.name), \(product.colors.joined(separator: ", "))")
    }
    
    @ViewBuilder
    private var selectionCheckbox: some View {
        if isBatchMode {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? LopanColors.primary : LopanColors.textSecondary)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(isSelected ? "取消选择" : "选择此产品")
        }
    }
    
    private var productInfoView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(product.name)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(LopanColors.textPrimary)
            
            productColorsView
            productSizesView
        }
    }
    
    @ViewBuilder
    private var productColorsView: some View {
        if !product.colors.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(product.colors.prefix(3), id: \.self) { color in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorForName(color))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle().stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                                )
                            LopanBadge(color, style: .neutral, size: .small)
                        }
                    }
                    if product.colors.count > 3 {
                        LopanBadge("+\(product.colors.count - 3)", style: .outline, size: .small)
                    }
                }
            }
        } else {
            Text("暂无颜色")
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
        }
    }
    
    @ViewBuilder
    private var productSizesView: some View {
        if let sizes = product.sizes, !sizes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sizes.prefix(4)) { size in
                        LopanBadge(size.size, style: .secondary, size: .small)
                    }
                    if sizes.count > 4 {
                        LopanBadge("+\(sizes.count - 4)", style: .outline, size: .small)
                    }
                }
            }
        } else {
            Text("暂无尺寸")
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? LopanColors.primary.opacity(0.1) : Color.white)
            .shadow(
                color: isSelected ? LopanColors.primary.opacity(0.2) : Color.black.opacity(0.05),
                radius: isSelected ? 8 : 2,
                x: 0,
                y: isSelected ? 4 : 1
            )
    }
    
    private var productImage: some View {
        Group {
            if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                // 本地图片数据
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LopanColors.border, lineWidth: 0.5)
                    )
            } else {
                // 占位符
                RoundedRectangle(cornerRadius: 12)
                    .fill(LopanColors.backgroundTertiary)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "cube.box.fill")
                            .font(.title2)
                            .foregroundColor(LopanColors.textSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LopanColors.border, lineWidth: 0.5)
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                productInfoView
                sizesView
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(LopanColors.background)
        .navigationTitle("产品详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundColor(LopanColors.primary)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditProductView(product: product)
        }
    }
    
    private var productInfoView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("产品信息")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(LopanColors.textPrimary)
            
            HStack(spacing: 20) {
                // Product image
                Group {
                    if let imageData = product.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LopanColors.border, lineWidth: 0.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LopanColors.backgroundTertiary)
                            .frame(width: 100, height: 100)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(LopanColors.textSecondary)
                                    Text("无图片")
                                        .font(.caption)
                                        .foregroundColor(LopanColors.textSecondary)
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LopanColors.border, lineWidth: 0.5)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(product.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("颜色")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(LopanColors.textPrimary)
                        
                        if !product.colors.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 6) {
                                ForEach(product.colors, id: \.self) { color in
                                    LopanBadge(color, style: .neutral, size: .small)
                                }
                            }
                        } else {
                            Text("暂无颜色")
                                .font(.body)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                    }
                    
                    Text("创建时间: \(product.createdAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private var sizesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("可用尺寸")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(LopanColors.textPrimary)
            
            if let sizes = product.sizes, !sizes.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(sizes) { size in
                        LopanBadge(size.size, style: .secondary, size: .medium)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "ruler")
                        .foregroundColor(LopanColors.textSecondary)
                    Text("暂无尺寸信息")
                        .foregroundColor(LopanColors.textSecondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
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
        NavigationStack {
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
            NotificationCenter.default.post(name: .productUpdated, object: product)
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
