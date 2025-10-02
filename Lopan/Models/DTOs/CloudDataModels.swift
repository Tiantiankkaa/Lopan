//
//  CloudDataModels.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/23.
//

import Foundation

// MARK: - Cloud Data Transfer Objects (DTOs)

/// Cloud-compatible DTO for CustomerOutOfStock
struct CustomerOutOfStockDTO: Codable, Identifiable {
    let id: String
    let customerId: String
    let customerName: String
    let customerAddress: String
    let productId: String
    let productName: String
    let productSizeId: String?
    let productSizeName: String?
    let quantity: Int
    let status: String  // OutOfStockStatus.rawValue
    let priority: Int
    let notes: String
    let requestDate: Date
    let actualCompletionDate: Date?
    let deliveryQuantity: Int
    let deliveryDate: Date?
    let deliveryNotes: String?
    let createdAt: Date
    let updatedAt: Date
    let createdBy: String
    let updatedBy: String
    
    // Display properties for compatibility
    var customerDisplayName: String { customerName }
    var customerDisplayAddress: String { customerAddress }
    var customerDisplayPhone: String { "" }
    var productDisplayName: String { productName }
    
    // Metadata for cloud sync
    let version: Int
    let lastSyncedAt: Date?
    let cloudId: String?
    let isDeleted: Bool
    
    init(from model: CustomerOutOfStock, cloudId: String? = nil, version: Int = 1) {
        self.id = model.id
        self.customerId = model.customer?.id ?? ""
        self.customerName = model.customer?.name ?? ""
        self.customerAddress = model.customer?.address ?? ""
        self.productId = model.product?.id ?? ""
        self.productName = model.product?.name ?? ""
        self.productSizeId = model.productSize?.id
        self.productSizeName = model.productSize?.size
        self.quantity = model.quantity
        self.status = model.status.rawValue
        self.priority = 0 // TODO: Add priority field to CustomerOutOfStock model
        self.notes = model.notes ?? ""
        self.requestDate = model.requestDate
        self.actualCompletionDate = model.actualCompletionDate
        self.deliveryQuantity = model.deliveryQuantity
        self.deliveryDate = model.deliveryDate
        self.deliveryNotes = model.deliveryNotes
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.createdBy = model.createdBy
        self.updatedBy = ""  // TODO: Add updatedBy field to CustomerOutOfStock model
        self.version = version
        self.lastSyncedAt = nil
        self.cloudId = cloudId
        self.isDeleted = false
    }
}

/// Cloud-compatible DTO for Customer
struct CustomerDTO: Codable, Identifiable {
    let id: String
    let customerNumber: String
    let name: String
    let address: String
    let phone: String
    let createdAt: Date
    let updatedAt: Date
    
    // Cloud metadata
    let version: Int
    let lastSyncedAt: Date?
    let cloudId: String?
    let isDeleted: Bool
    
    init(from model: Customer, cloudId: String? = nil, version: Int = 1) {
        self.id = model.id
        self.customerNumber = model.customerNumber
        self.name = model.name
        self.address = model.address
        self.phone = model.phone
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.version = version
        self.lastSyncedAt = nil
        self.cloudId = cloudId
        self.isDeleted = false
    }
}

/// Cloud-compatible DTO for Product
struct ProductDTO: Codable, Identifiable {
    let id: String
    let name: String
    let colors: [String]
    let imageDataBase64: String? // Store image as base64 string for cloud
    let createdAt: Date
    let updatedAt: Date
    
    // Cloud metadata
    let version: Int
    let lastSyncedAt: Date?
    let cloudId: String?
    let isDeleted: Bool
    
    init(from model: Product, cloudId: String? = nil, version: Int = 1) {
        self.id = model.id
        self.name = model.name
        self.colors = model.colors
        self.imageDataBase64 = model.imageData?.base64EncodedString()
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.version = version
        self.lastSyncedAt = nil
        self.cloudId = cloudId
        self.isDeleted = false
    }
}

/// Cloud-compatible DTO for User
struct UserDTO: Codable, Identifiable {
    let id: String
    let wechatId: String?
    let appleUserId: String?
    let name: String
    let phone: String?
    let email: String?
    let authMethod: String  // AuthenticationMethod.rawValue
    let roles: [String]  // Array of UserRole.rawValue
    let primaryRole: String  // UserRole.rawValue
    let isActive: Bool
    let lastLoginAt: Date?
    let createdAt: Date
    
    // Cloud metadata
    let version: Int
    let lastSyncedAt: Date?
    let cloudId: String?
    let isDeleted: Bool
    
    init(from model: User, cloudId: String? = nil, version: Int = 1) {
        self.id = model.id
        self.wechatId = model.wechatId
        self.appleUserId = model.appleUserId
        self.name = model.name
        self.phone = model.phone
        self.email = model.email
        self.authMethod = model.authMethod.rawValue
        self.roles = model.roles.map { $0.rawValue }
        self.primaryRole = model.primaryRole.rawValue
        self.isActive = model.isActive
        self.lastLoginAt = model.lastLoginAt
        self.createdAt = model.createdAt
        self.version = version
        self.lastSyncedAt = nil
        self.cloudId = cloudId
        self.isDeleted = false
    }
}

// MARK: - Empty Response for DELETE operations

struct EmptyResponse: Codable {
    let success: Bool?
    
    init() {
        self.success = true
    }
}

// MARK: - Cloud Response Wrappers

struct CloudResponse<T: Codable>: Codable {
    let data: T?
    let success: Bool
    let error: String?
    let timestamp: Date
    let requestId: String
}

struct CloudPaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let hasNextPage: Bool
    let hasPreviousPage: Bool
    let success: Bool
    let error: String?
    let timestamp: Date
    let requestId: String
}

// MARK: - Cloud Sync Status

struct CloudSyncStatus: Codable {
    let entityType: String
    let lastSyncedAt: Date?
    let pendingUpload: Int
    let pendingDownload: Int
    let conflictsCount: Int
    let syncInProgress: Bool
    let lastError: String?
}

// MARK: - Model-to-DTO Mapping Protocol

protocol CloudMappable {
    associatedtype CloudDTO: Codable
    
    func toCloudDTO() -> CloudDTO
    static func fromCloudDTO(_ dto: CloudDTO) throws -> Self
}

// MARK: - DTO Extensions

extension CustomerOutOfStockDTO {
    func toDomain() throws -> CustomerOutOfStock {
        guard let status = OutOfStockStatus(rawValue: status) else {
            throw RepositoryError.invalidInput("Invalid out of stock status: \(status)")
        }
        
        let customer = Customer(
            name: customerName,
            address: customerAddress,
            phone: "" // Default phone since not available in DTO
        )
        
        let product = Product(
            name: productName,
            colors: [], // Default empty colors
            imageData: nil
        )
        
        let productSize: ProductSize?
        if let sizeId = productSizeId, let sizeName = productSizeName {
            productSize = ProductSize(size: sizeName, product: product)
        } else {
            productSize = nil
        }
        
        return CustomerOutOfStock(
            customer: customer,
            product: product,
            productSize: productSize,
            quantity: quantity,
            notes: notes,
            createdBy: createdBy
        )
    }
}

extension CustomerDTO {
    func toDomain() -> Customer {
        return Customer(
            name: name,
            address: address,
            phone: phone
        )
    }
}

extension ProductDTO {
    func toDomain() -> Product {
        let imageData = imageDataBase64.flatMap { Data(base64Encoded: $0) }
        return Product(
            name: name,
            colors: colors,
            imageData: imageData
        )
    }
}

extension UserDTO {
    func toDomain() throws -> User {
        if let wechatId = wechatId {
            return User(wechatId: wechatId, name: name, phone: phone)
        } else {
            // Create a generic user - this is simplified for DTO conversion
            return User(wechatId: "", name: name, phone: phone)
        }
    }
    
    static func fromDomain(_ user: User) -> UserDTO {
        return UserDTO(from: user)
    }
}