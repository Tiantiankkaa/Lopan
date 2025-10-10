//
//  CreateProductView.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-10.
//  Multi-step product creation flow matching HTML mockup design
//  iOS 26 Liquid Glass design with 4 steps: Basic → Media → Price → Status
//

import SwiftUI
import PhotosUI
import os.log

/// Multi-step product creation view following HTML mockup design
/// Steps: 1) Basic Info, 2) Media, 3) Attributes & Price, 4) Status
struct CreateProductView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var appDependencies

    private var productRepository: ProductRepository {
        appDependencies.serviceFactory.repositoryFactory.productRepository
    }

    private let logger = Logger(subsystem: "com.lopan.ui", category: "create-product")

    // MARK: - Form State

    @State private var productName: String = ""
    @State private var productDescription: String = ""
    @State private var price: String = ""
    @State private var weight: String = ""
    @State private var sizeInput: String = ""
    @State private var imageDataArray: [Data] = []
    @State private var selectedStatus: Product.InventoryStatus = .active
    @State private var inventoryQuantity: String = ""

    // Photo picker
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isLoadingImages = false

    // Step management
    @State private var currentStep: CreateStep = .basic
    @State private var completedSteps: Set<CreateStep> = []

    // UI state
    @State private var isSaving = false
    @State private var showValidationError = false
    @State private var validationMessage = ""

    // MARK: - Step Enum

    enum CreateStep: Int, CaseIterable {
        case basic = 1
        case media = 2
        case attributesPrice = 3
        case status = 4

        var title: String {
            switch self {
            case .basic: return "Basic"
            case .media: return "Media"
            case .attributesPrice: return "Price"
            case .status: return "Status"
            }
        }

        var stepNumber: Int {
            return rawValue
        }
    }

    // MARK: - Validation

    private func isStepValid(_ step: CreateStep) -> Bool {
        switch step {
        case .basic:
            return !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .media:
            return true // Media is optional
        case .attributesPrice:
            // Price is required and must be > 0
            guard let priceValue = Double(price), priceValue > 0 else { return false }
            // Weight is optional but must be valid if entered
            if !weight.isEmpty {
                guard let weightValue = Double(weight), weightValue > 0 else { return false }
            }
            return true
        case .status:
            // If Low Stock selected, quantity is required
            if selectedStatus == .lowStock {
                guard !inventoryQuantity.isEmpty else { return false }
                guard let qty = Int(inventoryQuantity), qty > 0 else { return false }
            }
            return true
        }
    }

    private var canProceed: Bool {
        isStepValid(currentStep)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Step Indicator
                stepIndicatorView
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                    .background(Color.white)

                // Step Content
                ScrollView {
                    VStack(spacing: 24) {
                        stepContentView

                        // Bottom padding for footer
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }
                .background(Color(hex: "#F7F8FA") ?? Color.gray.opacity(0.05))
            }

            // Sticky Footer
            footerView
        }
        .navigationTitle("Create New Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(Color(hex: "#4B5563") ?? Color.secondary)
                }
            }
        }
        .onChange(of: selectedPhotos) { _, newPhotos in
            loadSelectedPhotos(newPhotos)
        }
        .alert("Validation Error", isPresented: $showValidationError) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }

    // MARK: - Step Indicator

    private var stepIndicatorView: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(CreateStep.allCases, id: \.self) { step in
                // Step circle
                stepCircle(step)

                // Connector line (except after last step)
                if step != CreateStep.allCases.last {
                    stepConnector
                }
            }
        }
    }

    private func stepCircle(_ step: CreateStep) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(stepBackgroundColor(step))
                    .frame(width: 28, height: 28)

                if completedSteps.contains(step) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(step.stepNumber)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(step == currentStep ? .white : Color(hex: "#6B7280") ?? Color.secondary)
                }
            }

            Text(step.title)
                .font(.system(size: 12, weight: step == currentStep ? .bold : .medium))
                .foregroundColor(step == currentStep ? Color(hex: "#6366F1") ?? Color.blue : Color(hex: "#6B7280") ?? Color.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var stepConnector: some View {
        Rectangle()
            .fill(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    private func stepBackgroundColor(_ step: CreateStep) -> Color {
        if completedSteps.contains(step) {
            return Color(hex: "#6366F1") ?? Color.blue
        } else if step == currentStep {
            return Color(hex: "#6366F1") ?? Color.blue
        } else {
            return Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContentView: some View {
        switch currentStep {
        case .basic:
            basicStepView
        case .media:
            mediaStepView
        case .attributesPrice:
            attributesPriceStepView
        case .status:
            statusStepView
        }
    }

    // MARK: - Step 1: Basic Information

    private var basicStepView: some View {
        VStack(spacing: 16) {
            sectionCard {
                VStack(spacing: 16) {
                    formField(label: "Product Name", isRequired: true) {
                        TextField("Enter product name", text: $productName)
                            .textFieldStyle(ModernTextFieldStyle())
                    }

                    formField(label: "SKU") {
                        Text("Auto-generated")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#9CA3AF") ?? Color.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(hex: "#F9FAFB") ?? Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                            )
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
    }

    // MARK: - Step 2: Media

    private var mediaStepView: some View {
        VStack(spacing: 16) {
            if imageDataArray.isEmpty {
                // Empty State
                emptyMediaState
            } else {
                // Populated State
                populatedMediaState
            }
        }
    }

    private var emptyMediaState: some View {
        sectionCard {
            VStack(spacing: 16) {
                // Large icon with dashed border
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2),
                                   style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .frame(height: 200)

                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#6366F1")?.opacity(0.1) ?? Color.blue.opacity(0.1))
                                    .frame(width: 64, height: 64)

                                Image(systemName: "camera.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: "#6366F1") ?? Color.blue)
                            }

                            VStack(spacing: 4) {
                                Text("Add Product Photos")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(hex: "#111827") ?? Color.primary)

                                Text("Showcase your product with high-quality images.")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedPhotos,
                                maxSelectionCount: 3,
                                matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Photos")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#6366F1") ?? Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var populatedMediaState: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header: "Photos (2/3)" with "Clear All"
                HStack {
                    Text("Photos (\(imageDataArray.count)/3)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "#111827") ?? Color.primary)

                    Spacer()

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

                // Photo Grid (3 columns)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(Array(imageDataArray.enumerated()), id: \.offset) { index, data in
                        photoThumbnail(data: data, index: index)
                    }

                    // Add button (when < 3 photos)
                    if imageDataArray.count < 3 {
                        addPhotoButton
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
        }
    }

    private func photoThumbnail(data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: {
                LopanHapticEngine.shared.light()
                imageDataArray.remove(at: index)
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 24, height: 24)

                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .offset(x: 8, y: -8)
        }
    }

    private var addPhotoButton: some View {
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

    // MARK: - Step 3: Attributes & Price

    private var attributesPriceStepView: some View {
        VStack(spacing: 16) {
            sectionCard {
                VStack(spacing: 16) {
                    formField(label: "Price", isRequired: true) {
                        TextField("0.00", text: $price)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(ModernTextFieldStyle())
                    }

                    formField(label: "Weight (grams)") {
                        TextField("250", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(ModernTextFieldStyle())
                    }

                    formField(label: "Size") {
                        TextField("e.g., 41-45, M, L", text: $sizeInput)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Status

    private var statusStepView: some View {
        VStack(spacing: 16) {
            sectionCard {
                VStack(spacing: 16) {
                    formField(label: "Inventory Status", isRequired: true) {
                        Menu {
                            ForEach([Product.InventoryStatus.active, .lowStock, .inactive], id: \.self) { status in
                                Button(action: {
                                    selectedStatus = status
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
                            HStack {
                                Text(selectedStatus.displayName)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#111827") ?? Color.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                            }
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Conditional inventory quantity field
                    if selectedStatus == .lowStock {
                        formField(label: "Inventory Quantity", isRequired: true) {
                            TextField("Enter quantity", text: $inventoryQuantity)
                                .keyboardType(.numberPad)
                                .textFieldStyle(ModernTextFieldStyle())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            inventoryQuantity.isEmpty && !canProceed ?
                                                Color(hex: "#EF4444") ?? Color.red :
                                                Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 12) {
                // Back button (only show after step 1)
                if currentStep != .basic {
                    Button(action: handleBack) {
                        Text("Back")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#6366F1") ?? Color.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#6366F1") ?? Color.blue, lineWidth: 2)
                            )
                    }
                    .disabled(isSaving)
                }

                // Continue button
                Button(action: handleContinue) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(currentStep == .status ? "Create Product" : "Continue")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 56)
                .background(
                    canProceed && !isSaving ?
                        Color(hex: "#6366F1") ?? Color.blue :
                        (Color(hex: "#6366F1") ?? Color.blue).opacity(0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!canProceed || isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#F7F8FA") ?? Color.gray.opacity(0.05))
        }
    }

    // MARK: - Reusable Components

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#E5E7EB") ?? Color.gray.opacity(0.2), lineWidth: 1)
            )
    }

    private func formField<Content: View>(label: String, isRequired: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#374151") ?? Color.primary)

                if isRequired {
                    Text("*")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#EF4444") ?? Color.red)
                }
            }

            content()
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        guard canProceed else {
            validationMessage = getValidationMessage()
            showValidationError = true
            return
        }

        LopanHapticEngine.shared.medium()

        if currentStep == .status {
            // Last step - create product
            createProduct()
        } else {
            // Mark current step as completed
            completedSteps.insert(currentStep)

            // Move to next step
            if let nextStep = CreateStep(rawValue: currentStep.rawValue + 1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = nextStep
                }
            }
        }
    }

    private func handleBack() {
        guard let previousStep = CreateStep(rawValue: currentStep.rawValue - 1) else { return }

        // Remove current step from completed steps
        completedSteps.remove(currentStep)

        // Navigate to previous step with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = previousStep
        }

        LopanHapticEngine.shared.light()
    }

    private func getValidationMessage() -> String {
        switch currentStep {
        case .basic:
            return "Product name is required."
        case .media:
            return "" // Media is optional
        case .attributesPrice:
            if price.isEmpty {
                return "Price is required."
            } else if Double(price) == nil || Double(price)! <= 0 {
                return "Please enter a valid price greater than 0."
            } else if !weight.isEmpty && (Double(weight) == nil || Double(weight)! <= 0) {
                return "Please enter a valid weight greater than 0."
            }
            return "Please fill in all required fields correctly."
        case .status:
            if selectedStatus == .lowStock {
                if inventoryQuantity.isEmpty {
                    return "Inventory quantity is required when status is Low Stock."
                } else if Int(inventoryQuantity) == nil || Int(inventoryQuantity)! <= 0 {
                    return "Please enter a valid inventory quantity greater than 0."
                }
            }
            return "Please complete the status configuration."
        }
    }

    private func createProduct() {
        isSaving = true

        Task {
            do {
                // Generate SKU
                let skuSuffix = String(UUID().uuidString.prefix(6).uppercased())
                let sku = "PRD-\(skuSuffix)"

                // Parse price
                let priceValue = Double(price) ?? 0.0

                // Create product
                let product = Product(
                    sku: sku,
                    name: productName.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageData: imageDataArray.first,
                    price: priceValue,
                    productDescription: productDescription.isEmpty ? nil : productDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    weight: weight.isEmpty ? nil : Double(weight)
                )

                // Set images
                product.imageDataArray = imageDataArray

                // Parse and set sizes
                let sizeNames = sizeInput
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                var sizes: [ProductSize] = []
                for (index, sizeName) in sizeNames.enumerated() {
                    let size = ProductSize(
                        size: sizeName,
                        quantity: 0,
                        sortIndex: index,
                        product: product
                    )
                    sizes.append(size)
                }
                product.sizes = sizes

                // Set status
                product.manualInventoryStatus = selectedStatus.rawValue

                // Set inventory quantity for Low Stock
                if selectedStatus == .lowStock, let qty = Int(inventoryQuantity) {
                    product.quantity = qty
                    product.lowStockThreshold = qty
                }

                // Update cached inventory status
                product.updateCachedInventoryStatus()

                // Save via repository
                try await productRepository.addProduct(product)

                // Post notification to trigger list refresh
                NotificationCenter.default.post(name: .productAdded, object: product)

                await MainActor.run {
                    isSaving = false
                    LopanHapticEngine.shared.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    validationMessage = "Failed to create product: \(error.localizedDescription)"
                    showValidationError = true
                    LopanHapticEngine.shared.error()
                }
            }
        }
    }

    private func loadSelectedPhotos(_ photos: [PhotosPickerItem]) {
        guard !photos.isEmpty else { return }

        let remainingSlots = max(0, 3 - imageDataArray.count)
        guard remainingSlots > 0 else {
            logger.warning("⚠️ Photo limit reached (3/3)")
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
                // Filter duplicates
                let uniquePhotos = newImageData.filter { newData in
                    !imageDataArray.contains(newData)
                }

                // Enforce limit
                let currentRemaining = max(0, 3 - imageDataArray.count)
                let photosToAdd = Array(uniquePhotos.prefix(currentRemaining))

                imageDataArray.append(contentsOf: photosToAdd)
                selectedPhotos = []
                isLoadingImages = false

                logger.debug("✅ Photos added: \(photosToAdd.count), Total: \(imageDataArray.count)/3")
            }
        }
    }
}

// MARK: - Modern TextField Style

struct ModernTextFieldStyle: TextFieldStyle {
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

#Preview {
    NavigationStack {
        CreateProductView()
    }
}
