//
//  Customer.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

@Model
public final class Customer {
    public var id: String
    var customerNumber: String
    var name: String
    var address: String
    var phone: String
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool = false
    var lastViewedAt: Date? = nil

    // Cached pinyin values for performance optimization
    // Pre-computed to avoid expensive CFStringTransform calls during sorting/grouping
    var pinyinName: String = ""        // Full pinyin: "zhang san"
    var pinyinInitial: String = ""     // First letter: "Z"

    init(name: String, address: String, phone: String) {
        self.id = UUID().uuidString
        self.customerNumber = CustomerIDService.shared.generateNextCustomerID()
        self.name = name
        self.address = address
        self.phone = phone
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isFavorite = false
        self.lastViewedAt = nil

        // Pre-compute pinyin values for performance
        self.pinyinName = name.toPinyin()
        self.pinyinInitial = name.pinyinInitial()
    }

    /// Updates the pinyin cached values after name change
    /// Call this method after modifying the name property
    func updatePinyinCache() {
        self.pinyinName = name.toPinyin()
        self.pinyinInitial = name.pinyinInitial()
    }
} 