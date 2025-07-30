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
    
    /// Example: Adding audit logging to CREATE operations
    func createCustomerOutOfStock(
        customer: Customer?,
        product: Product?,
        quantity: Int,
        priority: OutOfStockPriority,
        notes: String?,
        modelContext: ModelContext
    ) {
        // Create the new item
        let newItem = CustomerOutOfStock(
            customer: customer,
            product: product,
            quantity: quantity,
            priority: priority,
            notes: notes,
            createdBy: "demo_user" // TODO: Get from current user
        )
        
        // Insert into context
        modelContext.insert(newItem)
        
        // Log the creation AFTER inserting but BEFORE saving
        AuditingService.shared.logCustomerOutOfStockCreation(
            item: newItem,
            operatorUserId: "demo_user", // TODO: Get from authentication service
            operatorUserName: "演示用户", // TODO: Get from authentication service
            modelContext: modelContext
        )
        
        // Save the context
        do {
            try modelContext.save()
        } catch {
            print("Error saving new item: \(error)")
        }
    }
    
    /// Example: Adding audit logging to UPDATE operations
    func updateCustomerOutOfStock(
        item: CustomerOutOfStock,
        newQuantity: Int?,
        newPriority: OutOfStockPriority?,
        newNotes: String?,
        modelContext: ModelContext
    ) {
        // Capture values before update for audit log
        let beforeValues = CustomerOutOfStockOperation.CustomerOutOfStockValues(
            customerName: item.customer?.name,
            productName: item.product?.name,
            quantity: item.quantity,
            priority: item.priority.displayName,
            status: item.status.displayName,
            notes: item.notes,
            returnQuantity: item.returnQuantity,
            returnNotes: item.returnNotes
        )
        
        // Track which fields changed
        var changedFields: [String] = []
        
        // Apply updates
        if let newQuantity = newQuantity, newQuantity != item.quantity {
            item.quantity = newQuantity
            changedFields.append("quantity")
        }
        
        if let newPriority = newPriority, newPriority != item.priority {
            item.priority = newPriority
            changedFields.append("priority")
        }
        
        if let newNotes = newNotes, newNotes != item.notes {
            item.notes = newNotes.isEmpty ? nil : newNotes
            changedFields.append("notes")
        }
        
        // Update timestamp
        item.updatedAt = Date()
        
        // Log the update if any fields changed
        if !changedFields.isEmpty {
            AuditingService.shared.logCustomerOutOfStockUpdate(
                item: item,
                beforeValues: beforeValues,
                changedFields: changedFields,
                operatorUserId: "demo_user", // TODO: Get from authentication service
                operatorUserName: "演示用户", // TODO: Get from authentication service
                modelContext: modelContext,
                additionalInfo: "字段更新: \(changedFields.joined(separator: ", "))"
            )
        }
        
        // Save the context
        do {
            try modelContext.save()
        } catch {
            print("Error updating item: \(error)")
        }
    }
    
    /// Example: Adding audit logging to RETURN PROCESSING operations
    func processReturn(
        item: CustomerOutOfStock,
        returnQuantity: Int,
        returnNotes: String?,
        modelContext: ModelContext
    ) {
        // Process the return using the existing method
        let success = item.processReturn(quantity: returnQuantity, notes: returnNotes)
        
        if success {
            // Log the return processing
            AuditingService.shared.logReturnProcessing(
                item: item,
                returnQuantity: returnQuantity,
                returnNotes: returnNotes,
                operatorUserId: "demo_user", // TODO: Get from authentication service
                operatorUserName: "演示用户", // TODO: Get from authentication service
                modelContext: modelContext
            )
            
            // Save the context
            do {
                try modelContext.save()
            } catch {
                print("Error processing return: \(error)")
            }
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
        quantity: Int,
        modelContext: ModelContext
    ) {
        let (userId, userName) = getCurrentUserInfo()
        
        let newItem = CustomerOutOfStock(
            customer: customer,
            product: product,
            quantity: quantity,
            createdBy: userId
        )
        
        modelContext.insert(newItem)
        
        AuditingService.shared.logCustomerOutOfStockCreation(
            item: newItem,
            operatorUserId: userId,
            operatorUserName: userName,
            modelContext: modelContext
        )
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving: \(error)")
        }
    }
}

/*
INTEGRATION CHECKLIST for adding audit logging to existing views:

1. Import the AuditingService (already available as shared instance)

2. For CREATE operations:
   - Create and insert the entity
   - Call AuditingService.shared.logCustomerOutOfStockCreation()
   - Save the context

3. For UPDATE operations:
   - Capture before values
   - Apply changes
   - Track changed fields
   - Call AuditingService.shared.logCustomerOutOfStockUpdate()
   - Save the context

4. For DELETE operations:
   - Call AuditingService.shared.logCustomerOutOfStockDeletion() BEFORE deleting
   - Delete the entity
   - Save the context

5. For STATUS CHANGES:
   - Call AuditingService.shared.logCustomerOutOfStockStatusChange()
   - Apply the status change
   - Save the context

6. For RETURN PROCESSING:
   - Call AuditingService.shared.logReturnProcessing()
   - Process the return
   - Save the context

7. For BATCH operations:
   - Call AuditingService.shared.logBatchOperation()
   - Apply the batch changes
   - Save the context

8. Get user information from AuthenticationService instead of hardcoded values

Remember:
- Always log BEFORE deleting entities (they won't exist after deletion)
- Always log AFTER creating/updating entities (so they have valid data)
- Capture before values for updates
- Use meaningful operation descriptions
- Track which fields changed
- Handle errors appropriately
*/