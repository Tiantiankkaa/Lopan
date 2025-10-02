//
//  SalespersonDashboardViewModel.swift
//  Lopan
//
//  Created by Codex on 2025/10/05.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
final class SalespersonDashboardViewModel: ObservableObject {
    // MARK: - Nested Types

    struct HeroState: Equatable {
        var greeting: String
        var summaryLine: String
        var lastSync: Date?
    }

    enum MetricAccent {
        case primary
        case success
        case warning
        case info
        case neutral
    }

    struct Metric: Identifiable, Equatable {
        enum Trend: Equatable {
            case up(Double)
                // percentage in range 0-1
            case down(Double)
            case steady
        }

        let id = UUID()
        let title: LocalizedStringKey
        let value: String
        let caption: LocalizedStringKey
        let systemImage: String
        let accent: MetricAccent
        let trend: Trend?
    }

    enum TaskStatus: Equatable {
        case critical
        case warning
        case info
        case neutral
    }

    struct PriorityTask: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let category: LocalizedStringKey
        let status: TaskStatus
        let destination: Destination
        let dueDate: Date?
    }

    struct QuickAction: Identifiable, Equatable {
        let id = UUID()
        let title: LocalizedStringKey
        let systemImage: String
        let destination: Destination
    }

    struct Activity: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let detail: String
        let date: Date
        let destination: Destination
        let iconName: String
        let iconColor: Color
    }

    struct ReminderItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let count: Int
        let systemImage: String
        let accentColor: Color
        let destination: Destination
    }

    struct DailySalesMetric: Equatable {
        let amount: Decimal
        let trend: Double // percentage change
        let comparisonText: LocalizedStringKey
    }

    enum Destination: Hashable {
        case customerOutOfStock
        case deliveryManagement
        case customerManagement
        case productManagement
        case analytics
        case salesEntry
        case viewSales
    }

    // MARK: - Published State

    @Published private(set) var isLoading = false
    @Published private(set) var heroState = HeroState(
        greeting: "",
        summaryLine: NSLocalizedString("salesperson_dashboard_summary_loading", comment: ""),
        lastSync: nil
    )
    @Published private(set) var metrics: [Metric] = []
    @Published private(set) var priorityTasks: [PriorityTask] = []
    @Published private(set) var quickActions: [QuickAction] = []
    @Published private(set) var recentActivities: [Activity] = []
    @Published private(set) var reminders: [ReminderItem] = []
    @Published private(set) var dailySales: DailySalesMetric?
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    // MARK: - Dependencies

    private weak var authService: AuthenticationService?
    private var dependencies: HasAppDependencies?
    private var modelContainer: ModelContainer?
    private let calendar = Calendar.current
    private var isRefreshing = false  // Debounce flag
    private var periodicRefreshTask: Task<Void, Never>?  // Periodic refresh timer

    // MARK: - Initialization

    init(authService: AuthenticationService?) {
        self.authService = authService
        configureSkeletonState()
    }

    // MARK: - Configuration

    func configureIfNeeded(dependencies: HasAppDependencies, modelContainer: ModelContainer) {
        guard self.dependencies == nil else { return }
        self.dependencies = dependencies
        self.modelContainer = modelContainer
        refresh()
    }

    // MARK: - Public API

    func refresh() {
        guard dependencies != nil else { return }
        Task {
            await loadDashboardContent()
        }
    }

    func refreshAsync() async {
        guard dependencies != nil else { return }
        guard !isRefreshing else {
            print("🔄 [ViewModel] Refresh already in progress, skipping...")
            return
        }
        await loadDashboardContent()
    }

    func dismissTask(_ task: PriorityTask) {
        priorityTasks.removeAll { $0.id == task.id }
    }

    // MARK: - Auto-Refresh Support

    /// Check if data is stale beyond the threshold (in seconds)
    func isDataStale(threshold: TimeInterval) -> Bool {
        guard let lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > threshold
    }

    /// Start periodic background refresh (5 minutes interval)
    func startPeriodicRefresh() {
        // Cancel any existing task first
        periodicRefreshTask?.cancel()

        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                // Wait 5 minutes (300 seconds)
                try? await Task.sleep(nanoseconds: 300_000_000_000)

                // Check if cancelled during sleep
                guard !Task.isCancelled else { break }

                // Only refresh if data is stale (>5 min old)
                if await self?.isDataStale(threshold: 300) == true {
                    print("🔄 [ViewModel] Periodic refresh triggered (5 min)")
                    await self?.refreshAsync()
                }
            }
        }
    }

    /// Stop periodic refresh timer
    func stopPeriodicRefresh() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil
        print("⏹️ [ViewModel] Periodic refresh stopped")
    }

    // MARK: - Loading

    private func loadDashboardContent() async {
        guard let dependencies = dependencies else { return }

        // Debounce: prevent multiple simultaneous refreshes
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        isLoading = true
        errorMessage = nil

        let repositoryFactory = dependencies.repositoryFactory
        let customerRepository = repositoryFactory.customerRepository
        let productRepository = repositoryFactory.productRepository
        let stockoutRepository = repositoryFactory.customerOutOfStockRepository

        do {
            // PHASE 2 OPTIMIZATION: Load customers/products + compute metrics off MainActor
            // Use ModelActor for dashboard metrics to avoid blocking UI during initial load
            async let customersTask = customerRepository.fetchCustomers()
            async let productsTask = productRepository.fetchProducts()

            // Compute dashboard metrics using ModelActor (off MainActor for zero UI blocking)
            let dashboardMetricsTask = Task {
                guard let container = modelContainer else {
                    throw NSError(domain: "SalespersonDashboardViewModel", code: 5001,
                                userInfo: [NSLocalizedDescriptionKey: "ModelContainer not available"])
                }
                let actor = DashboardStatisticsActor(modelContainer: container)
                return try await actor.computeDashboardMetrics()
            }

            let customers = try await customersTask
            let products = try await productsTask
            let dashboardMetrics = try await dashboardMetricsTask.value

            // Build UI components from single-pass data
            let hero = buildHero(customers: customers, metrics: dashboardMetrics)
            let metricItems = buildMetrics(customers: customers, products: products, metrics: dashboardMetrics)
            let tasks = buildPriorityTasks(metrics: dashboardMetrics)
            let quick = buildQuickActions()
            let activities = buildRecentActivities(metrics: dashboardMetrics)
            let reminderItems = buildReminders(metrics: dashboardMetrics)

            // Load daily sales asynchronously
            let sales = await loadDailySales()

            await MainActor.run {
                heroState = hero
                metrics = metricItems
                priorityTasks = tasks
                quickActions = quick
                recentActivities = activities
                reminders = reminderItems
                dailySales = sales
                lastUpdated = Date()
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Builders

    private func configureSkeletonState() {
        heroState = HeroState(
            greeting: greeting(for: Date(), name: authService?.currentUser?.name ?? ""),
            summaryLine: NSLocalizedString("salesperson_dashboard_summary_loading", comment: ""),
            lastSync: nil
        )
        metrics = []
        priorityTasks = []
        quickActions = buildQuickActions()
        recentActivities = []
    }

    private func buildHero(customers: [Customer], metrics: DashboardMetrics) -> HeroState {
        let userName = authService?.currentUser?.name ?? ""
        let greetingText = greeting(for: Date(), name: userName)
        let summaryLine = heroSummaryLine(
            customersCount: customers.count,
            pendingCount: metrics.statusCounts[.pending] ?? 0,
            returnsCount: metrics.needsReturnCount
        )

        return HeroState(
            greeting: greetingText,
            summaryLine: summaryLine,
            lastSync: Date()
        )
    }

    private func buildMetrics(customers: [Customer], products: [Product], metrics: DashboardMetrics) -> [Metric] {
        // Use completed count from efficient single-pass query
        let completedCount = metrics.statusCounts[.completed] ?? 0
        let deliveryQueueCount = metrics.needsReturnCount

        let metrics: [Metric] = [
            Metric(
                title: "salesperson_dashboard_metric_customers".localizedKey,
                value: NumberFormatter.localizedString(from: NSNumber(value: customers.count), number: .decimal),
                caption: "salesperson_dashboard_metric_customers_caption".localizedKey,
                systemImage: "person.2.fill",
                accent: .info,
                trend: nil
            ),
            Metric(
                title: "salesperson_dashboard_metric_products".localizedKey,
                value: NumberFormatter.localizedString(from: NSNumber(value: products.count), number: .decimal),
                caption: "salesperson_dashboard_metric_products_caption".localizedKey,
                systemImage: "shippingbox.fill",
                accent: .primary,
                trend: nil
            ),
            Metric(
                title: "salesperson_dashboard_metric_completed".localizedKey,
                value: NumberFormatter.localizedString(from: NSNumber(value: completedCount), number: .decimal),
                caption: "salesperson_dashboard_metric_completed_caption".localizedKey,
                systemImage: "checkmark.seal.fill",
                accent: .success,
                trend: .steady
            ),
            Metric(
                title: "salesperson_dashboard_metric_returns".localizedKey,
                value: NumberFormatter.localizedString(from: NSNumber(value: deliveryQueueCount), number: .decimal),
                caption: "salesperson_dashboard_metric_returns_caption".localizedKey,
                systemImage: "arrow.uturn.left.circle.fill",
                accent: deliveryQueueCount > 0 ? .warning : .neutral,
                trend: .steady
            )
        ]

        return metrics
    }

    private func buildPriorityTasks(metrics: DashboardMetrics) -> [PriorityTask] {
        // Use display items from single-pass query
        // Note: topPendingItems are already filtered to < 7 days by repository
        let pending = metrics.topPendingItems
        let returns = metrics.topReturnItems
        let completed = metrics.recentCompleted

        // Pending tasks - already filtered to < 7 days and sorted by oldest first
        let pendingTasks: [PriorityTask] = pending
            .prefix(5)
            .map { item in
                PriorityTask(
                    id: item.id,
                    title: item.customerDisplayName,
                    detail: formattedQuantityDetail(for: item),
                    category: "salesperson_dashboard_section_critical".localizedKey,
                    status: overdueStatus(for: item),
                    destination: .customerOutOfStock,
                    dueDate: item.requestDate
                )
            }

        // Return tasks
        let returnTasks: [PriorityTask] = returns
            .sorted { ($0.deliveryDate ?? $0.requestDate) < ($1.deliveryDate ?? $1.requestDate) }
            .prefix(4)
            .map { item in
                PriorityTask(
                    id: item.id + "-return",
                    title: item.productDisplayName,
                    detail: formattedReturnDetail(for: item),
                    category: "salesperson_dashboard_section_returns".localizedKey,
                    status: .warning,
                    destination: .deliveryManagement,
                    dueDate: item.deliveryDate ?? item.requestDate
                )
            }

        // Followup tasks from recently completed
        let followupTasks: [PriorityTask] = completed
            .filter { isRecentCompletion($0) }
            .prefix(4)
            .map { item in
                PriorityTask(
                    id: item.id + "-followup",
                    title: item.customerDisplayName,
                    detail: "salesperson_dashboard_task_followup_detail".localized(arguments: item.productDisplayName),
                    category: "salesperson_dashboard_section_followup".localizedKey,
                    status: .info,
                    destination: .customerManagement,
                    dueDate: item.actualCompletionDate ?? item.updatedAt
                )
            }

        return Array((pendingTasks + returnTasks + followupTasks).prefix(10))
    }

    private func buildQuickActions() -> [QuickAction] {
        return [
            QuickAction(
                title: "salesperson_dashboard_action_customers".localizedKey,
                systemImage: "person.2.fill",
                destination: .customerManagement
            ),
            QuickAction(
                title: "salesperson_dashboard_action_stockouts".localizedKey,
                systemImage: "exclamationmark.bubble.fill",
                destination: .customerOutOfStock
            ),
            QuickAction(
                title: "salesperson_dashboard_action_products".localizedKey,
                systemImage: "shippingbox.fill",
                destination: .productManagement
            ),
            QuickAction(
                title: "salesperson_dashboard_action_returns".localizedKey,
                systemImage: "arrow.uturn.left.circle.fill",
                destination: .deliveryManagement
            )
        ]
    }

    private func buildRecentActivities(metrics: DashboardMetrics) -> [Activity] {
        var activities: [Activity] = []

        // Use display items from single-pass query
        let pending = metrics.topPendingItems
        let returns = metrics.topReturnItems
        let completed = metrics.recentCompleted

        // Recent shortages created
        let recentShortages = pending
            .prefix(2)
            .map { item in
                Activity(
                    title: "You created a shortage for \(item.productDisplayName).",
                    detail: "\(item.remainingQuantity) units requested",
                    date: item.requestDate,
                    destination: .customerOutOfStock,
                    iconName: "shippingbox.fill",
                    iconColor: Color(red: 0.86, green: 0.15, blue: 0.15)
                )
            }
        activities.append(contentsOf: recentShortages)

        // Recent returns processed
        let recentReturns = returns
            .filter { $0.deliveryDate != nil }
            .sorted { ($0.deliveryDate ?? Date.distantPast) > ($1.deliveryDate ?? Date.distantPast) }
            .prefix(2)
            .map { item in
                Activity(
                    title: "Return processed for \(item.customerDisplayName).",
                    detail: "\(item.productDisplayName) - \(item.remainingQuantity) units",
                    date: item.deliveryDate ?? item.updatedAt,
                    destination: .deliveryManagement,
                    iconName: "arrow.uturn.backward.circle.fill",
                    iconColor: Color(red: 0.15, green: 0.39, blue: 0.92)
                )
            }
        activities.append(contentsOf: recentReturns)

        // Recent completed orders
        let completedActivities = completed
            .prefix(2)
            .map { item in
                let completionDate = item.actualCompletionDate ?? item.updatedAt
                return Activity(
                    title: "You added a note to \(item.customerDisplayName)'s profile.",
                    detail: "Completed order for \(item.productDisplayName)",
                    date: completionDate,
                    destination: .customerManagement,
                    iconName: "note.text",
                    iconColor: Color(red: 0.29, green: 0.33, blue: 0.39)
                )
            }
        activities.append(contentsOf: completedActivities)

        return Array(activities.sorted { $0.date > $1.date }.prefix(5))
    }

    private func buildReminders(metrics: DashboardMetrics) -> [ReminderItem] {
        // Use counts from single-pass query
        // Use recentPendingCount (< 7 days) instead of needsReturnCount (all pending)
        let pendingReturnsCount = metrics.recentPendingCount
        let dueSoonCount = metrics.dueSoonCount
        let overdueCount = metrics.overdueCount

        return [
            ReminderItem(
                title: "Pending Returns",
                count: pendingReturnsCount,
                systemImage: "arrow.uturn.backward.circle.fill",
                accentColor: Color(red: 0.2, green: 0.6, blue: 1.0),
                destination: .deliveryManagement
            ),
            ReminderItem(
                title: "Due Soon",
                count: dueSoonCount,
                systemImage: "hourglass.circle.fill",
                accentColor: Color(red: 1.0, green: 0.6, blue: 0.0),
                destination: .customerOutOfStock
            ),
            ReminderItem(
                title: "Overdue",
                count: overdueCount,
                systemImage: "exclamationmark.circle.fill",
                accentColor: Color(red: 0.9, green: 0.0, blue: 0.0),
                destination: .customerOutOfStock
            )
        ]
    }

    private func buildDailySales() -> DailySalesMetric? {
        // Will be loaded asynchronously via loadDailySales()
        return nil
    }

    private func loadDailySales() async -> DailySalesMetric {
        guard let dependencies = dependencies,
              let currentUser = authService?.currentUser else {
            // Return default if no dependencies or user
            return DailySalesMetric(
                amount: 0,
                trend: 0,
                comparisonText: "salesperson_overview_daily_sales_vs_yesterday".localizedKey
            )
        }

        let salesService = dependencies.serviceFactory.salesService

        do {
            // Calculate today's sales and trend
            let metric = try await salesService.calculateDailySales(
                forDate: Date(),
                salespersonId: currentUser.id
            )
            return metric
        } catch {
            // Return zero sales on error
            return DailySalesMetric(
                amount: 0,
                trend: 0,
                comparisonText: "salesperson_overview_daily_sales_vs_yesterday".localizedKey
            )
        }
    }

    // MARK: - Helpers

    private func greeting(for date: Date, name: String) -> String {
        let hour = calendar.component(.hour, from: date)
        let baseKey: String
        switch hour {
        case 5..<11:
            baseKey = "salesperson_dashboard_greeting_morning"
        case 11..<14:
            baseKey = "salesperson_dashboard_greeting_midday"
        case 14..<18:
            baseKey = "salesperson_dashboard_greeting_afternoon"
        case 18..<23:
            baseKey = "salesperson_dashboard_greeting_evening"
        default:
            baseKey = "salesperson_dashboard_greeting_night"
        }
        let base = NSLocalizedString(baseKey, comment: "")
        let fallbackName = NSLocalizedString("salesperson_dashboard_greeting_default_name", comment: "")
        let finalName = name.isEmpty ? fallbackName : name
        return String(format: base, finalName)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedQuantityDetail(for item: OutOfStockDisplayItem) -> String {
        let quantityText = NumberFormatter.localizedString(from: NSNumber(value: item.remainingQuantity), number: .decimal)
        let requestDate = relativeDateString(for: item.requestDate)
        return String(format: NSLocalizedString("salesperson_dashboard_task_pending_detail", comment: ""), quantityText, requestDate)
    }

    private func formattedReturnDetail(for item: OutOfStockDisplayItem) -> String {
        let quantityText = NumberFormatter.localizedString(from: NSNumber(value: item.remainingQuantity), number: .decimal)
        let requestDate = relativeDateString(for: item.requestDate)
        return String(format: NSLocalizedString("salesperson_dashboard_task_return_detail", comment: ""), quantityText, requestDate)
    }

    private func heroSummaryLine(customersCount: Int, pendingCount: Int, returnsCount: Int) -> String {
        let customersText = NumberFormatter.localizedString(from: NSNumber(value: customersCount), number: .decimal)
        let pendingText = NumberFormatter.localizedString(from: NSNumber(value: pendingCount), number: .decimal)
        let returnsText = NumberFormatter.localizedString(from: NSNumber(value: returnsCount), number: .decimal)
        return String.localizedStringWithFormat(
            NSLocalizedString("salesperson_dashboard_summary_format", comment: ""),
            customersText,
            pendingText,
            returnsText
        )
    }

    private func overdueStatus(for item: OutOfStockDisplayItem) -> TaskStatus {
        let hours = calendar.dateComponents([.hour], from: item.requestDate, to: Date()).hour ?? 0
        if hours >= 72 {
            return .critical
        } else if hours >= 48 {
            return .warning
        }
        return .info
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func stockoutsCompletedThisWeek(_ stockouts: [OutOfStockDisplayItem]) -> Int {
        let now = Date()
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return stockouts.filter { record in
            guard record.status == .completed,
                  let completionDate = record.actualCompletionDate else { return false }
            return completionDate >= startOfWeek
        }.count
    }

    private func isRecentCompletion(_ record: OutOfStockDisplayItem) -> Bool {
        guard record.status == .completed else { return false }
        let completion = completionDate(for: record)
        guard let diff = calendar.dateComponents([.day], from: completion, to: Date()).day else { return false }
        return diff <= 2
    }

    private func completionDate(for record: OutOfStockDisplayItem) -> Date {
        return record.actualCompletionDate ?? record.updatedAt
    }

    private func isDueSoon(_ record: OutOfStockDisplayItem) -> Bool {
        let days = calendar.dateComponents([.day], from: record.requestDate, to: Date()).day ?? 0
        return days >= 7 && days < 14
    }

    private func isOverdue(_ record: OutOfStockDisplayItem) -> Bool {
        let days = calendar.dateComponents([.day], from: record.requestDate, to: Date()).day ?? 0
        return days >= 14
    }
}
private extension String {
    func localized(arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, comment: "")
        return String(format: format, arguments: arguments)
    }
}
