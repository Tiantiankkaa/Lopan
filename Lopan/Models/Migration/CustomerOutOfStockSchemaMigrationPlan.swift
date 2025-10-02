//
//  CustomerOutOfStockSchemaMigrationPlan.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/02.
//  Migration plan for semantic refactoring: returnQuantity → deliveryQuantity
//

import Foundation
import SwiftData

enum CustomerOutOfStockMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            CustomerOutOfStockSchemaV1.self,
            CustomerOutOfStockSchemaV2.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            migrateV1toV2
        ]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: CustomerOutOfStockSchemaV1.self,
        toVersion: CustomerOutOfStockSchemaV2.self,
        willMigrate: { context in
            print("🔄 Starting migration from V1 to V2...")
            print("   Mapping: returnQuantity → deliveryQuantity")
            print("   Mapping: returnDate → deliveryDate")
            print("   Mapping: returnNotes → deliveryNotes")
        },
        didMigrate: { context in
            print("✅ Migration from V1 to V2 completed successfully")

            // Verify migration
            let descriptor = FetchDescriptor<CustomerOutOfStock>()
            if let records = try? context.fetch(descriptor) {
                print("   Migrated \(records.count) CustomerOutOfStock records")
            }
        }
    )
}
