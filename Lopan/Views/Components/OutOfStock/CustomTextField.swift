//
//  CustomTextField.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import SwiftUI
import UIKit

struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onEditingChanged: (Bool) -> Void
    let onCommit: () -> Void
    
    init(
        _ placeholder: String,
        text: Binding<String>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        
        // Configure basic properties
        textField.placeholder = placeholder
        textField.font = UIFont.systemFont(ofSize: 15)
        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        
        // Disable automatic toolbar and suggestions
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        // Explicitly remove any input accessory view to avoid constraint conflicts
        textField.inputAccessoryView = nil
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no
        
        // Set delegates
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        
        // Set return key type
        textField.returnKeyType = .search
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onEditingChanged(true)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onEditingChanged(false)
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit()
            textField.resignFirstResponder()
            return true
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CustomTextField(
            "搜索客户、产品、备注...",
            text: .constant("")
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LopanColors.backgroundTertiary)
        .cornerRadius(10)
        
        CustomTextField(
            "测试输入",
            text: .constant("测试文本")
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LopanColors.backgroundTertiary)
        .cornerRadius(10)
    }
    .padding()
}