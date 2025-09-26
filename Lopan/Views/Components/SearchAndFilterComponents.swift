//
//  SearchAndFilterComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import Combine

// MARK: - Debounced Search Observable Object
@MainActor
class DebouncedSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedSearchText = ""
    @Published var isSearching = false
    
    private var searchCancellable: AnyCancellable?
    private let debounceTime: TimeInterval
    
    init(debounceTime: TimeInterval = 0.5) {
        self.debounceTime = debounceTime
        setupDebounce()
    }
    
    private func setupDebounce() {
        searchCancellable = $searchText
            .removeDuplicates()
            .debounce(for: .seconds(debounceTime), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isSearching = false
            })
            .assign(to: \.debouncedSearchText, on: self)
        
        // Track when user is actively typing
        _ = $searchText
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.isSearching = true
            }
    }
    
    func clearSearch() {
        searchText = ""
    }
}

// MARK: - Advanced Search Bar
struct AdvancedSearchBar: View {
    @StateObject private var searchViewModel = DebouncedSearchViewModel()
    @Binding var searchText: String
    let placeholder: String
    let showSearchingIndicator: Bool
    let onSearchTextChanged: ((String) -> Void)?
    
    init(
        searchText: Binding<String>,
        placeholder: String = "搜索...",
        showSearchingIndicator: Bool = true,
        onSearchTextChanged: ((String) -> Void)? = nil
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.showSearchingIndicator = showSearchingIndicator
        self.onSearchTextChanged = onSearchTextChanged
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Search icon or loading indicator
            if searchViewModel.isSearching && showSearchingIndicator {
                ProgressView()
                    .scaleEffect(0.8)
                    .accessibilityLabel("正在搜索")
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            
            // Search text field
            TextField(placeholder, text: $searchViewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityLabel("搜索输入框")
                .accessibilityValue(searchViewModel.searchText.isEmpty ? "空白" : searchViewModel.searchText)
            
            // Clear button
            if !searchViewModel.searchText.isEmpty {
                Button(action: {
                    searchViewModel.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("清除搜索")
                .accessibilityHint("清除搜索文本")
            }
        }
        .padding(.horizontal)
        .onChange(of: searchViewModel.debouncedSearchText) { _, newValue in
            searchText = newValue
            onSearchTextChanged?(newValue)
        }
        .onAppear {
            searchViewModel.searchText = searchText
        }
    }
}

// MARK: - Filter Chip
struct GenericFilterChip<T: Hashable & CustomStringConvertible>: View {
    let title: String
    let value: T?
    let isActive: Bool
    let onTap: () -> Void
    let onClear: (() -> Void)?
    
    init(
        _ title: String,
        value: T? = nil,
        isActive: Bool = false,
        onTap: @escaping () -> Void,
        onClear: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.isActive = isActive
        self.onTap = onTap
        self.onClear = onClear
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isActive && onClear != nil {
                    Button(action: { onClear?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(LopanColors.textOnPrimary.opacity(0.8))
                    }
                    .accessibilityLabel("清除\(title)筛选")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(isActive ? 1.0 : 0.98)
            .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("轻点以\(isActive ? "取消" : "应用")\(title)筛选")
    }
    
    private var displayText: String {
        if let value = value {
            return "\(title): \(value.description)"
        } else {
            return title
        }
    }
    
    private var backgroundColor: Color {
        isActive ? LopanColors.info : LopanColors.backgroundTertiary
    }
    
    private var foregroundColor: Color {
        isActive ? LopanColors.textOnPrimary : .primary
    }
    
    private var borderColor: Color {
        isActive ? LopanColors.info : LopanColors.secondary
    }
    
    private var accessibilityLabel: String {
        if let value = value {
            return "\(title)筛选器，当前值：\(value.description)"
        } else {
            return "\(title)筛选器"
        }
    }
}

// MARK: - Filter Bar
struct FilterBar<T: Hashable & CustomStringConvertible>: View {
    let filters: [FilterItem<T>]
    let showClearAll: Bool
    let onClearAll: (() -> Void)?
    
    struct FilterItem<T: Hashable & CustomStringConvertible> {
        let id: String
        let title: String
        let value: T?
        let isActive: Bool
        let onTap: () -> Void
        let onClear: (() -> Void)?
    }
    
    init(
        filters: [FilterItem<T>],
        showClearAll: Bool = true,
        onClearAll: (() -> Void)? = nil
    ) {
        self.filters = filters
        self.showClearAll = showClearAll
        self.onClearAll = onClearAll
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters, id: \.id) { filter in
                    GenericFilterChip(
                        filter.title,
                        value: filter.value,
                        isActive: filter.isActive,
                        onTap: filter.onTap,
                        onClear: filter.onClear
                    )
                }
                
                if showClearAll && filters.contains(where: { $0.isActive }) {
                    Button("清除全部") {
                        onClearAll?()
                    }
                    .font(.subheadline)
                    .foregroundColor(LopanColors.error)
                    .accessibilityLabel("清除所有筛选")
                }
            }
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("筛选选项")
    }
}

// MARK: - Sort Option
struct SortOption<T: Hashable & CustomStringConvertible>: View {
    let title: String
    let value: T
    let currentValue: T?
    let ascending: Bool
    let onSelect: (T, Bool) -> Void
    
    init(
        _ title: String,
        value: T,
        currentValue: T?,
        ascending: Bool = true,
        onSelect: @escaping (T, Bool) -> Void
    ) {
        self.title = title
        self.value = value
        self.currentValue = currentValue
        self.ascending = ascending
        self.onSelect = onSelect
    }
    
    var body: some View {
        Button(action: {
            if currentValue as? AnyHashable == value as? AnyHashable {
                // Toggle direction if same field
                onSelect(value, !ascending)
            } else {
                // Select new field
                onSelect(value, true)
            }
        }) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if currentValue as? AnyHashable == value as? AnyHashable {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .foregroundColor(LopanColors.info)
                        .accessibilityLabel(ascending ? "升序" : "降序")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)排序")
        .accessibilityValue(currentValue as? AnyHashable == value as? AnyHashable ? (ascending ? "升序" : "降序") : "未选中")
        .accessibilityHint("轻点选择排序方式")
    }
}

// MARK: - Search and Filter Container
struct SearchAndFilterContainer<Content: View>: View {
    @StateObject private var searchViewModel = DebouncedSearchViewModel()
    @Binding var searchText: String
    @Binding var isFilterExpanded: Bool
    
    let placeholder: String
    let filterContent: Content
    let onSearchChanged: ((String) -> Void)?
    
    init(
        searchText: Binding<String>,
        isFilterExpanded: Binding<Bool>,
        placeholder: String = "搜索...",
        onSearchChanged: ((String) -> Void)? = nil,
        @ViewBuilder filterContent: () -> Content
    ) {
        self._searchText = searchText
        self._isFilterExpanded = isFilterExpanded
        self.placeholder = placeholder
        self.onSearchChanged = onSearchChanged
        self.filterContent = filterContent()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            AdvancedSearchBar(
                searchText: $searchText,
                placeholder: placeholder,
                onSearchTextChanged: onSearchChanged
            )
            
            // Filter toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFilterExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .accessibilityHidden(true)
                    
                    Text("筛选选项")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isFilterExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .accessibilityHidden(true)
                }
                .foregroundColor(LopanColors.info)
            }
            .accessibilityLabel("筛选选项")
            .accessibilityValue(isFilterExpanded ? "已展开" : "已收起")
            .accessibilityHint("轻点以\(isFilterExpanded ? "收起" : "展开")筛选选项")
            .padding(.horizontal)
            
            // Filter content
            if isFilterExpanded {
                filterContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .background(LopanColors.backgroundTertiary)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Real-time Filter Manager
@MainActor
class FilterManager<T: Hashable>: ObservableObject {
    @Published var activeFilters: [String: T] = [:]
    @Published var searchText = ""
    @Published var sortField: String?
    @Published var sortAscending = true
    
    private var filterSubject = PassthroughSubject<[String: T], Never>()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce filter changes to prevent excessive updates
        filterSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] filters in
                self?.activeFilters = filters
            }
            .store(in: &cancellables)
    }
    
    func setFilter(key: String, value: T?) {
        var currentFilters = activeFilters
        if let value = value {
            currentFilters[key] = value
        } else {
            currentFilters.removeValue(forKey: key)
        }
        filterSubject.send(currentFilters)
    }
    
    func clearAllFilters() {
        filterSubject.send([:])
        searchText = ""
        sortField = nil
        sortAscending = true
    }
    
    func setSort(field: String, ascending: Bool) {
        sortField = field
        sortAscending = ascending
    }
}

// MARK: - Debounced Search Field
struct DebouncedSearchField: View {
    let placeholder: String
    @Binding var searchText: String
    let debounceTime: TimeInterval
    
    @StateObject private var viewModel = DebouncedSearchViewModel()
    
    init(placeholder: String, searchText: Binding<String>, debounceTime: TimeInterval = 0.5) {
        self.placeholder = placeholder
        self._searchText = searchText
        self.debounceTime = debounceTime
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $viewModel.searchText)
                .onChange(of: viewModel.debouncedSearchText) { _, newValue in
                    searchText = newValue
                }
            
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.clearSearch()
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(LopanColors.backgroundTertiary)
        .cornerRadius(10)
    }
}

// MARK: - Filter Chip Group
struct FilterChipGroup: View {
    let title: String
    let options: [String]
    @Binding var selectedOption: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All option chip
                    GenericFilterChip<String>(
                        "全部",
                        isActive: selectedOption.isEmpty,
                        onTap: {
                            selectedOption = ""
                        }
                    )
                    
                    // Individual option chips
                    ForEach(options, id: \.self) { option in
                        GenericFilterChip<String>(
                            option,
                            isActive: selectedOption == option,
                            onTap: {
                                selectedOption = option
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func debouncedSearch(
        searchText: Binding<String>,
        placeholder: String = "搜索...",
        debounceTime: TimeInterval = 0.5,
        onSearchChanged: @escaping (String) -> Void
    ) -> some View {
        self.searchable(text: searchText, prompt: placeholder)
            .onChange(of: searchText.wrappedValue) { _, newValue in
                // Implement debounce logic here if needed
                DispatchQueue.main.asyncAfter(deadline: .now() + debounceTime) {
                    onSearchChanged(newValue)
                }
            }
    }
}