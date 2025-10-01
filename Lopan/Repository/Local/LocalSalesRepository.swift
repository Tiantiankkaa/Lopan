//
//  LocalSalesRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/01.
//

import Foundation
import SwiftData

@MainActor
final class LocalSalesRepository: SalesRepository {
    private let modelContext: ModelContext
    private let calendar = Calendar.current

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSalesEntries(forDate date: Date) async throws -> [DailySalesEntry] {
        let normalizedDate = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: normalizedDate)!

        print("🔍 LocalSalesRepository: Fetching entries for date range \(normalizedDate) to \(nextDay)")

        let predicate = #Predicate<DailySalesEntry> { entry in
            entry.date >= normalizedDate && entry.date < nextDay
        }

        var descriptor = FetchDescriptor<DailySalesEntry>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]

        let results = try modelContext.fetch(descriptor)
        print("📦 LocalSalesRepository: Found \(results.count) entries")
        return results
    }

    func fetchSalesEntries(from startDate: Date, to endDate: Date, salespersonId: String) async throws -> [DailySalesEntry] {
        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!

        print("🔍 LocalSalesRepository: Fetching entries for salesperson \(salespersonId)")
        print("   Date range: \(normalizedStartDate) to \(normalizedEndDate)")

        let predicate = #Predicate<DailySalesEntry> { entry in
            entry.date >= normalizedStartDate &&
            entry.date < normalizedEndDate &&
            entry.salespersonId == salespersonId
        }

        var descriptor = FetchDescriptor<DailySalesEntry>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]

        let results = try modelContext.fetch(descriptor)
        print("📦 LocalSalesRepository: Found \(results.count) entries for salesperson")
        results.forEach { entry in
            print("   ✅ Entry \(entry.id): date=\(entry.date), items=\(entry.items?.count ?? 0), total=₦\(entry.totalAmount)")
        }
        return results
    }

    func createSalesEntry(_ entry: DailySalesEntry) async throws {
        print("💾 LocalSalesRepository: Inserting sales entry \(entry.id)")
        print("   Date: \(entry.date)")
        print("   Salesperson: \(entry.salespersonId)")
        print("   Line items: \(entry.items?.count ?? 0)")
        entry.items?.forEach { item in
            print("     - \(item.productName): \(item.quantity) @ ₦\(item.unitPrice)")
        }

        // Insert parent
        modelContext.insert(entry)

        // CRITICAL FIX: Explicitly insert children until @Relationship cascade is active
        // This ensures line items are persisted even if @Relationship isn't working yet
        if let items = entry.items {
            print("📦 Explicitly inserting \(items.count) line items into context")

            // DUPLICATE DETECTION: Track inserted IDs to prevent duplicates
            var insertedIds = Set<String>()
            var duplicateCount = 0

            for (index, item) in items.enumerated() {
                if insertedIds.contains(item.id) {
                    print("  ⚠️ DUPLICATE ID DETECTED at index \(index): \(item.id)")
                    print("     This item will be SKIPPED to prevent save failure")
                    duplicateCount += 1
                    continue  // Skip duplicate
                }

                modelContext.insert(item)
                insertedIds.insert(item.id)
                print("  ✅ Inserted item \(index + 1): \(item.id)")
            }

            if duplicateCount > 0 {
                print("⚠️ WARNING: Skipped \(duplicateCount) duplicate item(s)")
                print("   This indicates a bug in the form state management")
            }
        }

        try modelContext.save()
        print("✅ LocalSalesRepository: modelContext.save() completed")

        // DIAGNOSTIC: Check ModelContext configuration
        print("📊 ModelContext Configuration:")
        if let config = modelContext.container.configurations.first {
            print("   Is in-memory: \(config.isStoredInMemoryOnly)")
            print("   Store URL: \(config.url.absoluteString)")
            print("   CloudKit: \(config.cloudKitDatabase != nil ? "Enabled" : "Disabled")")
        } else {
            print("   ⚠️ No configuration found!")
        }

        // Force context to process all pending changes
        print("🔄 Processing pending changes...")
        modelContext.processPendingChanges()

        // DIAGNOSTIC: Count ALL entries in database
        print("🗄️ Checking total entries in database...")
        let allDescriptor = FetchDescriptor<DailySalesEntry>()
        let allEntries = try modelContext.fetch(allDescriptor)
        print("   Total DailySalesEntry records: \(allEntries.count)")
        if allEntries.count > 0 {
            print("   Latest entry IDs:")
            allEntries.prefix(3).forEach { e in
                print("     - \(e.id): \(e.items?.count ?? 0) items")
            }
        }

        // IMMEDIATE VERIFICATION: Query back to confirm persistence
        print("🔍 VERIFICATION: Querying entry immediately after save...")
        let entryId = entry.id
        let predicate = #Predicate<DailySalesEntry> { e in
            e.id == entryId
        }
        var descriptor = FetchDescriptor<DailySalesEntry>(predicate: predicate)
        descriptor.fetchLimit = 1
        let verificationResults = try modelContext.fetch(descriptor)

        if let verified = verificationResults.first {
            let itemCount = verified.items?.count ?? 0
            print("✅ VERIFIED: Entry \(verified.id) persisted")
            print("   Items count: \(itemCount)")
            print("   Total amount: ₦\(verified.totalAmount)")

            if itemCount == 0 && entry.items?.count ?? 0 > 0 {
                print("⚠️ WARNING: Entry saved but items were NOT persisted!")
                print("   Expected \(entry.items?.count ?? 0) items but found \(itemCount)")
                print("   This indicates @Relationship cascade is not working.")
                print("   App needs complete restart to activate @Relationship macro.")
            }
        } else {
            print("❌ CRITICAL ERROR: Entry NOT found in database after save!")
            throw RepositoryError.saveFailed("Saved entry not found in verification query")
        }
    }

    func updateSalesEntry(_ entry: DailySalesEntry) async throws {
        entry.updatedAt = Date()
        try modelContext.save()
    }

    func deleteSalesEntry(id: String) async throws {
        let predicate = #Predicate<DailySalesEntry> { entry in
            entry.id == id
        }

        let descriptor = FetchDescriptor<DailySalesEntry>(predicate: predicate)
        let entries = try modelContext.fetch(descriptor)

        guard let entry = entries.first else {
            throw RepositoryError.notFound("Sales entry with id \(id) not found")
        }

        modelContext.delete(entry)
        try modelContext.save()
    }

    func calculateDailySalesTotal(forDate date: Date, salespersonId: String) async throws -> Decimal {
        let entries = try await fetchSalesEntries(forDate: date)
        let salespersonEntries = entries.filter { $0.salespersonId == salespersonId }

        return salespersonEntries.reduce(Decimal(0)) { total, entry in
            total + entry.totalAmount
        }
    }
}
