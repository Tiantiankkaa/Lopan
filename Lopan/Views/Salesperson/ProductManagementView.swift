//
//  ProductManagementView.swift
//  Lopan
//
//  Completely reconstructed to match HTML mockup
//  Overlay-based drawers with slide animations
//

import SwiftUI
import SwiftData

struct ProductManagementView: View {
    @Environment(\.appDependencies) private var appDependencies

    private var productRepository: ProductRepository {
        appDependencies.serviceFactory.repositoryFactory.productRepository
    }

    // MARK: - State

    @State private var products: [Product] = []
    @State private var filteredProducts: [Product] = []

    // Drawer State
    @State private var showFilterDrawer = false
    @State private var showDetailDrawer = false
    @State private var selectedProduct: Product?

    // Filter State
    @State private var selectedProductFilterCategory: ProductFilterCategory = .all
    @State private var statusFilter: Set<Product.InventoryStatus> = [.active, .lowStock, .outOfStock, .inactive]
    @State private var inventoryRange: Double = 100

    // UI State
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var showAddProduct = false

    // Scroll State
    @State private var previousScrollOffset: CGFloat = 0
    @State private var showHeaderContent = true

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main ScrollView at top level (required for navigation bar collapse)
            ScrollView {
                VStack(spacing: 0) {
                    // Search Bar (Expandable)
                    if showSearch {
                        searchBarView
                    }

                    // Filter Chips Row
                    filterChipsRow

                    // Hidden GeometryReader to track scroll offset
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).origin.y
                        )
                    }
                    .frame(height: 0)

                    // Product List
                    LazyVStack(spacing: 12) {
                        ForEach(filteredProducts, id: \.id) { product in
                            HTMLProductCard(product: product) {
                                selectedProduct = product
                                showDetailDrawer = true
                                LopanHapticEngine.shared.light()
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                updateScrollPosition(value)
            }
            .refreshable {
                await refreshData()
            }
            .background(Color(hex: "#F7F8FA") ?? Color.gray.opacity(0.05)) // light-gray

            // Backdrop Overlay
            if showFilterDrawer || showDetailDrawer {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(30)
                    .onTapGesture {
                        closeAllDrawers()
                    }
            }

            // Filter Drawer (Left Slide)
            if showFilterDrawer {
                filterDrawerView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
                    .zIndex(40)
            }

            // Detail Drawer (Right Slide)
            if showDetailDrawer, let product = selectedProduct {
                detailDrawerView(product: product)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                    .zIndex(40)
            }

            // Floating Action Button (FAB) - Lower Right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingActionButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 34)
                }
            }
            .zIndex(25)
        }
        .navigationTitle("Products")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: {
                        LopanHapticEngine.shared.light()
                        showSearch.toggle()
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hex: "#4B5563") ?? Color.secondary)
                    }
                    .accessibilityLabel("Search products")
                    .disabled(!showHeaderContent)

                    Button(action: {
                        LopanHapticEngine.shared.light()
                        showFilterDrawer = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(Color(hex: "#4B5563") ?? Color.secondary)
                    }
                    .accessibilityLabel("Open filters")
                    .disabled(!showHeaderContent)
                }
                .opacity(showHeaderContent ? 1 : 0)
                .animation(.easeOut(duration: 0.25), value: showHeaderContent)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showFilterDrawer)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showDetailDrawer)
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showAddProduct) {
            ModernAddProductView()
        }
        .onChange(of: selectedProductFilterCategory) { _, _ in
            updateFilteredProducts()
        }
        .onChange(of: statusFilter) { _, _ in
            updateFilteredProducts()
        }
        .onChange(of: searchText) { _, _ in
            updateFilteredProducts()
        }
    }

    // MARK: - Search Bar View

    /// Expandable search bar
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(hex: "#9CA3AF") ?? Color.gray)
            TextField("Search products...", text: $searchText)
                .font(.system(size: 16))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "#9CA3AF") ?? Color.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Filter Chips Row

    /// Matches HTML: <div class="flex space-x-2 overflow-x-auto">
    private var filterChipsRow: some View {
        HStack(spacing: 0) {
            // Scrollable chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProductFilterCategory.allCases, id: \.self) { chip in
                        filterChipButton(chip)
                    }
                }
                .padding(.horizontal, 16)
            }

            // View Toggle Button (Fixed Right)
            Button(action: {
                LopanHapticEngine.shared.light()
                // View toggle functionality (placeholder)
            }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(Color(hex: "#4B5563") ?? Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .accessibilityLabel("Toggle view mode")
        }
        .padding(.bottom, 12)
        .frame(height: showHeaderContent ? nil : 0)
        .clipped()
        .opacity(showHeaderContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: showHeaderContent)
    }

    private func filterChipButton(_ chip: ProductFilterCategory) -> some View {
        Button(action: {
            LopanHapticEngine.shared.light()
            selectedProductFilterCategory = chip
        }) {
            HStack(spacing: 6) {
                Text(chip.label)
                if let count = chip.count(from: products) {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(selectedProductFilterCategory == chip ? .white : Color(hex: "#4B5563") ?? Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                selectedProductFilterCategory == chip ?
                    Color(hex: "#6366F1") ?? Color.blue : // primary (indigo)
                    Color.white
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        selectedProductFilterCategory == chip ?
                            Color.clear :
                            Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }


    // MARK: - Floating Action Button

    /// FAB in lower right corner for adding products
    private var floatingActionButton: some View {
        Button(action: {
            LopanHapticEngine.shared.medium()
            showAddProduct = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color(hex: "#6366F1") ?? Color.blue) // Primary indigo
                        .shadow(color: (Color(hex: "#6366F1") ?? Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .accessibilityLabel("Add product")
        .accessibilityHint("Opens form to add a new product")
    }

    // MARK: - Filter Drawer View

    /// Left-sliding filter drawer matching HTML mockup
    /// Width: 80% max 320pt, white background
    private var filterDrawerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Filters")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#111827") ?? Color.primary)

                    Spacer()

                    Button(action: {
                        LopanHapticEngine.shared.light()
                        showFilterDrawer = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                    }
                }
                .padding(24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Status Filter
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Status")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#374151") ?? Color.primary)

                            Menu {
                                Button("All") { statusFilter = [.active, .lowStock, .outOfStock, .inactive] }
                                Button("Active") { statusFilter = [.active] }
                                Button("Low Stock") { statusFilter = [.lowStock] }
                                Button("Out of Stock") { statusFilter = [.outOfStock] }
                                Button("Inactive") { statusFilter = [.inactive] }
                            } label: {
                                HStack {
                                    Text(statusFilterLabel)
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#111827") ?? Color.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                                }
                                .padding(12)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }

                        // Inventory Range
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Inventory")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#374151") ?? Color.primary)

                            VStack(spacing: 8) {
                                Slider(value: $inventoryRange, in: 0...100, step: 5)
                                    .tint(Color(hex: "#6366F1") ?? Color.blue)

                                HStack {
                                    Text("0")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                                    Spacer()
                                    Text("100+")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                                }
                            }
                        }

                        // Apply Button
                        Button(action: {
                            LopanHapticEngine.shared.medium()
                            updateFilteredProducts()
                            showFilterDrawer = false
                        }) {
                            Text("Apply Filters")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#6366F1") ?? Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Reset Button
                        Button(action: {
                            LopanHapticEngine.shared.light()
                            statusFilter = [.active, .lowStock, .outOfStock, .inactive]
                            inventoryRange = 100
                            selectedProductFilterCategory = .all
                            updateFilteredProducts()
                        }) {
                            Text("Reset")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#374151") ?? Color.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: 320)
            .frame(maxHeight: .infinity)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 2, y: 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Detail Drawer View

    /// Right-sliding detail drawer (full width)
    private func detailDrawerView(product: Product) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Product Details")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "#111827") ?? Color.primary)

                Spacer()

                Button(action: {
                    LopanHapticEngine.shared.light()
                    showDetailDrawer = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                }
            }
            .padding(16)

            // Form Content
            ScrollView {
                VStack(spacing: 24) {
                    formField(label: "Name", value: product.name)
                    formField(label: "SKU", value: product.formattedSKU)
                    formField(label: "Price", value: product.formattedPrice)
                    formField(label: "Inventory", value: "\(product.inventoryQuantity)")
                    formField(label: "Status", value: product.inventoryStatus.htmlLabel)

                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            LopanHapticEngine.shared.medium()
                            // Save changes
                            showDetailDrawer = false
                        }) {
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#6366F1") ?? Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: {
                            LopanHapticEngine.shared.light()
                            showDetailDrawer = false
                        }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#374151") ?? Color.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(24)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#F7F8FA") ?? Color.gray.opacity(0.05))
    }

    private func formField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#111827") ?? Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }

    // MARK: - Helper Methods

    private var statusFilterLabel: String {
        if statusFilter.count == 4 { return "All" }
        if statusFilter.count == 1 {
            switch statusFilter.first {
            case .active: return "Active"
            case .lowStock: return "Low Stock"
            case .outOfStock: return "Out of Stock"
            case .inactive: return "Inactive"
            case .none: return "All"
            }
        }
        return "Custom"
    }

    private func closeAllDrawers() {
        LopanHapticEngine.shared.light()
        showFilterDrawer = false
        showDetailDrawer = false
    }

    private func updateScrollPosition(_ offset: CGFloat) {
        // Small threshold to ignore tiny movements (prevent jitter)
        let minMovement: CGFloat = 5

        // Calculate scroll delta
        let delta = offset - previousScrollOffset

        // Ignore very small movements
        guard abs(delta) > minMovement else { return }

        // Determine scroll direction
        if delta > 0 {
            // Scrolling UP (content moving down) - show header
            if !showHeaderContent {
                withAnimation(.easeOut(duration: 0.25)) {
                    showHeaderContent = true
                }
            }
        } else if delta < 0 {
            // Scrolling DOWN (content moving up) - hide header
            // But keep visible if already at/near top
            if offset > -20 {
                // Near top - keep header visible
                if !showHeaderContent {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showHeaderContent = true
                    }
                }
            } else if showHeaderContent {
                withAnimation(.easeOut(duration: 0.25)) {
                    showHeaderContent = false
                }
            }
        }

        previousScrollOffset = offset
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

    @MainActor
    private func refreshData() async {
        loadData()
    }

    @MainActor
    private func updateFilteredProducts() {
        var filtered = products

        // Apply chip filter
        switch selectedProductFilterCategory {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.inventoryStatus == .active }
        case .lowStock:
            filtered = filtered.filter { $0.inventoryStatus == .lowStock }
        case .outOfStock:
            filtered = filtered.filter { $0.inventoryStatus == .outOfStock }
        }

        // Apply status filter
        filtered = filtered.filter { statusFilter.contains($0.inventoryStatus) }

        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.formattedSKU.localizedCaseInsensitiveContains(searchText)
            }
        }

        filteredProducts = filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Filter Chip Enum

enum ProductFilterCategory: CaseIterable {
    case all
    case active
    case lowStock
    case outOfStock

    var label: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .lowStock: return "Low Stock"
        case .outOfStock: return "Out of Stock"
        }
    }

    func count(from products: [Product]) -> Int? {
        switch self {
        case .all:
            return products.count
        case .active:
            return products.filter { $0.inventoryStatus == .active }.count
        case .lowStock:
            return products.filter { $0.inventoryStatus == .lowStock }.count
        case .outOfStock:
            return products.filter { $0.inventoryStatus == .outOfStock }.count
        }
    }
}

// Note: ScrollOffsetPreferenceKey is defined in VirtualScrollView.swift

// MARK: - Preview

#Preview {
    ProductManagementView()
}
