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
    var whatsappNumber: String = ""    // WhatsApp contact number
    var avatarImageData: Data? = nil   // Customer profile photo
    var avatarBackgroundColor: String? = nil  // Hex color for avatar background (e.g., "#007AFF")
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool = false
    var lastViewedAt: Date? = nil

    // Location data
    var country: String = ""           // Country code (e.g., "CN", "US", "NG")
    var countryName: String = ""       // Country name (e.g., "China", "United States", "Nigeria")
    var region: String = ""            // Region/state/province
    var city: String = ""              // City name

    // Cached pinyin values for performance optimization
    // Pre-computed to avoid expensive CFStringTransform calls during sorting/grouping
    var pinyinName: String = ""        // Full pinyin: "zhang san"
    var pinyinInitial: String = ""     // First letter: "Z"

    init(name: String, address: String, phone: String, whatsappNumber: String = "", avatarImageData: Data? = nil, avatarBackgroundColor: String? = nil, country: String = "", countryName: String = "", region: String = "", city: String = "") {
        self.id = UUID().uuidString
        self.customerNumber = CustomerIDService.shared.generateNextCustomerID()
        self.name = name
        self.address = address
        self.phone = phone
        self.whatsappNumber = whatsappNumber
        self.avatarImageData = avatarImageData
        self.avatarBackgroundColor = avatarBackgroundColor
        self.country = country
        self.countryName = countryName
        self.region = region
        self.city = city
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