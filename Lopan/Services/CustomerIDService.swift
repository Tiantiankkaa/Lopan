//
//  CustomerIDService.swift
//  Lopan
//
//  Created by Claude on 2025/8/19.
//

import Foundation
import SwiftData

class CustomerIDService {
    private let userDefaults = UserDefaults.standard
    private let customerIDKey = "LastCustomerID"
    
    static let shared = CustomerIDService()
    
    private init() {}
    
    func generateNextCustomerID() -> String {
        let lastID = userDefaults.integer(forKey: customerIDKey)
        let nextID = lastID + 1
        userDefaults.set(nextID, forKey: customerIDKey)
        
        // Format as 6-digit number with leading zeros
        return String(format: "%06d", nextID)
    }
    
    func resetIDCounter() {
        userDefaults.removeObject(forKey: customerIDKey)
    }
    
    func getCurrentIDCount() -> Int {
        return userDefaults.integer(forKey: customerIDKey)
    }
    
    func setIDCount(to count: Int) {
        userDefaults.set(count, forKey: customerIDKey)
    }
}