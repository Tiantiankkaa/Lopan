//
//  InsightsFilterComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Filter panel and chip components for Insights analytics
//

import SwiftUI

// MARK: - Filter Panel

/// Comprehensive filter configuration panel
struct InsightsFilterPanel: View {
    @Binding var filters: [InsightsFilter]
    @Environment(\.dismiss) private var dismiss

    @State private var minValue: Double = 0
    @State private var maxValue: Double = 1000
    @State private var selectedSort: InsightsFilter.SortOrder = .valueDescending
    @State private var thresholdValue: Double = 50
    @State private var thresholdOperation: InsightsFilter.ComparisonOperation = .greaterThan
    @State private var selectedCategories: Set<String> = []

    // Available categories (should be passed from parent or loaded from data)
    let availableCategories: [String]

    init(filters: Binding<[InsightsFilter]>, availableCategories: [String] = []) {
        self._filters = filters
        self.availableCategories = availableCategories

        // Initialize from existing filters
        if let valueRangeFilter = filters.wrappedValue.first(where: {
            if case .valueRange = $0.type { return true }
            return false
        }), case .valueRange(let min, let max) = valueRangeFilter.type {
            _minValue = State(initialValue: min)
            _maxValue = State(initialValue: max)
        }

        if let sortFilter = filters.wrappedValue.first(where: {
            if case .sortOrder = $0.type { return true }
            return false
        }), case .sortOrder(let order) = sortFilter.type {
            _selectedSort = State(initialValue: order)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                valueRangeSection
                sortingSection
                thresholdSection

                if !availableCategories.isEmpty {
                    categorySection
                }

                presetSection
            }
            .navigationTitle("insights_filter_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("insights_cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("insights_apply") {
                        applyFilters()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                }

                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        resetFilters()
                    } label: {
                        Label("insights_clear_all", systemImage: "trash")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Value Range Section

    private var valueRangeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("insights_filter_range_label")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(minValue)) - \(Int(maxValue))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("insights_filter_min")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("0", value: $minValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("insights_filter_max")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("1000", value: $maxValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                    }
                }

                // Visual range slider
                RangeSliderView(
                    minValue: $minValue,
                    maxValue: $maxValue,
                    bounds: 0...1000
                )
            }
        } header: {
            Label("insights_filter_value_range", systemImage: "slider.horizontal.3")
        }
    }

    // MARK: - Sorting Section

    private var sortingSection: some View {
        Section {
            ForEach(InsightsFilter.SortOrder.allCases) { order in
                Button {
                    selectedSort = order
                } label: {
                    HStack {
                        Image(systemName: order.systemImage)
                            .foregroundColor(LopanColors.primary)
                            .frame(width: 24)

                        Text(order.displayName)
                            .foregroundColor(.primary)

                        Spacer()

                        if selectedSort == order {
                            Image(systemName: "checkmark")
                                .foregroundColor(LopanColors.primary)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        } header: {
            Label("insights_filter_sorting", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Threshold Section

    private var thresholdSection: some View {
        Section {
            HStack {
                Text("insights_filter_threshold_value")
                    .foregroundColor(.secondary)

                Spacer()

                TextField("50", value: $thresholdValue, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }

            Picker("insights_filter_operation", selection: $thresholdOperation) {
                ForEach(InsightsFilter.ComparisonOperation.allCases, id: \.self) { operation in
                    HStack {
                        Text(operation.symbol)
                            .font(.system(.body, design: .monospaced))
                        Text(operation.displayName)
                    }
                    .tag(operation)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Label("insights_filter_threshold", systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        Section {
            ForEach(availableCategories, id: \.self) { category in
                Button {
                    toggleCategory(category)
                } label: {
                    HStack {
                        Text(category)
                            .foregroundColor(.primary)

                        Spacer()

                        if selectedCategories.contains(category) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(LopanColors.primary)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } header: {
            Label("insights_filter_categories", systemImage: "square.grid.2x2")
        }
    }

    // MARK: - Preset Section

    private var presetSection: some View {
        Section {
            ForEach([
                InsightsFilter.Preset.topPerformers,
                .highValue,
                .recentActivity,
                .lowStock,
                .alphabetical
            ], id: \.self) { preset in
                Button {
                    applyPreset(preset)
                } label: {
                    HStack {
                        Image(systemName: preset.filter.icon)
                            .foregroundColor(preset.filter.color)
                            .frame(width: 24)

                        Text(preset.displayName)
                            .foregroundColor(.primary)

                        Spacer()

                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Label("insights_filter_presets", systemImage: "star")
        }
    }

    // MARK: - Actions

    private var hasChanges: Bool {
        // Check if any values have changed from initial state
        true // Simplified for now
    }

    private func applyFilters() {
        var newFilters: [InsightsFilter] = []

        // Add value range filter
        if minValue > 0 || maxValue < 1000 {
            newFilters.append(InsightsFilter(
                type: .valueRange(min: minValue, max: maxValue),
                isActive: true
            ))
        }

        // Add sort filter
        newFilters.append(InsightsFilter(
            type: .sortOrder(selectedSort),
            isActive: true
        ))

        // Add threshold filter if meaningful
        if thresholdValue > 0 {
            newFilters.append(InsightsFilter(
                type: .threshold(value: thresholdValue, operation: thresholdOperation),
                isActive: true
            ))
        }

        // Add category filter
        if !selectedCategories.isEmpty {
            newFilters.append(InsightsFilter(
                type: .categories(selected: selectedCategories),
                isActive: true
            ))
        }

        filters = newFilters

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        dismiss()
    }

    private func resetFilters() {
        minValue = 0
        maxValue = 1000
        selectedSort = .valueDescending
        thresholdValue = 50
        thresholdOperation = .greaterThan
        selectedCategories.removeAll()
        filters.removeAll()

        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
    }

    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }

        // Light haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    private func applyPreset(_ preset: InsightsFilter.Preset) {
        filters = [preset.filter]

        // Update UI state
        if case .sortOrder(let order) = preset.filter.type {
            selectedSort = order
        }

        // Success haptic
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        dismiss()
    }
}

// MARK: - Range Slider View

private struct RangeSliderView: View {
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let bounds: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Active range
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LopanColors.primary)
                        .frame(
                            width: activeRangeWidth(in: geometry.size.width),
                            height: 8
                        )
                        .offset(x: minOffset(in: geometry.size.width))
                }
            }
            .frame(height: 8)

            // Dual sliders
            HStack(spacing: 0) {
                Slider(value: $minValue, in: bounds)
                    .tint(LopanColors.primary)

                Slider(value: $maxValue, in: bounds)
                    .tint(LopanColors.primary)
            }
        }
    }

    private func minOffset(in width: CGFloat) -> CGFloat {
        let ratio = (minValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return width * ratio
    }

    private func activeRangeWidth(in width: CGFloat) -> CGFloat {
        let minRatio = (minValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        let maxRatio = (maxValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return width * (maxRatio - minRatio)
    }
}

// MARK: - Filter Chip

/// Compact filter display chip
struct InsightsFilterChip: View {
    let filter: InsightsFilter
    let onRemove: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: filter.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(filter.color)

            Text(filter.displayLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(LopanColors.textPrimary)
                .lineLimit(1)

            Button(action: handleRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(LopanColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(chipBackground)
        .clipShape(Capsule())
        .shadow(color: filter.color.opacity(0.15), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    private var chipBackground: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            filter.color.opacity(0.15),
                            filter.color.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Capsule()
                .strokeBorder(filter.color.opacity(0.3), lineWidth: 1)
        }
    }

    private func handleRemove() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()

            onRemove()
        }
    }
}

// MARK: - Active Filters Bar

/// Horizontal scrolling bar showing active filters
struct ActiveFiltersBar: View {
    @Binding var filters: [InsightsFilter]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters.filter(\.isActive)) { filter in
                    InsightsFilterChip(filter: filter) {
                        removeFilter(filter)
                    }
                }

                if !filters.isEmpty {
                    clearAllButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
    }

    private var clearAllButton: some View {
        Button {
            clearAllFilters()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))

                Text("insights_clear_all")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func removeFilter(_ filter: InsightsFilter) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            filters.removeAll { $0.id == filter.id }
        }
    }

    private func clearAllFilters() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            filters.removeAll()
        }

        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
    }
}

// MARK: - Preview

#Preview("Filter Panel") {
    struct PreviewWrapper: View {
        @State private var filters: [InsightsFilter] = []

        var body: some View {
            InsightsFilterPanel(
                filters: $filters,
                availableCategories: ["产品A", "产品B", "产品C", "产品D"]
            )
        }
    }

    return PreviewWrapper()
}

#Preview("Filter Chips") {
    struct PreviewWrapper: View {
        @State private var filters: [InsightsFilter] = [
            InsightsFilter(type: .valueRange(min: 10, max: 100)),
            InsightsFilter(type: .sortOrder(.valueDescending)),
            InsightsFilter(type: .threshold(value: 50, operation: .greaterThan))
        ]

        var body: some View {
            VStack(spacing: 20) {
                Text("Active Filters")
                    .font(.headline)

                ActiveFiltersBar(filters: $filters)

                Spacer()
            }
            .padding()
        }
    }

    return PreviewWrapper()
}