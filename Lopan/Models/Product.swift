//
//  Product.swift
//  Lopan
//
//  Created by Bobo on 2025/7/28.
//

import Foundation
import SwiftData

@Model
public final class Product {
    public var id: String
    var name: String
    var colors: [String] // Changed from single color to array of colors
    var imageData: Data? // Store image as Data
    var sizes: [ProductSize]? // Relationship to sizes
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, colors: [String] = [], imageData: Data? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.colors = colors
        self.imageData = imageData
        self.sizes = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Helper method to get all sizes as strings
    var sizeNames: [String] {
        return sizes?.map { $0.size } ?? []
    }
    
    // Helper method to get display name with sizes
    var displayName: String {
        let sizeList = sizeNames.joined(separator: ", ")
        return "\(name) (\(sizeList))"
    }
    
    // Helper method to get colors as comma-separated string
    var colorDisplay: String {
        return colors.joined(separator: ", ")
    }
    
    // Backward compatibility for single color
    var color: String {
        return colors.first ?? ""
    }
}

@Model
final class ProductSize {
    public var id: String
    var size: String
    var product: Product?
    var createdAt: Date
    
    init(size: String, product: Product? = nil) {
        self.id = UUID().uuidString
        self.size = size
        self.product = product
        self.createdAt = Date()
    }
} 