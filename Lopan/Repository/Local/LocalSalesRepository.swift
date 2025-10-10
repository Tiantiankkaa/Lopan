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

        // In demo mode, show ALL sales regardless of who created them
        // This handles cases where sample data was generated before demo user ID fix
        let results: [DailySalesEntry]

        if salespersonId.hasPrefix("demo-user-") {
            // Demo mode: fetch ALL entries without salesperson filter
            print("   🎭 Demo mode: Fetching ALL sales entries for visibility")
            let predicate = #Predicate<DailySalesEntry> { entry in
                entry.date >= normalizedStartDate &&
                entry.date < normalizedEndDate
            }

            var descriptor = FetchDescriptor<DailySalesEntry>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
            results = try modelContext.fetch(descriptor)
        } else {
            // Production mode: filter by exact salesperson ID
            let predicate = #Predicate<DailySalesEntry> { entry in
                entry.date >= normalizedStartDate &&
                entry.date < normalizedEndDate &&
                entry.salespersonId == salespersonId
            }

            var descriptor = FetchDescriptor<DailySalesEntry>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
            results = try modelContext.fetch(descriptor)
        }

        print("📦 LocalSalesRepository: Found \(results.count) entries for salesperson")
        results.forEach { entry in
            print("   ✅ Entry \(entry.id): date=\(entry.date), salesperson=\(entry.salespersonId), items=\(entry.items?.count ?? 0), total=₦\(entry.totalAmount)")
        }
        return results
    }

    func createSalesEntry(_ entry: DailySalesEntry) async throws {
        // Insert parent
        modelContext.insert(entry)

        // Explicitly insert line items (SwiftData @Relationship cascade may not be active)
        if let items = entry.items {
            for item in items {
                modelContext.insert(item)
            }
        }

        try modelContext.save()
    }

    func createSalesEntries(_ entries: [DailySalesEntry]) async throws {
        // Insert all entries and their line items
        for entry in entries {
            modelContext.insert(entry)

            // Explicitly insert line items for each entry
            if let items = entry.items {
                for item in items {
                    modelContext.insert(item)
                }
            }
        }

        // Save ONCE for entire batch (MUCH faster!)
        try modelContext.save()
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

        // In demo mode, show ALL sales regardless of who created them
        // This handles cases where sample data was generated before demo user ID fix
        let salespersonEntries: [DailySalesEntry]

        if salespersonId.hasPrefix("demo-user-") {
            // Demo mode: show ALL sales for visibility during testing
            salespersonEntries = entries
        } else {
            // Production mode: filter by exact salesperson ID
            salespersonEntries = entries.filter { entry in
                entry.salespersonId == salespersonId
            }
        }

        return salespersonEntries.reduce(Decimal(0)) { total, entry in
            total + entry.totalAmount
        }
    }
}
