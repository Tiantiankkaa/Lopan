//
//  CustomerOutOfStockInsightsView.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Main view for Customer Out-of-Stock Insights analytics
//

import SwiftUI
import Foundation
import os.log

/// Main insights view with time range selector and analysis modes
struct CustomerOutOfStockInsightsView: View {

    // MARK: - Environment & Dependencies

    @Environment(\.appDependencies) private var appDependencies
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @StateObject private var viewModel: CustomerOutOfStockInsightsViewModel
    @State private var showingTimeRangePicker = false
    @State private var segmentImages: [AnalysisMode: UIImage] = [:]

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.lopan.app", category: "InsightsView")

    // MARK: - Initialization

    init() {
        // ViewModel will be initialized in setupViewModel using environment dependencies
        _viewModel = StateObject(wrappedValue: CustomerOutOfStockInsightsViewModel(
            coordinator: CustomerOutOfStockCoordinator.placeholder()
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                backgroundView

                VStack(spacing: 0) {
                    // Time range selector
                    timeRangeSection

                    // Analysis mode selector
                    analysisModeSection

                    // Main content area
                    contentSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("数据洞察")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        refreshButton
                        Divider()
                        exportButton
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                            .accessibilityLabel("更多选项")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showingTimeRangePicker) {
                customDateRangePickerSheet
            }
            .sheet(isPresented: $viewModel.showingExportOptions) {
                exportOptionsSheet
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .onAppear {
                setupViewModel()
                Task {
                    await viewModel.loadInsightsData()
                }
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                LopanColors.backgroundPrimary,
                LopanColors.backgroundSecondary.opacity(0.3)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Time Range Section

    private var timeRangeSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            HStack {
                Text("时间范围")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Text(viewModel.formattedTimeRange)
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LopanSpacing.sm) {
                    ForEach(TimeRange.allCases) { timeRange in
                        timeRangeButton(timeRange)
                    }
                }
                .padding(.horizontal, LopanSpacing.screenPadding)
            }
        }
        .padding(.horizontal, LopanSpacing.screenPadding)
        .padding(.vertical, LopanSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.container)
                .fill(.ultraThinMaterial)
                .shadow(color: LopanColors.shadow, radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, LopanSpacing.screenPadding)
        .padding(.top, LopanSpacing.md)
    }

    private func timeRangeButton(_ timeRange: TimeRange) -> some View {
        Button(action: {
            if timeRange == .custom {
                showingTimeRangePicker = true
            } else {
                viewModel.changeTimeRange(timeRange)
            }
        }) {
            HStack(spacing: LopanSpacing.xs) {
                if timeRange == .custom {
                    Image(systemName: "calendar")
                        .font(.caption)
                }

                Text(timeRange.displayName)
                    .font(.subheadline)
                    .fontWeight(viewModel.selectedTimeRange == timeRange ? .semibold : .regular)
            }
            .padding(.horizontal, LopanSpacing.md)
            .padding(.vertical, LopanSpacing.sm)
            .background(
                Capsule()
                    .fill(viewModel.selectedTimeRange == timeRange ?
                          LopanColors.primary : LopanColors.backgroundSecondary)
            )
            .foregroundColor(
                viewModel.selectedTimeRange == timeRange ?
                LopanColors.textOnPrimary : .primary
            )
            .overlay(
                Capsule()
                    .stroke(
                        viewModel.selectedTimeRange == timeRange ?
                        Color.clear : LopanColors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTimeRange)
        .accessibilityLabel(timeRange.displayName)
        .accessibilityAddTraits(viewModel.selectedTimeRange == timeRange ? [.isSelected] : [])
    }

    // MARK: - Analysis Mode Section

    private var analysisModeSection: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            Text("分析维度")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Picker("分析维度", selection: $viewModel.selectedAnalysisMode) {
                ForEach(AnalysisMode.allCases) { mode in
                    if let image = segmentImages[mode] {
                        Image(uiImage: image)
                            .tag(mode)
                    }
                }
            }
            .pickerStyle(.segmented)
            .onAppear {
                if segmentImages.isEmpty {
                    renderSegmentImages()
                }
            }
            .onChange(of: viewModel.selectedAnalysisMode) { oldMode, newMode in
                logger.info("📝 [AnalysisDimension] Picker selection CHANGED: \(oldMode.rawValue, privacy: .public) → \(newMode.rawValue, privacy: .public)")
                logger.info("🔄 [AnalysisDimension] Calling changeAnalysisMode with: \(newMode.rawValue, privacy: .public)")
                viewModel.changeAnalysisMode(newMode)
            }
        }
        .padding(.horizontal, LopanSpacing.screenPadding)
        .padding(.vertical, LopanSpacing.md)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        ZStack {
            if viewModel.isLoading && !viewModel.isRefreshing {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else {
                analyticsContentView
                    .opacity(viewModel.isRefreshing ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isRefreshing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var analyticsContentView: some View {
        switch viewModel.selectedAnalysisMode {
        case .region:
            RegionInsightsView(data: viewModel.regionAnalytics)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
                .onAppear {
                    logger.info("✅ [AnalysisDimension] RegionInsightsView APPEARED - mode: region, totalItems: \(viewModel.regionAnalytics.totalItems)")
                }

        case .product:
            ProductInsightsView(data: viewModel.productAnalytics)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
                .onAppear {
                    logger.info("✅ [AnalysisDimension] ProductInsightsView APPEARED - mode: product, totalItems: \(viewModel.productAnalytics.totalItems)")
                }

        case .customer:
            CustomerInsightsView(data: viewModel.customerAnalytics)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
                .onAppear {
                    logger.info("✅ [AnalysisDimension] CustomerInsightsView APPEARED - mode: customer, totalItems: \(viewModel.customerAnalytics.totalItems)")
                }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: LopanSpacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)

            Text("正在分析数据...")
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LopanColors.backgroundPrimary.opacity(0.8))
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: LopanSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(LopanColors.error)

            Text("数据加载失败")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(LopanColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, LopanSpacing.xl)

            Button("重试") {
                Task {
                    await viewModel.loadInsightsData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LopanColors.backgroundPrimary)
    }

    // MARK: - Toolbar Buttons

    private var refreshButton: some View {
        Button(action: {
            Task {
                await viewModel.refreshData()
            }
        }) {
            Label("刷新数据", systemImage: "arrow.clockwise")
        }
        .disabled(!viewModel.canRefresh)
    }

    private var exportButton: some View {
        Button(action: {
            viewModel.showingExportOptions = true
        }) {
            Label("导出数据", systemImage: "square.and.arrow.up")
        }
        .disabled(viewModel.isLoading)
    }

    // MARK: - Sheets

    private var customDateRangePickerSheet: some View {
        NavigationStack {
            DateRangePickerView(
                selectedRange: viewModel.customDateRange ?? Date()...Date(),
                onSave: { range in
                    viewModel.setCustomDateRange(range)
                    showingTimeRangePicker = false
                },
                onCancel: {
                    showingTimeRangePicker = false
                }
            )
            .navigationTitle("自定义时间范围")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var exportOptionsSheet: some View {
        NavigationStack {
            ExportOptionsView(
                currentMode: viewModel.selectedAnalysisMode,
                timeRange: viewModel.selectedTimeRange,
                customDateRange: viewModel.customDateRange,
                onExport: { format in
                    Task {
                        try? await viewModel.exportData(format: format)
                        viewModel.showingExportOptions = false
                    }
                },
                onCancel: {
                    viewModel.showingExportOptions = false
                }
            )
            .navigationTitle("导出选项")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helper Methods

    private func setupViewModel() {
        // Inject the actual coordinator from app dependencies
        let realCoordinator = appDependencies.customerOutOfStockCoordinator

        // Replace the ViewModel's coordinator with the real one
        viewModel.updateCoordinator(realCoordinator)
    }

    private func renderSegmentImages() {
        for mode in AnalysisMode.allCases {
            let renderer = ImageRenderer(content:
                HStack(spacing: 4) {
                    Image(systemName: mode.systemImage)
                        .font(.caption)
                    Text(mode.displayName)
                        .font(.caption)
                }
            )
            renderer.scale = UIScreen.main.scale
            if let image = renderer.uiImage {
                segmentImages[mode] = image
            }
        }
    }
}

// MARK: - Date Range Picker View

private struct DateRangePickerView: View {
    let selectedRange: ClosedRange<Date>
    let onSave: (ClosedRange<Date>) -> Void
    let onCancel: () -> Void

    @State private var startDate: Date
    @State private var endDate: Date

    init(
        selectedRange: ClosedRange<Date>,
        onSave: @escaping (ClosedRange<Date>) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.selectedRange = selectedRange
        self.onSave = onSave
        self.onCancel = onCancel

        _startDate = State(initialValue: selectedRange.lowerBound)
        _endDate = State(initialValue: selectedRange.upperBound)
    }

    var body: some View {
        Form {
            Section("开始日期") {
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }

            Section("结束日期") {
                DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消", action: onCancel)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("确定") {
                    let range = min(startDate, endDate)...max(startDate, endDate)
                    onSave(range)
                }
                .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Export Options View

private struct ExportOptionsView: View {
    let currentMode: AnalysisMode
    let timeRange: TimeRange
    let customDateRange: ClosedRange<Date>?
    let onExport: (InsightsExportFormat) -> Void
    let onCancel: () -> Void

    var body: some View {
        List {
            Section {
                Text("分析模式: \(currentMode.displayName)")
                Text("时间范围: \(timeRange.displayName)")

                if let range = customDateRange, timeRange == .custom {
                    Text("自定义范围: \(DateFormatter.mediumDateFormatter.string(from: range.lowerBound)) - \(DateFormatter.mediumDateFormatter.string(from: range.upperBound))")
                }
            } header: {
                Text("导出内容")
            }

            Section {
                ForEach(InsightsExportFormat.allCases) { format in
                    Button(action: {
                        onExport(format)
                    }) {
                        HStack {
                            Image(systemName: format.systemImage)
                                .frame(width: 24, height: 24)
                                .foregroundColor(LopanColors.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Text(format == .csv ? "表格数据，适合进一步分析" : "完整报告，包含图表和数据")
                                    .font(.caption)
                                    .foregroundColor(LopanColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(LopanColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("导出格式")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消", action: onCancel)
            }
        }
    }
}

// Note: RegionInsightsView, ProductInsightsView, and CustomerInsightsView are now imported from their respective files

// MARK: - Preview

#if DEBUG
struct CustomerOutOfStockInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        CustomerOutOfStockInsightsView()
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")

        CustomerOutOfStockInsightsView()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}

// MARK: - DateFormatter Extension
fileprivate extension DateFormatter {
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}
#endif