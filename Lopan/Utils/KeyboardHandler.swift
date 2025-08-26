//
//  KeyboardHandler.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import SwiftUI
import UIKit
import Combine

class KeyboardHandler: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var keyboardIsVisible: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupKeyboardNotifications()
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardWillShow(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                self?.handleKeyboardWillHide(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleKeyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        // Use no animation to prevent constraint conflicts
        withAnimation(.none) {
            self.keyboardHeight = keyboardHeight
            self.keyboardIsVisible = true
        }
    }
    
    private func handleKeyboardWillHide(_ notification: Notification) {
        // Use no animation to prevent constraint conflicts
        withAnimation(.none) {
            self.keyboardHeight = 0
            self.keyboardIsVisible = false
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - View Extension

extension View {
    func keyboardAware() -> some View {
        self.modifier(KeyboardAwareModifier())
    }
}

struct KeyboardAwareModifier: ViewModifier {
    @StateObject private var keyboardHandler = KeyboardHandler()
    
    func body(content: Content) -> some View {
        content
            .environmentObject(keyboardHandler)
    }
}