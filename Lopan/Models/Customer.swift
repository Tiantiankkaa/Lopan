//
//  Customer.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

@Model
final class Customer {
    var id: String
    var customerNumber: String
    var name: String
    var address: String
    var phone: String
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, address: String, phone: String) {
        self.id = UUID().uuidString
        self.customerNumber = CustomerIDService.shared.generateNextCustomerID()
        self.name = name
        self.address = address
        self.phone = phone
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 