//
//  FileSharingService.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import UIKit

public class FileSharingService {
    
    static func getExportsDirectory() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsPath = documentsPath.appendingPathComponent("Lopan_Exports")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: exportsPath, withIntermediateDirectories: true)
        
        return exportsPath
    }
    
    static func listExportedFiles() -> [URL] {
        guard let exportsPath = getExportsDirectory() else { return [] }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: exportsPath, includingPropertiesForKeys: nil)
            return fileURLs.sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            print("❌ Failed to list exported files: \(error)")
            return []
        }
    }
    
    static func shareFile(url: URL, from viewController: UIViewController) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityViewController, animated: true)
    }
    
    static func getFileAccessInstructions() -> String {
        return """
        📁 文件访问说明：
        
        📂 文件位置：
        - 打开 "文件" 应用
        - 进入 "我的 iPhone" 或 "我的 iPad"
        - 找到 "Lopan" 文件夹
        - 进入 "Lopan_Exports" 子文件夹
        
        📋 导出文件：
        - 客户数据：customers_[时间戳].xlsx
        - 产品数据：products_[时间戳].xlsx
        - 客户模板：customer_template.xlsx
        - 产品模板：product_template.xlsx
        
        💡 使用提示：
        - 文件可以直接在 Excel、Numbers 或 Google Sheets 中打开
        - 支持通过邮件、AirDrop、微信等方式分享
        - 可以在电脑上通过 iTunes 文件共享访问
        
        ⚠️ 如果文件无法访问：
        - 请检查项目配置中的文件共享设置
        - 参考 FileSharingConfig.swift 中的配置说明
        """
    }
} 