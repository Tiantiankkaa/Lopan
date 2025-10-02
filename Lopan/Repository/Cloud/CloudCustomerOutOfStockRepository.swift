//
//  CloudCustomerOutOfStockRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import Foundation

// MARK: - Cloud Customer Out of Stock Repository

final class CloudCustomerOutOfStockRepository: CustomerOutOfStockRepository, Sendable {
    private let cloudProvider: CloudProvider
    private let baseEndpoint = "/api/customer-out-of-stock"

    // PHASE 2: Local repository fallback for graceful degradation
    private let localFallback: CustomerOutOfStockRepository?

    init(cloudProvider: CloudProvider, localFallback: CustomerOutOfStockRepository? = nil) {
        self.cloudProvider = cloudProvider
        self.localFallback = localFallback
        print("🎯 CloudRepository: Initialized with \(localFallback != nil ? "local fallback" : "no fallback")")
    }
    
    // MARK: - Legacy Methods (maintained for backward compatibility)
    
    func fetchOutOfStockRecords() async throws -> [CustomerOutOfStock] {
        let criteria = OutOfStockFilterCriteria()
        let result = try await fetchOutOfStockRecords(criteria: criteria, page: 0, pageSize: 1000)
        return result.items
    }
    
    func fetchOutOfStockRecord(by id: String) async throws -> CustomerOutOfStock? {
        let endpoint = "\(baseEndpoint)/\(id)"
        let response = try await cloudProvider.get(endpoint: endpoint, type: CustomerOutOfStockDTO.self)
        
        guard response.success, let dto = response.data else {
            if let error = response.error {
                throw RepositoryError.notFound(error)
            }
            return nil
        }
        
        return try dto.toDomain()
    }
    
    func fetchOutOfStockRecords(for customer: Customer) async throws -> [CustomerOutOfStock] {
        let criteria = OutOfStockFilterCriteria(customer: customer)
        let result = try await fetchOutOfStockRecords(criteria: criteria, page: 0, pageSize: 1000)
        return result.items
    }
    
    func fetchOutOfStockRecords(for product: Product) async throws -> [CustomerOutOfStock] {
        let criteria = OutOfStockFilterCriteria(product: product)
        let result = try await fetchOutOfStockRecords(criteria: criteria, page: 0, pageSize: 1000)
        return result.items
    }
    
    // MARK: - New Paginated Methods
    
    func fetchOutOfStockRecords(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> OutOfStockPaginationResult {
        do {
            var endpoint = "\(baseEndpoint)/filtered?page=\(page)&pageSize=\(pageSize)"

            // Add filter parameters with proper encoding
            if let customerId = criteria.customer?.id {
                endpoint += "&customerId=\(customerId)"
            }
            if let productId = criteria.product?.id {
                endpoint += "&productId=\(productId)"
            }
            if let status = criteria.status {
                endpoint += "&status=\(status.rawValue)"
            }
            if !criteria.searchText.isEmpty {
                let encodedSearch = criteria.searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                endpoint += "&search=\(encodedSearch)"
            }
            if let dateRange = criteria.dateRange {
                let formatter = ISO8601DateFormatter()
                endpoint += "&startDate=\(formatter.string(from: dateRange.start))"
                endpoint += "&endDate=\(formatter.string(from: dateRange.end))"
            }

            let response = try await cloudProvider.getPaginated(
                endpoint: endpoint,
                type: CustomerOutOfStockDTO.self,
                page: page,
                pageSize: pageSize
            )

            guard response.success else {
                throw RepositoryError.connectionFailed(response.error ?? "Network request failed")
            }

            let entities = try response.items.compactMap { dto in
                try? dto.toDomain()
            }

            return OutOfStockPaginationResult(
                items: entities,
                totalCount: response.totalCount,
                hasMoreData: response.hasNextPage,
                page: page,
                pageSize: pageSize
            )
        } catch {
            // PHASE 2: Graceful fallback to local cache on network failure
            print("⚠️ Cloud fetch failed: \(error.localizedDescription), falling back to local cache...")
            return try await fallbackToLocal(criteria: criteria, page: page, pageSize: pageSize)
        }
    }

    // MARK: - Private Fallback Helper

    private func fallbackToLocal(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> OutOfStockPaginationResult {
        guard let fallback = localFallback else {
            print("❌ No local fallback available, throwing original error")
            throw RepositoryError.connectionFailed("Cloud unavailable and no local fallback configured")
        }

        print("🔄 Using local fallback repository...")
        return try await fallback.fetchOutOfStockRecords(criteria: criteria, page: page, pageSize: pageSize)
    }
    
    func countOutOfStockRecords(criteria: OutOfStockFilterCriteria) async throws -> Int {
        let endpoint = "\(baseEndpoint)/count"
        
        // Build query parameters for count
        var queryItems: [URLQueryItem] = []
        
        if let customerId = criteria.customer?.id {
            queryItems.append(URLQueryItem(name: "customerId", value: customerId))
        }
        if let productId = criteria.product?.id {
            queryItems.append(URLQueryItem(name: "productId", value: productId))
        }
        if let status = criteria.status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if !criteria.searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: criteria.searchText))
        }
        if let dateRange = criteria.dateRange {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: dateRange.start)))
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: dateRange.end)))
        }
        
        let fullEndpoint: String
        if !queryItems.isEmpty {
            var urlComponents = URLComponents(string: endpoint)
            urlComponents?.queryItems = queryItems
            fullEndpoint = urlComponents?.string ?? endpoint
        } else {
            fullEndpoint = endpoint
        }
        
        struct CountResponse: Codable {
            let count: Int
        }
        
        let response = try await cloudProvider.get(endpoint: fullEndpoint, type: CountResponse.self)
        
        guard response.success, let data = response.data else {
            throw RepositoryError.connectionFailed(response.error ?? "Count request failed")
        }
        
        return data.count
    }
    
    func countOutOfStockRecordsByStatus(criteria: OutOfStockFilterCriteria) async throws -> [OutOfStockStatus: Int] {
        let endpoint = "\(baseEndpoint)/analytics/status-counts"
        
        // Build query parameters for analytics
        var queryItems: [URLQueryItem] = []
        
        if let customerId = criteria.customer?.id {
            queryItems.append(URLQueryItem(name: "customerId", value: customerId))
        }
        if let productId = criteria.product?.id {
            queryItems.append(URLQueryItem(name: "productId", value: productId))
        }
        if !criteria.searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: criteria.searchText))
        }
        if let dateRange = criteria.dateRange {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: dateRange.start)))
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: dateRange.end)))
        }
        
        let fullEndpoint: String
        if !queryItems.isEmpty {
            var urlComponents = URLComponents(string: endpoint)
            urlComponents?.queryItems = queryItems
            fullEndpoint = urlComponents?.string ?? endpoint
        } else {
            fullEndpoint = endpoint
        }
        
        struct StatusCountResponse: Codable {
            let statusCounts: [String: Int]
        }
        
        let response = try await cloudProvider.get(endpoint: fullEndpoint, type: StatusCountResponse.self)
        
        guard response.success, let data = response.data else {
            throw RepositoryError.connectionFailed(response.error ?? "Status count request failed")
        }
        
        var result: [OutOfStockStatus: Int] = [:]
        for (statusString, count) in data.statusCounts {
            if let status = OutOfStockStatus(rawValue: statusString) {
                result[status] = count
            }
        }
        
        return result
    }

    func countPartialReturnRecords(criteria: OutOfStockFilterCriteria) async throws -> Int {
        let endpoint = "\(baseEndpoint)/analytics/partial-return-count"

        var queryItems: [URLQueryItem] = []

        if let customerId = criteria.customer?.id {
            queryItems.append(URLQueryItem(name: "customerId", value: customerId))
        }
        if let productId = criteria.product?.id {
            queryItems.append(URLQueryItem(name: "productId", value: productId))
        }
        if !criteria.searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: criteria.searchText))
        }
        if let dateRange = criteria.dateRange {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: dateRange.start)))
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: dateRange.end)))
        }

        if let status = criteria.status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }

        let fullEndpoint: String
        if !queryItems.isEmpty {
            var urlComponents = URLComponents(string: endpoint)
            urlComponents?.queryItems = queryItems
            fullEndpoint = urlComponents?.string ?? endpoint
        } else {
            fullEndpoint = endpoint
        }

        struct PartialCountResponse: Codable {
            let count: Int
        }

        let response = try await cloudProvider.get(endpoint: fullEndpoint, type: PartialCountResponse.self)

        if response.success, let data = response.data {
            return data.count
        }

        // Fallback: fetch first page and estimate partial count
        let fallback = try await fetchOutOfStockRecords(
            criteria: criteria,
            page: 0,
            pageSize: max(criteria.pageSize, 200)
        )
        let partialCount = fallback.items.filter { item in
            item.deliveryQuantity > 0 && item.deliveryQuantity < item.quantity
        }.count
        return partialCount
    }

    func countDueSoonRecords(criteria: OutOfStockFilterCriteria) async throws -> Int {
        let endpoint = "\(baseEndpoint)/analytics/due-soon-count"

        var queryItems: [URLQueryItem] = []

        if let customerId = criteria.customer?.id {
            queryItems.append(URLQueryItem(name: "customerId", value: customerId))
        }
        if let productId = criteria.product?.id {
            queryItems.append(URLQueryItem(name: "productId", value: productId))
        }
        if !criteria.searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: criteria.searchText))
        }
        if let dateRange = criteria.dateRange {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: dateRange.start)))
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: dateRange.end)))
        }

        let fullEndpoint: String
        if !queryItems.isEmpty {
            var urlComponents = URLComponents(string: endpoint)
            urlComponents?.queryItems = queryItems
            fullEndpoint = urlComponents?.string ?? endpoint
        } else {
            fullEndpoint = endpoint
        }

        struct DueSoonCountResponse: Codable {
            let count: Int
        }

        let response = try await cloudProvider.get(endpoint: fullEndpoint, type: DueSoonCountResponse.self)

        if response.success, let data = response.data {
            return data.count
        }

        // Fallback: use local repository if available
        if let fallback = localFallback {
            return try await fallback.countDueSoonRecords(criteria: criteria)
        }

        // Final fallback: return 0
        return 0
    }

    func countOverdueRecords(criteria: OutOfStockFilterCriteria) async throws -> Int {
        let endpoint = "\(baseEndpoint)/analytics/overdue-count"

        var queryItems: [URLQueryItem] = []

        if let customerId = criteria.customer?.id {
            queryItems.append(URLQueryItem(name: "customerId", value: customerId))
        }
        if let productId = criteria.product?.id {
            queryItems.append(URLQueryItem(name: "productId", value: productId))
        }
        if !criteria.searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: criteria.searchText))
        }
        if let dateRange = criteria.dateRange {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "startDate", value: formatter.string(from: dateRange.start)))
            queryItems.append(URLQueryItem(name: "endDate", value: formatter.string(from: dateRange.end)))
        }

        let fullEndpoint: String
        if !queryItems.isEmpty {
            var urlComponents = URLComponents(string: endpoint)
            urlComponents?.queryItems = queryItems
            fullEndpoint = urlComponents?.string ?? endpoint
        } else {
            fullEndpoint = endpoint
        }

        struct OverdueCountResponse: Codable {
            let count: Int
        }

        let response = try await cloudProvider.get(endpoint: fullEndpoint, type: OverdueCountResponse.self)

        if response.success, let data = response.data {
            return data.count
        }

        // Fallback: use local repository if available
        if let fallback = localFallback {
            return try await fallback.countOverdueRecords(criteria: criteria)
        }

        // Final fallback: return 0
        return 0
    }

    // MARK: - CRUD Operations
    
    func addOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        let dto = CustomerOutOfStockDTO(from: record)
        let response = try await cloudProvider.post(
            endpoint: baseEndpoint,
            body: dto,
            responseType: CustomerOutOfStockDTO.self
        )

        guard response.success else {
            throw RepositoryError.saveFailed(response.error ?? "Create operation failed")
        }

        // Notify observers of new record
        await MainActor.run {
            NotificationCenter.default.post(name: .outOfStockAdded, object: record)
        }
    }

    func addOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws {
        // Use existing batch create method for optimal performance
        _ = try await batchCreateRecords(records)

        // Notify observers of new records (single notification for batch)
        await MainActor.run {
            NotificationCenter.default.post(name: .outOfStockAdded, object: nil)
        }
    }
    
    func updateOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        let dto = CustomerOutOfStockDTO(from: record)
        let endpoint = "\(baseEndpoint)/\(record.id)"
        let response = try await cloudProvider.put(
            endpoint: endpoint,
            body: dto,
            responseType: CustomerOutOfStockDTO.self
        )

        guard response.success else {
            throw RepositoryError.saveFailed(response.error ?? "Update operation failed")
        }

        // Notify observers of updated record
        await MainActor.run {
            NotificationCenter.default.post(name: .outOfStockUpdated, object: record)
        }
    }
    
    func deleteOutOfStockRecord(_ record: CustomerOutOfStock) async throws {
        let endpoint = "\(baseEndpoint)/\(record.id)"
        let response = try await cloudProvider.delete(endpoint: endpoint)

        guard response.success else {
            throw RepositoryError.deleteFailed(response.error ?? "Delete operation failed")
        }

        // Notify observers of deletion
        await MainActor.run {
            NotificationCenter.default.post(name: .outOfStockUpdated, object: record)
        }
    }
    
    func deleteOutOfStockRecords(_ records: [CustomerOutOfStock]) async throws {
        let ids = records.map { $0.id }

        struct DeleteBatchRequest: Codable {
            let ids: [String]
        }

        let endpoint = "\(baseEndpoint)/batch/delete"
        let response = try await cloudProvider.post(
            endpoint: endpoint,
            body: DeleteBatchRequest(ids: ids),
            responseType: EmptyResponse.self
        )

        guard response.success else {
            throw RepositoryError.deleteFailed(response.error ?? "Batch delete operation failed")
        }

        // Notify observers of batch deletion (single notification)
        await MainActor.run {
            NotificationCenter.default.post(name: .outOfStockUpdated, object: nil)
        }
    }
    
    // MARK: - Batch Operations
    
    func batchCreateRecords(_ records: [CustomerOutOfStock]) async throws -> [CustomerOutOfStock] {
        let dtos = records.map { CustomerOutOfStockDTO(from: $0) }
        let endpoint = "\(baseEndpoint)/batch/create"
        
        let response = try await cloudProvider.post(
            endpoint: endpoint,
            body: dtos,
            responseType: [CustomerOutOfStockDTO].self
        )
        
        guard response.success, let responseDTOs = response.data else {
            throw RepositoryError.saveFailed(response.error ?? "Batch create operation failed")
        }
        
        return try responseDTOs.map { try $0.toDomain() }
    }
    
    func batchUpdateRecords(_ records: [CustomerOutOfStock]) async throws -> [CustomerOutOfStock] {
        let dtos = records.map { CustomerOutOfStockDTO(from: $0) }
        let endpoint = "\(baseEndpoint)/batch/update"
        
        let response = try await cloudProvider.post(
            endpoint: endpoint,
            body: dtos,
            responseType: [CustomerOutOfStockDTO].self
        )
        
        guard response.success, let responseDTOs = response.data else {
            throw RepositoryError.saveFailed(response.error ?? "Batch update operation failed")
        }
        
        return try responseDTOs.map { try $0.toDomain() }
    }
    
    // MARK: - Sync Operations
    
    func syncWithCloud() async throws -> CloudSyncStatus {
        let endpoint = "\(baseEndpoint)/sync/status"
        let response = try await cloudProvider.get(endpoint: endpoint, type: CloudSyncStatus.self)
        
        guard response.success, let syncStatus = response.data else {
            throw RepositoryError.connectionFailed(response.error ?? "Sync status request failed")
        }
        
        return syncStatus
    }
    
    func pushPendingChanges(_ records: [CustomerOutOfStock]) async throws {
        let dtos = records.map { CustomerOutOfStockDTO(from: $0) }
        let endpoint = "\(baseEndpoint)/sync/push"
        
        let response = try await cloudProvider.post(
            endpoint: endpoint,
            body: dtos,
            responseType: EmptyResponse.self
        )
        
        guard response.success else {
            throw RepositoryError.saveFailed(response.error ?? "Push operation failed")
        }
    }
}

// MARK: - Cloud Provider Protocol Extension

extension CloudCustomerOutOfStockRepository {
    
    // MARK: - Health Check
    
    func healthCheck() async throws -> Bool {
        let endpoint = "\(baseEndpoint)/health"
        
        do {
            struct HealthResponse: Codable {
                let status: String
                let timestamp: Date
            }
            
            let response = try await cloudProvider.get(endpoint: endpoint, type: HealthResponse.self)
            return response.success && response.data?.status == "healthy"
        } catch {
            throw RepositoryError.connectionFailed("Health check failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cache Invalidation
    
    func invalidateCloudCache() async throws {
        let endpoint = "\(baseEndpoint)/cache/invalidate"
        let response = try await cloudProvider.post(endpoint: endpoint, body: EmptyResponse(), responseType: EmptyResponse.self)
        
        guard response.success else {
            throw RepositoryError.unknownError(NSError(
                domain: "CloudCache",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.error ?? "Cache invalidation failed"]
            ))
        }
    }
    
    func invalidateCloudCache(for id: String) async throws {
        let endpoint = "\(baseEndpoint)/cache/invalidate/\(id)"
        let response = try await cloudProvider.delete(endpoint: endpoint)

        guard response.success else {
            throw RepositoryError.unknownError(NSError(
                domain: "CloudCache",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.error ?? "Cache invalidation failed"]
            ))
        }
    }

    // MARK: - OPTIMIZED Dashboard Metrics

    /// Single-pass dashboard metrics calculation - calls dedicated cloud endpoint
    func fetchDashboardMetrics() async throws -> DashboardMetrics {
        let endpoint = "\(baseEndpoint)/analytics/dashboard-metrics"

        do {
            let response = try await cloudProvider.get(endpoint: endpoint, type: DashboardMetricsDTO.self)

            guard response.success, let dto = response.data else {
                // Fall back to local if available
                if let localRepo = localFallback {
                    print("☁️ CloudRepository: Dashboard metrics failed, using local fallback")
                    return try await localRepo.fetchDashboardMetrics()
                }
                throw RepositoryError.serverError(response.error ?? "Failed to fetch dashboard metrics")
            }

            return try dto.toDomain()

        } catch {
            // Fall back to local if available
            if let localRepo = localFallback {
                print("☁️ CloudRepository: Dashboard metrics error, using local fallback: \(error)")
                return try await localRepo.fetchDashboardMetrics()
            }
            throw error
        }
    }

    // MARK: - OPTIMIZED Delivery Management Metrics

    /// Single-pass delivery management metrics calculation - calls dedicated cloud endpoint
    func fetchDeliveryManagementMetrics(
        criteria: OutOfStockFilterCriteria,
        page: Int,
        pageSize: Int
    ) async throws -> DeliveryManagementMetrics {
        // Build query string
        var queryParams: [String] = [
            "page=\(page)",
            "pageSize=\(pageSize)"
        ]

        if let status = criteria.status {
            queryParams.append("status=\(status.rawValue)")
        }
        if let customer = criteria.customer {
            queryParams.append("customerId=\(customer.id)")
        }
        if let product = criteria.product {
            queryParams.append("productId=\(product.id)")
        }
        if !criteria.searchText.isEmpty {
            if let encoded = criteria.searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                queryParams.append("search=\(encoded)")
            }
        }
        if let dateRange = criteria.dateRange {
            let formatter = ISO8601DateFormatter()
            queryParams.append("startDate=\(formatter.string(from: dateRange.start))")
            queryParams.append("endDate=\(formatter.string(from: dateRange.end))")
        }

        let endpoint = "\(baseEndpoint)/analytics/delivery-management-metrics?\(queryParams.joined(separator: "&"))"

        do {
            let response = try await cloudProvider.get(endpoint: endpoint, type: DeliveryManagementMetricsDTO.self)

            guard response.success, let dto = response.data else {
                // Fall back to local if available
                if let localRepo = localFallback {
                    print("☁️ CloudRepository: Delivery management metrics failed, using local fallback")
                    return try await localRepo.fetchDeliveryManagementMetrics(criteria: criteria, page: page, pageSize: pageSize)
                }
                throw RepositoryError.connectionFailed(response.error ?? "Failed to fetch delivery management metrics")
            }

            return try dto.toDomain()

        } catch {
            // Fall back to local if available
            if let localRepo = localFallback {
                print("☁️ CloudRepository: Delivery management metrics error, using local fallback: \(error)")
                return try await localRepo.fetchDeliveryManagementMetrics(criteria: criteria, page: page, pageSize: pageSize)
            }
            throw error
        }
    }

    // MARK: - Background Statistics

    func fetchDeliveryStatistics(
        criteria: OutOfStockFilterCriteria
    ) async throws -> DeliveryStatistics {
        // For cloud implementation, fall back to local repository
        // Cloud API would need a separate endpoint for statistics only
        if let localRepo = localFallback {
            print("☁️ CloudRepository: Using local fallback for delivery statistics")
            return try await localRepo.fetchDeliveryStatistics(criteria: criteria)
        }

        // If no local fallback, return empty statistics
        return DeliveryStatistics(
            totalCount: 0,
            needsDeliveryCount: 0,
            partialDeliveryCount: 0,
            completedDeliveryCount: 0
        )
    }
}

// MARK: - Dashboard Metrics DTO

private struct DashboardMetricsDTO: Codable {
    let statusCounts: [String: Int]
    let needsReturnCount: Int
    let recentPendingCount: Int?  // Optional for backward compatibility
    let dueSoonCount: Int
    let overdueCount: Int
    let topPendingItems: [CustomerOutOfStockDTO]
    let topReturnItems: [CustomerOutOfStockDTO]
    let recentCompleted: [CustomerOutOfStockDTO]

    func toDomain() throws -> DashboardMetrics {
        // Convert string keys to OutOfStockStatus enum
        var domainStatusCounts: [OutOfStockStatus: Int] = [:]
        for (key, value) in statusCounts {
            if let status = OutOfStockStatus(rawValue: key) {
                domainStatusCounts[status] = value
            }
        }

        // Convert DTOs to display items (not full SwiftData models to avoid context issues)
        let pendingItems = try topPendingItems.map { OutOfStockDisplayItem(from: try $0.toDomain()) }
        let returnItems = try topReturnItems.map { OutOfStockDisplayItem(from: try $0.toDomain()) }
        let completedItems = try recentCompleted.map { OutOfStockDisplayItem(from: try $0.toDomain()) }

        return DashboardMetrics(
            statusCounts: domainStatusCounts,
            needsReturnCount: needsReturnCount,
            recentPendingCount: recentPendingCount ?? 0,  // Default to 0 if not provided
            dueSoonCount: dueSoonCount,
            overdueCount: overdueCount,
            topPendingItems: pendingItems,
            topReturnItems: returnItems,
            recentCompleted: completedItems
        )
    }
}

// MARK: - Delivery Management Metrics DTO

private struct DeliveryManagementMetricsDTO: Codable {
    let items: [CustomerOutOfStockDTO]
    let totalCount: Int
    let hasMoreData: Bool
    let page: Int
    let pageSize: Int
    let needsDeliveryCount: Int
    let partialDeliveryCount: Int
    let completedDeliveryCount: Int

    func toDomain() throws -> DeliveryManagementMetrics {
        // Convert DTOs to domain models
        let domainItems = try items.map { try $0.toDomain() }

        return DeliveryManagementMetrics(
            items: domainItems,
            totalCount: totalCount,
            hasMoreData: hasMoreData,
            page: page,
            pageSize: pageSize,
            needsDeliveryCount: needsDeliveryCount,
            partialDeliveryCount: partialDeliveryCount,
            completedDeliveryCount: completedDeliveryCount
        )
    }
}
