//
//  ProgressiveDataLoader.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/28.
//  Progressive data loading system for optimized dashboard performance
//

import Foundation
import SwiftUI
import os

// MARK: - Helper Types

private struct PaginationResult {
    let items: [CustomerOutOfStock]
    let totalCount: Int
    let hasMoreData: Bool
}

// MARK: - Progressive Data Loader

@MainActor
final class ProgressiveDataLoader: ObservableObject {

    // MARK: - Published Properties

    @Published var items: [CustomerOutOfStock] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreData = true
    @Published var totalCount = 0
    @Published var error: Error?

    // MARK: - Progressive Loading State

    @Published var loadingStage: LoadingStage = .initial
    @Published var progressPercentage: Double = 0.0
    @Published var estimatedItemHeight: CGFloat = 80.0

    // MARK: - Private Properties

    private let coordinator: CustomerOutOfStockCoordinator
    private let logger = Logger(subsystem: "com.lopan.app", category: "ProgressiveDataLoader")

    private var currentCriteria: OutOfStockFilterCriteria?
    private var loadingTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?

    // Progressive loading configuration
    private let initialBatchSize = 20
    private let normalBatchSize = 50
    private let prefetchThreshold = 10 // Start prefetching when 10 items from end
    private let maxPrefetchPages = 2

    // Performance tracking
    private var loadStartTime: Date?
    private var batchLoadTimes: [TimeInterval] = []

    // MARK: - Loading Stages

    enum LoadingStage: CaseIterable {
        case initial
        case loadingFirstBatch
        case loadingSubsequentBatches
        case prefetching
        case completed
        case error

        var description: String {
            switch self {
            case .initial:
                return "Preparing to load data..."
            case .loadingFirstBatch:
                return "Loading initial items..."
            case .loadingSubsequentBatches:
                return "Loading more items..."
            case .prefetching:
                return "Optimizing future scrolling..."
            case .completed:
                return "All data loaded"
            case .error:
                return "Loading failed"
            }
        }
    }

    // MARK: - Initialization

    init(coordinator: CustomerOutOfStockCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - Public Interface

    func loadData(criteria: OutOfStockFilterCriteria) {
        // Cancel any existing loading
        loadingTask?.cancel()
        prefetchTask?.cancel()

        // Reset state
        resetState()
        currentCriteria = criteria

        // Start progressive loading
        loadingTask = Task {
            await performProgressiveLoad(criteria: criteria)
        }
    }

    func loadNextPage() {
        guard let criteria = currentCriteria,
              hasMoreData && !isLoadingMore else {
            return
        }

        let nextPageCriteria = OutOfStockFilterCriteria(
            customer: criteria.customer,
            product: criteria.product,
            status: criteria.status,
            dateRange: criteria.dateRange,
            searchText: criteria.searchText,
            page: items.count / normalBatchSize,
            pageSize: normalBatchSize,
            sortOrder: criteria.sortOrder
        )

        Task {
            await loadBatch(criteria: nextPageCriteria, append: true)
        }
    }

    func shouldTriggerPrefetch(for index: Int) -> Bool {
        return index >= items.count - prefetchThreshold && hasMoreData && !isLoadingMore
    }

    // MARK: - Progressive Loading Implementation

    private func performProgressiveLoad(criteria: OutOfStockFilterCriteria) async {
        loadStartTime = Date()

        do {
            // Stage 1: Load first batch (smaller for faster perceived performance)
            await updateLoadingStage(.loadingFirstBatch, progress: 0.1)

            let firstBatchCriteria = OutOfStockFilterCriteria(
                customer: criteria.customer,
                product: criteria.product,
                status: criteria.status,
                dateRange: criteria.dateRange,
                searchText: criteria.searchText,
                page: 0,
                pageSize: initialBatchSize,
                sortOrder: criteria.sortOrder
            )

            await loadBatch(criteria: firstBatchCriteria, append: false)

            // Early exit if no data or task cancelled
            guard !Task.isCancelled && totalCount > 0 else { return }

            await updateLoadingStage(.loadingSubsequentBatches, progress: 0.3)

            // Stage 2: Load subsequent batches progressively
            await loadRemainingBatches(baseCriteria: criteria)

            // Stage 3: Start prefetching if needed
            if hasMoreData {
                await updateLoadingStage(.prefetching, progress: 0.9)
                startPrefetching(baseCriteria: criteria)
            }

            await updateLoadingStage(.completed, progress: 1.0)

        } catch {
            await updateLoadingStage(.error, progress: 0.0)
            self.error = error
            logger.safeError("Progressive loading failed", error: error)
        }
    }

    private func loadBatch(criteria: OutOfStockFilterCriteria, append: Bool) async {
        let batchStartTime = Date()

        if append {
            isLoadingMore = true
        } else {
            isLoading = true
        }

        do {
            // Load batch through coordinator's public interface
            await coordinator.loadFilteredItems(criteria: criteria, resetPagination: !append)

            // Get the updated items from coordinator
            let result = PaginationResult(
                items: coordinator.items,
                totalCount: coordinator.totalRecordsCount,
                hasMoreData: coordinator.hasMoreData
            )

            // Update state
            if append {
                items.append(contentsOf: result.items)
            } else {
                items = result.items
                totalCount = result.totalCount
            }

            hasMoreData = result.hasMoreData

            // Track performance
            let loadTime = Date().timeIntervalSince(batchStartTime)
            batchLoadTimes.append(loadTime)

            // Update progress
            let loadedRatio = Double(items.count) / Double(max(1, totalCount))
            await updateProgress(loadedRatio)

            logger.safeInfo("Batch loaded", [
                "append": String(append),
                "itemsLoaded": String(result.items.count),
                "totalItems": String(items.count),
                "totalCount": String(totalCount),
                "loadTime": String(format: "%.3f", loadTime)
            ])

        } catch {
            self.error = error
            logger.safeError("Batch loading failed", error: error)
        }

        isLoading = false
        isLoadingMore = false
    }

    private func loadRemainingBatches(baseCriteria: OutOfStockFilterCriteria) async {
        let totalPages = max(1, (totalCount + normalBatchSize - 1) / normalBatchSize)

        for page in 1..<totalPages {
            // Check for cancellation
            guard !Task.isCancelled else { break }

            let batchCriteria = OutOfStockFilterCriteria(
                customer: baseCriteria.customer,
                product: baseCriteria.product,
                status: baseCriteria.status,
                dateRange: baseCriteria.dateRange,
                searchText: baseCriteria.searchText,
                page: page,
                pageSize: normalBatchSize,
                sortOrder: baseCriteria.sortOrder
            )

            await loadBatch(criteria: batchCriteria, append: true)

            // Progressive delay to maintain responsiveness
            let adaptiveDelay = calculateAdaptiveDelay(page: page)
            try? await Task.sleep(nanoseconds: UInt64(adaptiveDelay * 1_000_000_000))
        }
    }

    private func startPrefetching(baseCriteria: OutOfStockFilterCriteria) {
        prefetchTask?.cancel()

        prefetchTask = Task {
            let currentPage = items.count / normalBatchSize

            for prefetchPage in 1...maxPrefetchPages {
                guard !Task.isCancelled && hasMoreData else { break }

                let prefetchCriteria = OutOfStockFilterCriteria(
                    customer: baseCriteria.customer,
                    product: baseCriteria.product,
                    status: baseCriteria.status,
                    dateRange: baseCriteria.dateRange,
                    searchText: baseCriteria.searchText,
                    page: currentPage + prefetchPage,
                    pageSize: normalBatchSize,
                    sortOrder: baseCriteria.sortOrder
                )

                // Prefetch data through coordinator's public interface
                // Note: Using coordinator's public methods instead of direct cache access
                await coordinator.loadFilteredItems(criteria: prefetchCriteria, resetPagination: true)

                // Longer delay for prefetching to not interfere with user interaction
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }

    // MARK: - Helper Methods

    private func resetState() {
        items.removeAll()
        isLoading = false
        isLoadingMore = false
        hasMoreData = true
        totalCount = 0
        error = nil
        loadingStage = .initial
        progressPercentage = 0.0
        batchLoadTimes.removeAll()
    }

    private func updateLoadingStage(_ stage: LoadingStage, progress: Double) async {
        loadingStage = stage
        progressPercentage = progress
    }

    private func updateProgress(_ progress: Double) async {
        let clampedProgress = min(1.0, max(0.0, progress))
        progressPercentage = clampedProgress
    }

    private func calculateAdaptiveDelay(page: Int) -> TimeInterval {
        // Calculate adaptive delay based on loading performance
        let averageLoadTime = batchLoadTimes.isEmpty ? 0.1 : batchLoadTimes.reduce(0, +) / Double(batchLoadTimes.count)

        // Base delay starts small and increases for later pages
        let baseDelay = 0.05 + (Double(page) * 0.01)

        // Adjust based on performance
        let performanceMultiplier = averageLoadTime > 0.5 ? 2.0 : 1.0

        return min(0.3, baseDelay * performanceMultiplier)
    }

    // MARK: - Performance Metrics

    func getPerformanceMetrics() -> ProgressiveLoadingMetrics {
        let totalLoadTime = loadStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let averageBatchTime = batchLoadTimes.isEmpty ? 0 : batchLoadTimes.reduce(0, +) / Double(batchLoadTimes.count)

        return ProgressiveLoadingMetrics(
            totalItems: items.count,
            totalLoadTime: totalLoadTime,
            averageBatchTime: averageBatchTime,
            batchCount: batchLoadTimes.count,
            currentStage: loadingStage
        )
    }
}

// MARK: - Performance Metrics

struct ProgressiveLoadingMetrics {
    let totalItems: Int
    let totalLoadTime: TimeInterval
    let averageBatchTime: TimeInterval
    let batchCount: Int
    let currentStage: ProgressiveDataLoader.LoadingStage
}

// MARK: - Notes
// Cache prefetching is handled through the coordinator's public interface
// to maintain proper encapsulation and avoid accessing private services