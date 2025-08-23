//
//  IntelligentSearchSystem.swift
//  Lopan
//
//  Created by Claude Code - Perfectionist UI/UX Design
//  智能搜索系统 - 每个字符输入都经过精心优化的搜索体验
//

import SwiftUI
import Speech
import Combine

// MARK: - 智能搜索系统主组件
struct IntelligentSearchSystem: View {
    // MARK: - Properties
    @StateObject private var searchEngine = SearchEngine()
    @StateObject private var voiceSearchEngine = VoiceSearchEngine()
    @StateObject private var searchAnalytics = SearchAnalytics()
    
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    let placeholder: String
    let searchScope: SearchScope
    let onSearchResults: ([String]) -> Void
    let onSearchEmpty: () -> Void
    
    // MARK: - State Management
    @State private var isSearchFieldFocused = false
    @State private var showingSuggestions = false
    @State private var showingVoiceSearch = false
    @State private var showingSearchHistory = false
    @State private var currentSuggestions: [SearchSuggestion] = []
    @State private var searchResults: [String] = []
    @State private var isVoiceSearchAvailable = false
    
    // MARK: - Animation States
    @State private var searchFieldScale: CGFloat = 1.0
    @State private var suggestionsOffset: CGFloat = 0
    @State private var searchIconRotation: Double = 0
    
    enum SearchScope {
        case customers
        case products
        case orders
        case global
        
        var title: String {
            switch self {
            case .customers: return "客户"
            case .products: return "产品"
            case .orders: return "订单"
            case .global: return "全局"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 主搜索栏
            mainSearchBar
            
            // 搜索建议和历史记录
            if showingSuggestions || showingSearchHistory {
                searchSuggestionsView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    .zIndex(1)
            }
            
            // 语音搜索界面
            if showingVoiceSearch {
                voiceSearchView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                    .zIndex(2)
            }
        }
        .onAppear {
            setupSearch()
        }
        .onChange(of: searchText) { _, newValue in
            handleSearchTextChange(newValue)
        }
    }
    
    // MARK: - Main Search Bar
    private var mainSearchBar: some View {
        HStack(spacing: 12) {
            // 搜索图标
            searchIcon
            
            // 搜索输入框
            searchTextField
            
            // 语音搜索按钮
            if isVoiceSearchAvailable {
                voiceSearchButton
                    .transition(.scale.combined(with: .opacity))
            }
            
            // 清除按钮
            if !searchText.isEmpty {
                clearSearchButton
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(searchBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(searchBarBorder)
        .scaleEffect(searchFieldScale)
        .shadow(
            color: isSearchFieldFocused ? LopanColors.primary.opacity(0.1) : Color.clear,
            radius: isSearchFieldFocused ? 8 : 0,
            x: 0,
            y: isSearchFieldFocused ? 4 : 0
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSearchFieldFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searchFieldScale)
    }
    
    // MARK: - Search Icon
    private var searchIcon: some View {
        Image(systemName: isSearching ? "magnifyingglass" : "magnifyingglass")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isSearchFieldFocused ? LopanColors.primary : LopanColors.textSecondary)
            .rotationEffect(.degrees(searchIconRotation))
            .scaleEffect(isSearching ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isSearchFieldFocused)
            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: searchIconRotation)
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                if isSearching {
                    searchIconRotation += 36 // 每次旋转36度
                    if searchIconRotation >= 360 {
                        searchIconRotation = 0
                    }
                } else {
                    searchIconRotation = 0
                }
            }
    }
    
    // MARK: - Search Text Field
    private var searchTextField: some View {
        TextField(placeholder, text: $searchText)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.body)
            .foregroundColor(LopanColors.textPrimary)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .onTapGesture {
                handleSearchFieldTap()
            }
            .onReceive(
                Just(searchText)
                    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            ) { _ in
                performSearch()
            }
    }
    
    // MARK: - Voice Search Button
    private var voiceSearchButton: some View {
        Button(action: handleVoiceSearchTap) {
            Image(systemName: voiceSearchEngine.isListening ? "waveform.circle.fill" : "mic.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(voiceSearchEngine.isListening ? LopanColors.error : LopanColors.info)
                .scaleEffect(voiceSearchEngine.isListening ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: voiceSearchEngine.isListening)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("语音搜索")
        .accessibilityHint(voiceSearchEngine.isListening ? "正在监听，点击停止" : "点击开始语音搜索")
    }
    
    // MARK: - Clear Search Button
    private var clearSearchButton: some View {
        Button(action: handleClearSearch) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(LopanColors.textTertiary)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("清除搜索")
    }
    
    // MARK: - Search Bar Visual Properties
    private var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                isSearchFieldFocused
                ? Color(.systemBackground)
                : Color(.systemGray6)
            )
    }
    
    private var searchBarBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                isSearchFieldFocused
                ? LopanColors.primary.opacity(0.3)
                : Color.clear,
                lineWidth: isSearchFieldFocused ? 1.5 : 0
            )
    }
    
    // MARK: - Search Suggestions View
    private var searchSuggestionsView: some View {
        VStack(spacing: 0) {
            if showingSuggestions && !currentSuggestions.isEmpty {
                suggestionsList
            }
            
            if showingSearchHistory && !searchAnalytics.recentSearches.isEmpty {
                searchHistoryList
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .offset(y: suggestionsOffset)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: suggestionsOffset)
    }
    
    // MARK: - Suggestions List
    private var suggestionsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("搜索建议")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textSecondary)
                
                Spacer()
                
                Button("隐藏") {
                    hideSuggestions()
                }
                .font(.caption)
                .foregroundColor(LopanColors.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            ForEach(currentSuggestions.prefix(5), id: \.id) { suggestion in
                SuggestionRow(
                    suggestion: suggestion,
                    searchText: searchText,
                    onTap: { handleSuggestionTap(suggestion) }
                )
            }
        }
    }
    
    // MARK: - Search History List
    private var searchHistoryList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("最近搜索")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(LopanColors.textSecondary)
                
                Spacer()
                
                Button("清除历史") {
                    searchAnalytics.clearSearchHistory()
                    hideSearchHistory()
                }
                .font(.caption)
                .foregroundColor(LopanColors.error)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            ForEach(searchAnalytics.recentSearches.prefix(5), id: \.id) { historyItem in
                SearchHistoryRow(
                    historyItem: historyItem,
                    onTap: { handleHistoryItemTap(historyItem) },
                    onDelete: { searchAnalytics.removeFromHistory(historyItem) }
                )
            }
        }
    }
    
    // MARK: - Voice Search View
    private var voiceSearchView: some View {
        VStack(spacing: 24) {
            // 语音波形动画
            VoiceWaveformView(
                isListening: voiceSearchEngine.isListening,
                amplitude: voiceSearchEngine.audioLevel
            )
            .frame(height: 100)
            
            // 语音搜索状态文本
            Text(voiceSearchStatusText)
                .font(.headline)
                .foregroundColor(LopanColors.textPrimary)
                .multilineTextAlignment(.center)
            
            if let recognizedText = voiceSearchEngine.recognizedText, !recognizedText.isEmpty {
                Text("识别结果: \(recognizedText)")
                    .font(.subheadline)
                    .foregroundColor(LopanColors.textSecondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // 控制按钮
            HStack(spacing: 20) {
                Button(action: cancelVoiceSearch) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                        Text("取消")
                    }
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(LopanColors.textSecondary)
                    .clipShape(Capsule())
                }
                
                Button(action: toggleVoiceListening) {
                    HStack(spacing: 8) {
                        Image(systemName: voiceSearchEngine.isListening ? "stop.fill" : "mic.fill")
                        Text(voiceSearchEngine.isListening ? "停止" : "开始")
                    }
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(voiceSearchEngine.isListening ? LopanColors.error : LopanColors.primary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
    
    private var voiceSearchStatusText: String {
        switch voiceSearchEngine.state {
        case .idle:
            return "点击开始语音搜索"
        case .listening:
            return "正在聆听..."
        case .processing:
            return "正在识别语音..."
        case .completed:
            return "语音识别完成"
        case .error(let message):
            return "识别失败: \(message)"
        }
    }
    
    // MARK: - Action Handlers
    private func setupSearch() {
        // 检查语音搜索可用性
        checkVoiceSearchAvailability()
        
        // 设置搜索引擎
        searchEngine.configure(for: searchScope)
        
        // 监听语音搜索结果
        voiceSearchEngine.onRecognitionComplete = { recognizedText in
            searchText = recognizedText
            showingVoiceSearch = false
            searchEngine.addToHistory(recognizedText)
            
            // 触觉反馈
            EnhancedHapticEngine.shared.perform(.searchResultFound)
        }
        
        voiceSearchEngine.onError = { error in
            // 显示错误提示
            EnhancedHapticEngine.shared.perform(.searchNoResults)
            showingVoiceSearch = false
        }
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        // 更新建议
        updateSuggestions(for: newValue)
        
        // 显示或隐藏建议
        showingSuggestions = !newValue.isEmpty && isSearchFieldFocused
        showingSearchHistory = newValue.isEmpty && isSearchFieldFocused
        
        // 触觉反馈
        if !newValue.isEmpty && newValue.count == 1 {
            EnhancedHapticEngine.shared.light()
        }
    }
    
    private func handleSearchFieldTap() {
        isSearchFieldFocused = true
        
        // 显示搜索历史（如果搜索框为空）或建议
        if searchText.isEmpty {
            showingSearchHistory = true
            showingSuggestions = false
        } else {
            showingSuggestions = true
            showingSearchHistory = false
        }
        
        // 动画效果
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            searchFieldScale = 1.02
            suggestionsOffset = 0
        }
        
        // 触觉反馈
        EnhancedHapticEngine.shared.light()
    }
    
    private func handleVoiceSearchTap() {
        guard isVoiceSearchAvailable else { return }
        
        showingVoiceSearch = true
        hideSuggestions()
        hideSearchHistory()
        
        // 触觉反馈
        EnhancedHapticEngine.shared.perform(.cardLongPress)
    }
    
    private func handleClearSearch() {
        searchText = ""
        searchResults = []
        onSearchEmpty()
        
        // 显示搜索历史
        showingSearchHistory = true
        showingSuggestions = false
        
        // 触觉反馈
        EnhancedHapticEngine.shared.light()
    }
    
    private func handleSuggestionTap(_ suggestion: SearchSuggestion) {
        searchText = suggestion.text
        hideSuggestions()
        isSearchFieldFocused = false
        
        // 记录到搜索历史
        searchAnalytics.addToHistory(suggestion.text, type: .suggestion)
        
        // 触觉反馈
        EnhancedHapticEngine.shared.perform(.selectionToggle)
        
        // 执行搜索
        performSearch()
    }
    
    private func handleHistoryItemTap(_ historyItem: SearchHistoryItem) {
        searchText = historyItem.query
        hideSearchHistory()
        isSearchFieldFocused = false
        
        // 更新历史记录的使用时间
        searchAnalytics.updateHistoryUsage(historyItem)
        
        // 触觉反馈
        EnhancedHapticEngine.shared.perform(.selectionToggle)
        
        // 执行搜索
        performSearch()
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onSearchEmpty()
            return
        }
        
        isSearching = true
        
        searchEngine.search(
            query: searchText,
            scope: searchScope
        ) { results in
            DispatchQueue.main.async {
                isSearching = false
                searchResults = results
                onSearchResults(results)
                
                // 记录搜索
                searchAnalytics.recordSearch(
                    query: searchText,
                    resultCount: results.count,
                    scope: searchScope
                )
                
                // 触觉反馈
                if results.isEmpty {
                    EnhancedHapticEngine.shared.perform(.searchNoResults)
                } else {
                    EnhancedHapticEngine.shared.perform(.searchResultFound)
                }
            }
        }
    }
    
    private func updateSuggestions(for query: String) {
        guard !query.isEmpty else {
            currentSuggestions = []
            return
        }
        
        searchEngine.generateSuggestions(for: query, scope: searchScope) { suggestions in
            DispatchQueue.main.async {
                currentSuggestions = suggestions
            }
        }
    }
    
    private func hideSuggestions() {
        withAnimation(.easeOut(duration: 0.2)) {
            showingSuggestions = false
            suggestionsOffset = -10
        }
    }
    
    private func hideSearchHistory() {
        withAnimation(.easeOut(duration: 0.2)) {
            showingSearchHistory = false
            suggestionsOffset = -10
        }
    }
    
    private func checkVoiceSearchAvailability() {
        voiceSearchEngine.requestPermission { granted in
            DispatchQueue.main.async {
                isVoiceSearchAvailable = granted
            }
        }
    }
    
    private func toggleVoiceListening() {
        if voiceSearchEngine.isListening {
            voiceSearchEngine.stopListening()
        } else {
            voiceSearchEngine.startListening()
        }
        
        // 触觉反馈
        EnhancedHapticEngine.shared.perform(voiceSearchEngine.isListening ? .cardLongPress : .cardTap)
    }
    
    private func cancelVoiceSearch() {
        voiceSearchEngine.stopListening()
        showingVoiceSearch = false
        
        // 触觉反馈
        EnhancedHapticEngine.shared.light()
    }
}

// MARK: - Supporting Views

/// 搜索建议行组件
struct SuggestionRow: View {
    let suggestion: SearchSuggestion
    let searchText: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: suggestion.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(suggestion.iconColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    // 高亮匹配文本
                    Text(highlightedText)
                        .font(.body)
                        .foregroundColor(LopanColors.textPrimary)
                    
                    if let subtitle = suggestion.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(LopanColors.textSecondary)
                    }
                }
                
                Spacer()
                
                if suggestion.isPopular {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(LopanColors.error)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
    }
    
    private var highlightedText: AttributedString {
        var attributedString = AttributedString(suggestion.text)
        
        // 高亮匹配的部分
        if let range = suggestion.text.lowercased().range(of: searchText.lowercased()) {
            let nsRange = NSRange(range, in: suggestion.text)
            let attributedRange = Range(nsRange, in: attributedString)
            
            if let attributedRange = attributedRange {
                attributedString[attributedRange].backgroundColor = LopanColors.primary.opacity(0.2)
                attributedString[attributedRange].font = .body.weight(.semibold)
            }
        }
        
        return attributedString
    }
}

/// 搜索历史行组件
struct SearchHistoryRow: View {
    let historyItem: SearchHistoryItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LopanColors.textTertiary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(historyItem.query)
                            .font(.body)
                            .foregroundColor(LopanColors.textPrimary)
                        
                        Text(historyItem.timestamp.timeAgoDisplay())
                            .font(.caption2)
                            .foregroundColor(LopanColors.textTertiary)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(LopanColors.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// 语音波形视图
struct VoiceWaveformView: View {
    let isListening: Bool
    let amplitude: Double
    
    @State private var waveAnimation: [Double] = Array(repeating: 0.3, count: 5)
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: isListening ? [LopanColors.primary, LopanColors.info] : [Color.gray.opacity(0.3)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 6)
                    .frame(height: CGFloat(20 + waveAnimation[index] * 60))
                    .animation(
                        .easeInOut(duration: 0.5 + Double(index) * 0.1)
                        .repeatForever(autoreverses: true),
                        value: waveAnimation[index]
                    )
            }
        }
        .onChange(of: isListening) { _, newValue in
            updateWaveAnimation(isActive: newValue)
        }
        .onChange(of: amplitude) { _, newValue in
            if isListening {
                updateWaveAmplitude(newValue)
            }
        }
    }
    
    private func updateWaveAnimation(isActive: Bool) {
        if isActive {
            for i in 0..<waveAnimation.count {
                waveAnimation[i] = Double.random(in: 0.3...1.0)
            }
        } else {
            waveAnimation = Array(repeating: 0.3, count: 5)
        }
    }
    
    private func updateWaveAmplitude(_ amplitude: Double) {
        let clampedAmplitude = max(0.3, min(1.0, amplitude))
        for i in 0..<waveAnimation.count {
            waveAnimation[i] = clampedAmplitude * Double.random(in: 0.8...1.2)
        }
    }
}

// MARK: - Supporting Models

struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let subtitle: String?
    let iconName: String
    let iconColor: Color
    let isPopular: Bool
}

struct SearchHistoryItem: Identifiable {
    let id = UUID()
    let query: String
    let timestamp: Date
}

class SearchEngine: ObservableObject {
    func configure(for scope: IntelligentSearchSystem.SearchScope) {
        // Configure search engine
    }
    
    func search(query: String, scope: IntelligentSearchSystem.SearchScope, completion: @escaping ([String]) -> Void) {
        // Simulate search
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(["Result 1", "Result 2", "Result 3"])
        }
    }
    
    func generateSuggestions(for query: String, scope: IntelligentSearchSystem.SearchScope, completion: @escaping ([SearchSuggestion]) -> Void) {
        // Generate suggestions
        let suggestions = [
            SearchSuggestion(text: "\(query) 建议1", subtitle: "建议描述", iconName: "magnifyingglass", iconColor: LopanColors.primary, isPopular: true),
            SearchSuggestion(text: "\(query) 建议2", subtitle: "建议描述", iconName: "magnifyingglass", iconColor: LopanColors.secondary, isPopular: false)
        ]
        DispatchQueue.main.async {
            completion(suggestions)
        }
    }
    
    func addToHistory(_ query: String) {
        // Add to search history
    }
}

class VoiceSearchEngine: ObservableObject {
    @Published var isListening = false
    @Published var recognizedText: String?
    @Published var audioLevel: Double = 0
    @Published var state: VoiceSearchState = .idle
    
    enum VoiceSearchState {
        case idle
        case listening
        case processing
        case completed
        case error(String)
    }
    
    var onRecognitionComplete: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        // Request speech recognition permission
        completion(true)
    }
    
    func startListening() {
        isListening = true
        state = .listening
    }
    
    func stopListening() {
        isListening = false
        state = .idle
    }
}

class SearchAnalytics: ObservableObject {
    @Published var recentSearches: [SearchHistoryItem] = []
    @Published var savedFilters: [String] = []
    
    func addToHistory(_ query: String, type: HistoryType) {
        let item = SearchHistoryItem(query: query, timestamp: Date())
        recentSearches.append(item)
    }
    
    func clearSearchHistory() {
        recentSearches.removeAll()
    }
    
    func removeFromHistory(_ item: SearchHistoryItem) {
        recentSearches.removeAll { $0.id == item.id }
    }
    
    func recordSearch(query: String, resultCount: Int, scope: IntelligentSearchSystem.SearchScope) {
        // Record search analytics
    }
    
    func updateHistoryUsage(_ item: SearchHistoryItem) {
        // Update usage statistics
    }
    
    enum HistoryType {
        case manual, suggestion, voice
    }
}

#Preview {
    IntelligentSearchSystem(
        searchText: Binding.constant(""),
        isSearching: Binding.constant(false),
        placeholder: "搜索客户、产品或订单...",
        searchScope: IntelligentSearchSystem.SearchScope.global,
        onSearchResults: { results in
            print("Found \(results.count) results")
        },
        onSearchEmpty: {
            print("Search cleared")
        }
    )
    .padding()
}