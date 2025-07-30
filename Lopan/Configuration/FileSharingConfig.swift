//
//  FileSharingConfig.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation

/*
 IMPORTANT: To enable file sharing, you need to add these keys to your Info.plist:
 
 1. Add this key to enable file sharing:
    Key: UIFileSharingEnabled
    Type: Boolean
    Value: YES
 
 2. Add this key to support opening documents in place:
    Key: LSSupportsOpeningDocumentsInPlace
    Type: Boolean
    Value: YES
 
 3. Add document types for CSV and Excel files:
    Key: CFBundleDocumentTypes
    Type: Array
    Value: [
        {
            CFBundleTypeName: "CSV Document",
            LSHandlerRank: "Owner",
            LSItemContentTypes: ["public.comma-separated-values-text"]
        },
        {
            CFBundleTypeName: "Excel Document", 
            LSHandlerRank: "Owner",
            LSItemContentTypes: ["org.openxmlformats.spreadsheetml.sheet"]
        }
    ]
 
 You can add these in Xcode by:
 1. Opening your project
 2. Selecting your target
 3. Going to Info tab
 4. Adding the keys manually or editing the Info.plist source
 */

struct FileSharingConfig {
    static let isFileSharingEnabled = true
    
    static func getFileSharingInstructions() -> String {
        return """
        📁 文件共享配置说明：
        
        如果文件无法在"文件"应用中访问，请检查以下配置：
        
        1. 在 Xcode 中打开项目
        2. 选择 Lopan target
        3. 进入 Info 标签页
        4. 添加以下键值对：
        
        UIFileSharingEnabled (Boolean) = YES
        LSSupportsOpeningDocumentsInPlace (Boolean) = YES
        
        5. 添加文档类型支持：
        CFBundleDocumentTypes (Array) = [
            {
                CFBundleTypeName: "CSV Document",
                LSHandlerRank: "Owner", 
                LSItemContentTypes: ["public.comma-separated-values-text"]
            },
            {
                CFBundleTypeName: "Excel Document",
                LSHandlerRank: "Owner",
                LSItemContentTypes: ["org.openxmlformats.spreadsheetml.sheet"]
            }
        ]
        """
    }
} 