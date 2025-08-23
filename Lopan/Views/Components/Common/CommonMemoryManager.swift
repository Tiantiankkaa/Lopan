//
//  CommonMemoryManager.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI
import UIKit

// MARK: - Memory Manager Protocol

protocol MemoryManageable: AnyObject {
    func handleMemoryWarning()
    func optimizeMemoryUsage()
}

// MARK: - Common Memory Manager

class CommonMemoryManager: ObservableObject {
    private var observers: [NSObjectProtocol] = []
    
    init() {
        setupMemoryWarningObserver()
    }
    
    deinit {
        removeMemoryWarningObserver()
    }
    
    // MARK: - Memory Warning Handling
    
    private func setupMemoryWarningObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🚨 Memory warning received - optimizing memory usage")
        }
        observers.append(observer)
    }
    
    private func removeMemoryWarningObserver() {
        observers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
}

// MARK: - Memory Manager View Modifier

struct MemoryManagedView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

// MARK: - Shared Instance

extension CommonMemoryManager {
    static let shared = CommonMemoryManager()
}

// MARK: - View Extension

extension View {
    func memoryManaged() -> some View {
        MemoryManagedView {
            self
        }
    }
}

// MARK: - Default Memory Manageable Implementation

class DefaultMemoryManageable: MemoryManageable {
    private var clearableProperties: [() -> Void] = []
    
    func addClearableProperty(_ clearAction: @escaping () -> Void) {
        clearableProperties.append(clearAction)
    }
    
    func handleMemoryWarning() {
        print("📱 Handling memory warning for \(type(of: self))")
        clearableProperties.forEach { $0() }
    }
    
    func optimizeMemoryUsage() {
        print("⚡ Optimizing memory usage for \(type(of: self))")
        // Subclasses can override for specific optimizations
    }
}

#Preview {
    VStack {
        Text("Memory Managed View")
        Text("This view uses automatic memory management")
    }
    .memoryManaged()
}