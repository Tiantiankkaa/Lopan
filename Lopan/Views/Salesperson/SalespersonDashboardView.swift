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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

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
                VStack(alignment: .leading, spacing: 0) {
                    // Large title header
                    Text("Overview")
                        .lopanDisplayLarge()
                        .padding(.horizontal, LopanSpacing.screenPadding)
                        .padding(.top, LopanSpacing.xxxs)
                        .padding(.bottom, LopanSpacing.xxl)

                    VStack(alignment: .leading, spacing: LopanSpacing.sectionSpacing) {
                        if let errorMessage = viewModel.errorMessage {
                            errorBanner(errorMessage)
                        }

                        todaysRemindersSection
                        dailySalesSection
                        activityTimelineSection
                        bottomActionsSection
                    }
                    .padding(.horizontal, LopanSpacing.screenPadding)
                    .padding(.bottom, LopanSpacing.sectionSpacing)
                }
            }
            .background(Color.white.ignoresSafeArea())
            .refreshable {
                await viewModel.refreshAsync()
                toastManager.showSuccess(NSLocalizedString("salesperson_dashboard_refresh_success", comment: ""))
            }
            .onAppear {
                // Debug: Log salesperson ID for data filtering
                if let currentUser = authService.currentUser {
                    print("👤 [Dashboard] Current User ID: \(currentUser.id)")
                    print("👤 [Dashboard] Current User Name: \(currentUser.name)")
                    print("👤 [Dashboard] Current User Roles: \(currentUser.roles)")
                } else {
                    print("⚠️ [Dashboard] No current user logged in")
                }

                // Configure once and load data
                // configureIfNeeded already calls refresh internally
                viewModel.configureIfNeeded(
                    dependencies: appDependencies,
                    modelContainer: modelContext.container
                )
                // Start periodic refresh timer
                viewModel.startPeriodicRefresh()
            }
            .onDisappear {
                // Stop periodic refresh to save resources
                viewModel.stopPeriodicRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .outOfStockAdded)) { _ in
                print("🔔 [View] Received .outOfStockAdded notification")
                viewModel.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .outOfStockUpdated)) { _ in
                print("🔔 [View] Received .outOfStockUpdated notification")
                viewModel.refresh()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active && oldPhase != .active {
                    // Only refresh if data is stale (>5 min old)
                    if viewModel.isDataStale(threshold: 300) {
                        print("🔄 [View] Scene became active, refreshing stale data")
                        viewModel.refresh()
                    }
                }
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
        .navigationTransitionCoordinator()
    }

    // MARK: - Sections

    private var todaysRemindersSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            HStack(alignment: .center) {
                Text("Today's Reminders")
                    .lopanTitleMedium()

                Spacer()

                if let lastUpdate = viewModel.lastUpdated {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formatLastUpdatedTime(lastUpdate))
                            .font(.caption)
                    }
                    .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
            .padding(.horizontal, LopanSpacing.xs)
            .padding(.bottom, LopanSpacing.xxs)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.reminders.enumerated()), id: \.element.id) { index, reminder in
                    Button {
                        open(reminder.destination)
                    } label: {
                        reminderRow(for: reminder)
                    }
                    .buttonStyle(.plain)

                    if index < viewModel.reminders.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(LopanCornerRadius.card)
            .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        }
    }

    private var dailySalesSection: some View {
        Button {
            open(.salesEntry)
        } label: {
            VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                HStack {
                    Text("Daily Sales")
                        .lopanTitleMedium()
                    Spacer()
                    if let sales = viewModel.dailySales {
                        let trendPercent = Int(sales.trend * 100)
                        let (arrowIcon, trendColor, bgColor) = trendStyle(for: sales.trend)

                        HStack(spacing: 4) {
                            Image(systemName: arrowIcon)
                                .lopanLabelSmall()
                            Text("\(trendPercent > 0 ? "+" : "")\(trendPercent)% vs yesterday")
                                .lopanLabelSmall()
                        }
                        .foregroundColor(trendColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(bgColor)
                        .cornerRadius(12)
                    }
                }

                if let sales = viewModel.dailySales {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("₦")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(UIColor.label))

                        EnhancedAnimatedNumber(
                            value: Double(truncating: sales.amount as NSNumber),
                            format: .number.precision(.fractionLength(2)),
                            font: .system(size: 28, weight: .bold, design: .rounded),
                            foregroundColor: Color(UIColor.label)
                        )
                    }
                }

                Text("Tap to add detailed sales entries")
                    .lopanLabelMedium()
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LopanSpacing.lg)
            .background(Color.white)
            .cornerRadius(LopanCornerRadius.card)
            .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var activityTimelineSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.md) {
            Text("Activity Timeline")
                .lopanTitleMedium()
                .padding(.horizontal, LopanSpacing.xs)

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
                VStack(spacing: LopanSpacing.md) {
                    ForEach(Array(viewModel.recentActivities.enumerated()), id: \.element.id) { index, activity in
                        HStack(alignment: .top, spacing: 16) {
                            // Icon with connecting line
                            ZStack(alignment: .top) {
                                // Connecting line (skip for last item)
                                if index < viewModel.recentActivities.count - 1 {
                                    Rectangle()
                                        .fill(Color(UIColor.separator))
                                        .frame(width: 1)
                                        .offset(y: 40)
                                }

                                // Icon circle with subtle background
                                Circle()
                                    .fill(activity.iconColor.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: activity.iconName)
                                            .lopanBodyLarge()
                                            .foregroundColor(activity.iconColor)
                                    }
                            }
                            .frame(width: 40)

                            // Card content
                            Button {
                                open(activity.destination)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Text(activity.title)
                                        .font(LopanTypography.bodyLarge)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .foregroundColor(Color(UIColor.label))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(formatActivityTime(activity.date))
                                        .font(LopanTypography.labelMedium)
                                        .lineLimit(1)
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                        .fixedSize()
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(LopanCornerRadius.card)
                                .shadow(color: Color.black.opacity(0.1), radius: 1.5, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(activity.title))
                        }
                    }
                }
            }
        }
    }

    private var bottomActionsSection: some View {
        HStack(spacing: LopanSpacing.md) {
            Button {
                // Navigate to add product
                open(.productManagement)
            } label: {
                HStack(spacing: LopanSpacing.xs) {
                    Image(systemName: "storefront")
                        .imageScale(.medium)
                        .font(.title3)
                        .frame(width: 24, height: 24)
                        .layoutPriority(1)
                    Text("View Products")
                        .lopanTitleMedium(maxLines: 1)
                        .truncationMode(.tail)
                        .allowsTightening(true)
                        .dynamicTypeSize(...(.xxxLarge))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, LopanSpacing.md)
                .background(LopanColors.primary.opacity(0.1))
                .foregroundColor(LopanColors.primary)
                .cornerRadius(LopanCornerRadius.card)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Button {
                // Navigate to view sales
                open(.viewSales)
            } label: {
                HStack(spacing: LopanSpacing.xs) {
                    Image(systemName: "eye.fill")
                        .imageScale(.medium)
                        .font(.title3)
                        .frame(width: 24, height: 24)
                        .layoutPriority(1)
                    Text("View Sales")
                        .lopanTitleMedium(maxLines: 1)
                        .truncationMode(.tail)
                        .allowsTightening(true)
                        .dynamicTypeSize(...(.xxxLarge))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, LopanSpacing.md)
                .background(LopanColors.primary.opacity(0.1))
                .foregroundColor(LopanColors.primary)
                .cornerRadius(LopanCornerRadius.card)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func open(_ destination: SalespersonDashboardViewModel.Destination) {
        navigationPath.append(destination)
    }

    private func reminderRow(for reminder: SalespersonDashboardViewModel.ReminderItem) -> some View {
        HStack(spacing: LopanSpacing.md) {
            // Icon circle
            Circle()
                .fill(reminder.accentColor)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: reminder.systemImage)
                        .lopanLabelLarge()
                        .foregroundColor(.white)
                }

            // Title
            Text(reminder.title)
                .lopanBodyLarge()
                .foregroundColor(Color(UIColor.label))

            Spacer()

            // Count badge
            Text("\(reminder.count)")
                .lopanLabelMedium()
                .foregroundColor(reminder.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(minWidth: 24, minHeight: 24)
                .background(reminder.accentColor.opacity(0.12))
                .clipShape(Capsule())

            // Chevron
            Image(systemName: "chevron.right")
                .lopanLabelLarge()
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, LopanSpacing.sm)
        .padding(.horizontal, LopanSpacing.md)
        .contentShape(Rectangle())
    }

    private func trendStyle(for trend: Double) -> (icon: String, color: Color, background: Color) {
        if trend > 0.001 {
            // Positive trend: upward arrow, green
            return ("arrow.up", Color(red: 0.0, green: 0.7, blue: 0.0), Color(red: 0.0, green: 0.7, blue: 0.0).opacity(0.12))
        } else if trend < -0.001 {
            // Negative trend: downward arrow, red
            return ("arrow.down", Color(red: 0.8, green: 0.0, blue: 0.0), Color(red: 0.8, green: 0.0, blue: 0.0).opacity(0.12))
        } else {
            // No change: minus icon, gray
            return ("minus", Color(UIColor.secondaryLabel), Color(UIColor.secondarySystemFill))
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }

    private func formatActivityTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "hh:mm a"
            formatter.locale = Locale.current
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            formatter.locale = Locale.current
            return formatter.string(from: date)
        }
    }

    private func formatLastUpdatedTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @ViewBuilder
    private func destinationView(for destination: SalespersonDashboardViewModel.Destination) -> some View {
        switch destination {
        case .customerOutOfStock:
            CustomerOutOfStockDashboard()
        case .deliveryManagement:
            DeliveryManagementView()
        case .customerManagement:
            CustomerManagementView()
        case .productManagement:
            ProductManagementView()
                .hidesTabBarOnPush()
        case .analytics:
            CustomerOutOfStockAnalyticsView()
        case .salesEntry:
            SalesEntryView()
        case .viewSales:
            ViewSalesView()
                .hidesTabBarOnPush()
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
}
