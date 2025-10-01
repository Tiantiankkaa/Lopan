//
//  SalespersonDashboardView.swift
//  Lopan
//
//  Updated by Codex on 2025/10/05.
//

import SwiftUI

struct SalespersonDashboardView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var navigationService: WorkbenchNavigationService
    @Environment(\.appDependencies) private var appDependencies

    @StateObject private var viewModel: SalespersonDashboardViewModel
    @StateObject private var toastManager = EnhancedToastManager()
    @State private var navigationPath = NavigationPath()

    // MARK: - Init

    init(authService: AuthenticationService, navigationService: WorkbenchNavigationService) {
        self.authService = authService
        self.navigationService = navigationService
        _viewModel = StateObject(wrappedValue: SalespersonDashboardViewModel(authService: authService))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: LopanSpacing.sectionSpacing) {
                    if let errorMessage = viewModel.errorMessage {
                        errorBanner(errorMessage)
                    }

                    heroSection
                    metricsSection
                    quickActionsSection
                    priorityTasksSection
                    activitySection
                }
                .padding(.horizontal, LopanSpacing.screenPadding)
                .padding(.vertical, LopanSpacing.sectionSpacing)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .refreshable {
                await viewModel.refreshAsync()
                toastManager.showSuccess(NSLocalizedString("salesperson_dashboard_refresh_success", comment: ""))
            }
            .onAppear {
                viewModel.configureIfNeeded(dependencies: appDependencies)
            }
            .overlay(alignment: .top) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding()
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, LopanSpacing.md)
                }
            }
            .withToastFeedback(toastManager: toastManager)
            .navigationDestination(for: SalespersonDashboardViewModel.Destination.self) { destination in
                destinationView(for: destination)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { navigationService.showWorkbenchSelector() }) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("workbench_manage".localized)
                    .accessibilityHint("workbench_manage_hint".localized)
                }
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        CompactHeroCard(heroState: viewModel.heroState, lastUpdated: viewModel.lastUpdated)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            sectionHeader(icon: "chart.bar.fill", title: "salesperson_dashboard_section_metrics".localizedKey, showTime: true)

            if viewModel.metrics.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LopanSpacing.sm) {
                        ForEach(Array(viewModel.metrics.prefix(3))) { metric in
                            metricSummaryChip(for: metric)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            sectionHeader(icon: "bolt.fill", title: "salesperson_dashboard_section_shortcuts".localizedKey)

            LazyVGrid(columns: quickActionColumns, spacing: LopanSpacing.md) {
                ForEach(viewModel.quickActions) { action in
                    Button {
                        open(action.destination)
                    } label: {
                        quickActionTile(for: action)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(action.title))
                }
            }
        }
    }

    private var priorityTasksSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            sectionHeader(icon: "list.star", title: "salesperson_dashboard_section_priority".localizedKey)

            if viewModel.priorityTasks.isEmpty {
                ContentUnavailableView(
                    "salesperson_dashboard_empty_priority_title".localized,
                    systemImage: "checkmark.circle",
                    description: Text("salesperson_dashboard_empty_priority_message".localized)
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: LopanSpacing.md) {
                        ForEach(viewModel.priorityTasks) { task in
                            priorityTaskCard(for: task)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            sectionHeader(icon: "clock", title: "salesperson_dashboard_section_activity".localizedKey)

            if viewModel.recentActivities.isEmpty {
                ContentUnavailableView(
                    "salesperson_dashboard_empty_activity_title".localized,
                    systemImage: "text.badge.checkmark",
                    description: Text("salesperson_dashboard_empty_activity_message".localized)
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous))
            } else {
                LazyVStack(spacing: LopanSpacing.sm) {
                    ForEach(viewModel.recentActivities) { activity in
                        Button {
                            open(activity.destination)
                        } label: {
                            activityRow(for: activity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(activity.title))
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous))
            }
        }
    }

    // MARK: - Helpers

    private var quickActionColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: LopanSpacing.md), count: 2)
    }

    private func open(_ destination: SalespersonDashboardViewModel.Destination) {
        navigationPath.append(destination)
    }

    private func sectionHeader(icon: String, title: LocalizedStringKey, showTime: Bool = false) -> some View {
        HStack(spacing: LopanSpacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(LopanColors.textSecondary)

            Text(title)
                .lopanHeadlineMedium()
                .foregroundStyle(LopanColors.textPrimary)

            Spacer(minLength: 0)

            if showTime, let updated = viewModel.lastUpdated {
                Text(updated, style: .time)
                    .font(.caption2)
                    .foregroundStyle(LopanColors.textSecondary)
            }
        }
    }

    private func metricSummaryChip(for metric: SalespersonDashboardViewModel.Metric) -> some View {
        VStack(alignment: .leading, spacing: LopanSpacing.xs) {
            HStack(spacing: LopanSpacing.xs) {
                Image(systemName: metric.systemImage)
                    .font(.caption)
                    .foregroundStyle(color(for: metric.accent))
                Text(metric.title)
                    .font(.caption)
                    .foregroundStyle(LopanColors.textSecondary)
            }

            Text(metric.value)
                .lopanHeadlineMedium()
                .foregroundStyle(LopanColors.textPrimary)

            if let trend = metric.trend {
                trendLabel(for: trend)
            }
        }
        .padding(.vertical, LopanSpacing.sm)
        .padding(.horizontal, LopanSpacing.md)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous))
    }

    private func quickActionTile(for action: SalespersonDashboardViewModel.QuickAction) -> some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            Image(systemName: action.systemImage)
                .font(.title2)
                .foregroundStyle(LopanColors.primary)
                .frame(width: 44, height: 44)
                .background(LopanColors.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: LopanCornerRadius.button, style: .continuous))

            Text(action.title)
                .lopanBodyLarge(maxLines: 2)
                .foregroundStyle(LopanColors.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous))
    }

    private func priorityTaskCard(for task: SalespersonDashboardViewModel.PriorityTask) -> some View {
        Button {
            open(task.destination)
        } label: {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                Label(task.category, systemImage: "flag.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(for: task.status))
                    .labelStyle(.titleAndIcon)

                Text(task.title)
                    .lopanHeadlineMedium()
                    .foregroundStyle(LopanColors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(task.detail)
                    .font(.subheadline)
                    .foregroundStyle(LopanColors.textSecondary)
                    .multilineTextAlignment(.leading)

                if let dueDate = task.dueDate {
                    Label {
                        Text(dueDate, style: .relative)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(LopanColors.textSecondary)
                }
            }
            .frame(width: 240, alignment: .leading)
            .padding()
            .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(statusColor(for: task.status))
                    .frame(width: 10, height: 10)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(NSLocalizedString("salesperson_dashboard_task_action_open", comment: "")) {
                open(task.destination)
            }
            .tint(LopanColors.primary)

            Button(NSLocalizedString("salesperson_dashboard_task_action_complete", comment: "")) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.dismissTask(task)
                }
            }
            .tint(LopanColors.success)
        }
    }

    private func activityRow(for activity: SalespersonDashboardViewModel.Activity) -> some View {
        HStack(alignment: .top, spacing: LopanSpacing.md) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.title3)
                .foregroundStyle(LopanColors.primary)
                .frame(width: 36, height: 36)
                .background(LopanColors.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: LopanCornerRadius.button, style: .continuous))

            VStack(alignment: .leading, spacing: LopanSpacing.xs) {
                Text(activity.title)
                    .lopanBodyLarge(maxLines: 2)
                    .foregroundStyle(LopanColors.textPrimary)

                Text(activity.detail)
                    .font(.subheadline)
                    .foregroundStyle(LopanColors.textSecondary)

                Text(activity.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(LopanColors.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(LopanColors.textSecondary)
        }
        .padding(.vertical, LopanSpacing.xs)
    }

    private func color(for accent: SalespersonDashboardViewModel.MetricAccent) -> Color {
        switch accent {
        case .primary:
            return LopanColors.primary
        case .success:
            return LopanColors.success
        case .warning:
            return LopanColors.warning
        case .info:
            return LopanColors.info
        case .neutral:
            return LopanColors.secondary
        }
    }

    private func statusColor(for status: SalespersonDashboardViewModel.TaskStatus) -> Color {
        switch status {
        case .critical:
            return LopanColors.error
        case .warning:
            return LopanColors.warning
        case .info:
            return LopanColors.info
        case .neutral:
            return LopanColors.secondary
        }
    }

    @ViewBuilder
    private func destinationView(for destination: SalespersonDashboardViewModel.Destination) -> some View {
        switch destination {
        case .customerOutOfStock:
            CustomerOutOfStockDashboard()
        case .giveBack:
            GiveBackManagementView()
        case .customerManagement:
            CustomerManagementView()
        case .productManagement:
            ProductManagementView()
        case .analytics:
            CustomerOutOfStockAnalyticsView()
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: LopanSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LopanColors.warning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LopanSpacing.xxs) {
                Text("salesperson_dashboard_error_title".localizedKey)
                    .lopanHeadlineSmall()
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(LopanColors.textSecondary)
                Button("salesperson_dashboard_error_retry".localizedKey) {
                    viewModel.refresh()
                }
                .font(.footnote)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(LopanColors.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func trendLabel(for trend: SalespersonDashboardViewModel.Metric.Trend) -> some View {
        let configuration: (text: String, symbol: String, tint: Color) = {
            switch trend {
            case .up(let value):
                let percent = NumberFormatter.localizedString(from: NSNumber(value: value), number: .percent)
                return (percent, "arrow.up.right", LopanColors.success)
            case .down(let value):
                let percent = NumberFormatter.localizedString(from: NSNumber(value: value), number: .percent)
                return (percent, "arrow.down.right", LopanColors.error)
            case .steady:
                return (NSLocalizedString("salesperson_dashboard_trend_flat", comment: ""), "arrow.right", LopanColors.secondary)
            }
        }()

        return Label(configuration.text, systemImage: configuration.symbol)
            .font(.caption)
            .padding(.vertical, LopanSpacing.xxs)
            .padding(.horizontal, LopanSpacing.sm)
            .background(configuration.tint.opacity(0.12), in: Capsule())
            .foregroundColor(configuration.tint)
    }
}

// MARK: - Components

private struct CompactHeroCard: View {
    let heroState: SalespersonDashboardViewModel.HeroState
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            Text(heroState.greeting)
                .lopanTitleLarge()
                .foregroundStyle(LopanColors.textPrimary)

            Text(heroState.summaryLine)
                .lopanBodyLarge()
                .foregroundStyle(LopanColors.textSecondary)

            if let lastUpdated {
                Label {
                    Text(lastUpdated, style: .relative)
                } icon: {
                    Image(systemName: "clock.arrow.2.circlepath")
                }
                .font(.caption)
                .foregroundStyle(LopanColors.textSecondary)
            }
        }
        .padding(LopanSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: LopanCornerRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
