//
//  LopanTextField.swift
//  Lopan
//
//  Created by Claude on 2025/7/29.
//

import SwiftUI

/// Modern text field component system for Lopan production management app
/// Supports different variants, validation states, and accessibility features
struct LopanTextField: View {
    // MARK: - Properties
    let title: String
    let placeholder: String
    @Binding var text: String
    let variant: TextFieldVariant
    let state: ValidationState
    let isRequired: Bool
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let autocapitalization: TextInputAutocapitalization
    let icon: String?
    let helperText: String?
    let errorText: String?
    let maxLength: Int?
    let onCommit: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    @State private var isSecureVisible = false
    
    // MARK: - Initializers
    init(
        title: String,
        placeholder: String = "",
        text: Binding<String>,
        variant: TextFieldVariant = .outline,
        state: ValidationState = .normal,
        isRequired: Bool = false,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences,
        icon: String? = nil,
        helperText: String? = nil,
        errorText: String? = nil,
        maxLength: Int? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.variant = variant
        self.state = state
        self.isRequired = isRequired
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.icon = icon
        self.helperText = helperText
        self.errorText = errorText
        self.maxLength = maxLength
        self.onCommit = onCommit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            // Title and Required Indicator
            if !title.isEmpty {
                HStack(spacing: LopanSpacing.xxs) {
                    Text(title)
                        .font(LopanTypography.labelMedium)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    if isRequired {
                        Text("*")
                            .font(LopanTypography.labelMedium)
                            .foregroundColor(LopanColors.error)
                    }
                }
            }
            
            // Text Field Container
            HStack(spacing: LopanSpacing.sm) {
                // Leading Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(LopanTypography.bodyMedium)
                        .foregroundColor(iconColor)
                        .frame(width: 20)
                }
                
                // Text Input
                Group {
                    if isSecure && !isSecureVisible {
                        SecureField(placeholder, text: $text)
                            .focused($isFocused)
                    } else {
                        TextField(placeholder, text: $text)
                            .focused($isFocused)
                    }
                }
                .font(LopanTypography.bodyMedium)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .onChange(of: text) { _, newValue in
                    if let maxLength = maxLength, newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
                .onSubmit {
                    onCommit?()
                }
                
                // Trailing Actions
                HStack(spacing: LopanSpacing.xs) {
                    // Clear Button
                    if !text.isEmpty && isFocused {
                        Button(action: {
                            text = ""
                            LopanHapticEngine.shared.light()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(LopanTypography.bodySmall)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                    }
                    
                    // Secure Toggle
                    if isSecure {
                        Button(action: {
                            isSecureVisible.toggle()
                            LopanHapticEngine.shared.light()
                        }) {
                            Image(systemName: isSecureVisible ? "eye.slash" : "eye")
                                .font(LopanTypography.bodyMedium)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                    }
                    
                    // Validation Icon
                    if state != .normal && !isFocused {
                        Image(systemName: state.icon)
                            .font(LopanTypography.bodyMedium)
                            .foregroundColor(state.color)
                    }
                }
            }
            .padding(.horizontal, LopanSpacing.md)
            .padding(.vertical, LopanSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.input)
                    .fill(variant.backgroundColor(isFocused: isFocused, state: state))
                    .overlay(
                        RoundedRectangle(cornerRadius: LopanCornerRadius.input)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            )
            .animation(LopanAnimation.easeOut, value: isFocused)
            .animation(LopanAnimation.easeOut, value: state)
            
            // Helper/Error Text and Character Count
            HStack {
                if let errorText = errorText, state == .error {
                    Text(errorText)
                        .font(LopanTypography.caption)
                        .foregroundColor(LopanColors.error)
                } else if let helperText = helperText {
                    Text(helperText)
                        .font(LopanTypography.caption)
                        .foregroundColor(LopanColors.textSecondary)
                }
                
                Spacer()
                
                if let maxLength = maxLength {
                    Text("\(text.count)/\(maxLength)")
                        .font(LopanTypography.caption)
                        .foregroundColor(text.count == maxLength ? LopanColors.warning : LopanColors.textTertiary)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var iconColor: Color {
        if state == .error {
            return LopanColors.error
        } else if state == .success {
            return LopanColors.success
        } else if isFocused {
            return LopanColors.primary
        } else {
            return LopanColors.textSecondary
        }
    }
    
    private var borderColor: Color {
        if state == .error {
            return LopanColors.error
        } else if state == .success {
            return LopanColors.success
        } else if isFocused {
            return LopanColors.primary
        } else {
            return variant.defaultBorderColor
        }
    }
    
    private var borderWidth: CGFloat {
        if state != .normal || isFocused {
            return 2
        } else {
            return variant.defaultBorderWidth
        }
    }
}

// MARK: - Text Field Variants
extension LopanTextField {
    enum TextFieldVariant {
        case filled
        case outline
        case underline
        
        func backgroundColor(isFocused: Bool, state: ValidationState) -> Color {
            switch self {
            case .filled:
                if state == .error {
                    return LopanColors.errorLight
                } else if isFocused {
                    return LopanColors.primaryLight
                } else {
                    return LopanColors.backgroundSecondary
                }
            case .outline, .underline:
                return LopanColors.background
            }
        }
        
        var defaultBorderColor: Color {
            switch self {
            case .filled:
                return LopanColors.clear
            case .outline:
                return LopanColors.border
            case .underline:
                return LopanColors.border
            }
        }
        
        var defaultBorderWidth: CGFloat {
            switch self {
            case .filled:
                return 0
            case .outline:
                return 1
            case .underline:
                return 1
            }
        }
    }
}

// MARK: - Validation States
extension LopanTextField {
    enum ValidationState {
        case normal
        case success
        case error
        case warning
        
        var color: Color {
            switch self {
            case .normal:
                return LopanColors.textSecondary
            case .success:
                return LopanColors.success
            case .error:
                return LopanColors.error
            case .warning:
                return LopanColors.warning
            }
        }
        
        var icon: String {
            switch self {
            case .normal:
                return ""
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            }
        }
    }
}

// MARK: - Convenience Initializers
extension LopanTextField {
    /// Creates a standard text field
    static func standard(
        title: String,
        placeholder: String = "",
        text: Binding<String>,
        isRequired: Bool = false,
        icon: String? = nil,
        helperText: String? = nil,
        onCommit: (() -> Void)? = nil
    ) -> LopanTextField {
        LopanTextField(
            title: title,
            placeholder: placeholder,
            text: text,
            variant: .outline,
            isRequired: isRequired,
            icon: icon,
            helperText: helperText,
            onCommit: onCommit
        )
    }
    
    /// Creates a password field
    static func password(
        title: String,
        placeholder: String = "",
        text: Binding<String>,
        isRequired: Bool = false,
        helperText: String? = nil,
        onCommit: (() -> Void)? = nil
    ) -> LopanTextField {
        LopanTextField(
            title: title,
            placeholder: placeholder,
            text: text,
            variant: .outline,
            isRequired: isRequired,
            isSecure: true,
            icon: "lock",
            helperText: helperText,
            onCommit: onCommit
        )
    }
    
    /// Creates an email field
    static func email(
        title: String,
        placeholder: String = "",
        text: Binding<String>,
        isRequired: Bool = false,
        helperText: String? = nil,
        onCommit: (() -> Void)? = nil
    ) -> LopanTextField {
        LopanTextField(
            title: title,
            placeholder: placeholder,
            text: text,
            variant: .outline,
            isRequired: isRequired,
            keyboardType: .emailAddress,
            autocapitalization: .never,
            icon: "envelope",
            helperText: helperText,
            onCommit: onCommit
        )
    }
    
    /// Creates a phone number field
    static func phone(
        title: String,
        placeholder: String = "",
        text: Binding<String>,
        isRequired: Bool = false,
        helperText: String? = nil,
        onCommit: (() -> Void)? = nil
    ) -> LopanTextField {
        LopanTextField(
            title: title,
            placeholder: placeholder,
            text: text,
            variant: .outline,
            isRequired: isRequired,
            keyboardType: .phonePad,
            icon: "phone",
            helperText: helperText,
            onCommit: onCommit
        )
    }
    
    /// Creates a search field
    static func search(
        placeholder: String = "搜索...",
        text: Binding<String>,
        onCommit: (() -> Void)? = nil
    ) -> LopanTextField {
        LopanTextField(
            title: "",
            placeholder: placeholder,
            text: text,
            variant: .filled,
            icon: "magnifyingglass",
            onCommit: onCommit
        )
    }
}

// MARK: - Dynamic Type Previews

#Preview("Default Size") {
    ScrollView {
        VStack(spacing: 20) {
            Text("Text Field Variants")
                .font(.headline)
                .padding(.bottom)

            LopanTextField.standard(
                title: "客户姓名",
                placeholder: "请输入客户姓名",
                text: .constant(""),
                isRequired: true,
                icon: "person",
                helperText: "客户的真实姓名"
            )

            LopanTextField.email(
                title: "邮箱地址",
                placeholder: "请输入邮箱",
                text: .constant(""),
                isRequired: true,
                helperText: "用于接收订单通知"
            )

            LopanTextField.phone(
                title: "联系电话",
                placeholder: "请输入手机号",
                text: .constant("138")
            )

            LopanTextField.password(
                title: "密码",
                placeholder: "请输入密码",
                text: .constant(""),
                isRequired: true,
                helperText: "密码长度至少8位"
            )

            Divider()

            LopanTextField.search(
                placeholder: "搜索客户、产品...",
                text: .constant("")
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Extra Large") {
    ScrollView {
        VStack(spacing: 24) {
            Text("Text Field Preview at Extra Large Size")
                .font(.title2)
                .padding(.bottom)

            LopanTextField.standard(
                title: "Manufacturing Customer Information",
                placeholder: "Enter complete customer name for production order",
                text: .constant(""),
                isRequired: true,
                icon: "person.fill",
                helperText: "Full legal name as registered for manufacturing contracts"
            )

            LopanTextField.email(
                title: "Production Notification Email Address",
                placeholder: "customer@company.com",
                text: .constant(""),
                isRequired: true,
                helperText: "Email address for production status updates and quality reports"
            )

            LopanTextField(
                title: "Quality Control Notes with Character Limit",
                placeholder: "Enter detailed quality control observations",
                text: .constant("Initial inspection complete"),
                helperText: "Detailed notes about product quality and inspection results",
                maxLength: 200
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .xLarge)
}

#Preview("Accessibility 3") {
    ScrollView {
        VStack(spacing: 28) {
            Text("Text Field Preview at AX3 Size")
                .font(.title2)
                .padding(.bottom)

            LopanTextField.standard(
                title: "Production Batch Customer Name (Required Field)",
                placeholder: "Enter customer full legal name for manufacturing order processing",
                text: .constant(""),
                isRequired: true,
                icon: "person.badge.plus",
                helperText: "Customer name must match exactly with manufacturing contract documentation"
            )

            LopanTextField(
                title: "Critical Alert: Quality Control Issue Description",
                placeholder: "Describe quality control problem in detail",
                text: .constant("Surface defect detected"),
                state: .error,
                icon: "exclamationmark.triangle.fill",
                errorText: "Quality issue description must be comprehensive and specific"
            )

            LopanTextField(
                title: "Successfully Validated Production Specification",
                placeholder: "Product specification details",
                text: .constant("Meets all manufacturing standards"),
                state: .success,
                icon: "checkmark.circle.fill",
                helperText: "Production specification has passed all quality validation checks"
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5 (Maximum)") {
    ScrollView {
        VStack(spacing: 32) {
            Text("Maximum Accessibility Size")
                .font(.largeTitle)
                .padding(.bottom)

            LopanTextField.standard(
                title: "Customer Name",
                placeholder: "Enter name",
                text: .constant(""),
                isRequired: true,
                icon: "person",
                helperText: "Required field"
            )

            LopanTextField(
                title: "Error Example",
                placeholder: "Enter data",
                text: .constant("Invalid"),
                state: .error,
                errorText: "Invalid format"
            )

            LopanTextField.search(
                placeholder: "Search...",
                text: .constant("")
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Dark Mode - AX3") {
    ScrollView {
        VStack(spacing: 28) {
            Text("Dark Mode Text Field Preview")
                .font(.title2)
                .padding(.bottom)

            LopanTextField.standard(
                title: "Dark Mode Customer Information Entry",
                placeholder: "Enter customer details for night shift processing",
                text: .constant(""),
                isRequired: true,
                icon: "moon.stars.fill",
                helperText: "Customer information for after-hours manufacturing operations"
            )

            LopanTextField.password(
                title: "Secure Access for Night Operations",
                placeholder: "Enter secure access password",
                text: .constant(""),
                isRequired: true,
                helperText: "Enhanced security required for night shift access"
            )

            LopanTextField.search(
                placeholder: "Search night shift production records...",
                text: .constant("")
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Field States") {
    ScrollView {
        VStack(spacing: 20) {
            Text("Text Field Validation States")
                .font(.headline)
                .padding(.bottom)

            LopanTextField(
                title: "Normal State",
                placeholder: "Enter information",
                text: .constant(""),
                helperText: "Standard input field"
            )

            LopanTextField(
                title: "Success State",
                placeholder: "Enter information",
                text: .constant("valid@example.com"),
                state: .success,
                helperText: "Email format is valid"
            )

            LopanTextField(
                title: "Error State",
                placeholder: "Enter information",
                text: .constant("invalid"),
                state: .error,
                errorText: "Input format is incorrect"
            )

            LopanTextField(
                title: "Warning State",
                placeholder: "Enter information",
                text: .constant("caution"),
                state: .warning,
                helperText: "Please review this input"
            )

            Divider()

            LopanTextField(
                title: "Filled Variant",
                placeholder: "Filled style",
                text: .constant(""),
                variant: .filled,
                helperText: "Filled background style"
            )

            LopanTextField(
                title: "Character Count",
                placeholder: "Type here...",
                text: .constant("Sample text"),
                helperText: "Text with character limit",
                maxLength: 50
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .xLarge)
}