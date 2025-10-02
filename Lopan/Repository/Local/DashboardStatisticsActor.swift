//
//  DashboardStatisticsActor.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/02.
//

import Foundation
import SwiftData

/// ModelActor for computing dashboard statistics using targeted queries
/// Only fetches recent records (last 90 days) to avoid loading all historical data
@ModelActor
actor DashboardStatisticsActor {

    /// Compute complete dashboard metrics using smart date-filtered queries
    /// Fetches only recent data (last 90 days) to minimize memory and improve speed
    func computeDashboardMetrics() async throws -> DashboardMetrics {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("📊 [DashboardActor] Computing metrics with date-filtered queries...")

        let calendar = Calendar.current
        let now = Date()

        // Calculate date thresholds
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now),
              let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) else {
            throw NSError(domain: "DashboardStatisticsActor", code: 4001,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to calculate date thresholds"])
        }

        try Task.checkCancellation()

        // OPTIMIZED: Only fetch recent records (last 90 days)
        // Dashboard doesn't need ancient historical data
        print("📊 [DashboardActor] Fetching records from last 90 days...")

        let recentRecordsDescriptor = FetchDescriptor<CustomerOutOfStock>(
            predicate: #Predicate<CustomerOutOfStock> { record in
                record.requestDate >= ninetyDaysAgo
            },
            sortBy: [SortDescriptor(\.requestDate, order: .reverse)]
        )
        let recentRecords = try modelContext.fetch(recentRecordsDescriptor)

        print("📊 [DashboardActor] Processing \(recentRecords.count) recent records...")

        // Count by status in memory (can't use predicate for enum)
        var statusCounts: [OutOfStockStatus: Int] = [:]
        for record in recentRecords {
            statusCounts[record.status, default: 0] += 1
        }

        // Filter to pending/partial only for date categorization
        let pendingOrPartial = recentRecords.filter {
            $0.status == .pending || $0.hasPartialDelivery
        }

        try Task.checkCancellation()

        // Categorize pending/partial by date ranges
        var recentPendingCount = 0
        var dueSoonCount = 0
        var overdueCount = 0
        var needsReturnCount = 0

        var recentPendingItems: [OutOfStockDisplayItem] = []
        var returnItems: [OutOfStockDisplayItem] = []

        for record in pendingOrPartial {
            // Categorize by date
            if record.requestDate >= sevenDaysAgo {
                recentPendingCount += 1
                if recentPendingItems.count < 50 {
                    // Convert to DTO while in ModelContext
                    recentPendingItems.append(OutOfStockDisplayItem(from: record))
                }
            } else if record.requestDate >= fourteenDaysAgo {
                dueSoonCount += 1
            } else {
                overdueCount += 1
            }

            // Count needs return (pending with remainingQuantity > 0)
            if record.status == .pending && record.remainingQuantity > 0 {
                needsReturnCount += 1
                if returnItems.count < 10 {
                    // Convert to DTO while in ModelContext
                    returnItems.append(OutOfStockDisplayItem(from: record))
                }
            }
        }

        // Sort recent pending by date descending (already sorted from query)
        recentPendingItems = Array(recentPendingItems.prefix(50))

        // Sort return items by date descending
        returnItems = returnItems.sorted { $0.requestDate > $1.requestDate }.prefix(10).map { $0 }

        try Task.checkCancellation()

        // Fetch recently completed items from recentRecords and convert to DTOs
        let completedItems: [OutOfStockDisplayItem] = recentRecords
            .filter { $0.status == .completed }
            .sorted { ($0.actualCompletionDate ?? $0.updatedAt) > ($1.actualCompletionDate ?? $1.updatedAt) }
            .prefix(10)
            .map { OutOfStockDisplayItem(from: $0) }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("📊 [DashboardActor] ✅ Metrics computed in \(String(format: "%.3f", elapsed))s")
        print("   Recent records (90 days): \(recentRecords.count)")
        print("   Status counts - Pending: \(statusCounts[.pending] ?? 0), Completed: \(statusCounts[.completed] ?? 0), Refunded: \(statusCounts[.refunded] ?? 0)")
        print("   Date ranges - Recent: \(recentPendingCount), Due: \(dueSoonCount), Overdue: \(overdueCount)")
        print("   Display items - Pending: \(recentPendingItems.count), Return: \(returnItems.count), Completed: \(completedItems.count)")

        return DashboardMetrics(
            statusCounts: statusCounts,
            needsReturnCount: needsReturnCount,
            recentPendingCount: recentPendingCount,
            dueSoonCount: dueSoonCount,
            overdueCount: overdueCount,
            topPendingItems: Array(recentPendingItems),
            topReturnItems: Array(returnItems),
            recentCompleted: Array(completedItems)
        )
    }
}
