//
//  ModernAddProductView.swift
//  Lopan
//
//  Created by Claude on 2025/8/19.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ModernAddProductView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Form Data
    @State private var productName = ""
    @State private var colors: [String] = []
    @State private var newColor = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var sizes: [String] = []
    @State private var newSize = ""
    @State private var productDescription = ""
    
    // Step Management
    @State private var currentStep: CreationStep = .basicInfo
    @State private var completedSteps: Set<CreationStep> = []
    @State private var isValidatingStep = false
    
    // Smart Input
    @State private var colorSuggestions: [String] = []
    @State private var sizeSuggestions: [String] = []
    @State private var isShowingColorPicker = false
    @State private var customColor = LopanColors.primary
    @State private var isDraftSaved = false
    @State private var lastAutoSave = Date()
    
    // Validation
    @State private var validationErrors: [ValidationError] = []
    @State private var showingValidationAlert = false
    
    enum CreationStep: Int, CaseIterable {
        case basicInfo = 0
        case visualAssets = 1
        case specifications = 2
        case review = 3
        
        var title: String {
            switch self {
            case .basicInfo: return "基本信息"
            case .visualAssets: return "视觉资产"
            case .specifications: return "规格详情"
            case .review: return "确认创建"
            }
        }
        
        var subtitle: String {
            switch self {
            case .basicInfo: return "产品名称和分类"
            case .visualAssets: return "图片和颜色"
            case .specifications: return "尺寸和描述"
            case .review: return "最终确认"
            }
        }
        
        var icon: String {
            switch self {
            case .basicInfo: return "info.circle"
            case .visualAssets: return "photo"
            case .specifications: return "ruler"
            case .review: return "checkmark.seal"
            }
        }
    }
    
    
    struct ValidationError: Identifiable {
        let id = UUID()
        let field: String
        let message: String
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Header
                progressHeaderView
                
                // Step Content
                stepContentView
                
                // Navigation Footer
                navigationFooterView
            }
            .background(LopanColors.background)
            .navigationTitle("创建产品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        handleCancel()
                    }
                    .foregroundColor(LopanColors.textSecondary)
                }
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        imageData = data
                        autoSave()
                    }
                }
            }
            .onChange(of: productName) { _, _ in autoSave() }
            .onChange(of: colors) { _, _ in autoSave() }
            .onChange(of: sizes) { _, _ in autoSave() }
            .onAppear {
                updateSuggestions()
            }
            .sheet(isPresented: $isShowingColorPicker) {
                colorPickerSheet
            }
            .alert("验证错误", isPresented: $showingValidationAlert) {
                Button("确定") { }
            } message: {
                Text(validationErrors.map { $0.message }.joined(separator: "\n"))
            }
        }
    }
    
    // MARK: - Progress Header
    
    private var progressHeaderView: some View {
        VStack(spacing: 16) {
            // Step Indicator
            HStack {
                ForEach(CreationStep.allCases, id: \.self) { step in
                    stepIndicator(for: step)
                    
                    if step != CreationStep.allCases.last {
                        stepConnector(for: step)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Current Step Info
            VStack(spacing: 4) {
                Text(currentStep.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(LopanColors.textPrimary)
                
                Text(currentStep.subtitle)
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
        .padding(.vertical, 20)
        .background(LopanColors.backgroundSecondary)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.border),
            alignment: .bottom
        )
    }
    
    private func stepIndicator(for step: CreationStep) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(stepIndicatorBackground(for: step))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().stroke(stepIndicatorBorder(for: step), lineWidth: 2)
                    )
                
                if completedSteps.contains(step) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LopanColors.textPrimary)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(stepIndicatorIconColor(for: step))
                }
            }
            .scaleEffect(step == currentStep ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentStep)
            
            Text("\(step.rawValue + 1)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(step == currentStep ? LopanColors.primary : LopanColors.textTertiary)
        }
    }
    
    private func stepConnector(for step: CreationStep) -> some View {
        Rectangle()
            .fill(completedSteps.contains(step) ? LopanColors.primary : LopanColors.border)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.3), value: completedSteps)
    }
    
    private func stepIndicatorBackground(for step: CreationStep) -> Color {
        if completedSteps.contains(step) {
            return LopanColors.primary
        } else if step == currentStep {
            return LopanColors.primary.opacity(0.1)
        } else {
            return LopanColors.backgroundSecondary
        }
    }
    
    private func stepIndicatorBorder(for step: CreationStep) -> Color {
        if completedSteps.contains(step) || step == currentStep {
            return LopanColors.primary
        } else {
            return LopanColors.border
        }
    }
    
    private func stepIndicatorIconColor(for step: CreationStep) -> Color {
        if step == currentStep {
            return LopanColors.primary
        } else {
            return LopanColors.textTertiary
        }
    }
    
    // MARK: - Step Content View
    
    private var stepContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                switch currentStep {
                case .basicInfo:
                    basicInfoStepView
                case .visualAssets:
                    visualAssetsStepView
                case .specifications:
                    specificationsStepView
                case .review:
                    reviewStepView
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    
    // MARK: - Basic Info Step
    
    private var basicInfoStepView: some View {
        VStack(spacing: 24) {
            formCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("产品名称", "为您的产品起一个吸引人的名称")
                    
                    validatedTextField(
                        text: $productName,
                        placeholder: "例如：iPhone 15 Pro Max",
                        validation: validateProductName
                    )
                }
            }
            
            if !productName.isEmpty {
                duplicateCheckView
            }
        }
    }
    
    
    private var duplicateCheckView: some View {
        formCard {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(LopanColors.warning)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("重复检查")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    Text("我们发现可能存在相似的产品名称，请确认这是一个新产品")
                        .font(.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(LopanColors.warning.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Visual Assets Step
    
    private var visualAssetsStepView: some View {
        VStack(spacing: 24) {
            formCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("产品图片", "添加高质量的产品图片")
                    
                    imageUploadView
                }
            }
            
            formCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("产品颜色", "添加可用的颜色选项")
                    
                    colorInputView
                    colorSuggestionsView
                    selectedColorsView
                }
            }
        }
    }
    
    private var imageUploadView: some View {
        VStack(spacing: 16) {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                VStack(spacing: 12) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LopanColors.border, lineWidth: 0.5)
                        )
                    
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            Label("更换图片", systemImage: "photo.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("移除图片") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                self.imageData = nil
                                selectedImage = nil
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(LopanColors.error)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(LopanColors.textTertiary)
                        
                        VStack(spacing: 4) {
                            Text("添加产品图片")
                                .font(.headline)
                                .foregroundColor(LopanColors.textPrimary)
                            
                            Text("支持 JPG、PNG 格式，建议分辨率 1080x1080")
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(LopanColors.backgroundTertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LopanColors.border, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        Label("选择图片", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private var colorInputView: some View {
        HStack(spacing: 12) {
            HStack {
                TextField("输入颜色名称", text: $newColor)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(LopanColors.backgroundSecondary)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(LopanColors.border, lineWidth: 0.5)
                    )
                
                Button("添加") {
                    addColor()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newColor.isEmpty)
            }
            
            Button(action: { isShowingColorPicker = true }) {
                Image(systemName: "eyedropper")
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(width: 44, height: 44)
            .background(LopanColors.backgroundSecondary)
            .foregroundColor(LopanColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private var colorSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("常用颜色")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textSecondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(colorSuggestions, id: \.self) { suggestion in
                    colorSuggestionButton(suggestion)
                }
            }
        }
    }
    
    private func colorSuggestionButton(_ color: String) -> some View {
        Button(action: {
            if !colors.contains(color) {
                LopanHapticEngine.shared.light()
                colors.append(color)
            }
        }) {
            Text(color)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(colors.contains(color) ? LopanColors.textTertiary : LopanColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colors.contains(color) ? LopanColors.backgroundTertiary : LopanColors.backgroundSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(colors.contains(color) ? LopanColors.border : LopanColors.clear, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(colors.contains(color))
    }
    
    private var selectedColorsView: some View {
        Group {
            if !colors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已选颜色")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(LopanColors.textSecondary)
                    
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
                                        .font(.caption)
                                        .foregroundColor(LopanColors.error)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Specifications Step
    
    private var specificationsStepView: some View {
        VStack(spacing: 24) {
            formCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("产品尺寸", "添加可用的尺寸规格")
                    
                    sizeInputView
                    sizeSuggestionsView
                    selectedSizesView
                }
            }
            
            formCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("产品描述", "详细描述产品特点（可选）")
                    
                    TextEditor(text: $productDescription)
                        .font(.body)
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(LopanColors.backgroundSecondary)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(LopanColors.border, lineWidth: 0.5)
                        )
                }
            }
        }
    }
    
    private var sizeInputView: some View {
        HStack {
            TextField("输入尺寸", text: $newSize)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(LopanColors.backgroundSecondary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LopanColors.border, lineWidth: 0.5)
                )
            
            Button("添加") {
                addSize()
            }
            .buttonStyle(.borderedProminent)
            .disabled(newSize.isEmpty)
        }
    }
    
    private var sizeSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("推荐尺寸")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textSecondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(sizeSuggestions, id: \.self) { suggestion in
                    sizeSuggestionButton(suggestion)
                }
            }
        }
    }
    
    private func sizeSuggestionButton(_ size: String) -> some View {
        Button(action: {
            if !sizes.contains(size) {
                LopanHapticEngine.shared.light()
                sizes.append(size)
            }
        }) {
            Text(size)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(sizes.contains(size) ? LopanColors.textTertiary : LopanColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(sizes.contains(size) ? LopanColors.backgroundTertiary : LopanColors.backgroundSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(sizes.contains(size) ? LopanColors.border : LopanColors.clear, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(sizes.contains(size))
    }
    
    private var selectedSizesView: some View {
        Group {
            if !sizes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已选尺寸")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(LopanColors.textSecondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(sizes, id: \.self) { size in
                            HStack(spacing: 6) {
                                LopanBadge(size, style: .secondary, size: .medium)
                                
                                Button(action: {
                                    removeSize(size)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(LopanColors.error)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Review Step
    
    private var reviewStepView: some View {
        VStack(spacing: 24) {
            formCard {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("确认产品信息", "请检查所有信息是否正确")
                    
                    ProductSummaryCard(
                        name: productName,
                        colors: colors,
                        sizes: sizes,
                        imageData: imageData,
                        description: productDescription
                    )
                }
            }
        }
    }
    
    // MARK: - Utility Components
    
    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(LopanColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: LopanColors.shadow, radius: 2, x: 0, y: 1)
    }
    
    private func sectionHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(LopanColors.textPrimary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)
        }
    }
    
    private func validatedTextField(text: Binding<String>, placeholder: String, validation: @escaping (String) -> String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(placeholder, text: text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(LopanColors.backgroundSecondary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(validation(text.wrappedValue) != nil ? LopanColors.error : LopanColors.border, lineWidth: 0.5)
                )
            
            if let error = validation(text.wrappedValue) {
                Text(error)
                    .font(.caption)
                    .foregroundColor(LopanColors.error)
            }
        }
    }
    
    // MARK: - Navigation Footer
    
    private var navigationFooterView: some View {
        HStack {
            if currentStep != .basicInfo {
                Button("上一步") {
                    goToPreviousStep()
                }
                .buttonStyle(.bordered)
                .foregroundColor(LopanColors.textSecondary)
            }
            
            Spacer()
            
            Button(currentStep == .review ? "创建产品" : "下一步") {
                if currentStep == .review {
                    createProduct()
                } else {
                    proceedToNextStep()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canProceed)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(LopanColors.backgroundSecondary)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(LopanColors.border),
            alignment: .top
        )
    }
    
    // MARK: - Color Picker Sheet
    
    private var colorPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ColorPicker("选择颜色", selection: $customColor)
                    .labelsHidden()
                    .scaleEffect(2.0)
                    .frame(height: 200)
                
                Button("添加颜色") {
                    let colorName = colorToString(customColor)
                    if !colors.contains(colorName) {
                        colors.append(colorName)
                    }
                    isShowingColorPicker = false
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("自定义颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isShowingColorPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Computed Properties
    
    private var canProceed: Bool {
        switch currentStep {
        case .basicInfo:
            return !productName.isEmpty && validateProductName(productName) == nil
        case .visualAssets:
            return !colors.isEmpty
        case .specifications:
            return true // Optional step
        case .review:
            return !productName.isEmpty && !colors.isEmpty
        }
    }
    
    // MARK: - Actions
    
    private func handleCancel() {
        dismiss()
    }
    
    private func proceedToNextStep() {
        guard canProceed else { return }
        
        completedSteps.insert(currentStep)
        
        if let nextStep = CreationStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = nextStep
            }
        }
        
        autoSave()
    }
    
    private func goToPreviousStep() {
        if let previousStep = CreationStep(rawValue: currentStep.rawValue - 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = previousStep
            }
        }
    }
    
    private func createProduct() {
        let product = Product(name: productName, colors: colors, imageData: imageData)
        
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
            NotificationCenter.default.post(name: .productAdded, object: product)
            dismiss()
        } catch {
            print("Failed to save product: \(error)")
        }
    }
    
    private func updateSuggestions() {
        colorSuggestions = ["黑色", "白色", "灰色", "蓝色", "红色", "绿色", "黄色", "粉色", "紫色", "橙色", "棕色", "米色"]
        sizeSuggestions = ["XS", "S", "M", "L", "XL", "XXL", "XXXL", "均码"]
    }
    
    private func autoSave() {
        isDraftSaved = true
        lastAutoSave = Date()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isDraftSaved = false
        }
    }
    
    private func validateProductName(_ name: String) -> String? {
        if name.isEmpty {
            return "产品名称不能为空"
        }
        if name.count < 2 {
            return "产品名称至少需要2个字符"
        }
        if name.count > 50 {
            return "产品名称不能超过50个字符"
        }
        return nil
    }
    
    private func colorToString(_ color: Color) -> String {
        return "自定义颜色"
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
}

// MARK: - Product Summary Card

struct ProductSummaryCard: View {
    let name: String
    let colors: [String]
    let sizes: [String]
    let imageData: Data?
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Product Image
                Group {
                    if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LopanColors.backgroundTertiary)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(LopanColors.textTertiary)
                            )
                    }
                }
                
                // Product Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    
                    if !colors.isEmpty {
                        HStack {
                            Text("颜色:")
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                            Text(colors.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(LopanColors.textPrimary)
                        }
                    }
                    
                    if !sizes.isEmpty {
                        HStack {
                            Text("尺寸:")
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                            Text(sizes.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(LopanColors.textPrimary)
                        }
                    }
                }
                
                Spacer()
            }
            
            if !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("描述")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(LopanColors.textSecondary)
                    
                    Text(description)
                        .font(.body)
                        .foregroundColor(LopanColors.textPrimary)
                }
            }
        }
        .padding(16)
        .background(LopanColors.backgroundSecondary)
        .cornerRadius(12)
    }
}

#Preview {
    ModernAddProductView()
        .modelContainer(for: [Product.self, ProductSize.self], inMemory: true)
}