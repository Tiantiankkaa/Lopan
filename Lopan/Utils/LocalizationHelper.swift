//
//  LocalizationHelper.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
} 