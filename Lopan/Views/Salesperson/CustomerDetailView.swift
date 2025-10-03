//
//  CustomerDetailView.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import SwiftData

struct CustomerDetailView: View {
    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.dismiss) private var dismiss
    let customer: Customer

    private var customerRepository: CustomerRepository {
        appDependencies.serviceFactory.repositoryFactory.customerRepository
    }

    private var customerOutOfStockRepository: CustomerOutOfStockRepository {
        appDependencies.serviceFactory.repositoryFactory.customerOutOfStockRepository
    }

    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    @State private var recentOutOfStockItems: [CustomerOutOfStock] = []
    @State private var isLoadingOutOfStock = true
    @State private var isEditMode = false
    @State private var showingImagePicker = false
    @State private var selectedAvatarImage: UIImage?
    @State private var showingColorPicker = false
    @State private var editedName: String = ""
    @State private var editedAddress: String = ""
    @State private var editedPhone: String = ""
    @State private var editedWhatsappNumber: String = ""
    @State private var selectedAvatarColor: Color?
    @State private var hasUnsavedChanges: Bool = false
    @State private var showingUnsavedChangesAlert: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: LopanSpacing.xl) {
                // Centered Profile Section
                profileSection

                // Contact Card
                contactCard

                // Out of Stock Card - only show in normal mode
                if !isEditMode {
                    outOfStockOverviewCard
                }
            }
            .screenPadding()
        }
        .navigationTitle("Customer Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(LopanColors.backgroundPrimary)
        .navigationBarBackButtonHidden(isEditMode)
        .toolbar {
            if isEditMode {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        handleCancelTapped()
                    }
                    .confirmationDialog("Unsaved Changes", isPresented: $showingUnsavedChangesAlert, titleVisibility: .visible) {
                        Button("Discard", role: .destructive) {
                            discardChanges()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("You have unsaved changes. Do you want to save them?")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        enterEditMode()
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedAvatarImage)
        }
        .sheet(isPresented: $showingColorPicker) {
            AvatarColorPickerView(selectedColor: $selectedAvatarColor)
        }
        .onChange(of: selectedAvatarImage) { _, newImage in
            if let image = newImage {
                saveAvatarImage(image)
                hasUnsavedChanges = true
            }
        }
        .onChange(of: editedName) { _, _ in
            if isEditMode { checkForUnsavedChanges() }
        }
        .onChange(of: editedAddress) { _, _ in
            if isEditMode { checkForUnsavedChanges() }
        }
        .onChange(of: editedPhone) { _, _ in
            if isEditMode { checkForUnsavedChanges() }
        }
        .onChange(of: editedWhatsappNumber) { _, _ in
            if isEditMode { checkForUnsavedChanges() }
        }
        .onChange(of: selectedAvatarColor) { _, _ in
            if isEditMode { hasUnsavedChanges = true }
        }
        .onAppear {
            loadRecentOutOfStockRecords()
        }
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: LopanSpacing.md) {
            // Large centered avatar
            Group {
                if isEditMode {
                    // Edit mode: Avatar tappable for color picker
                    Button(action: {
                        showingColorPicker = true
                    }) {
                        avatarView
                    }
                    .buttonStyle(.plain)
                } else {
                    // Normal mode: Avatar not tappable
                    avatarView
                }
            }

            // "Add photo" button - only visible in edit mode
            if isEditMode {
                Button(action: {
                    showingImagePicker = true
                }) {
                    Text("Add photo")
                        .font(LopanTypography.bodyMedium)
                        .foregroundColor(LopanColors.primary)
                }
            }

            // Customer name (editable in edit mode)
            if isEditMode {
                TextField("Name", text: $editedName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(LopanColors.textPrimary)
                    .multilineTextAlignment(.center)
            } else {
                Text(customer.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(LopanColors.textPrimary)
            }

            // Customer address (editable in edit mode)
            if isEditMode {
                TextField("Address", text: $editedAddress)
                    .font(LopanTypography.bodyMedium)
                    .foregroundColor(LopanColors.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(customer.address)
                    .font(LopanTypography.bodyMedium)
                    .foregroundColor(LopanColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarView: some View {
        CustomerAvatarView(customer: customer, size: 128, overrideColor: selectedAvatarColor)
    }

    // MARK: - Contact Card
    private var contactCard: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            Text("Contact")
                .font(LopanTypography.titleMedium)
                .foregroundColor(LopanColors.textSecondary)
                .lopanPaddingHorizontal(LopanSpacing.xs)

            VStack(spacing: 0) {
                if isEditMode {
                    // Edit mode: Show text fields
                    EditableContactRow(
                        icon: "phone",
                        iconColor: LopanColors.primary,
                        label: "Phone",
                        text: $editedPhone
                    )

                    Divider()
                        .background(LopanColors.border)

                    EditableContactRow(
                        icon: "message",
                        iconColor: Color.green,
                        label: "WhatsApp",
                        text: $editedWhatsappNumber
                    )
                } else {
                    // Normal mode: Show read-only with tap actions
                    ContactRow(
                        icon: "phone",
                        iconColor: LopanColors.primary,
                        label: "Phone",
                        value: customer.phone.isEmpty ? "未设置" : customer.phone,
                        action: customer.phone.isEmpty ? nil : { callCustomer() }
                    )

                    Divider()
                        .background(LopanColors.border)

                    ContactRow(
                        icon: "message",
                        iconColor: Color.green,
                        label: "WhatsApp",
                        value: customer.whatsappNumber.isEmpty ? "未设置" : customer.whatsappNumber,
                        action: customer.whatsappNumber.isEmpty ? nil : { openWhatsApp() }
                    )
                }
            }
            .background(LopanColors.surface)
            .cornerRadius(LopanSpacing.md)
            .shadow(color: LopanColors.shadow, radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Out of Stock Card
    private var outOfStockOverviewCard: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            Text("Out of Stock (Last 7 Days)")
                .font(LopanTypography.titleMedium)
                .foregroundColor(LopanColors.textSecondary)
                .lopanPaddingHorizontal(LopanSpacing.xs)

            VStack(spacing: 0) {
                if isLoadingOutOfStock {
                    VStack(spacing: LopanSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在加载...")
                            .font(LopanTypography.bodySmall)
                            .foregroundColor(LopanColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .lopanPaddingVertical(LopanSpacing.xl)
                } else if recentOutOfStockItems.isEmpty {
                    VStack(spacing: LopanSpacing.md) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 32))
                            .foregroundColor(LopanColors.success)

                        Text("最近7天暂无缺货记录")
                            .font(LopanTypography.bodyMedium)
                            .foregroundColor(LopanColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .lopanPaddingVertical(LopanSpacing.xl)
                } else {
                    ForEach(Array(recentOutOfStockItems.prefix(3).enumerated()), id: \.element.id) { index, item in
                        ProductOutOfStockRow(item: item)

                        if index < min(2, recentOutOfStockItems.count - 1) {
                            Divider()
                                .background(LopanColors.border)
                        }
                    }
                }
            }
            .background(LopanColors.surface)
            .cornerRadius(LopanSpacing.md)
            .shadow(color: LopanColors.shadow, radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Helper Methods

    // Edit Mode Management
    private func enterEditMode() {
        editedName = customer.name
        editedAddress = customer.address
        editedPhone = customer.phone
        editedWhatsappNumber = customer.whatsappNumber
        selectedAvatarColor = customer.avatarBackgroundColor != nil ? Color(hex: customer.avatarBackgroundColor!) : nil
        hasUnsavedChanges = false
        isEditMode = true
    }

    private func handleCancelTapped() {
        if hasUnsavedChanges {
            showingUnsavedChangesAlert = true
        } else {
            discardChanges()
        }
    }

    private func discardChanges() {
        isEditMode = false
        hasUnsavedChanges = false
        selectedAvatarImage = nil
        selectedAvatarColor = nil
        // Restore avatar if image was changed but not saved
        if let originalColor = customer.avatarBackgroundColor {
            selectedAvatarColor = Color(hex: originalColor)
        }
    }

    private func checkForUnsavedChanges() {
        hasUnsavedChanges =
            editedName != customer.name ||
            editedAddress != customer.address ||
            editedPhone != customer.phone ||
            editedWhatsappNumber != customer.whatsappNumber ||
            selectedAvatarColor != nil
    }

    private func saveChanges() {
        Task {
            customer.name = editedName
            customer.address = editedAddress
            customer.phone = editedPhone
            customer.whatsappNumber = editedWhatsappNumber

            if let color = selectedAvatarColor {
                customer.avatarBackgroundColor = color.toHex()
                // Clear photo when color is selected to allow color to display
                customer.avatarImageData = nil
            }

            customer.updatedAt = Date()
            customer.updatePinyinCache()

            do {
                try await customerRepository.updateCustomer(customer)
                await MainActor.run {
                    isEditMode = false
                    hasUnsavedChanges = false
                    selectedAvatarColor = nil
                }
            } catch {
                print("Failed to save customer changes: \(error)")
            }
        }
    }

    // Contact Actions
    private func callCustomer() {
        guard !customer.phone.isEmpty,
              let url = URL(string: "tel://\(customer.phone)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func openWhatsApp() {
        guard !customer.whatsappNumber.isEmpty,
              let url = URL(string: "whatsapp://send?phone=\(customer.whatsappNumber)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    // Avatar Management
    private func saveAvatarImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        customer.avatarImageData = imageData
        selectedAvatarImage = nil
    }

    private func loadRecentOutOfStockRecords() {
        Task {
            isLoadingOutOfStock = true
            
            do {
                // Fetch all records for this customer
                let allRecords = try await customerOutOfStockRepository.fetchOutOfStockRecords(for: customer)
                
                // Filter to last 7 days only and sort by most recent first
                let filteredRecords = allRecords
                    .filter { $0.requestDate >= sevenDaysAgo }
                    .sorted { $0.requestDate > $1.requestDate }
                
                await MainActor.run {
                    recentOutOfStockItems = filteredRecords
                    isLoadingOutOfStock = false
                }
            } catch {
                await MainActor.run {
                    isLoadingOutOfStock = false
                    print("Failed to load out-of-stock records: \(error)")
                }
            }
        }
    }
}

// MARK: - Supporting Views

/// Contact row component with circular icon background (read-only)
struct ContactRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let action: (() -> Void)?

    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: LopanSpacing.md) {
                // Circular icon background
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(iconColor)
                    }

                // Label and value
                VStack(alignment: .leading, spacing: LopanSpacing.xxs) {
                    Text(label)
                        .font(LopanTypography.bodyMedium)
                        .foregroundColor(LopanColors.textPrimary)

                    Text(value)
                        .font(LopanTypography.bodySmall)
                        .foregroundColor(LopanColors.textSecondary)
                }

                Spacer()
            }
            .lopanPadding(LopanSpacing.md)
        }
        .disabled(action == nil)
    }
}

/// Editable contact row component for edit mode
struct EditableContactRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: LopanSpacing.md) {
            // Circular icon background
            Circle()
                .fill(iconColor.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }

            // Label and editable text field
            VStack(alignment: .leading, spacing: LopanSpacing.xxs) {
                Text(label)
                    .font(LopanTypography.bodyMedium)
                    .foregroundColor(LopanColors.textPrimary)

                TextField("未设置", text: $text)
                    .font(LopanTypography.bodySmall)
                    .foregroundColor(LopanColors.textSecondary)
                    .keyboardType(icon == "phone" ? .phonePad : .default)
            }

            Spacer()
        }
        .lopanPadding(LopanSpacing.md)
    }
}

/// Product out of stock row with product image
struct ProductOutOfStockRow: View {
    let item: CustomerOutOfStock

    var body: some View {
        HStack(spacing: LopanSpacing.md) {
            // Product image
            Group {
                if let product = item.product,
                   let imageData = product.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: LopanSpacing.xs)
                        .fill(LopanColors.primary.opacity(0.1))
                        .overlay {
                            Image(systemName: "cube.box")
                                .foregroundColor(LopanColors.primary)
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: LopanSpacing.xs))

            // Product name
            Text(item.product?.name ?? "未知产品")
                .font(LopanTypography.bodyMedium)
                .foregroundColor(LopanColors.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .lopanPadding(LopanSpacing.sm)
    }
}

struct EditCustomerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var appDependencies
    let customer: Customer

    private var customerRepository: CustomerRepository {
        appDependencies.serviceFactory.repositoryFactory.customerRepository
    }

    @State private var name: String
    @State private var address: String
    @State private var phone: String
    @State private var whatsappNumber: String
    @State private var isSaving = false
    @State private var isCheckingDuplicate = false
    @State private var duplicateError: String?

    init(customer: Customer) {
        self.customer = customer
        self._name = State(initialValue: customer.name)
        self._address = State(initialValue: customer.address)
        self._phone = State(initialValue: customer.phone)
        self._whatsappNumber = State(initialValue: customer.whatsappNumber)
    }

    var isValid: Bool {
        !name.isEmpty && !address.isEmpty && duplicateError == nil && !isCheckingDuplicate
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: LopanSpacing.lg) {
                Text("客户信息")
                    .font(LopanTypography.headlineSmall)
                    .foregroundColor(LopanColors.textPrimary)
                
                VStack(spacing: LopanSpacing.md) {
                    LopanTextField(
                        title: "客户姓名",
                        placeholder: "请输入客户姓名",
                        text: $name,
                        variant: .outline,
                        state: {
                            if duplicateError != nil {
                                return .error
                            } else if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                return .error
                            } else {
                                return .normal
                            }
                        }(),
                        isRequired: true,
                        icon: "person",
                        errorText: duplicateError ?? (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "客户姓名不能为空" : nil)
                    )
                    .onChange(of: name) { _, newValue in
                        Task {
                            await checkForDuplicates()
                        }
                    }
                    .disabled(isSaving)

                    LopanTextField(
                        title: "客户地址",
                        placeholder: "请输入客户地址",
                        text: $address,
                        variant: .outline,
                        state: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .error : .normal,
                        isRequired: true,
                        icon: "location",
                        errorText: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "客户地址不能为空" : nil
                    )
                    .disabled(isSaving)

                    LopanTextField(
                        title: "联系电话",
                        placeholder: "请输入联系电话（可选）",
                        text: $phone,
                        variant: .outline,
                        keyboardType: .phonePad,
                        icon: "phone",
                        helperText: "联系电话为可选信息"
                    )
                    .disabled(isSaving)

                    LopanTextField(
                        title: "WhatsApp号码",
                        placeholder: "请输入WhatsApp号码（可选）",
                        text: $whatsappNumber,
                        variant: .outline,
                        keyboardType: .phonePad,
                        icon: "message",
                        helperText: "WhatsApp号码为可选信息"
                    )
                    .disabled(isSaving)
                }
                
                Spacer()
            }
            .screenPadding()
            .navigationTitle("编辑客户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCustomer()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }
    
    private func checkForDuplicates() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            duplicateError = nil
            return
        }

        // Skip check if name unchanged from original
        if trimmedName == customer.name.trimmingCharacters(in: .whitespacesAndNewlines) {
            duplicateError = nil
            return
        }

        isCheckingDuplicate = true
        do {
            let hasDuplicate = try await customerRepository.checkDuplicateName(trimmedName, excludingId: customer.id)
            await MainActor.run {
                duplicateError = hasDuplicate ? "客户姓名已存在，请使用其他姓名" : nil
                isCheckingDuplicate = false
            }
        } catch {
            await MainActor.run {
                duplicateError = nil
                isCheckingDuplicate = false
            }
        }
    }

    private func saveCustomer() {
        isSaving = true

        customer.name = name
        customer.address = address
        customer.phone = phone
        customer.whatsappNumber = whatsappNumber
        customer.updatedAt = Date()

        // Update cached pinyin values if name changed
        customer.updatePinyinCache()

        Task {
            do {
                try await customerRepository.updateCustomer(customer)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("Error saving customer: \(error)")
                }
            }
        }
    }
}

/// Avatar color picker view for selecting background color
struct AvatarColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: Color?
    @State private var showingCustomColorPicker = false
    @State private var customColor: Color = .blue

    private let colors: [Color] = [
        Color(red: 0.0, green: 0.5, blue: 1.0),      // Blue
        Color(red: 0.0, green: 0.8, blue: 0.6),      // Teal
        Color(red: 0.6, green: 0.0, blue: 0.8),      // Purple
        Color(red: 1.0, green: 0.6, blue: 0.0),      // Orange
        Color(red: 0.9, green: 0.0, blue: 0.0),      // Red
        Color(red: 0.0, green: 0.7, blue: 0.0),      // Green
        Color(red: 1.0, green: 0.8, blue: 0.2),      // Yellow
        Color(red: 0.5, green: 0.5, blue: 0.5),      // Gray
        Color(red: 0.2, green: 0.4, blue: 0.9),      // Indigo
        Color(red: 0.9, green: 0.2, blue: 0.4),      // Pink
        Color(red: 0.3, green: 0.0, blue: 0.8),      // Deep Purple
        Color(red: 0.0, green: 0.4, blue: 0.8),      // Sky Blue
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: LopanSpacing.lg) {
                Text("选择头像颜色")
                    .font(LopanTypography.titleLarge)
                    .foregroundColor(LopanColors.textPrimary)
                    .lopanPaddingVertical(LopanSpacing.md)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: LopanSpacing.md) {
                    ForEach(colors, id: \.self) { color in
                        Button(action: {
                            selectedColor = color
                            dismiss()
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 60, height: 60)
                                .overlay {
                                    if let selected = selectedColor, selected.toHex() == color.toHex() {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                        }
                    }
                }
                .lopanPadding(LopanSpacing.md)

                // Custom Color Picker Button
                Button(action: {
                    showingCustomColorPicker = true
                }) {
                    HStack {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 20))
                        Text("Custom Color")
                            .font(LopanTypography.bodyMedium)
                    }
                    .foregroundColor(LopanColors.primary)
                    .lopanPadding(LopanSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(LopanColors.primary.opacity(0.1))
                    .cornerRadius(LopanSpacing.md)
                }
                .lopanPaddingHorizontal(LopanSpacing.lg)

                Spacer()
            }
            .screenPadding()
            .navigationTitle("Avatar Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCustomColorPicker) {
                CustomColorPickerSheet(selectedColor: $selectedColor, customColor: $customColor)
            }
        }
    }
}

/// Custom color picker sheet using native ColorPicker
struct CustomColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: Color?
    @Binding var customColor: Color

    var body: some View {
        NavigationStack {
            VStack(spacing: LopanSpacing.xl) {
                Text("选择自定义颜色")
                    .font(LopanTypography.titleLarge)
                    .foregroundColor(LopanColors.textPrimary)
                    .lopanPaddingVertical(LopanSpacing.md)

                // Preview circle
                Circle()
                    .fill(customColor)
                    .frame(width: 100, height: 100)
                    .shadow(color: customColor.opacity(0.3), radius: 10)

                // Native color picker
                ColorPicker("Select Color", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(height: 200)

                Spacer()

                // Done button
                Button(action: {
                    selectedColor = customColor
                    dismiss()
                }) {
                    Text("Done")
                        .font(LopanTypography.bodyLarge)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .lopanPadding(LopanSpacing.md)
                        .background(LopanColors.primary)
                        .cornerRadius(LopanSpacing.md)
                }
                .lopanPaddingHorizontal(LopanSpacing.lg)
            }
            .screenPadding()
            .navigationTitle("Custom Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let customer = Customer(name: "张三", address: "北京市朝阳区", phone: "13800138000")

    CustomerDetailView(customer: customer)
        .modelContainer(for: Customer.self, inMemory: true)
}
