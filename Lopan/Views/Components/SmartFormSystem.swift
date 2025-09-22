//
//  SmartFormSystem.swift
//  Lopan
//
//  Created by Claude Code - Perfectionist UI/UX Design
//  智能表单系统 - 完美主义设计师的交互艺术巅峰
//

import SwiftUI
import Combine

// MARK: - 智能表单系统主组件
/// 自适应表单系统，每个输入字段都经过精心设计的用户体验
struct SmartFormSystem: View {
    
    // MARK: - Properties
    @StateObject private var formEngine = FormEngine()
    @StateObject private var validationEngine = ValidationEngine()
    @StateObject private var adaptiveEngine = AdaptiveFormEngine()
    
    @Binding var formData: FormData
    @Binding var isFormValid: Bool
    
    let formConfiguration: FormConfiguration
    let onFormSubmit: (FormData) -> Void
    let onFormCancel: () -> Void
    
    // MARK: - State Management
    @State private var currentStep = 0
    @State private var showingValidationSummary = false
    @State private var isFormSubmitting = false
    @State private var formProgress: Double = 0.0
    @State private var showingSmartSuggestions = false
    @State private var keyboardHeight: CGFloat = 0
    
    // MARK: - Focus Management
    @FocusState private var focusedField: FormField.ID?
    
    init(
        formData: Binding<FormData>,
        isValid: Binding<Bool>,
        configuration: FormConfiguration,
        onSubmit: @escaping (FormData) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._formData = formData
        self._isFormValid = isValid
        self.formConfiguration = configuration
        self.onFormSubmit = onSubmit
        self.onFormCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 主表单内容
                mainFormContent
                
                // 智能建议浮层
                if showingSmartSuggestions {
                    smartSuggestionsOverlay
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        ))
                        .zIndex(1)
                }
                
                // 加载状态覆盖层
                if isFormSubmitting {
                    submissionLoadingOverlay
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .navigationTitle(formConfiguration.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                formToolbar
            }
            .sheet(isPresented: $showingValidationSummary) {
                validationSummarySheet
            }
        }
        .onReceive(keyboardPublisher) { height in
            withAnimation(.easeInOut(duration: 0.3)) {
                keyboardHeight = height
            }
        }
        .onAppear {
            setupForm()
        }
        .onChange(of: formData) { _, newValue in
            validateAndUpdateProgress(newValue)
        }
        .onChange(of: focusedField) { _, newField in
            handleFieldFocus(newField)
        }
    }
    
    // MARK: - Main Form Content
    @ViewBuilder
    private var mainFormContent: some View {
        if formConfiguration.layout == .stepped {
            steppedFormContent
        } else {
            singlePageFormContent
        }
    }
    
    // MARK: - Stepped Form Content
    private var steppedFormContent: some View {
        VStack(spacing: 0) {
            // 步骤指示器
            if formConfiguration.steps.count > 1 {
                SteppedProgressIndicator(
                    currentStep: currentStep,
                    totalSteps: formConfiguration.steps.count,
                    stepTitles: formConfiguration.steps.map { $0.title },
                    progress: formProgress
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            // 当前步骤内容
            ScrollView {
                LazyVStack(spacing: 20) {
                    if currentStep < formConfiguration.steps.count {
                        let currentStepConfig = formConfiguration.steps[currentStep]
                        
                        ForEach(currentStepConfig.fields, id: \.id) { field in
                            SmartFormField(
                                field: field,
                                value: binding(for: field),
                                validationState: validationEngine.getValidationState(for: field.id),
                                isFocused: focusedField == field.id,
                                adaptiveHints: adaptiveEngine.getHints(for: field),
                                onFocusChanged: { isFocused in
                                    focusedField = isFocused ? field.id : nil
                                },
                                onValueChanged: { newValue in
                                    updateFieldValue(field: field, value: newValue)
                                }
                            )
                            .focused($focusedField, equals: field.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, keyboardHeight + 100)
            }
            
            Spacer()
            
            // 步骤导航控件
            stepNavigationControls
        }
    }
    
    // MARK: - Single Page Form Content
    private var singlePageFormContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // 表单进度指示器
                if formConfiguration.showProgress {
                    FormProgressBar(progress: formProgress)
                        .padding(.horizontal, 20)
                }
                
                // 表单字段组
                ForEach(formConfiguration.fieldGroups, id: \.id) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        if let title = group.title {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(LopanColors.textPrimary)
                        }
                        
                        if let description = group.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                        
                        // Placeholder for form fields
                        ForEach(group.fields, id: \.id) { field in
                            Text("Field: \(field.id)")
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, keyboardHeight + 100)
        }
        .overlay(alignment: .bottom) {
            singlePageActionButtons
        }
    }
    
    // MARK: - Step Navigation Controls
    private var stepNavigationControls: some View {
        HStack(spacing: 16) {
            // 上一步按钮
            if currentStep > 0 {
                Button(action: previousStep) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.callout)
                        Text("上一步")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(LopanColors.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            Spacer()
            
            // 下一步/完成按钮
            Button(action: nextStepOrSubmit) {
                HStack(spacing: 8) {
                    Text(isLastStep ? "完成" : "下一步")
                        .font(.callout)
                        .fontWeight(.medium)
                    
                    if !isLastStep {
                        Image(systemName: "chevron.right")
                            .font(.callout)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(canProceedToNextStep ? LopanColors.primary : Color.gray)
                )
            }
            .disabled(!canProceedToNextStep)
            .animation(.easeInOut(duration: 0.2), value: canProceedToNextStep)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
        )
    }
    
    // MARK: - Single Page Action Buttons
    private var singlePageActionButtons: some View {
        HStack(spacing: 12) {
            Button("取消", action: onFormCancel)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textSecondary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            
            Button(action: submitForm) {
                HStack(spacing: 8) {
                    if isFormSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    
                    Text(isFormSubmitting ? "提交中..." : "提交")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isFormValid ? LopanColors.primary : Color.gray)
                )
            }
            .disabled(!isFormValid || isFormSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
        )
    }
    
    // MARK: - Form Toolbar
    @ToolbarContentBuilder
    private var formToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("取消", action: onFormCancel)
                .font(.callout)
                .foregroundColor(LopanColors.textSecondary)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button(action: { showingValidationSummary = true }) {
                    Label("验证摘要", systemImage: "checkmark.circle")
                }
                
                Button(action: { showingSmartSuggestions.toggle() }) {
                    Label("智能建议", systemImage: "brain")
                }
                
                if formConfiguration.allowSaveAsDraft {
                    Button(action: saveAsDraft) {
                        Label("保存草稿", systemImage: "square.and.arrow.down")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(LopanColors.primary)
            }
        }
    }
    
    // MARK: - Smart Suggestions Overlay
    private var smartSuggestionsOverlay: some View {
        VStack {
            Spacer()
            
            SmartSuggestionsPanel(
                suggestions: adaptiveEngine.getCurrentSuggestions(),
                onSuggestionApplied: { suggestion in
                    applySuggestion(suggestion)
                },
                onDismiss: {
                    showingSmartSuggestions = false
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, keyboardHeight + 20)
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showingSmartSuggestions = false
                }
        )
    }
    
    // MARK: - Submission Loading Overlay
    private var submissionLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: LopanColors.primary))
                
                Text("正在提交表单...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("请稍候，系统正在处理您的信息")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            )
        }
    }
    
    // MARK: - Validation Summary Sheet
    private var validationSummarySheet: some View {
        NavigationStack {
            ValidationSummaryView(
                validationResults: validationEngine.getAllValidationResults(),
                onFieldSelected: { fieldId in
                    showingValidationSummary = false
                    focusedField = fieldId
                }
            )
            .navigationTitle("表单验证")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingValidationSummary = false
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var isLastStep: Bool {
        currentStep >= formConfiguration.steps.count - 1
    }
    
    private var canProceedToNextStep: Bool {
        if formConfiguration.layout == .stepped {
            let currentStepConfig = formConfiguration.steps[currentStep]
            return validationEngine.areFieldsValid(currentStepConfig.fields.map { $0.id })
        } else {
            return isFormValid
        }
    }
    
    // MARK: - Action Methods
    private func setupForm() {
        formEngine.configure(with: formConfiguration)
        validationEngine.setupValidation(for: formConfiguration)
        adaptiveEngine.initialize(with: formConfiguration, formData: formData)
        validateAndUpdateProgress(formData)
    }
    
    private func validateAndUpdateProgress(_ data: FormData) {
        validationEngine.validateAll(data) { isValid in
            DispatchQueue.main.async {
                self.isFormValid = isValid
                self.formProgress = self.calculateFormProgress()
            }
        }
    }
    
    private func calculateFormProgress() -> Double {
        let allFields = formConfiguration.getAllFields()
        let completedFields = allFields.filter { field in
            formData.hasValue(for: field.id) && validationEngine.isFieldValid(field.id)
        }
        
        return allFields.isEmpty ? 0.0 : Double(completedFields.count) / Double(allFields.count)
    }
    
    private func handleFieldFocus(_ fieldId: FormField.ID?) {
        guard let fieldId = fieldId else { return }
        
        // 自动滚动到聚焦字段
        adaptiveEngine.recordFieldFocus(fieldId)
        
        // 提供智能建议
        adaptiveEngine.updateSuggestionsForField(fieldId, currentData: formData)
        
        // 触觉反馈
        EnhancedHapticEngine.shared.perform(.cardTap)
    }
    
    private func updateFieldValue(field: FormField, value: Any) {
        formData.setValue(value, for: field.id)
        adaptiveEngine.recordFieldUpdate(field.id, value: value)
        
        // 实时验证
        validationEngine.validateField(field.id, value: value, in: formData)
    }
    
    private func previousStep() {
        guard currentStep > 0 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep -= 1
        }
        
        EnhancedHapticEngine.shared.perform(.cardTap)
    }
    
    private func nextStepOrSubmit() {
        if isLastStep {
            submitForm()
        } else {
            nextStep()
        }
    }
    
    private func nextStep() {
        guard canProceedToNextStep && !isLastStep else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
        
        // 记录步骤完成
        adaptiveEngine.recordStepCompletion(currentStep - 1)
        
        EnhancedHapticEngine.shared.perform(.customerUpdated)
    }
    
    private func submitForm() {
        guard isFormValid && !isFormSubmitting else { return }
        
        isFormSubmitting = true
        
        // 最终验证
        validationEngine.validateAll(formData) { isValid in
            DispatchQueue.main.async {
                if isValid {
                    // 记录表单提交
                    self.adaptiveEngine.recordFormSubmission()
                    
                    // 提交表单
                    self.onFormSubmit(self.formData)
                    
                    // 成功反馈
                    EnhancedHapticEngine.shared.perform(.formSaveSuccess)
                } else {
                    // 显示验证错误
                    self.showingValidationSummary = true
                    EnhancedHapticEngine.shared.perform(.formValidationError)
                }
                
                self.isFormSubmitting = false
            }
        }
    }
    
    private func saveAsDraft() {
        formEngine.saveAsDraft(formData)
        EnhancedHapticEngine.shared.perform(.customerUpdated)
    }
    
    private func applySuggestion(_ suggestion: FormSuggestion) {
        suggestion.apply(&formData)
        adaptiveEngine.recordSuggestionUsage(suggestion)
        
        EnhancedHapticEngine.shared.perform(.customerAdded)
        showingSmartSuggestions = false
    }
    
    // MARK: - Helper Methods
    private func binding(for field: FormField) -> Binding<Any> {
        Binding(
            get: { formData.getValue(for: field.id) ?? field.defaultValue },
            set: { newValue in updateFieldValue(field: field, value: newValue) }
        )
    }
    
    private var keyboardPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { notification in
                    (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height
                },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        )
        .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Views

/// 步骤进度指示器
struct SteppedProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitles: [String]
    let progress: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .clipShape(Capsule())
                    
                    Rectangle()
                        .fill(LopanColors.primary.gradient)
                        .frame(
                            width: geometry.size.width * CGFloat(Double(currentStep) / Double(max(1, totalSteps - 1))),
                            height: 4
                        )
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 4)
            
            // 步骤标题
            HStack {
                Text(stepTitles.indices.contains(currentStep) ? stepTitles[currentStep] : "")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(LopanColors.textPrimary)
                
                Spacer()
                
                Text("第 \(currentStep + 1) 步，共 \(totalSteps) 步")
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
            }
        }
    }
}

/// 表单进度条
struct FormProgressBar: View {
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("完成进度")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textSecondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.primary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: LopanColors.primary))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .padding(.vertical, 8)
    }
}

/// 智能表单字段
struct SmartFormField: View {
    let field: FormField
    @Binding var value: Any
    let validationState: ValidationState
    let isFocused: Bool
    let adaptiveHints: [String]
    let onFocusChanged: (Bool) -> Void
    let onValueChanged: (Any) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 字段标签
            fieldLabel
            
            // 字段输入控件
            fieldInput
            
            // 验证消息和提示
            fieldMessages
        }
        .padding(.vertical, 4)
    }
    
    private var fieldLabel: some View {
        HStack {
            Text(field.title)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(LopanColors.textPrimary)
            
            if field.isRequired {
                Text("*")
                    .font(.callout)
                    .foregroundColor(LopanColors.error)
            }
            
            Spacer()
            
            if !adaptiveHints.isEmpty {
                Button(action: {}) {
                    Image(systemName: "brain")
                        .font(.caption)
                        .foregroundColor(LopanColors.info)
                }
            }
        }
    }
    
    @ViewBuilder
    private var fieldInput: some View {
        switch field.type {
        case .text:
            TextField(field.placeholder, text: textBinding)
                .textFieldStyle(SmartTextFieldStyle(
                    isValid: validationState.isValid,
                    isFocused: isFocused
                ))
                .onReceive(Just(textBinding.wrappedValue)) { newValue in
                    onValueChanged(newValue)
                }
            
        case .email:
            TextField(field.placeholder, text: textBinding)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(SmartTextFieldStyle(
                    isValid: validationState.isValid,
                    isFocused: isFocused
                ))
            
        case .number:
            TextField(field.placeholder, text: textBinding)
                .keyboardType(.numberPad)
                .textFieldStyle(SmartTextFieldStyle(
                    isValid: validationState.isValid,
                    isFocused: isFocused
                ))
            
        case .multiline:
            TextEditor(text: textBinding)
                .frame(minHeight: 80)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
            
        case .picker(let options):
            Picker(field.title, selection: pickerBinding) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
        case .toggle:
            Toggle(field.title, isOn: toggleBinding)
                .toggleStyle(SwitchToggleStyle())
        }
    }
    
    @ViewBuilder
    private var fieldMessages: some View {
        if let errorMessage = validationState.errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(LopanColors.error)
                
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(LopanColors.error)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        
        if !adaptiveHints.isEmpty && isFocused {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(adaptiveHints, id: \.self) { hint in
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption2)
                            .foregroundColor(LopanColors.info)
                        
                        Text(hint)
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    // MARK: - Computed Properties
    private var textBinding: Binding<String> {
        Binding(
            get: { value as? String ?? "" },
            set: { onValueChanged($0) }
        )
    }
    
    private var pickerBinding: Binding<String> {
        Binding(
            get: { value as? String ?? "" },
            set: { onValueChanged($0) }
        )
    }
    
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { value as? Bool ?? false },
            set: { onValueChanged($0) }
        )
    }
    
    private var borderColor: Color {
        if !validationState.isValid && validationState.errorMessage != nil {
            return LopanColors.error
        } else if isFocused {
            return LopanColors.primary
        } else {
            return Color(.systemGray4)
        }
    }
}

/// 智能文本字段样式
struct SmartTextFieldStyle: TextFieldStyle {
    let isValid: Bool
    let isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
    
    private var borderColor: Color {
        if !isValid {
            return LopanColors.error
        } else if isFocused {
            return LopanColors.primary
        } else {
            return Color(.systemGray4)
        }
    }
}

// MARK: - Supporting Models

/// 表单配置
struct FormConfiguration {
    let id: String
    let title: String
    let layout: FormLayout
    let steps: [FormStep]
    let fieldGroups: [FormFieldGroup]
    let showProgress: Bool
    let allowSaveAsDraft: Bool
    let validationRules: [ValidationRule]
    
    enum FormLayout {
        case stepped
        case singlePage
    }
    
    func getAllFields() -> [FormField] {
        if layout == .stepped {
            return steps.flatMap { $0.fields }
        } else {
            return fieldGroups.flatMap { $0.fields }
        }
    }
}

/// 表单步骤
struct FormStep {
    let id: String
    let title: String
    let description: String?
    let fields: [FormField]
    let isRequired: Bool
}

/// 表单字段组
struct FormFieldGroup: Identifiable {
    let id: String
    let title: String?
    let description: String?
    let fields: [FormField]
    let layout: GroupLayout
    
    enum GroupLayout {
        case vertical
        case horizontal
        case grid(columns: Int)
    }
}

/// 表单字段
struct FormField: Identifiable {
    let id: String
    let title: String
    let placeholder: String
    let type: FieldType
    let defaultValue: Any
    let isRequired: Bool
    let validationRules: [ValidationRule]
    
    enum FieldType {
        case text
        case email
        case number
        case multiline
        case picker([String])
        case toggle
    }
}

/// 表单数据
class FormData: ObservableObject, Equatable {
    static func == (lhs: FormData, rhs: FormData) -> Bool {
        // Basic equality check - can be expanded as needed
        return lhs.data.keys == rhs.data.keys
    }
    private var data: [String: Any] = [:]
    
    func setValue(_ value: Any, for fieldId: String) {
        data[fieldId] = value
        objectWillChange.send()
    }
    
    func getValue(for fieldId: String) -> Any? {
        return data[fieldId]
    }
    
    func hasValue(for fieldId: String) -> Bool {
        return data[fieldId] != nil
    }
}

/// 验证状态
struct ValidationState {
    let isValid: Bool
    let errorMessage: String?
    
    static let valid = ValidationState(isValid: true, errorMessage: nil)
    static func invalid(_ message: String) -> ValidationState {
        return ValidationState(isValid: false, errorMessage: message)
    }
}

/// 验证规则
struct ValidationRule {
    let fieldId: String
    let type: ValidationType
    let errorMessage: String
    
    enum ValidationType {
        case required
        case email
        case minLength(Int)
        case maxLength(Int)
        case regex(String)
        case custom((Any) -> Bool)
    }
}

/// 表单建议
struct FormSuggestion {
    let id: String
    let title: String
    let description: String
    let apply: (inout FormData) -> Void
}

// MARK: - Form Engines

class FormEngine: ObservableObject {
    func configure(with configuration: FormConfiguration) {
        // 配置表单引擎
    }
    
    func saveAsDraft(_ data: FormData) {
        // 保存草稿逻辑
    }
}

class ValidationEngine: ObservableObject {
    private var validationStates: [String: ValidationState] = [:]
    
    func setupValidation(for configuration: FormConfiguration) {
        // 设置验证规则
    }
    
    func validateField(_ fieldId: String, value: Any, in formData: FormData) {
        // 验证单个字段
        validationStates[fieldId] = .valid
    }
    
    func validateAll(_ formData: FormData, completion: @escaping (Bool) -> Void) {
        // 验证所有字段
        completion(true)
    }
    
    func getValidationState(for fieldId: String) -> ValidationState {
        return validationStates[fieldId] ?? .valid
    }
    
    func areFieldsValid(_ fieldIds: [String]) -> Bool {
        return fieldIds.allSatisfy { validationStates[$0]?.isValid ?? false }
    }
    
    func isFieldValid(_ fieldId: String) -> Bool {
        return validationStates[fieldId]?.isValid ?? false
    }
    
    func getAllValidationResults() -> [ValidationResult] {
        // 返回所有验证结果
        return []
    }
}

class AdaptiveFormEngine: ObservableObject {
    func initialize(with configuration: FormConfiguration, formData: FormData) {
        // 初始化自适应引擎
    }
    
    func getHints(for field: FormField) -> [String] {
        return []
    }
    
    func getCurrentSuggestions() -> [FormSuggestion] {
        return []
    }
    
    func recordFieldFocus(_ fieldId: String) {
        // 记录字段聚焦
    }
    
    func recordFieldUpdate(_ fieldId: String, value: Any) {
        // 记录字段更新
    }
    
    func updateSuggestionsForField(_ fieldId: String, currentData: FormData) {
        // 更新字段建议
    }
    
    func recordStepCompletion(_ step: Int) {
        // 记录步骤完成
    }
    
    func recordFormSubmission() {
        // 记录表单提交
    }
    
    func recordSuggestionUsage(_ suggestion: FormSuggestion) {
        // 记录建议使用
    }
}

struct ValidationResult {
    let fieldId: String
    let isValid: Bool
    let errorMessage: String?
}

struct SmartSuggestionsPanel: View {
    let suggestions: [FormSuggestion]
    let onSuggestionApplied: (FormSuggestion) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("智能建议")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(LopanColors.textTertiary)
                }
            }
            
            if suggestions.isEmpty {
                Text("暂无建议")
                    .font(.callout)
                    .foregroundColor(LopanColors.textSecondary)
            } else {
                ForEach(suggestions, id: \.id) { suggestion in
                    Button(action: { onSuggestionApplied(suggestion) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.title)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(LopanColors.textPrimary)
                            
                            Text(suggestion.description)
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        )
    }
}

struct ValidationSummaryView: View {
    let validationResults: [ValidationResult]
    let onFieldSelected: (String) -> Void
    
    var body: some View {
        List {
            if validationResults.isEmpty {
                Text("所有字段都已通过验证")
                    .font(.headline)
                    .foregroundColor(LopanColors.success)
            } else {
                ForEach(validationResults, id: \.fieldId) { result in
                    HStack {
                        Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.isValid ? LopanColors.success : LopanColors.error)
                        
                        VStack(alignment: .leading) {
                            Text(result.fieldId)
                                .font(.headline)
                            
                            if let errorMessage = result.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(LopanColors.error)
                            }
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onFieldSelected(result.fieldId)
                    }
                }
            }
        }
    }
}

#Preview {
    let configuration = FormConfiguration(
        id: "customer-form",
        title: "客户信息",
        layout: .singlePage,
        steps: [],
        fieldGroups: [
            FormFieldGroup(
                id: "basic",
                title: "基本信息",
                description: nil,
                fields: [
                    FormField(
                        id: "name",
                        title: "姓名",
                        placeholder: "请输入客户姓名",
                        type: .text,
                        defaultValue: "",
                        isRequired: true,
                        validationRules: []
                    ),
                    FormField(
                        id: "email",
                        title: "邮箱",
                        placeholder: "请输入邮箱地址",
                        type: .email,
                        defaultValue: "",
                        isRequired: false,
                        validationRules: []
                    )
                ],
                layout: .vertical
            )
        ],
        showProgress: true,
        allowSaveAsDraft: true,
        validationRules: []
    )
    
    SmartFormSystem(
        formData: .constant(FormData()),
        isValid: .constant(false),
        configuration: configuration,
        onSubmit: { _ in },
        onCancel: { }
    )
}