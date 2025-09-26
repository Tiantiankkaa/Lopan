//
//  SmartSuggestionService.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/19.
//  iOS 26 Smart Text Suggestions with Apple Intelligence
//

import Foundation
import NaturalLanguage

/// Smart suggestion service providing intelligent text predictions and contextual suggestions
@available(iOS 26.0, *)
@MainActor
public final class SmartSuggestionService: ObservableObject, Sendable {

    // MARK: - Published Properties
    @Published public var textSuggestions: [TextSuggestion] = []
    @Published public var contextualActions: [ContextualAction] = []
    @Published public var smartSearchResults: [SmartSearchResult] = []

    // MARK: - Private Properties
    private nonisolated(unsafe) let nlLanguageRecognizer = NLLanguageRecognizer()
    private nonisolated(unsafe) let nlTokenizer = NLTokenizer(unit: .word)
    private nonisolated(unsafe) let sentimentAnalyzer = NLModel.init()

    // MARK: - Dependencies
    private nonisolated(unsafe) weak var repositoryFactory: RepositoryFactory?

    // MARK: - Initialization
    public init(repositoryFactory: RepositoryFactory? = nil) {
        self.repositoryFactory = repositoryFactory
        setupNaturalLanguageProcessing()
    }

    // MARK: - Text Suggestions

    /// Generate smart text suggestions based on input
    public func generateTextSuggestions(for input: String, context: SuggestionContext) async {
        guard !input.isEmpty else {
            textSuggestions = []
            return
        }

        let suggestions = await processTextInput(input, context: context)

        await MainActor.run {
            self.textSuggestions = suggestions
        }
    }

    /// Generate contextual actions based on current app state
    public func generateContextualActions(for context: AIAppContext) async {
        let actions = await processAIAppContext(context)

        await MainActor.run {
            self.contextualActions = actions
        }
    }

    /// Perform smart search with natural language understanding
    public func performSmartSearch(query: String, scope: SearchScope) async {
        let results = await processSmartSearch(query, scope: scope)

        await MainActor.run {
            self.smartSearchResults = results
        }
    }

    // MARK: - Clear Methods

    public func clearSuggestions() {
        textSuggestions = []
        contextualActions = []
        smartSearchResults = []
    }

    // MARK: - Private Methods

    private func setupNaturalLanguageProcessing() {
        nlLanguageRecognizer.languageConstraints = [.simplifiedChinese, .english]
        nlTokenizer.setLanguage(.simplifiedChinese)
    }

    private func processTextInput(_ input: String, context: SuggestionContext) async -> [TextSuggestion] {
        var suggestions: [TextSuggestion] = []

        // Detect language and analyze intent
        nlLanguageRecognizer.processString(input)
        let dominantLanguage = nlLanguageRecognizer.dominantLanguage

        // Generate context-aware suggestions
        switch context.type {
        case .customerName:
            suggestions.append(contentsOf: await generateCustomerNameSuggestions(input))
        case .productDescription:
            suggestions.append(contentsOf: await generateProductDescriptionSuggestions(input))
        case .notes:
            suggestions.append(contentsOf: await generateNotesSuggestions(input))
        case .search:
            suggestions.append(contentsOf: await generateSearchSuggestions(input))
        }

        // Add grammar and spelling corrections
        suggestions.append(contentsOf: await generateCorrectionSuggestions(input))

        return suggestions.sorted { $0.confidence > $1.confidence }.prefix(5).map { $0 }
    }

    private func processAIAppContext(_ context: AIAppContext) async -> [ContextualAction] {
        var actions: [ContextualAction] = []

        switch context.currentView {
        case .customerManagement:
            actions.append(contentsOf: await generateCustomerActions(context))
        case .productionDashboard:
            actions.append(contentsOf: await generateProductionActions(context))
        case .inventoryDashboard:
            actions.append(contentsOf: await generateInventoryActions(context))
        case .salespersonDashboard:
            actions.append(contentsOf: await generateSalespersonActions(context))
        }

        return actions
    }

    private func processSmartSearch(_ query: String, scope: SearchScope) async -> [SmartSearchResult] {
        var results: [SmartSearchResult] = []

        // Analyze query intent
        let intent = await analyzeSearchIntent(query)

        switch scope {
        case .customers:
            results.append(contentsOf: await searchCustomers(query, intent: intent))
        case .products:
            results.append(contentsOf: await searchProducts(query, intent: intent))
        case .outOfStock:
            results.append(contentsOf: await searchOutOfStock(query, intent: intent))
        case .all:
            results.append(contentsOf: await searchAll(query, intent: intent))
        }

        return results
    }

    // MARK: - Suggestion Generators

    private func generateCustomerNameSuggestions(_ input: String) async -> [TextSuggestion] {
        guard let customerRepo = repositoryFactory?.customerRepository else { return [] }

        do {
            let customers = try await customerRepo.fetchCustomers()
            let matches = customers.filter { customer in
                customer.name.localizedCaseInsensitiveContains(input) ||
                customer.phone.contains(input)
            }

            return matches.prefix(3).map { customer in
                TextSuggestion(
                    id: UUID().uuidString,
                    text: customer.name,
                    type: .completion,
                    confidence: calculateSimilarity(input, customer.name),
                    metadata: ["customerId": customer.id]
                )
            }
        } catch {
            return []
        }
    }

    private func generateProductDescriptionSuggestions(_ input: String) async -> [TextSuggestion] {
        // Common product description templates
        let templates = [
            "高质量",
            "耐用材料制造",
            "符合行业标准",
            "经过质量检测",
            "适用于多种场景"
        ]

        return templates.filter { $0.localizedCaseInsensitiveContains(input) }.map { template in
            TextSuggestion(
                id: UUID().uuidString,
                text: template,
                type: .template,
                confidence: 0.8,
                metadata: [:]
            )
        }
    }

    private func generateNotesSuggestions(_ input: String) async -> [TextSuggestion] {
        // Common business phrases
        let phrases = [
            "需要跟进",
            "已完成处理",
            "等待客户确认",
            "安排生产",
            "质量良好",
            "按时交付"
        ]

        return phrases.filter { $0.localizedCaseInsensitiveContains(input) }.map { phrase in
            TextSuggestion(
                id: UUID().uuidString,
                text: phrase,
                type: .quickPhrase,
                confidence: 0.7,
                metadata: [:]
            )
        }
    }

    private func generateSearchSuggestions(_ input: String) async -> [TextSuggestion] {
        // Recent search terms would be stored and suggested here
        let recentSearches = ["客户管理", "库存查询", "生产状态", "质量报告"]

        return recentSearches.filter { $0.localizedCaseInsensitiveContains(input) }.map { search in
            TextSuggestion(
                id: UUID().uuidString,
                text: search,
                type: .recentSearch,
                confidence: 0.6,
                metadata: [:]
            )
        }
    }

    private func generateCorrectionSuggestions(_ input: String) async -> [TextSuggestion] {
        // Simplified spell checking - in production, use more sophisticated NLP
        let corrections: [String: String] = [
            "顾客": "客户",
            "産品": "产品",
            "庫存": "库存"
        ]

        return corrections.compactMap { (incorrect, correct) in
            if input.contains(incorrect) {
                let correctedText = input.replacingOccurrences(of: incorrect, with: correct)
                return TextSuggestion(
                    id: UUID().uuidString,
                    text: correctedText,
                    type: .correction,
                    confidence: 0.9,
                    metadata: ["original": input, "corrected": correctedText]
                )
            }
            return nil
        }
    }

    // MARK: - Action Generators

    private func generateCustomerActions(_ context: AIAppContext) async -> [ContextualAction] {
        return [
            ContextualAction(
                id: UUID().uuidString,
                title: "添加新客户",
                description: "快速创建客户档案",
                icon: "person.badge.plus",
                action: .createCustomer,
                confidence: 0.9
            ),
            ContextualAction(
                id: UUID().uuidString,
                title: "导入客户数据",
                description: "从文件导入客户信息",
                icon: "square.and.arrow.down",
                action: .importData(type: "customers"),
                confidence: 0.7
            )
        ]
    }

    private func generateProductionActions(_ context: AIAppContext) async -> [ContextualAction] {
        return [
            ContextualAction(
                id: UUID().uuidString,
                title: "检查生产进度",
                description: "查看当前生产状态",
                icon: "chart.line.uptrend.xyaxis",
                action: .checkProduction,
                confidence: 0.9
            )
        ]
    }

    private func generateInventoryActions(_ context: AIAppContext) async -> [ContextualAction] {
        return [
            ContextualAction(
                id: UUID().uuidString,
                title: "库存盘点",
                description: "进行库存清点",
                icon: "list.clipboard",
                action: .inventoryCount,
                confidence: 0.8
            )
        ]
    }

    private func generateSalespersonActions(_ context: AIAppContext) async -> [ContextualAction] {
        return [
            ContextualAction(
                id: UUID().uuidString,
                title: "查看待处理订单",
                description: "检查需要处理的客户订单",
                icon: "exclamationmark.triangle",
                action: .viewPendingOrders,
                confidence: 0.9
            )
        ]
    }

    // MARK: - Search Methods

    private func analyzeSearchIntent(_ query: String) async -> SearchIntent {
        // Simplified intent analysis
        if query.contains("客户") || query.contains("customer") {
            return .customer
        } else if query.contains("产品") || query.contains("product") {
            return .product
        } else if query.contains("库存") || query.contains("inventory") {
            return .inventory
        } else {
            return .general
        }
    }

    private func searchCustomers(_ query: String, intent: SearchIntent) async -> [SmartSearchResult] {
        // Implementation would search customer repository
        return []
    }

    private func searchProducts(_ query: String, intent: SearchIntent) async -> [SmartSearchResult] {
        // Implementation would search product repository
        return []
    }

    private func searchOutOfStock(_ query: String, intent: SearchIntent) async -> [SmartSearchResult] {
        // Implementation would search out-of-stock repository
        return []
    }

    private func searchAll(_ query: String, intent: SearchIntent) async -> [SmartSearchResult] {
        // Implementation would search across all repositories
        return []
    }

    // MARK: - Utility Methods

    private func calculateSimilarity(_ input: String, _ target: String) -> Double {
        // Simplified similarity calculation
        let commonPrefix = input.commonPrefix(with: target)
        return Double(commonPrefix.count) / Double(max(input.count, target.count))
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, *)
public struct TextSuggestion: Identifiable, Sendable {
    public let id: String
    public let text: String
    public let type: SuggestionType
    public let confidence: Double
    public let metadata: [String: Any]

    public enum SuggestionType: Sendable {
        case completion
        case correction
        case template
        case quickPhrase
        case recentSearch
    }
}

@available(iOS 26.0, *)
public struct ContextualAction: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
    public let action: ActionType
    public let confidence: Double

    public enum ActionType: Sendable {
        case createCustomer
        case importData(type: String)
        case checkProduction
        case inventoryCount
        case viewPendingOrders
    }
}

@available(iOS 26.0, *)
public struct SmartSearchResult: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let type: ResultType
    public let relevance: Double

    public enum ResultType: Sendable {
        case customer
        case product
        case outOfStock
        case production
    }
}

@available(iOS 26.0, *)
public struct SuggestionContext: Sendable {
    public let type: ContextType
    public let metadata: [String: Any]

    public enum ContextType: Sendable {
        case customerName
        case productDescription
        case notes
        case search
    }
}

@available(iOS 26.0, *)
public struct AIAppContext: Sendable {
    public let currentView: ViewType
    public let userRole: UserRole
    public let data: [String: Any]

    public enum ViewType: Sendable {
        case customerManagement
        case productionDashboard
        case inventoryDashboard
        case salespersonDashboard
    }
}

@available(iOS 26.0, *)
public enum SearchScope: Sendable {
    case customers
    case products
    case outOfStock
    case all
}

@available(iOS 26.0, *)
public enum SearchIntent: Sendable {
    case customer
    case product
    case inventory
    case general
}
