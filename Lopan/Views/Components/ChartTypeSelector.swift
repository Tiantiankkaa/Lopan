//
//  ChartTypeSelector.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/29.
//  Chart type selection component for multiple visualization options
//

import SwiftUI
import Foundation

/// Available chart types for data visualization
enum ChartType: String, CaseIterable, Identifiable {
    case pie = "pie"
    case donut = "donut"
    case bar = "bar"
    case horizontalBar = "horizontal_bar"
    case line = "line"
    case area = "area"
    case scatter = "scatter"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pie: return "饼图"
        case .donut: return "环形图"
        case .bar: return "柱状图"
        case .horizontalBar: return "条形图"
        case .line: return "折线图"
        case .area: return "面积图"
        case .scatter: return "散点图"
        }
    }

    var systemImage: String {
        switch self {
        case .pie: return "chart.pie.fill"
        case .donut: return "chart.pie"
        case .bar: return "chart.bar.fill"
        case .horizontalBar: return "chart.bar.xaxis"
        case .line: return "chart.xyaxis.line"
        case .area: return "chart.line.uptrend.xyaxis"
        case .scatter: return "chart.dots.scatter"
        }
    }

    var description: String {
        switch self {
        case .pie: return "显示部分与整体的关系"
        case .donut: return "环形显示占比关系"
        case .bar: return "垂直条形比较数据"
        case .horizontalBar: return "水平条形比较数据"
        case .line: return "展示数据趋势变化"
        case .area: return "填充区域显示趋势"
        case .scatter: return "显示数据点分布"
        }
    }

    /// Get suitable chart types for different data types
    static func suitableTypes(for analysisMode: AnalysisMode) -> [ChartType] {
        switch analysisMode {
        case .region:
            return [.donut, .horizontalBar]
        case .product:
            return [.horizontalBar, .line, .area]
        case .customer:
            return [.donut, .horizontalBar]
        }
    }
}

/// Chart type selector component with multiple display styles
struct ChartTypeSelector: View {

    // MARK: - Properties

    @Binding var selectedType: ChartType
    let availableTypes: [ChartType]
    let style: SelectorStyle
    let showDescription: Bool

    // MARK: - Initialization

    init(
        selectedType: Binding<ChartType>,
        availableTypes: [ChartType] = ChartType.allCases,
        style: SelectorStyle = .segmented,
        showDescription: Bool = false
    ) {
        self._selectedType = selectedType
        self.availableTypes = availableTypes
        self.style = style
        self.showDescription = showDescription
    }

    // MARK: - Selector Styles

    enum SelectorStyle {
        case segmented
        case pills
        case menu
        case grid
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: LopanSpacing.sm) {
            switch style {
            case .segmented:
                segmentedSelector
            case .pills:
                pillsSelector
            case .menu:
                menuSelector
            case .grid:
                gridSelector
            }

            if showDescription {
                descriptionView
            }
        }
    }

    // MARK: - Segmented Style

    private var segmentedSelector: some View {
        Picker("Chart Type", selection: $selectedType) {
            ForEach(availableTypes) { type in
                HStack(spacing: LopanSpacing.xs) {
                    Image(systemName: type.systemImage)
                        .font(.caption)
                    Text(type.displayName)
                        .font(.caption)
                }
                .tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Pills Style

    private var pillsSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LopanSpacing.sm) {
                ForEach(availableTypes) { type in
                    chartTypePill(type)
                }
            }
            .padding(.horizontal, LopanSpacing.screenPadding)
        }
    }

    private func chartTypePill(_ type: ChartType) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = type
            }
        }) {
            HStack(spacing: LopanSpacing.xs) {
                Image(systemName: type.systemImage)
                    .font(.caption)

                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(selectedType == type ? .semibold : .regular)
            }
            .padding(.horizontal, LopanSpacing.md)
            .padding(.vertical, LopanSpacing.sm)
            .background(
                Capsule()
                    .fill(selectedType == type ?
                          LopanColors.primary : LopanColors.backgroundSecondary)
            )
            .foregroundColor(
                selectedType == type ?
                LopanColors.textOnPrimary : .primary
            )
            .overlay(
                Capsule()
                    .stroke(
                        selectedType == type ?
                        Color.clear : LopanColors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityAddTraits(selectedType == type ? [.isSelected] : [])
    }

    // MARK: - Menu Style

    private var menuSelector: some View {
        Menu {
            ForEach(availableTypes) { type in
                Button(action: {
                    selectedType = type
                }) {
                    HStack {
                        Image(systemName: type.systemImage)
                        Text(type.displayName)
                        Spacer()
                        if selectedType == type {
                            Image(systemName: "checkmark")
                                .foregroundColor(LopanColors.primary)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: LopanSpacing.sm) {
                Image(systemName: selectedType.systemImage)
                    .font(.subheadline)
                    .foregroundColor(LopanColors.primary)

                Text(selectedType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(LopanColors.textSecondary)
            }
            .padding(.horizontal, LopanSpacing.md)
            .padding(.vertical, LopanSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                    .fill(LopanColors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                            .stroke(LopanColors.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid Style

    private var gridSelector: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: LopanSpacing.sm
        ) {
            ForEach(availableTypes) { type in
                chartTypeCard(type)
            }
        }
    }

    private func chartTypeCard(_ type: ChartType) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = type
            }
        }) {
            VStack(spacing: LopanSpacing.xs) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .foregroundColor(selectedType == type ? LopanColors.primary : LopanColors.textSecondary)

                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(selectedType == type ? .semibold : .regular)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, LopanSpacing.sm)
            .padding(.vertical, LopanSpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                    .fill(selectedType == type ?
                          LopanColors.primary.opacity(0.1) : LopanColors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: LopanCornerRadius.sm)
                            .stroke(
                                selectedType == type ?
                                LopanColors.primary : LopanColors.border,
                                lineWidth: selectedType == type ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityHint(type.description)
        .accessibilityAddTraits(selectedType == type ? [.isSelected] : [])
    }

    // MARK: - Description View

    private var descriptionView: some View {
        HStack(spacing: LopanSpacing.sm) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(LopanColors.info)

            Text(selectedType.description)
                .font(.caption)
                .foregroundColor(LopanColors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, LopanSpacing.sm)
        .padding(.vertical, LopanSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: LopanCornerRadius.xs)
                .fill(LopanColors.info.opacity(0.1))
        )
    }
}

// MARK: - Convenience Initializers

extension ChartTypeSelector {
    /// Create selector for specific analysis mode with suitable chart types
    static func forAnalysisMode(
        _ mode: AnalysisMode,
        selectedType: Binding<ChartType>,
        style: SelectorStyle = .pills,
        showDescription: Bool = false
    ) -> ChartTypeSelector {
        ChartTypeSelector(
            selectedType: selectedType,
            availableTypes: ChartType.suitableTypes(for: mode),
            style: style,
            showDescription: showDescription
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ChartTypeSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            Group {
                Text("Segmented Style")
                    .font(.headline)
                ChartTypeSelector(
                    selectedType: .constant(.pie),
                    availableTypes: [.pie, .bar, .line],
                    style: .segmented
                )

                Text("Pills Style")
                    .font(.headline)
                ChartTypeSelector(
                    selectedType: .constant(.donut),
                    style: .pills,
                    showDescription: true
                )

                Text("Menu Style")
                    .font(.headline)
                ChartTypeSelector(
                    selectedType: .constant(.bar),
                    style: .menu
                )

                Text("Grid Style")
                    .font(.headline)
                ChartTypeSelector(
                    selectedType: .constant(.area),
                    availableTypes: [.pie, .bar, .line, .area],
                    style: .grid
                )
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif