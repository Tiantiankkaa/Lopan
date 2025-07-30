//
//  FileShareService.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

class FileShareService {
    static let shared = FileShareService()
    
    private var currentDelegate: DocumentPickerDelegate?
    
    private init() {}
    
    // Share file with system share sheet
    func shareFile(_ url: URL, from sourceView: UIView? = nil) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad, configure popover presentation
        if let popover = activityVC.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        // Present the activity view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    // Save file to Files app
    func saveFileToDocuments(_ url: URL, completion: @escaping (Bool, String) -> Void) {
        let documentPicker = UIDocumentPickerViewController(forExporting: [url])
        
        // Store the delegate to prevent deallocation
        currentDelegate = DocumentPickerDelegate { [weak self] success, message in
            completion(success, message)
            self?.currentDelegate = nil // Clean up after completion
        }
        
        documentPicker.delegate = currentDelegate
        documentPicker.modalPresentationStyle = .formSheet
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(documentPicker, animated: true)
        }
    }
    
    // Get file info for display
    func getFileInfo(_ url: URL) -> (name: String, size: String) {
        let fileName = url.lastPathComponent
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                let sizeString = formatter.string(fromByteCount: fileSize)
                return (fileName, sizeString)
            }
        } catch {
            print("Error getting file attributes: \(error)")
        }
        
        return (fileName, "Unknown size")
    }
}

// MARK: - Document Picker Delegate
class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: (Bool, String) -> Void
    
    init(completion: @escaping (Bool, String) -> Void) {
        self.completion = completion
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if !urls.isEmpty {
            completion(true, "文件已成功保存到所选位置")
        } else {
            completion(false, "未选择保存位置")
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(false, "已取消保存")
    }
}

// MARK: - SwiftUI Integration
struct FileShareSheet: UIViewControllerRepresentable {
    let url: URL
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            isPresented = false
        }
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}