//
//  InsightsExportSheet.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Export sheet UI for Insights data with format selection and preview
//

import SwiftUI

// MARK: - Export Sheet

/// Comprehensive export configuration and action sheet
struct InsightsExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let barData: [BarChartItem]?
    let pieData: [PieChartSegment]?
    let chartView: AnyView?
    let configuration: InsightsExportService.ExportConfiguration
    let onExport: (InsightsExportService.ExportFormat, ExportOptions) -> Void

    @State private var selectedFormat: InsightsExportService.ExportFormat = .pdf
    @State private var exportOptions = ExportOptions()
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?

    init(
        barData: [BarChartItem]? = nil,
        pieData: [PieChartSegment]? = nil,
        chartView: AnyView? = nil,
        configuration: InsightsExportService.ExportConfiguration,
        onExport: @escaping (InsightsExportService.ExportFormat, ExportOptions) -> Void
    ) {
        self.barData = barData
        self.pieData = pieData
        self.chartView = chartView
        self.configuration = configuration
        self.onExport = onExport
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    formatSelectionSection
                    optionsSection
                    previewSection
                    exportButtonSection
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("insights_export_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("insights_cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Format Selection

    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights_export_format")
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)

            HStack(spacing: 12) {
                ForEach(InsightsExportService.ExportFormat.allCases) { format in
                    FormatOptionCard(
                        format: format,
                        isSelected: selectedFormat == format
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFormat = format
                            updateOptionsForFormat(format)
                        }

                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights_export_options")
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)

            VStack(spacing: 8) {
                if selectedFormat != .png {
                    ExportToggleRow(
                        title: "insights_export_include_chart",
                        icon: "chart.bar.fill",
                        isOn: $exportOptions.includeChart,
                        isEnabled: chartView != nil
                    )
                }

                if selectedFormat == .pdf || selectedFormat == .csv {
                    ExportToggleRow(
                        title: "insights_export_include_data",
                        icon: "tablecells.fill",
                        isOn: $exportOptions.includeData,
                        isEnabled: true
                    )
                }

                if selectedFormat == .pdf {
                    ExportToggleRow(
                        title: "insights_export_include_summary",
                        icon: "doc.text.fill",
                        isOn: $exportOptions.includeSummary,
                        isEnabled: true
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights_export_preview")
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)

            ExportPreviewCard(
                format: selectedFormat,
                options: exportOptions,
                itemCount: (barData?.count ?? 0) + (pieData?.count ?? 0)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Export Button

    private var exportButtonSection: some View {
        Button(action: handleExport) {
            HStack(spacing: 12) {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 20, weight: .semibold))

                    Text("insights_export_action")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: [
                        LopanColors.primary,
                        LopanColors.primary.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: LopanColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isExporting || !canExport)
        .opacity((isExporting || !canExport) ? 0.6 : 1.0)
    }

    // MARK: - Helper Properties

    private var canExport: Bool {
        switch selectedFormat {
        case .csv:
            return exportOptions.includeData && ((barData?.isEmpty == false) || (pieData?.isEmpty == false))
        case .pdf:
            return exportOptions.includeChart || exportOptions.includeData || exportOptions.includeSummary
        case .png:
            return chartView != nil
        }
    }

    // MARK: - Actions

    private func updateOptionsForFormat(_ format: InsightsExportService.ExportFormat) {
        switch format {
        case .csv:
            exportOptions.includeChart = false
            exportOptions.includeData = true
            exportOptions.includeSummary = false

        case .pdf:
            exportOptions.includeChart = chartView != nil
            exportOptions.includeData = true
            exportOptions.includeSummary = true

        case .png:
            exportOptions.includeChart = true
            exportOptions.includeData = false
            exportOptions.includeSummary = false
        }
    }

    private func handleExport() {
        isExporting = true

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Simulate short delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onExport(selectedFormat, exportOptions)
            isExporting = false

            // Success haptic
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)

            dismiss()
        }
    }
}

// MARK: - Export Options

struct ExportOptions {
    var includeChart: Bool = true
    var includeData: Bool = true
    var includeSummary: Bool = true
}

// MARK: - Format Option Card

private struct FormatOptionCard: View {
    let format: InsightsExportService.ExportFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? LopanColors.primary.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: format.systemImage)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(isSelected ? LopanColors.primary : LopanColors.textSecondary)
                }

                Text(format.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? LopanColors.primary : LopanColors.textSecondary)
                    .lineLimit(1)

                Text(".\(format.fileExtension)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(LopanColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(LopanColors.primary, lineWidth: 2)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                }
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Export Toggle Row

private struct ExportToggleRow: View {
    let title: LocalizedStringKey
    let icon: String
    @Binding var isOn: Bool
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isEnabled ? LopanColors.primary : LopanColors.textTertiary)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 15))
                .foregroundColor(isEnabled ? LopanColors.textPrimary : LopanColors.textTertiary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(LopanColors.primary)
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Export Preview Card

private struct ExportPreviewCard: View {
    let format: InsightsExportService.ExportFormat
    let options: ExportOptions
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: format.systemImage)
                    .font(.system(size: 32))
                    .foregroundColor(LopanColors.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(format.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LopanColors.textPrimary)

                    Text(previewSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(LopanColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                PreviewInfoRow(
                    icon: "doc.text",
                    text: "insights_export_format",
                    value: format.fileExtension.uppercased()
                )

                PreviewInfoRow(
                    icon: "tablecells",
                    text: "insights_export_data_items",
                    value: "\(itemCount)"
                )

                if options.includeChart {
                    PreviewInfoRow(
                        icon: "checkmark.circle.fill",
                        text: "insights_export_includes_chart",
                        value: ""
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private var previewSubtitle: String {
        switch format {
        case .csv:
            return NSLocalizedString("insights_export_csv_description", comment: "")
        case .pdf:
            return NSLocalizedString("insights_export_pdf_description", comment: "")
        case .png:
            return NSLocalizedString("insights_export_png_description", comment: "")
        }
    }
}

private struct PreviewInfoRow: View {
    let icon: String
    let text: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(LopanColors.primary)
                .frame(width: 16)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(LopanColors.textSecondary)

            if !value.isEmpty {
                Spacer()

                Text(value)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(LopanColors.textPrimary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Export Sheet") {
    struct PreviewWrapper: View {
        @State private var showingSheet = true

        var body: some View {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()
                .sheet(isPresented: $showingSheet) {
                    InsightsExportSheet(
                        barData: [
                            BarChartItem(category: "产品A", value: 120),
                            BarChartItem(category: "产品B", value: 85)
                        ],
                        pieData: nil,
                        chartView: AnyView(EmptyView()),
                        configuration: InsightsExportService.ExportConfiguration(
                            title: "缺货分析报告",
                            subtitle: "2025年9月",
                            timeRange: .thisWeek,
                            mode: .product
                        ),
                        onExport: { format, options in
                            print("Export: \(format) with options: \(options)")
                        }
                    )
                }
        }
    }

    return PreviewWrapper()
}