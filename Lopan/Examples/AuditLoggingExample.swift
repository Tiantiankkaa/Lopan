//
//  AuditLoggingExample.swift
//  Lopan
//
//  Created by Bobo on 2025/7/30.
//

import Foundation
import SwiftData

/// Example of how to integrate audit logging into CRUD operations
/// This demonstrates the patterns to follow when adding audit logging to existing views
class AuditLoggingExample {
    private let auditingService: AuditingService
    
    init(auditingService: AuditingService) {
        self.auditingService = auditingService
    }
    
    /// Example: Adding audit logging to CREATE operations
    func createCustomerOutOfStock(
        customer: Customer?,
        product: Product?,
        quantity: Int,
        notes: String?
    ) async {
        // Create the new item
        let newItem = CustomerOutOfStock(
            customer: customer,
            product: product,
            quantity: quantity,
            notes: notes,
            createdBy: "demo_user" // TODO: Get from current user
        )
        
        // Log the creation
        await auditingService.logCustomerOutOfStockCreation(
            item: newItem,
            operatorUserId: "demo_user", // TODO: Get from authentication service
            operatorUserName: "演示用户" // TODO: Get from authentication service
        )
    }
    
    /// Example: Adding audit logging to UPDATE operations
    func updateCustomerOutOfStock(
        item: CustomerOutOfStock,
        newQuantity: Int?,
        newNotes: String?
    ) async {
        // Capture values before update for audit log
        let beforeValues = CustomerOutOfStockOperation.CustomerOutOfStockValues(
            customerName: item.customer?.name,
            productName: item.product?.name,
            quantity: item.quantity,
            status: item.status.displayName,
            notes: item.notes,
            deliveryQuantity: item.deliveryQuantity,
            deliveryNotes: item.deliveryNotes
        )
        
        // Track which fields changed
        var changedFields: [String] = []
        
        // Apply updates
        if let newQuantity = newQuantity, newQuantity != item.quantity {
            item.quantity = newQuantity
            changedFields.append("quantity")
        }
        
        
        if let newNotes = newNotes, newNotes != item.notes {
            item.notes = newNotes.isEmpty ? nil : newNotes
            changedFields.append("notes")
        }
        
        // Update timestamp
        item.updatedAt = Date()
        
        // Log the update if any fields changed
        if !changedFields.isEmpty {
            await auditingService.logCustomerOutOfStockUpdate(
                item: item,
                beforeValues: beforeValues,
                changedFields: changedFields,
                operatorUserId: "demo_user", // TODO: Get from authentication service
                operatorUserName: "演示用户", // TODO: Get from authentication service
                additionalInfo: "字段更新: \(changedFields.joined(separator: ", "))"
            )
        }
        
        // Changes are handled by the repository layer
    }
    
    /// Example: Adding audit logging to DELIVERY PROCESSING operations
    func processReturn(
        item: CustomerOutOfStock,
        deliveryQuantity: Int,
        deliveryNotes: String?
    ) async {
        // Process the delivery using the existing method
        let success = item.processDelivery(quantity: deliveryQuantity, notes: deliveryNotes)

        if success {
            // Log the delivery processing
            await auditingService.logReturnProcessing(
                item: item,
                deliveryQuantity: deliveryQuantity,
                deliveryNotes: deliveryNotes,
                operatorUserId: "demo_user", // TODO: Get from authentication service
                operatorUserName: "演示用户" // TODO: Get from authentication service
            )
            
            // Changes are handled by the repository layer
        }
    }
    
    /// Example: How to integrate with authentication service
    /// This is how you would get the current user information
    func getCurrentUserInfo() -> (userId: String, userName: String) {
        // TODO: Replace with actual authentication service
        // Example:
        // if let currentUser = AuthenticationService.shared.currentUser {
        //     return (currentUser.id, currentUser.displayName)
        // }
        return ("demo_user", "演示用户")
    }
    
    /// Example: How to use the authentication service in audit logging
    func createWithRealUser(
        customer: Customer?,
        product: Product?,
        quantity: Int
    ) async {
        let (userId, userName) = getCurrentUserInfo()
        
        let newItem = CustomerOutOfStock(
            customer: customer,
            product: product,
            quantity: quantity,
            createdBy: userId
        )
        
        await auditingService.logCustomerOutOfStockCreation(
            item: newItem,
            operatorUserId: userId,
            operatorUserName: userName
        )
        
        // Changes are handled by the repository layer
    }
}

/*
INTEGRATION CHECKLIST for adding audit logging to existing views:

1. Inject AuditingService through dependency injection

2. For CREATE operations:
   - Create the entity
   - Call await auditingService.logCustomerOutOfStockCreation()

3. For UPDATE operations:
   - Capture before values
   - Apply changes
   - Track changed fields
   - Call await auditingService.logCustomerOutOfStockUpdate()

4. For DELETE operations:
   - Call await auditingService.logCustomerOutOfStockDeletion() BEFORE deleting
   - Delete the entity

5. For STATUS CHANGES:
   - Call await auditingService.logCustomerOutOfStockStatusChange()
   - Apply the status change

6. For RETURN PROCESSING:
   - Call await auditingService.logReturnProcessing()
   - Process the return

7. For BATCH operations:
   - Call await auditingService.logBatchOperation()
   - Apply the batch changes

8. Get user information from AuthenticationService instead of hardcoded values

Remember:
- Always log BEFORE deleting entities (they won't exist after deletion)
- Always log AFTER creating/updating entities (so they have valid data)
- Capture before values for updates
- Use meaningful operation descriptions
- Track which fields changed
- Handle errors appropriately
*/