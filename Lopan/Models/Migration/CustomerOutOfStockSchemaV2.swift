//
//  CustomerOutOfStockSchemaV2.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/02.
//  Schema V2 - After semantic refactoring (deliveryQuantity, deliveryDate, deliveryNotes)
//

import Foundation
import SwiftData

enum CustomerOutOfStockSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [
            CustomerOutOfStock.self,
            Customer.self,
            Product.self,
            ProductSize.self,
            User.self,
            ProductionStyle.self,
            WorkshopProduction.self,
            EVAGranulation.self,
            WorkshopIssue.self,
            PackagingRecord.self,
            PackagingTeam.self,
            AuditLog.self,
            Item.self,
            WorkshopMachine.self,
            WorkshopStation.self,
            WorkshopGun.self,
            ColorCard.self,
            ProductionBatch.self,
            ProductConfig.self,
            DailySalesEntry.self,
            SalesLineItem.self
        ]
    }

    // CustomerOutOfStock is the current version in Models/CustomerOutOfStock.swift
    // with deliveryQuantity, deliveryDate, deliveryNotes
}
