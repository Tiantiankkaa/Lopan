//
//  ProductDetailView.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-09.
//  Product detail editing view matching HTML mockup
//  iOS 26 Liquid Glass design with sectioned cards
//

import SwiftUI
import PhotosUI
import os.log

/// PreferenceKey for tracking status label size
struct StatusLabelSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// PreferenceKey for tracking status label frame position
struct StatusLabelFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Full-screen product detail editor matching HTML mockup design
/// Sections: Basics, Media, Price, Attributes with sticky footer
struct ProductDetailView: View {
    // Debug logger
    private let logger = Logger(subsystem: "com.lopan.ui", category: "product-detail")
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var appDependencies

    private var productRepository: ProductRepository {
        appDependencies.serviceFactory.repositoryFactory.productRepository
    }

    // MARK: - Input Product

    let product: Product

    // MARK: - Form State

    @State private var productName: String = ""
    @State private var productDescription: String = ""
    @State private var price: String = ""
    @State private var weight: String = ""
    @State private var sizeInput: String = ""
    @State private var imageDataArray: [Data] = []

    // Status & Inventory
    @State private var selectedStatus: Product.InventoryStatus = .active
    @State private var lowStockQuantity: String = ""

    // Media management
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isLoadingImages = false

    // UI State
    @State private var showDiscardConfirmation = false
    @State private var isSaving = false
    @State private var showValidationErrors = false
    @State private var validationMessage = ""

    // MARK: - Computed Properties

    private var hasChanges: Bool {
        let statusChanged = selectedStatus != product.inventoryStatus

        // Determine expected value based on product status and threshold (must match initialization logic)
        let expectedLowStockQty: String = {
            if product.inventoryStatus == .lowStock {
                // For Low Stock: compare against threshold if set, otherwise against current inventory
                return product.lowStockThreshold != nil
                    ? String(product.lowStockThreshold!)
                    : String(product.inventoryQuantity)
            } else {
                // For other statuses: compare against threshold (or empty if not set)
                return product.lowStockThreshold != nil ? String(product.lowStockThreshold!) : ""
            }
        }()
        let lowStockQtyChanged = lowStockQuantity != expectedLowStockQty

        return productName != product.name ||
               productDescription != (product.productDescription ?? "") ||
               price != String(format: "%.2f", product.price) ||
               weight != (product.weight != nil ? String(format: "%.0f", product.weight!) : "") ||
               sizeInput != product.sizeNames.joined(separator: ", ") ||
               imageDataArray != product.imageDataArray ||
               statusChanged ||
               lowStockQtyChanged
    }

    private var isValid: Bool {
        guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let priceValue = Double(price), priceValue > 0 else { return false }
        if !weight.isEmpty {
            guard let weightValue = Double(weight), weightValue > 0 else { return false }
        }

        // When Low Stock is selected, inventory quantity is required
        if selectedStatus == .lowStock {
            guard !lowStockQuantity.isEmpty else { return false }
            guard let qtyValue = Int(lowStockQuantity), qtyValue > 0 else { return false }
        }

        return true
    }

    // MARK: - Body

    var body: some View {
        let _ = logger.debug("📱 ProductDetailView body render")
        let _ = logger.debug("  └─ Product: \(product.name)")
        let _ = logger.debug("  └─ Product ID: \(product.id)")
        let _ = logger.debug("  └─ Images in product: \(product.imageDataArray.count)")
        let _ = logger.debug("  └─ Images in state: \(imageDataArray.count)")

        ZStack(alignment: .bottom) {
            // Main Content
            ScrollView {
                VStack(spacing: 24) {
                    basicsSection
                    mediaSection
                    priceSection
                    attributesSection

                    // Bottom spacing for sticky footer (reduced since footer is simpler)
                    Color.clear.frame(height: 70)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(hex: "#F7F8FA") ?? Color.gray.opacity(0.05))

            // Sticky Footer
            stickyFooter
        }
        .navigationTitle("Product Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: handleBack) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "#4B5563") ?? Color.secondary)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: initializeForm)
        .onChange(of: selectedPhotos) { _, newPhotos in
            loadSelectedPhotos(newPhotos)
        }
        .alert("Validation Error", isPresented: $showValidationErrors) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }

    // MARK: - Basics Section

    private var basicsSection: some View {
        sectionCard(title: "Basics") {
            VStack(spacing: 16) {
                formField(label: "Product Name") {
                    TextField("Product name", text: $productName)
                        .textFieldStyle(RoundedTextFieldStyle())
                }

                formField(label: "Description") {
                    TextEditor(text: $productDescription)
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Media Section

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Custom header: "Media" with "0/3 Clear All"
            HStack {
                Text("Media")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#111827") ?? Color.primary)

                Spacer()

                HStack(spacing: 8) {
                    Text("\(imageDataArray.count)/3")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)

                    if !imageDataArray.isEmpty {
                        Button(action: {
                            withAnimation {
                                imageDataArray.removeAll()
                            }
                            LopanHapticEngine.shared.light()
                        }) {
                            Text("Clear All")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#6366F1") ?? Color.blue)
                        }
                    }
                }
            }

            // Image Grid (always visible)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Existing images
                ForEach(Array(imageDataArray.enumerated()), id: \.offset) { index, data in
                    imageCard(data: data, index: index)
                }

                // Add photo button (when less than 3 images)
                if imageDataArray.count < 3 {
                    addPhotoCard
                }
            }

            if isLoadingImages {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading images...")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func imageCard(data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Delete button
            Button(action: {
                LopanHapticEngine.shared.light()
                imageDataArray.remove(at: index)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 24, height: 24)
                    )
            }
            .offset(x: 8, y: -8)
        }
    }

    private var addPhotoCard: some View {
        PhotosPicker(selection: $selectedPhotos,
                     maxSelectionCount: 3 - imageDataArray.count,
                     matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#F9FAFB") ?? Color.gray.opacity(0.05))

                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2),
                           style: StrokeStyle(lineWidth: 2, dash: [8]))

                Image(systemName: "plus")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color(hex: "#9CA3AF") ?? Color.gray)
            }
            .frame(width: 100, height: 100)
        }
    }

    // MARK: - Price Section

    private var priceSection: some View {
        sectionCard(title: "Price") {
            HStack(spacing: 16) {
                formField(label: "Price") {
                    TextField("0.00", text: $price)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedTextFieldStyle())
                }

                formField(label: "SKU") {
                    Text(product.formattedSKU)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#111827") ?? Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(hex: "#F9FAFB") ?? Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Attributes Section

    private var attributesSection: some View {
        sectionCard(title: "Attributes") {
            VStack(spacing: 16) {
                // Row 1: Weight and Size (2-column grid)
                HStack(spacing: 16) {
                    formField(label: "Weight") {
                        TextField("250g", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedTextFieldStyle())
                    }

                    formField(label: "Size") {
                        TextField("41-45", text: $sizeInput)
                            .textFieldStyle(RoundedTextFieldStyle())
                    }
                }

                // Row 2: Inventory Quantity (conditional - appears when Low Stock selected)
                if selectedStatus == .lowStock {
                    formField(label: "Inventory Quantity") {
                        TextField("Enter quantity", text: $lowStockQuantity)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        lowStockQuantity.isEmpty && !isValid ?
                                            Color(hex: "#EF4444") ?? Color.red :
                                            Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
            }
        }
    }

    // MARK: - Sticky Footer

    private var stickyFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2))
                .frame(height: 1)

            HStack {
                // Status Dropdown
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)

                    Menu {
                        ForEach([Product.InventoryStatus.active, .lowStock, .inactive], id: \.self) { status in
                            Button(action: {
                                let oldStatus = selectedStatus
                                selectedStatus = status
                                logger.debug("🔄 Status changed: \(oldStatus.displayName) → \(status.displayName)")
                                logger.debug("  └─ Old text length: \(oldStatus.displayName.count) chars")
                                logger.debug("  └─ New text length: \(status.displayName.count) chars")
                                logger.debug("  └─ Waiting for frame update...")
                                LopanHapticEngine.shared.light()
                            }) {
                                HStack {
                                    Text(status.displayName)
                                    if selectedStatus == status {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(selectedStatus.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "#111827") ?? Color.primary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                        }
                        .frame(minWidth: 100, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: StatusLabelFrameKey.self,
                                    value: geometry.frame(in: .global)
                                )
                            }
                        )
                        .onPreferenceChange(StatusLabelFrameKey.self) { frame in
                            logger.debug("📍 Status label frame:")
                            logger.debug("  └─ Position: x=\(String(format: "%.2f", frame.origin.x))pt, y=\(String(format: "%.2f", frame.origin.y))pt")
                            logger.debug("  └─ Size: width=\(String(format: "%.1f", frame.size.width))pt, height=\(String(format: "%.1f", frame.size.height))pt")
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(minWidth: 120, alignment: .leading)

                Spacer()

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: handleDiscard) {
                        Text("Discard")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#111827") ?? Color.primary)
                            .frame(minWidth: 70)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 999))
                    }
                    .confirmationDialog("Discard Changes?", isPresented: $showDiscardConfirmation) {
                        Button("Discard", role: .destructive) {
                            dismiss()
                        }
                        Button("Keep Editing", role: .cancel) { }
                    } message: {
                        Text("You have unsaved changes. Are you sure you want to discard them?")
                    }

                    Button(action: handleSave) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(minWidth: 70)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(hex: "#6366F1") ?? Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 999))
                    .disabled(isSaving || !isValid)
                    .opacity((isSaving || !isValid) ? 0.5 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#F7F8FA") ?? Color.gray.opacity(0.05))
        }
    }

    // MARK: - Reusable Components

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#111827") ?? Color.primary)

            content()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)

            content()
        }
    }

    // MARK: - Actions

    private func initializeForm() {
        logger.debug("🔧 initializeForm() called")
        logger.debug("  └─ Product ID: \(product.id)")
        logger.debug("  └─ Product Name: \(product.name)")
        logger.debug("  └─ Product Price: \(product.price)")
        logger.debug("  └─ Product Images: \(product.imageDataArray.count)")
        logger.debug("  └─ Product Description: \(product.productDescription ?? "nil")")
        logger.debug("  └─ Product Weight: \(product.weight.map { "\($0)g" } ?? "nil")")
        logger.debug("  └─ Product Sizes: \(product.sizeNames.joined(separator: ", "))")
        logger.debug("  └─ Product Status: \(product.inventoryStatus.displayName)")
        logger.debug("  └─ Product Low Stock Threshold: \(product.lowStockThreshold.map { "\($0)" } ?? "nil")")

        productName = product.name
        productDescription = product.productDescription ?? ""
        price = String(format: "%.2f", product.price)
        weight = product.weight != nil ? String(format: "%.0f", product.weight!) : ""
        sizeInput = product.sizeNames.joined(separator: ", ")
        imageDataArray = product.imageDataArray
        selectedStatus = product.inventoryStatus

        // Initialize inventory quantity field based on status
        if selectedStatus == .lowStock {
            // For Low Stock: show manual threshold if set, otherwise show current inventory
            lowStockQuantity = product.lowStockThreshold != nil
                ? String(product.lowStockThreshold!)
                : String(product.inventoryQuantity)
        } else {
            // For other statuses: show threshold only if manually set
            lowStockQuantity = product.lowStockThreshold != nil ? String(product.lowStockThreshold!) : ""
        }

        logger.debug("  └─ ✅ Form initialized")
        logger.debug("  └─ State imageDataArray count: \(imageDataArray.count)")
    }

    private func handleBack() {
        if hasChanges {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func handleDiscard() {
        if hasChanges {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func handleSave() {
        guard isValid else {
            if selectedStatus == .lowStock && lowStockQuantity.isEmpty {
                validationMessage = "Inventory quantity is required when status is Low Stock."
            } else {
                validationMessage = "Please fill in all required fields correctly."
            }
            showValidationErrors = true
            return
        }

        isSaving = true
        LopanHapticEngine.shared.medium()

        Task {
            do {
                // Update product properties
                product.name = productName.trimmingCharacters(in: .whitespacesAndNewlines)
                product.productDescription = productDescription.isEmpty ? nil : productDescription.trimmingCharacters(in: .whitespacesAndNewlines)

                if let priceValue = Double(price) {
                    product.price = priceValue
                }

                if !weight.isEmpty, let weightValue = Double(weight) {
                    product.weight = weightValue
                } else {
                    product.weight = nil
                }

                product.imageDataArray = imageDataArray

                // Update product sizes from size input
                updateProductSizes()

                // Update status and inventory
                product.manualInventoryStatus = selectedStatus.rawValue

                // Handle inventory quantity changes for Low Stock status
                if selectedStatus == .lowStock, let qtyValue = Int(lowStockQuantity) {
                    product.quantity = qtyValue // Save directly to stored property
                    product.lowStockThreshold = qtyValue
                } else {
                    product.lowStockThreshold = nil
                }

                // Update cached inventory status after changes
                product.updateCachedInventoryStatus()

                product.updatedAt = Date()

                // Update through repository
                try await productRepository.updateProduct(product)

                await MainActor.run {
                    isSaving = false
                    LopanHapticEngine.shared.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    validationMessage = "Failed to save product: \(error.localizedDescription)"
                    showValidationErrors = true
                    LopanHapticEngine.shared.error()
                }
            }
        }
    }

    /// Parses the size input string and updates product sizes
    /// Input format: "XXL, M, XL, S, L"
    /// Note: ProductSize.quantity is always 0 since sizes are labels only (inventory is stored in Product.quantity)
    private func updateProductSizes() {
        // Parse comma-separated sizes
        let newSizeNames = sizeInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Create new size array with explicit ordering to preserve insertion order
        var newSizes: [ProductSize] = []
        for (index, sizeName) in newSizeNames.enumerated() {
            let size = ProductSize(
                size: sizeName,
                quantity: 0,
                sortIndex: index,  // Assign sequential index to preserve order
                product: product
            )
            newSizes.append(size)
        }

        product.sizes = newSizes
        logger.debug("📝 Updated sizes: \(newSizeNames.joined(separator: ", "))")
    }

    private func loadSelectedPhotos(_ photos: [PhotosPickerItem]) {
        guard !photos.isEmpty else { return }

        // Enforce 3-photo limit: check available slots
        let remainingSlots = max(0, 3 - imageDataArray.count)
        guard remainingSlots > 0 else {
            logger.warning("⚠️ Photo limit reached (3/3) - cannot add more photos")
            return
        }

        isLoadingImages = true

        Task {
            var newImageData: [Data] = []

            for photo in photos {
                if let data = try? await photo.loadTransferable(type: Data.self) {
                    newImageData.append(data)
                }
            }

            await MainActor.run {
                // Filter out duplicates: compare against existing images
                let uniquePhotos = newImageData.filter { newData in
                    !imageDataArray.contains(newData)
                }

                let duplicateCount = newImageData.count - uniquePhotos.count
                if duplicateCount > 0 {
                    logger.warning("⚠️ Rejected \(duplicateCount) duplicate photo(s)")
                }

                // Strictly enforce limit: only append photos that fit
                let currentRemaining = max(0, 3 - imageDataArray.count)
                let photosToAdd = Array(uniquePhotos.prefix(currentRemaining))

                if photosToAdd.count < uniquePhotos.count {
                    logger.warning("⚠️ Photo limit: adding \(photosToAdd.count) of \(uniquePhotos.count) unique photos")
                }

                imageDataArray.append(contentsOf: photosToAdd)
                selectedPhotos = []
                isLoadingImages = false

                logger.debug("✅ Photos added: \(photosToAdd.count), Duplicates rejected: \(duplicateCount), Total: \(imageDataArray.count)/3")
            }
        }
    }
}

// MARK: - Custom TextField Style

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 14))
            .padding(12)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Preview

// Preview disabled - requires AppDependencies setup
// #Preview {
//     let sampleProduct: Product = {
//         let product = Product(
//             name: "Comfy Slippers",
//             colors: ["Black", "White"],
//             imageData: nil,
//             price: 24.99,
//             productDescription: "Plush and comfortable slippers perfect for indoor use.",
//             weight: 250
//         )
//         product.sizes = [
//             ProductSize(size: "41-45", quantity: 50, product: product)
//         ]
//         return product
//     }()
//
//     ProductDetailView(product: sampleProduct)
// }
