//
//  AccessibilityEnhancedViews.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI

// MARK: - Accessibility-Enhanced List Row
struct AccessibleListRow<Content: View>: View {
    let content: Content
    let accessibilityLabel: String
    let accessibilityValue: String?
    let accessibilityHint: String?
    let isSelected: Bool
    let onTap: (() -> Void)?
    
    init(
        accessibilityLabel: String,
        accessibilityValue: String? = nil,
        accessibilityHint: String? = nil,
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.accessibilityHint = accessibilityHint
        self.isSelected = isSelected
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap ?? {}) {
            content
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "")
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .dynamicTypeSize(.large...(.accessibility5))
    }
}

// MARK: - Accessible Input Field
struct AccessibleInputField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let isRequired: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let axis: Axis
    let lineLimit: ClosedRange<Int>?
    
    init(
        label: String,
        text: Binding<String>,
        placeholder: String = "",
        isRequired: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        axis: Axis = .horizontal,
        lineLimit: ClosedRange<Int>? = nil
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.axis = axis
        self.lineLimit = lineLimit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .accessibilityLabel("必填项")
                }
            }
            
            if axis == .vertical {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .lineLimit(lineLimit ?? 3...6)
                    .accessibilityLabel("\(label)\(isRequired ? "，必填项" : "")")
                    .accessibilityValue(text.isEmpty ? "空白" : text)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .accessibilityLabel("\(label)\(isRequired ? "，必填项" : "")")
                    .accessibilityValue(text.isEmpty ? "空白" : text)
            }
        }
        .dynamicTypeSize(.large...(.accessibility5))
    }
}

// MARK: - Accessible Picker
struct AccessiblePicker<T: CaseIterable & Hashable>: View where T.AllCases.Element == T, T: CustomStringConvertible {
    let label: String
    @Binding var selection: T
    let options: [T]
    let style: PickerStyle
    let accessibilityLabel: String?
    let accessibilityHint: String?
    
    enum PickerStyle {
        case segmented, menu, wheel
    }
    
    init(
        label: String,
        selection: Binding<T>,
        options: [T],
        style: PickerStyle = .segmented,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.label = label
        self._selection = selection
        self.options = options
        self.style = style
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            getPickerView()
                .accessibilityValue(selection.description)
        }
        .dynamicTypeSize(.large...(.accessibility5))
    }
    
    @ViewBuilder
    private func getPickerView() -> some View {
        let basePicker = Picker(label, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(option.description).tag(option)
            }
        }
        .accessibilityLabel(accessibilityLabel ?? label)
        
        switch style {
        case .segmented:
            basePicker.pickerStyle(.segmented)
                .accessibilityHint(accessibilityHint ?? "")
        case .menu:
            basePicker.pickerStyle(.menu)
                .accessibilityHint(accessibilityHint ?? "")
        case .wheel:
            basePicker.pickerStyle(.wheel)
                .accessibilityHint(accessibilityHint ?? "")
        }
    }
}

// MARK: - Accessible Toggle
struct AccessibleToggle: View {
    let label: String
    @Binding var isOn: Bool
    let description: String?
    
    init(
        _ label: String,
        isOn: Binding<Bool>,
        description: String? = nil
    ) {
        self.label = label
        self._isOn = isOn
        self.description = description
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(label, isOn: $isOn)
                .accessibilityLabel(label)
                .accessibilityValue(isOn ? "开启" : "关闭")
                .accessibilityHint(description ?? "切换设置")
            
            if let description = description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .dynamicTypeSize(.large...(.accessibility5))
    }
}

// MARK: - Accessible Badge
struct AccessibleBadge: View {
    let text: String
    let color: Color
    let accessibilityDescription: String?
    
    init(
        _ text: String,
        color: Color = .blue,
        accessibilityDescription: String? = nil
    ) {
        self.text = text
        self.color = color
        self.accessibilityDescription = accessibilityDescription
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
            .accessibilityElement()
            .accessibilityLabel(accessibilityDescription ?? "\(text)状态")
            .dynamicTypeSize(.large...(.accessibility3))
    }
}

// MARK: - Accessible Progress Indicator
struct AccessibleProgressView: View {
    let value: Double?
    let total: Double
    let label: String
    let format: ProgressFormat
    
    enum ProgressFormat {
        case percentage, fraction, custom(String)
    }
    
    init(
        value: Double?,
        total: Double = 1.0,
        label: String,
        format: ProgressFormat = .percentage
    ) {
        self.value = value
        self.total = total
        self.label = label
        self.format = format
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formattedValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let value = value {
                ProgressView(value: value, total: total)
                    .accessibilityLabel(label)
                    .accessibilityValue(formattedValue)
            } else {
                ProgressView()
                    .accessibilityLabel("\(label)，正在加载")
            }
        }
        .dynamicTypeSize(.large...(.accessibility5))
    }
    
    private var formattedValue: String {
        guard let value = value else { return "加载中" }
        
        switch format {
        case .percentage:
            return "\(Int((value / total) * 100))%"
        case .fraction:
            return "\(Int(value))/\(Int(total))"
        case .custom(let format):
            return format
        }
    }
}

// MARK: - Accessible Card
struct AccessibleCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let content: Content
    let onTap: (() -> Void)?
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            content
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
        .onTapGesture {
            onTap?()
        }
        .dynamicTypeSize(.large...(.accessibility5))
    }
}

// MARK: - Accessible Status Indicator
struct AccessibleStatusIndicator: View {
    let status: Status
    let customText: String?
    
    enum Status {
        case success, warning, error, info, pending
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            case .pending: return .gray
            }
        }
        
        var systemImage: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .pending: return "clock.fill"
            }
        }
        
        var description: String {
            switch self {
            case .success: return "成功"
            case .warning: return "警告"
            case .error: return "错误"
            case .info: return "信息"
            case .pending: return "待处理"
            }
        }
    }
    
    init(_ status: Status, customText: String? = nil) {
        self.status = status
        self.customText = customText
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.systemImage)
                .foregroundColor(status.color)
                .accessibilityHidden(true)
            
            Text(customText ?? status.description)
                .font(.subheadline)
                .foregroundColor(status.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.description)状态: \(customText ?? status.description)")
        .dynamicTypeSize(.large...(.accessibility5))
    }
}

// MARK: - View Extensions for Accessibility
extension View {
    func accessibleListItem(
        label: String,
        value: String? = nil,
        hint: String? = nil,
        isSelected: Bool = false
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .dynamicTypeSize(.large...(.accessibility5))
    }
    
    func accessibleButton(
        label: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .dynamicTypeSize(.large...(.accessibility5))
    }
    
    func enhancedForVoiceOver(
        label: String,
        value: String? = nil,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .dynamicTypeSize(.large...(.accessibility5))
    }
}