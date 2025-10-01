//
//  LocalizationHelper.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftUI

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    var localizedKey: LocalizedStringKey {
        LocalizedStringKey(self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
} 
