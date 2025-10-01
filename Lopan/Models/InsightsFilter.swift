//
//  InsightsFilter.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/30.
//  Filter models for Insights analytics with advanced filtering capabilities
//

import Foundation
import SwiftUI

// MARK: - Insights Filter

/// Filter configuration for Insights data
struct InsightsFilter: Identifiable, Codable, Hashable {
    let id: UUID
    var type: FilterType
    var isActive: Bool

    init(id: UUID = UUID(), type: FilterType, isActive: Bool = true) {
        self.id = id
        self.type = type
        self.isActive = isActive
    }

    enum FilterType: Codable, Hashable {
        case valueRange(min: Double, max: Double)
        case categories(selected: Set<String>)
        case dateRange(start: Date, end: Date)
        case sortOrder(SortOrder)
        case threshold(value: Double, operation: ComparisonOperation)

        enum CodingKeys: String, CodingKey {
            case type
            case valueRangeMin, valueRangeMax
            case categories
            case dateRangeStart, dateRangeEnd
            case sortOrder
            case thresholdValue, thresholdOperation
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .valueRange(let min, let max):
                try container.encode("valueRange", forKey: .type)
                try container.encode(min, forKey: .valueRangeMin)
                try container.encode(max, forKey: .valueRangeMax)

            case .categories(let selected):
                try container.encode("categories", forKey: .type)
                try container.encode(Array(selected), forKey: .categories)

            case .dateRange(let start, let end):
                try container.encode("dateRange", forKey: .type)
                try container.encode(start, forKey: .dateRangeStart)
                try container.encode(end, forKey: .dateRangeEnd)

            case .sortOrder(let order):
                try container.encode("sortOrder", forKey: .type)
                try container.encode(order, forKey: .sortOrder)

            case .threshold(let value, let operation):
                try container.encode("threshold", forKey: .type)
                try container.encode(value, forKey: .thresholdValue)
                try container.encode(operation, forKey: .thresholdOperation)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "valueRange":
                let min = try container.decode(Double.self, forKey: .valueRangeMin)
                let max = try container.decode(Double.self, forKey: .valueRangeMax)
                self = .valueRange(min: min, max: max)

            case "categories":
                let categories = try container.decode([String].self, forKey: .categories)
                self = .categories(selected: Set(categories))

            case "dateRange":
                let start = try container.decode(Date.self, forKey: .dateRangeStart)
                let end = try container.decode(Date.self, forKey: .dateRangeEnd)
                self = .dateRange(start: start, end: end)

            case "sortOrder":
                let order = try container.decode(SortOrder.self, forKey: .sortOrder)
                self = .sortOrder(order)

            case "threshold":
                let value = try container.decode(Double.self, forKey: .thresholdValue)
                let operation = try container.decode(ComparisonOperation.self, forKey: .thresholdOperation)
                self = .threshold(value: value, operation: operation)

            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown filter type")
            }
        }
    }

    enum SortOrder: String, Codable, CaseIterable, Identifiable, Hashable {
        case valueAscending = "value_asc"
        case valueDescending = "value_desc"
        case nameAscending = "name_asc"
        case nameDescending = "name_desc"
        case dateNewest = "date_newest"
        case dateOldest = "date_oldest"

        var id: String { rawValue }

        var displayName: LocalizedStringKey {
            switch self {
            case .valueAscending: return "insights_sort_value_asc"
            case .valueDescending: return "insights_sort_value_desc"
            case .nameAscending: return "insights_sort_name_asc"
            case .nameDescending: return "insights_sort_name_desc"
            case .dateNewest: return "insights_sort_date_newest"
            case .dateOldest: return "insights_sort_date_oldest"
            }
        }

        var systemImage: String {
            switch self {
            case .valueAscending, .nameAscending, .dateOldest:
                return "arrow.up"
            case .valueDescending, .nameDescending, .dateNewest:
                return "arrow.down"
            }
        }
    }

    enum ComparisonOperation: String, Codable, CaseIterable, Hashable {
        case greaterThan = "gt"
        case lessThan = "lt"
        case equalTo = "eq"
        case greaterThanOrEqual = "gte"
        case lessThanOrEqual = "lte"

        var displayName: LocalizedStringKey {
            switch self {
            case .greaterThan: return "insights_filter_greater_than"
            case .lessThan: return "insights_filter_less_than"
            case .equalTo: return "insights_filter_equal_to"
            case .greaterThanOrEqual: return "insights_filter_gte"
            case .lessThanOrEqual: return "insights_filter_lte"
            }
        }

        var symbol: String {
            switch self {
            case .greaterThan: return ">"
            case .lessThan: return "<"
            case .equalTo: return "="
            case .greaterThanOrEqual: return "≥"
            case .lessThanOrEqual: return "≤"
            }
        }
    }

    // MARK: - Display Properties

    var displayLabel: String {
        switch type {
        case .valueRange(let min, let max):
            return "\(Int(min))-\(Int(max))"

        case .categories(let selected):
            if selected.count == 1 {
                return selected.first ?? ""
            } else {
                return "\(selected.count) 类别"
            }

        case .dateRange(let start, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"

        case .sortOrder(let order):
            // Convert LocalizedStringKey to String
            let key = "\(order.displayName)"
            return NSLocalizedString(key, comment: "")

        case .threshold(let value, let operation):
            return "\(operation.symbol) \(Int(value))"
        }
    }

    var icon: String {
        switch type {
        case .valueRange: return "slider.horizontal.3"
        case .categories: return "square.grid.2x2"
        case .dateRange: return "calendar.badge.clock"
        case .sortOrder: return "arrow.up.arrow.down"
        case .threshold: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: Color {
        switch type {
        case .valueRange: return LopanColors.Jewel.sapphire
        case .categories: return LopanColors.Jewel.emerald
        case .dateRange: return LopanColors.Jewel.amethyst
        case .sortOrder: return LopanColors.primary
        case .threshold: return LopanColors.Jewel.ruby
        }
    }
}

// MARK: - Filter Presets

extension InsightsFilter {
    /// Common filter presets
    enum Preset {
        case topPerformers
        case lowStock
        case recentActivity
        case highValue
        case alphabetical

        var filter: InsightsFilter {
            switch self {
            case .topPerformers:
                return InsightsFilter(
                    type: .sortOrder(.valueDescending),
                    isActive: true
                )

            case .lowStock:
                return InsightsFilter(
                    type: .threshold(value: 10, operation: .lessThan),
                    isActive: true
                )

            case .recentActivity:
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                return InsightsFilter(
                    type: .dateRange(start: sevenDaysAgo, end: Date()),
                    isActive: true
                )

            case .highValue:
                return InsightsFilter(
                    type: .threshold(value: 100, operation: .greaterThan),
                    isActive: true
                )

            case .alphabetical:
                return InsightsFilter(
                    type: .sortOrder(.nameAscending),
                    isActive: true
                )
            }
        }

        var displayName: LocalizedStringKey {
            switch self {
            case .topPerformers: return "insights_preset_top_performers"
            case .lowStock: return "insights_preset_low_stock"
            case .recentActivity: return "insights_preset_recent"
            case .highValue: return "insights_preset_high_value"
            case .alphabetical: return "insights_preset_alphabetical"
            }
        }
    }
}

// MARK: - Filter Application

extension InsightsFilter {
    /// Apply this filter to a value
    func applies(to value: Double) -> Bool {
        guard isActive else { return true }

        switch type {
        case .valueRange(let min, let max):
            return value >= min && value <= max

        case .threshold(let threshold, let operation):
            switch operation {
            case .greaterThan: return value > threshold
            case .lessThan: return value < threshold
            case .equalTo: return value == threshold
            case .greaterThanOrEqual: return value >= threshold
            case .lessThanOrEqual: return value <= threshold
            }

        default:
            return true
        }
    }

    /// Apply this filter to a category
    func applies(to category: String) -> Bool {
        guard isActive else { return true }

        switch type {
        case .categories(let selected):
            return selected.isEmpty || selected.contains(category)
        default:
            return true
        }
    }

    /// Apply this filter to a date
    func applies(to date: Date) -> Bool {
        guard isActive else { return true }

        switch type {
        case .dateRange(let start, let end):
            return date >= start && date <= end
        default:
            return true
        }
    }
}

// MARK: - Preview

#Preview("Filter Display") {
    VStack(spacing: 12) {
        ForEach([
            InsightsFilter(type: .valueRange(min: 10, max: 50)),
            InsightsFilter(type: .categories(selected: ["A", "B", "C"])),
            InsightsFilter(type: .sortOrder(.valueDescending)),
            InsightsFilter(type: .threshold(value: 100, operation: .greaterThan))
        ]) { filter in
            HStack {
                Image(systemName: filter.icon)
                    .foregroundColor(filter.color)

                Text(filter.displayLabel)
                    .font(.caption)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    .padding()
}